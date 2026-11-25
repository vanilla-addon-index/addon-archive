-- Style_Graphite : style "Graphite" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("graphite", {
	label = "style.graphite.label", desc = "style.graphite.desc",
	c = { bg = "1E1E20F0", panel = "28282BF0", inset = "141415FF", border = "48484DFF", text = "EAEAEAFF", dim = "939399FF", good = "58C878FF", warn = "E8B84AFF", bad = "E5584CFF" },
	accent = "class", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.graphite.label"] = "Graphite",
	["style.graphite.desc"] = "Gris neutre, accent a la couleur de ta classe.",
})

SUI.AddStrings("en", {
	["style.graphite.label"] = "Graphite",
	["style.graphite.desc"] = "Neutral grey, accent in your class color.",
})
