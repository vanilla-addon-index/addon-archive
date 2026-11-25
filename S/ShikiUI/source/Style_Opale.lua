-- Style_Opale : style "Opale" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("opale", {
	label = "style.opale.label", desc = "style.opale.desc",
	c = { bg = "1C2230A0", panel = "262E3E9E", inset = "10141C99", border = "8FA8C8AA", text = "F0F4FAFF", dim = "A9B6C8FF", good = "6FD6A0FF", warn = "F2D06BFF", bad = "F27B7BFF" },
	accent = "blue", font = "arial", outline = "outline", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 0.7,
})

SUI.AddStrings("fr", {
	["style.opale.label"] = "Opale",
	["style.opale.desc"] = "Fonds translucides bleu-gris (on voit le jeu a travers), bordure claire, texte contourne.",
})

SUI.AddStrings("en", {
	["style.opale.label"] = "Opal",
	["style.opale.desc"] = "Translucent blue-grey panels (the game shows through), light border, outlined text.",
})
