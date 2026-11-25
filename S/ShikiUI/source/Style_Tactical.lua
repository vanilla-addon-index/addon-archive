-- Style_Tactical : style "Tactique" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("tactical", {
	label = "style.tactical.label", desc = "style.tactical.desc",
	c = { bg = "0C100CF0", panel = "121812F0", inset = "070A07FF", border = "3A4A33FF", text = "C8D8B8FF", dim = "7C8C70FF", good = "66CC55FF", warn = "D9B833FF", bad = "D95040FF" },
	accent = "green", font = "arial", outline = "outline", fontScale = 0.9, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 0.95,
})

SUI.AddStrings("fr", {
	["style.tactical.label"] = "Tactique",
	["style.tactical.desc"] = "Compact et sobre : fonds vert-noir, texte reduit et contourne, accent vert.",
})

SUI.AddStrings("en", {
	["style.tactical.label"] = "Tactical",
	["style.tactical.desc"] = "Compact and sober: green-black panels, smaller outlined text, green accent.",
})
