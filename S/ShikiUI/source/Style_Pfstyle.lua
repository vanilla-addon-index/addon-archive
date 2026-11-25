-- Style_Pfstyle : style "pfStyle" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("pfstyle", {
	label = "style.pfstyle.label", desc = "style.pfstyle.desc",
	c = { bg = "161616E6", panel = "1E1E1EE6", inset = "0A0A0AFF", border = "000000FF", text = "FFFFFFFF", dim = "AAAAAAFF", good = "33FF66FF", warn = "FFD633FF", bad = "FF4D4DFF" },
	accent = "blue", font = "arial", outline = "outline", fontScale = 1, bar = "blizzard",
	panel = "flat", edge = "thin", button = "flat", alpha = 0.9,
})

SUI.AddStrings("fr", {
	["style.pfstyle.label"] = "pfStyle",
	["style.pfstyle.desc"] = "Dans l'esprit des interfaces \"tout-en-un\" : fonds gris sombre translucides, bordure noire, barres en degrade, texte contourne.",
})

SUI.AddStrings("en", {
	["style.pfstyle.label"] = "pfStyle",
	["style.pfstyle.desc"] = "In the spirit of all-in-one interfaces: translucent dark grey panels, black border, gradient bars, outlined text.",
})
