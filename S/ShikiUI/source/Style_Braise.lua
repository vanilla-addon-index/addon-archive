-- Style_Braise : style "Braise" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("braise", {
	label = "style.braise.label", desc = "style.braise.desc",
	c = { bg = "160D0AF0", panel = "22130EF0", inset = "0C0605FF", border = "5A2C1CFF", text = "F4E4D8FF", dim = "A88A7AFF", good = "7CCB66FF", warn = "F5B040FF", bad = "F05A44FF" },
	accent = "orange", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.braise.label"] = "Braise",
	["style.braise.desc"] = "Brun-rouge chaud, accent orange.",
})

SUI.AddStrings("en", {
	["style.braise.label"] = "Ember",
	["style.braise.desc"] = "Warm red-brown, orange accent.",
})
