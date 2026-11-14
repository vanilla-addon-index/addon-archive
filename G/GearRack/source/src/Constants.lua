if not GearRack.enabled then return end

-- Player text, key binding names and extra set icons.

GearRackUI = GearRackUI or {}
GearRackUIText = GearRackUIText or {}

-- Goblin Brainwashing Device gossip: its name and the "Activate" line's spec number.
GearRackUIText.GBD = "Goblin Brainwashing Device"
GearRackUIText.GBDSpec = "Activate (%d).. Specialization"

--[[ Key bindings ]]--

-- Set bindings are stored per character with the set they equip.
-- To add more, raise .MaxKeyBindings and add matching _EQUIPSET entries here and in Bindings.xml.
GearRackUIText.BINDINGFORMAT = "Equip Set: %s"
GearRackUIText.BINDINGSEARCH = "Equip Set: (.+)"
GearRackUIText.MaxKeyBindings = 10
BINDING_HEADER_GEARRACK = "GearRack"
BINDING_NAME_GEARRACK_EQUIPSET1 = "Equip Set: 1" -- these values change to string.format of BINDINGFORMAT on the binding owner's set
BINDING_NAME_GEARRACK_EQUIPSET2 = "Equip Set: 2"
BINDING_NAME_GEARRACK_EQUIPSET3 = "Equip Set: 3"
BINDING_NAME_GEARRACK_EQUIPSET4 = "Equip Set: 4"
BINDING_NAME_GEARRACK_EQUIPSET5 = "Equip Set: 5"
BINDING_NAME_GEARRACK_EQUIPSET6 = "Equip Set: 6"
BINDING_NAME_GEARRACK_EQUIPSET7 = "Equip Set: 7"
BINDING_NAME_GEARRACK_EQUIPSET8 = "Equip Set: 8"
BINDING_NAME_GEARRACK_EQUIPSET9 = "Equip Set: 9"
BINDING_NAME_GEARRACK_EQUIPSET10 = "Equip Set: 10"


GearRackUIText.CONTROL_ROTATE_TEXT = "Rotate"
GearRackUIText.CONTROL_ROTATE_TOOLTIP	= "Switch the bar between horizontal and vertical."
GearRackUIText.CONTROL_LOCK_TEXT = "Lock"
GearRackUIText.CONTROL_LOCK_TOOLTIP = "Lock the bar. Hold Alt over a locked bar for these buttons."
GearRackUIText.CONTROL_OPTIONS_TEXT = "Settings"
GearRackUIText.CONTROL_OPTIONS_TOOLTIP = "Open Gear sets."
GearRackUIText.OPT_TOOLTIPFOLLOW_TEXT = "Tooltips beside item"
GearRackUIText.OPT_TOOLTIPFOLLOW_TOOLTIP = "Show tooltips beside the item, not in the default spot."
GearRackUIText.OPT_SOULBOUND_TEXT = "Hide tradables"
GearRackUIText.OPT_SOULBOUND_TOOLTIP = "Lists skip tradable items, such as fresh loot. Quest and conjured items still show."
GearRackUIText.OPT_BINDINGS_TEXT = "Show key labels"
GearRackUIText.OPT_BINDINGS_TOOLTIP = "Show each bar button's key."
GearRackUIText.OPT_MENUSHIFT_TEXT = "Lists on Shift only"
GearRackUIText.OPT_MENUSHIFT_TOOLTIP = "Item and trinket lists open only while you hold Shift."
GearRackUIText.INVFRAME_RESIZE_TEXT = "Resize"
GearRackUIText.INVFRAME_RESIZE_TOOLTIP = "Drag to resize the bar."
GearRackUIText.OPT_SHOWEMPTY_TEXT = "Allow empty slots"
GearRackUIText.OPT_SHOWEMPTY_TOOLTIP = "Lists also offer an empty slot to take the item off (needs a free bag slot)."
GearRackUIText.OPT_FLIPMENU_TEXT = "Flip menu"
GearRackUIText.OPT_FLIPMENU_TOOLTIP = "Lists open on the other side of the bar."
GearRackUIText.OPT_RIGHTCLICK_TEXT = "Trinket click mapping"
GearRackUIText.OPT_RIGHTCLICK_TOOLTIP = "In a trinket list: left-click for the top slot, right-click for the bottom. Side-by-side trinket buttons share one list."
GearRackUIText.OPT_SHOWTOOLTIPS_TEXT = "Show tooltips"
GearRackUIText.OPT_SHOWTOOLTIPS_TOOLTIP = "Show tooltips on GearRack buttons and lists."
GearRackUIText.OPT_NOTIFY_TEXT = "Notify when ready"
GearRackUIText.OPT_NOTIFY_TOOLTIP = "Tell you when an item or trinket you used is ready again."
GearRackUIText.OPT_ROTATEMENU_TEXT = "Rotate menu"
GearRackUIText.OPT_ROTATEMENU_TOOLTIP = "Lists run along the bar instead of out from it."
GearRackUIText.OPT_SHOWICON_TEXT = "Minimap buttons"
GearRackUIText.OPT_SHOWICON_TOOLTIP = "Show the Gear sets and Trinkets minimap buttons."
GearRackUIText.OPT_DISABLETOGGLE_TEXT = "Shift-click opens gear sets"
GearRackUIText.OPT_DISABLETOGGLE_TOOLTIP = "Shift-click the Gear sets minimap button for your sets. Off: it shows or hides the bar."
GearRackUIText.OPT_FLIPBAR_TEXT = "Flip bar growth"
GearRackUIText.OPT_FLIPBAR_TOOLTIP = "New buttons go left or up instead of right or down."
GearRackUIText.OPT_ENABLEEVENTS_TEXT = "Enable events"
GearRackUIText.OPT_ENABLEEVENTS_TOOLTIP = "Let the events below change gear. Off stops them all."
GearRackUIText.OPT_SHOWALLEVENTS_TEXT = "Show all"
GearRackUIText.OPT_SHOWALLEVENTS_TOOLTIP = "List every class's events."
GearRackUIText.OPT_COMPACTLIST_TEXT = "Compact"
GearRackUIText.OPT_COMPACTLIST_TOOLTIP = "Smaller rows, so more sets fit."
GearRackUIText.OPT_SAVEDSETSCLOSE_TEXT = "Cancel"
GearRackUIText.OPT_SAVEDSETSCLOSE_TOOLTIP = "Cancel choosing a set."
GearRackUIText.OPT_NOTIFYTHIRTY_TEXT = "Notify at 30 sec"
GearRackUIText.OPT_NOTIFYTHIRTY_TOOLTIP = "Notify 30 seconds before ready instead of when ready."
GearRackUIText.OPT_ALLOWHIDDEN_TEXT = "Allow hidden items"
GearRackUIText.OPT_ALLOWHIDDEN_TOOLTIP = "Alt-click a list item to hide it. Hold Alt while opening the list and Alt-click it to bring it back."
GearRackUIText.OPT_LARGEFONT_TEXT = "Large font"
GearRackUIText.OPT_LARGEFONT_TOOLTIP = "Bigger script editor text."
GearRackUIText.OPT_SQUAREMINIMAP_TEXT = "Square minimap"
GearRackUIText.OPT_SQUAREMINIMAP_TOOLTIP = "The buttons follow a square minimap's edge."
GearRackUIText.OPT_SETLABELS_TEXT = "Show set names"
GearRackUIText.OPT_SETLABELS_TOOLTIP = "Write the set's name on set icons."
GearRackUIText.OPT_AUTOTOGGLE_TEXT = "Click again to restore gear"
GearRackUIText.OPT_AUTOTOGGLE_TOOLTIP = "Picking a worn set from the Sets button puts your previous gear back. Out of combat only. Shift-click always does."
GearRackUIText.OPT_CHARSHEETMENU_TEXT = "Character sheet flyouts"
GearRackUIText.OPT_CHARSHEETMENU_TOOLTIP = "Hover a character window slot to swap to your other items for it."

GearRackUIText.SETS_CLOSE_TEXT = "Close Set Builder"
GearRackUIText.SETS_CLOSE_TOOLTIP = "Close Gear sets. /gr bar shows or hides the bar."
GearRackUIText.SETS_NAMELABEL_TEXT = "Choose a name and icon:"
GearRackUIText.SETS_HIDESET_TEXT = "Hide"
GearRackUIText.SETS_HIDESET_TOOLTIP = "Leave this set out of the Sets button's list. Hold Alt while opening the list to see hidden sets; Alt-click to hide or show one."
GearRackUIText.SETS_BINDBUTTON_TEXT = "Bind Key"
GearRackUIText.SETS_BINDBUTTON_TOOLTIP = "Bind a key to this set."
GearRackUIText.SETS_SAVEBUTTON_TEXT = "Save"
GearRackUIText.SETS_SAVEBUTTON_TOOLTIP = "Save the set under this name. Edits count after saving; key bindings apply at once."
GearRackUIText.SETS_REMOVEBUTTON_TEXT = "Remove"
GearRackUIText.SETS_REMOVEBUTTON_TOOLTIP = "Delete this set. To only leave it out of the list, tick Hide and save."

GearRackUIText.READY = "%s ready!"
GearRackUIText.READYTHIRTY = "%s ready soon!"
GearRackUIText.QUEUED = "Queued: %s"
GearRackUIText.SAVED = "Set %s saved with %d items."
GearRackUIText.BINDCLEAR = "Binding cleared for this set."
GearRackUIText.BINDSET = "Set bound to key %s"


GearRackUIText.COUNTFORMAT = "%d/20"
GearRackUIText.NOSAVEDSETS = "No saved sets."
GearRackUIText.SETTOOLTIPFORMAT = "Set: %s"
GearRackUIText.SETREMOVE = "Set %s removed."
GearRackUIText.EMPTYSET = ""
GearRackUIText.EVENTSSUSPENDED = "Events pause while this window is open."

GearRackUIText.UNDEFINEDEVENT_TEXT = "No set yet"
GearRackUIText.UNDEFINEDEVENT_TOOLTIP = "Click to choose the set this event equips."
GearRackUIText.ENABLEEVENT_TEXT = "Enable event"
GearRackUIText.ENABLEEVENT_TOOLTIP = "Turn this event on or off."

GearRackUIText.EVENTSDELETE_TEXT = "Delete"
GearRackUIText.EVENTSDELETE_TOOLTIP = "Delete this event. Other characters using it keep it; this one loses its set."
GearRackUIText.EVENTSEDIT_TEXT = "Edit"
GearRackUIText.EVENTSEDIT_TOOLTIP = "Edit this event's script. Pick its set with the icon in the list."
GearRackUIText.EVENTSNEW_TEXT = "New"
GearRackUIText.EVENTSNEW_TOOLTIP = "Create an event. Scripts are Lua, like macros."

GearRackUIText.EVENTSSAVE_TEXT = "Save"
GearRackUIText.EVENTSSAVE_TOOLTIP = "Save this event; give it a set when ready. A new name makes a copy."
GearRackUIText.EVENTSTEST_TEXT = "Test"
GearRackUIText.EVENTSTEST_TOOLTIP = "Run the script once to catch errors. The trigger is not checked."
GearRackUIText.EVENTSCANCEL_TEXT = "Back"
GearRackUIText.EVENTSCANCEL_TOOLTIP = "Drop unsaved changes and return to the list."
GearRackUIText.EVENTNAME_TEXT = "Event name"
GearRackUIText.EVENTNAME_TOOLTIP = "Name in the list. Start with a class, such as \"Priest:Shadowform\", so Show all can filter it."
GearRackUIText.EVENTTRIGGER_TEXT = "Trigger"
GearRackUIText.EVENTTRIGGER_TOOLTIP = "The game event that runs the script, such as:\nPLAYER_AURAS_CHANGED: buffs or forms\nPLAYER_REGEN_DISABLED: entering combat\nPLAYER_REGEN_ENABLED: leaving combat"
GearRackUIText.EVENTDELAY_TEXT = "Delay"
GearRackUIText.EVENTDELAY_TOOLTIP = "Seconds after the last trigger; 0 runs at once. A delay runs once per burst, such as BAG_UPDATE."

GearRackUIText.RESETBUTTON_TEXT = "Reset bar"
GearRackUIText.RESETBUTTON_TOOLTIP = "Put the bar back at its default place and size. Sets, events and buttons stay."
GearRackUIText.RESETEVENTSBUTTON_TEXT = "Reset events"
GearRackUIText.RESETEVENTSBUTTON_TOOLTIP = "Restore the included events. Your own events are deleted; GearRack asks first."

GearRackUIText.DisableToggleText = {
	["ON"] = "Left-click: gear sets\nRight-click: equipment options\nShift-left-click: saved-set menu\nDrag: move icon",
	["OFF"] = "Left-click: gear sets\nRight-click: equipment options\nShift-left-click: equipment bar\nDrag: move icon"
}

GearRackUIText.HELP = "GEAR SETS\nSave chosen slots in Sets. Bind a key there or use /gr equip <set>. Events can equip sets for you.\n\nWEAPONS\nHover a weapon button and click a carried weapon. A blocked choice waits; the newest choice per slot wins.\n\nTRINKETS\nBind the worn trinkets in Key Bindings. /gr queues opens priority lists, profiles and delays. A trinket you pick pauses its slot; tick its queue or Alt-click the trinket to resume.\n\nBAR\nBar layout orders the buttons. Alt-click a character window slot to add or remove it; Alt-click the character model for the Sets button. Alt-drag moves the bar.\n\nPOISONS\n/run GearRack.SwapPoison() swaps the off hand to a copy with another poison; pass 16 for the main hand.\n\nRESET\nReset bar restores its place and scale; sets stay. /gr trinkets reset clears trinket settings and lists."



--[[ Extra Icons

	Here you can add more icons available for use in the set builder.
	There are two ways to add an icon:

	1. Draw your own 64x64 uncompressed 32-bit TGA file and put it into Interface\Icons

	2. Use a "built-in" icon by adding its exact path/name to the list below.

	The icons below will list immediately after the icons for the worn gear in the order
	they are listed here.  If you draw your own icon and put it into Interface\Icons,
	you do not need to list it here.  They will be picked up automatically.

]]

GearRackUIExtraIcons = {
	"Interface\\Icons\\INV_Banner_02",
	"Interface\\Icons\\INV_Banner_03",
	-- add new icons here in this format: "Interface\\Icons\\(ExactIconName)",
}

BINDING_NAME_GEARRACK_TOGGLE_BAR = "Toggle equipment bar"

BINDING_NAME_GEARRACK_TOGGLE_EVENTS = "Toggle Events"

BINDING_NAME_GEARRACK_USE_HEAD_ITEM = "Use Head Item"

BINDING_NAME_GEARRACK_USE_NECK_ITEM = "Use Neck Item"

BINDING_NAME_GEARRACK_USE_SHOULDER_ITEM = "Use Shoulder Item"

BINDING_NAME_GEARRACK_USE_CHEST_ITEM = "Use Chest Item"

BINDING_NAME_GEARRACK_USE_WAIST_ITEM = "Use Waist Item"

BINDING_NAME_GEARRACK_USE_LEGS_ITEM = "Use Legs Item"

BINDING_NAME_GEARRACK_USE_FEET_ITEM = "Use Feet Item"

BINDING_NAME_GEARRACK_USE_WRIST_ITEM = "Use Wrist Item"

BINDING_NAME_GEARRACK_USE_HANDS_ITEM = "Use Hands Item"

BINDING_NAME_GEARRACK_USE_TOP_FINGER_ITEM = "Use Top Finger Item"

BINDING_NAME_GEARRACK_USE_BOTTOM_FINGER_ITEM = "Use Bottom Finger Item"

BINDING_NAME_GEARRACK_USE_TOP_TRINKET_ITEM = "Use Trinket 1 (Upper slot)"

BINDING_NAME_GEARRACK_USE_BOTTOM_TRINKET_ITEM = "Use Trinket 2 (Lower slot)"

BINDING_NAME_GEARRACK_USE_BACK_ITEM = "Use Back Item"

BINDING_NAME_GEARRACK_USE_MAIN_HAND_ITEM = "Use Main-Hand Item"

BINDING_NAME_GEARRACK_USE_OFF_HAND_ITEM = "Use Off-Hand Item"

BINDING_NAME_GEARRACK_USE_RANGE_ITEM = "Use ranged item"

BINDING_NAME_GEARRACK_TOGGLETRINKETS = "Toggle Trinkets"

BINDING_NAME_GEARRACK_TOGGLE_SETTINGS = "Open Gear Sets"
