-- Style_Elvstyle : style "ElvStyle" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("elvstyle", {
	label = "style.elvstyle.label", desc = "style.elvstyle.desc",
	c = { bg = "141414FF", panel = "1B1B1BFF", inset = "0A0A0AFF", border = "000000FF", text = "E0E0E0FF", dim = "8A8A8AFF", good = "4CCC66FF", warn = "E6B800FF", bad = "E64D4DFF" },
	accent = "class", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.elvstyle.label"] = "ElvStyle",
	["style.elvstyle.desc"] = "Dans l'esprit des interfaces plates et nettes : gris charbon opaque, bordure noire d'un pixel, barres plates, accent a la couleur de ta classe.",
})

SUI.AddStrings("en", {
	["style.elvstyle.label"] = "ElvStyle",
	["style.elvstyle.desc"] = "In the spirit of flat, crisp interfaces: opaque charcoal grey, one-pixel black border, flat bars, accent in your class color.",
})
