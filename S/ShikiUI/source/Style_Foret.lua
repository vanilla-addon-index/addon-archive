-- Style_Foret : style "Foret" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("foret", {
	label = "style.foret.label", desc = "style.foret.desc",
	c = { bg = "0C1410F0", panel = "121E17F0", inset = "080E0BFF", border = "2E4A38FF", text = "DCEBDDFF", dim = "88A08CFF", good = "6FDC7FFF", warn = "DDBB44FF", bad = "DD5A48FF" },
	accent = "green", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.foret.label"] = "Foret",
	["style.foret.desc"] = "Vert sombre naturel, accent vert, texte doux.",
})

SUI.AddStrings("en", {
	["style.foret.label"] = "Forest",
	["style.foret.desc"] = "Natural dark green, green accent, soft text.",
})
