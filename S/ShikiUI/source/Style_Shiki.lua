-- Style_Shiki : style "Shiki" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("shiki", {
	label = "style.shiki.label", desc = "style.shiki.desc",
	c = { bg = "111214F2", panel = "181A1DF2", inset = "0C0C0EFF", border = "33363DFF", text = "E6E8EDFF", dim = "9499A6FF", good = "5CCC78FF", warn = "F2C242FF", bad = "E85454FF" },
	accent = "blue", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.shiki.label"] = "Shiki",
	["style.shiki.desc"] = "Le style d'origine : sombre, minimaliste, bordures fines, accent bleu.",
})

SUI.AddStrings("en", {
	["style.shiki.label"] = "Shiki",
	["style.shiki.desc"] = "The original style: dark, minimal, thin borders, blue accent.",
})
