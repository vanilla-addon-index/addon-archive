-- Style_Glace : style "Glace" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("glace", {
	label = "style.glace.label", desc = "style.glace.desc",
	c = { bg = "E4F0F8CC", panel = "F2F8FCD9", inset = "C4D8E6E6", border = "7FA6C2FF", text = "12283CFF", dim = "4C6A82FF", good = "1E9E6AFF", warn = "B27A10FF", bad = "C23A3AFF" },
	accent = "blue", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 0.85,
})

SUI.AddStrings("fr", {
	["style.glace.label"] = "Glace",
	["style.glace.desc"] = "Clair bleute semi-transparent, texte bleu marine.",
})

SUI.AddStrings("en", {
	["style.glace.label"] = "Ice",
	["style.glace.desc"] = "Light translucent blue, navy text.",
})
