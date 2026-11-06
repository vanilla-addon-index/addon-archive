-- Utils: table serialization and LA table helpers.
do
	local function exportstring(s)
		return string.format("%q", s)
	end

	local function GetTableLng(tbl)
		local getN = 0
		for _ in pairs(tbl) do getN = getN + 1 end
		return getN
	end

	function table.serialize(tbl)
		local charS, charE = "   ", "\n"
		local file = ""
		local tables, lookup = { tbl }, { [tbl] = 1 }
		file = file .. ("return {" .. charE)
		for idx, t in ipairs(tables) do
			file = file .. ("-- Table: {" .. idx .. "}" .. charE)
			file = file .. ("{" .. charE)
			local thandled = {}
			for i, v in ipairs(t) do
				thandled[i] = true
				local stype = type(v)
				if stype == "table" then
					if not lookup[v] then
						table.insert(tables, v)
						lookup[v] = GetTableLng(tables)
					end
					file = file .. (charS .. "{" .. lookup[v] .. "}," .. charE)
				elseif stype == "string" then
					file = file .. (charS .. exportstring(v) .. "," .. charE)
				elseif stype == "number" then
					file = file .. (charS .. tostring(v) .. "," .. charE)
				end
			end
			for i, v in pairs(t) do
				if (not thandled[i]) then
					local str = ""
					local stype = type(i)
					if stype == "table" then
						if not lookup[i] then
							table.insert(tables, i)
							lookup[i] = GetTableLng(tables)
						end
						str = charS .. "[{" .. lookup[i] .. "}]="
					elseif stype == "string" then
						str = charS .. "[" .. exportstring(i) .. "]="
					elseif stype == "number" then
						str = charS .. "[" .. tostring(i) .. "]="
					end
					if str ~= "" then
						stype = type(v)
						if stype == "table" then
							if not lookup[v] then
								table.insert(tables, v)
								lookup[v] = GetTableLng(tables)
							end
							file = file .. (str .. "{" .. lookup[v] .. "}," .. charE)
						elseif stype == "string" then
							file = file .. (str .. exportstring(v) .. "," .. charE)
						elseif stype == "number" then
							file = file .. (str .. tostring(v) .. "," .. charE)
						end
					end
				end
			end
			file = file .. ("}," .. charE)
		end
		file = file .. ("}")
		return file
	end

	function table.deserialize(sfile)
		local ftables, err = loadstring(sfile)
		if err then return err end
		local tables = ftables()
		for idx = 1, GetTableLng(tables) do
			local tolinki = {}
			for i, v in pairs(tables[idx]) do
				if type(v) == "table" then
					tables[idx][i] = tables[v[1]]
				end
				if type(i) == "table" and tables[i[1]] then
					table.insert(tolinki, { i, tables[i[1]] })
				end
			end
			for _, v in ipairs(tolinki) do
				tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
			end
		end
		return tables[1]
	end

	function LA.GetOptionIndex(tbl, value)
		local index = {}
		for k, v in pairs(tbl) do index[v] = k end
		local result = index[value]
		if result == nil then result = index["None"] end
		return result
	end

	function LA.GetSoulstoneTargetIndex(tbl, value)
		local index = {}
		for k, v in pairs(tbl) do index[v.Name] = k end
		local result = index[value]
		if result == nil then result = index["None"] end
		return result
	end

	function LA.GetTableLength(T)
		local count = 0
		for _ in pairs(T) do count = count + 1 end
		return count
	end

	function LA.printTable(tbl, indent)
		indent = indent or 0
		local spacing = string.rep("  ", indent)
		if type(tbl) ~= "table" then
			LA.print(spacing .. tostring(tbl))
			return
		end
		for k, v in pairs(tbl) do
			local key = type(k) == "string" and string.format("%q", k) or tostring(k)
			LA.print(spacing .. "[" .. key .. "] = ")
			if type(v) == "table" then
				LA.print("")
				LA.printTable(v, indent + 1)
			else
				LA.print(tostring(v))
			end
		end
	end
end
