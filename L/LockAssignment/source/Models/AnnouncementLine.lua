-- Model: One announcement line (message + target for whisper). Used by announcement builder.
---@class AnnouncementLine
---@field message string
---@field targetName string

LA = LA or {}
LA.AnnouncementLine = LA.AnnouncementLine or {}

---@param message string
---@param targetName string
---@return AnnouncementLine
function LA.AnnouncementLine.create(message, targetName)
	return { message = message, targetName = targetName }
end
