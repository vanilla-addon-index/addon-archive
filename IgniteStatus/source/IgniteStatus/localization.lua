
IGNITESTATUS_VERSION = 1.05;

IGNITESTATUS_TEXT_WELCOME = "|cff3366ffIgnite Status v"..IGNITESTATUS_VERSION.." Loaded |cff20ff20(/is help for options)";

IGNITESTATUS_TEXT_SLASHCOMMAND = "/ignite";

IGNITESTATUS_TEXT_SLASHHELP1 = "/is - Enable/Disable Ignite Status";
IGNITESTATUS_TEXT_SLASHHELP2 = "/is reset - Set the values to the default";
IGNITESTATUS_TEXT_SLASHHELP3 = "/is scale <value> - Sets the scale and adjusts. Default is 1.0";
IGNITESTATUS_TEXT_SLASHHELP4 = "/is summary - Enable/Disable ignite summary";
IGNITESTATUS_TEXT_SLASHHELP5 = "/is lock - Enable/Disable lock";

IGNITESTATUS_TEXT_DEBUGON = "Debug is now enabled.";
IGNITESTATUS_TEXT_DEBUGOFF = "Debug is now disabled.";

IGNITESTATUS_TEXT_OFF = "Ignite Status is now: |cffff2020-OFF-. |cffffffff /is to enable";
IGNITESTATUS_TEXT_ON = "Ignite Status is now: |cff20ff20-ON-";

IGNITESTATUS_EVENT_YOU = "You";

IGNITESTATUS_RESET = "Ignite Status has been reset."

IGNITESTATUS_EVENT_SEARCH = " is afflicted by (.+)";

IGNITESTATUS_EVENT_FADE_SEARCH = "(.+) fades from ";

IGNITESTATUS_EVENT_SCORCH_FADE = "Fire Vulnerability";
IGNITESTATUS_EVENT_IGNITE_FADE = "Ignite";

IGNITESTATUS_EVENT_SCORCH1 = "Fire Vulnerability.";
IGNITESTATUS_EVENT_SCORCH2 = "Fire Vulnerability (2).";
IGNITESTATUS_EVENT_SCORCH3 = "Fire Vulnerability (3).";
IGNITESTATUS_EVENT_SCORCH4 = "Fire Vulnerability (4).";
IGNITESTATUS_EVENT_SCORCH5 = "Fire Vulnerability (5).";

IGNITESTATUS_EVENT_IGNITE1 = "Ignite.";
IGNITESTATUS_EVENT_IGNITE2 = "Ignite (2).";
IGNITESTATUS_EVENT_IGNITE3 = "Ignite (3).";
IGNITESTATUS_EVENT_IGNITE4 = "Ignite (4).";
IGNITESTATUS_EVENT_IGNITE5 = "Ignite (5).";

IGNITESTATUS_EVENT_IGNITEDMG_SEARCH  = " suffers (%d+) Fire damage from your Ignite.";
IGNITESTATUS_EVENT_IGNITEDMGR_SEARCH = " suffers (%d+) Fire damage from your Ignite. %((%d+) resisted%)";

IGNITESTATUS_EVENT_IGNITEDMG_OTHER_SEARCH  = " suffers (%d+) Fire damage from (.+) Ignite.";
IGNITESTATUS_EVENT_IGNITEDMGR_OTHER_SEARCH = " suffers (%d+) Fire damage from (.+) Ignite. %((%d+) resisted%)";

IGNITESTATUS_EVENT_FIRECRIT_SEARCH = " for (%d+) Fire damage.";
IGNITESTATUS_EVENT_FIRECRITR_SEARCH = " for (%d+) Fire damage. %((%d+) resisted%)";

IGNITESTATUS_DEATH_REGEXP = "(.*) dies.";
CHAT_MSG_IGNITESTATUS = "IGNITESTATUS";

-- Sync Messages (Sender, Mob, Charge)
IGNITESTATUS_SYNC_IG = "^IG (.+),(.+),(.+)$"
IGNITESTATUS_SYNC_SC = "^SC (.+),(.+),(.+)$"

-- Sync Messages (Sender, Mob)
IGNITESTATUS_SYNC_DE = "^DE (.+),(.+)$"

-- Sync Messages (Sender, Mob)
IGNITESTATUS_SYNC_IF = "^IF (.+),(.+)$"

-- Sync Messages (Sender, Mob, Owner, TickNum, Dmg)
IGNITESTATUS_SYNC_TK = "^TK (.+),(.+),(.+),(.+),(.+)$"

-- Sync Messages (Sender, Mob)
IGNITESTATUS_SYNC_FC = "^FC (.+),(.+)$"
