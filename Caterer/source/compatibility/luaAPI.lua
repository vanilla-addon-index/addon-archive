_G = getfenv()

local _G = _G
local error = _G.error
local geterrorhandler = _G.geterrorhandler
local type = _G.type
local pairs = _G.pairs
local unpack = _G.unpack
local pcall = _G.pcall
local tostring = _G.tostring
local find, format, sub = _G.string.find, _G.string.format, _G.string.sub
local concat, getn, setn, tremove = _G.table.concat, _G.table.getn, _G.table.setn, _G.table.remove



math.fmod = _G.math.mod

------------
-- select --
------------
function select(n, ...)
	if not (type(n) == "number" or (type(n) == "string" and n == "#")) then
		error(format("bad argument #1 to 'select' (number expected, got %s)", n and type(n) or "no value"), 2)
	end
	
	if n == "#" then
		return getn(arg)
		elseif n == 1 then
		return unpack(arg)
	end
	
	local args = {}
	
	for i = n, getn(arg) do
		args[i-n+1] = arg[i]
	end
	
	return unpack(args)
end

-----------
-- print --
-----------
do
	local LOCAL_ToStringAllTemp = {}
	function tostringall(...)
		local n = getn(arg)
		-- Simple versions for common argument counts
		if (n == 1) then
			return tostring(arg[1])
			elseif (n == 2) then
			return tostring(arg[1]), tostring(arg[2])
			elseif (n == 3) then
			return tostring(arg[1]), tostring(arg[2]), tostring(arg[3])
			elseif (n == 0) then
			return
		end
		
		local needfix
		for i = 1, n do
			local v = arg[i]
			if (type(v) ~= "string") then
				needfix = i
				break
			end
		end
		if (not needfix) then return unpack(arg) end
		
		wipe(LOCAL_ToStringAllTemp)
		for i = 1, needfix - 1 do
			LOCAL_ToStringAllTemp[i] = arg[i]
		end
		for i = needfix, n do
			LOCAL_ToStringAllTemp[i] = tostring(arg[i])
		end
		return unpack(LOCAL_ToStringAllTemp)
	end
	
	local LOCAL_PrintHandler = function(...)
		DEFAULT_CHAT_FRAME:AddMessage(strjoin(" ", tostringall(unpack(arg))))
	end
	
	function setprinthandler(func)
		if (type(func) ~= "function") then
			error("Invalid print handler")
			else
			LOCAL_PrintHandler = func
		end
	end
	
	function getprinthandler() return LOCAL_PrintHandler end
	
	local function print_inner(...)
		local ok, err = pcall(LOCAL_PrintHandler, unpack(arg))
		if (not ok) then
			local func = geterrorhandler()
			func(err)
		end
	end
	
	function print(...)
		pcall(print_inner, unpack(arg))
	end
	
	SLASH_PRINT1 = "/print"
	SlashCmdList["PRINT"] = print
end

-----------------
-- string.join --
-----------------
function string.join(delimiter, ...)
	if type(delimiter) ~= "string" and type(delimiter) ~= "number" then
		error(format("bad argument #1 to 'join' (string expected, got %s)", delimiter and type(delimiter) or "no value"), 2)
	end
	
	if getn(arg) == 0 then
		return ""
	end
	
	return concat(arg, delimiter)
end
strjoin = string.join

------------------
-- string.match --
------------------
function string.match(str, pattern, index)
	if type(str) ~= "string" and type(str) ~= "number" then
		error(format("bad argument #1 to 'match' (string expected, got %s)", str and type(str) or "no value"), 2)
		elseif type(pattern) ~= "string" and type(pattern) ~= "number" then
		error(format("bad argument #2 to 'match' (string expected, got %s)", pattern and type(pattern) or "no value"), 2)
		elseif index and type(index) ~= "number" and (type(index) ~= "string" or index == "") then
		error(format("bad argument #3 to 'match' (number expected, got %s)", index and type(index) or "no value"), 2)
	end
	
	local i1, i2, match, match2 = find(str, pattern, index)
	
	if not match and i2 and i2 >= i1 then
		return sub(str, i1, i2)
		elseif match2 then
		local matches = {find(str, pattern, index)}
		tremove(matches, 2)
		tremove(matches, 1)
		return unpack(matches)
	end
	
	return match
end
strmatch = string.match

----------------
-- table.wipe --
----------------
function table.wipe(t)
	if type(t) ~= "table" then
		error(format("bad argument #1 to 'wipe' (table expected, got %s)", t and type(t) or "no value"), 2)
	end
	
	for k in pairs(t) do
		t[k] = nil
	end
	
	if getn(t) ~= 0 then
		setn(t, 0)
	end
	
	return t
end
wipe = table.wipe

