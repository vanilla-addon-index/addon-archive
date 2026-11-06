-- Model: Serialized comm message (action, data, author, version). Used for addon communication.
---@class CommMessage
---@field action string
---@field data table
---@field dataAge number
---@field author string
---@field addonVersion number

LA = LA or {}
LA.CommMessage = LA.CommMessage or {}

---@param action string
---@param data table
---@param dataAge number
---@return CommMessage
function LA.CommMessage.create(action, data, dataAge)
	return {
		action = action,
		data = data,
		dataAge = dataAge,
		author = UnitName("player"),
		addonVersion = LA.Version or 0,
	}
end

---@param msg CommMessage
---@return string serialized for SendCommMessage
function LA.CommMessage.serialize(msg)
	return table.serialize(msg)
end

---@param serialized string
---@return CommMessage|nil
function LA.CommMessage.deserialize(serialized)
	local ok, msg = pcall(function()
		local fn, err = loadstring(serialized)
		if err then return nil end
		return fn()
	end)
	if ok and msg and msg.action then
		return msg
	end
	return nil
end
