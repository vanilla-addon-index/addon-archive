--[[
	Bagnon Localization file
	Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

--[[ Player text; the client is English only. ]]--

--[[ Keybindings ]]--

BINDING_HEADER_BAGNON = "Bagnon"
BINDING_NAME_BAGNON_TOGGLE = "Toggle Bagnon"
BINDING_NAME_BANKNON_TOGGLE = "Toggle Banknon"
BINDING_NAME_BAGNON_SORT = "Sort Bags"

--[[ Slash Commands ]]--

BAGNON_COMMAND_HELP = "help"
BAGNON_COMMAND_SHOWBAGS = "bags"
BAGNON_COMMAND_SHOWBANK = "bank"
BAGNON_COMMAND_SORT = "sort"
BAGNON_COMMAND_ENCHANTS = "enchants"
BAGNON_COMMAND_FREESLOTS = "freespace"

--[[ Messages from the slash commands ]]--

--/bgn help
BAGNON_HELP_TITLE = "Bagnon commands:"
BAGNON_HELP_SHOWBAGS = "/bgn " .. BAGNON_COMMAND_SHOWBAGS .. " - Show/Hide Bagnon."
BAGNON_HELP_SHOWBANK = "/bgn " .. BAGNON_COMMAND_SHOWBANK .. " - Show/Hide Banknon."
BAGNON_HELP_SORT = "/bgn " .. BAGNON_COMMAND_SORT .. " - Clean up and sort bags."
BAGNON_HELP_FREESLOTS = "/bgn " .. BAGNON_COMMAND_FREESLOTS .. " - Toggle free bag space display."
BAGNON_HELP_ENCHANTS = "/bgn " .. BAGNON_COMMAND_ENCHANTS .. " - Toggle weapon enchant badges."
BAGNON_HELP_HELP = "/bgn " .. BAGNON_COMMAND_HELP .. " - Display slash commands."

--/bgn enchants
BAGNON_ENCHANTS_ENABLED = "Weapon enchant badges enabled."
BAGNON_ENCHANTS_DISABLED = "Weapon enchant badges disabled."

--/bgn freespace
BAGNON_FREESLOTS_ENABLED = "Free bag space display enabled."
BAGNON_FREESLOTS_DISABLED = "Free bag space display disabled."

--[[ UI Text ]]--

--Titles

--These should probably read Inventory of <player> and Bank of <player> in other versions I guess
BAGNON_INVENTORY_TITLE = "%s's Inventory"
BAGNON_BANK_TITLE = "%s's Bank"

--Bag Button
BAGNON_SHOWBAGS = "Show Bags"
BAGNON_HIDEBAGS = "Hide Bags"

--Sort Button
BAGNON_SORT_BAGS = "Sort Bags"
BAGNON_SORT_BANK = "Sort Bank"
BAGNON_SORT_TOOLTIP_LEFT = "<Left-Click> to clean up and sort items."
BAGNON_SORT_TOOLTIP_RIGHT = "<Right-Click> to toggle sort direction (Currently: %s)."
BAGNON_SORT_LEFT_TO_RIGHT = "Top-Left to Bottom-Right"
BAGNON_SORT_RIGHT_TO_LEFT = "Bottom-Right to Top-Left"
BAGNON_SORT_DIRECTION_CHANGED = "Bagnon: Sort direction set to: %s."
BAGNON_CANNOT_SORT_OFFLINE = "Cannot sort bags of an offline character."
BAGNON_CANNOT_SORT_BANK_AWAY = "You must be at a bank to sort bank bags."

--Search
BAGNON_SEARCH = "Search items"
BAGNON_SEARCH_HINT = "Search"
BAGNON_SEARCH_TOOLTIP = "Type a name, a type or a slot, for example Potion, Cloth or Head. Items that do not match are dimmed. Escape clears it."

--Free Slot Counter
BAGNON_FREE_SLOTS_FORMAT = "%d / %d Free"
BAGNON_FREE_SLOTS_TITLE = "Free Space: %d / %d"

--Sort Exclusion / Bag Ignore
BAGNON_AUTOSORT_IGNORED = "Ignored from auto-sort"
BAGNON_AUTOSORT_TOGGLE_IGNORE = "<Alt-Click> or <Right-Click> to toggle sort ignore."
BAGNON_AUTOSORT_IGNORE_ENABLED = "Bagnon: %s will now be ignored by auto-sort."
BAGNON_AUTOSORT_IGNORE_DISABLED = "Bagnon: %s will now be sorted."

--[[ Tooltips ]]--

--Title tooltip
BAGNON_TITLE_TOOLTIP = "<Right-Click> to open up the settings menu."

--Bag Tooltips
BAGNON_BAGS_HIDE = "<Shift-Click> to hide."
BAGNON_BAGS_SHOW = "<Shift-Click> to show."

--[[ Bagnon Forever (other characters' bags) ]]--

--[[ Slash Commands ]]--

BAGNON_FOREVER_COMMAND_DELETE_CHARACTER = "delete"

--[[ Messages from the slash commands ]]--

--/bgn help
BAGNON_FOREVER_HELP_DELETE_CHARACTER = "/bgn " .. BAGNON_FOREVER_COMMAND_DELETE_CHARACTER ..
	" <character> <realm> - Removes the given character's inventory and bank data."

--[[ System Messages ]]--

BAGNON_FOREVER_HAS = "has"
BAGNON_FOREVER_BAGS = "(Bags)"
BAGNON_FOREVER_BANK = "(Bank)"

--[[ Tooltips ]]--

--Total gold on realm
BAGNON_FOREVER_MONEY_ON_REALM = "Total On %s"
