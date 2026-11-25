-- Style_Light : style "Clair" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("light", {
	label = "style.light.label", desc = "style.light.desc",
	c = { bg = "F2F2F2F2", panel = "FFFFFFF2", inset = "DCDCDCFF", border = "B0B0B0FF", text = "1E1E1EFF", dim = "5E5E5EFF", good = "2E9E4EFF", warn = "B87800FF", bad = "C93030FF" },
	accent = "blue", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.light.label"] = "Clair",
	["style.light.desc"] = "Minimal clair : fonds blancs, texte sombre, bordures grises.",
})

SUI.AddStrings("en", {
	["style.light.label"] = "Light",
	["style.light.desc"] = "Minimal light: white panels, dark text, grey borders.",
})
