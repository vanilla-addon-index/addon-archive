-- ShikiUI Locale_Target : textes du service de ciblage (Target.lua). Ajoutes par SUI.AddStrings.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["msg.target.caps"] = "Ciblage : plaques de nom %s, SuperWoW %s, UnitXP %s",
	["msg.target.scan"] = "Ennemis proches (source : %s) : %d",
	["msg.target.line"] = "  %s - %s yd - en combat : %s",
	["help.target"] = "/sui target - diagnostic du ciblage (ennemis proches, distance, source)",
})

SUI.AddStrings("en", {
	["msg.target.caps"] = "Targeting: nameplates %s, SuperWoW %s, UnitXP %s",
	["msg.target.scan"] = "Nearby enemies (source: %s): %d",
	["msg.target.line"] = "  %s - %s yd - in combat: %s",
	["help.target"] = "/sui target - targeting diagnostics (nearby enemies, distance, source)",
})
