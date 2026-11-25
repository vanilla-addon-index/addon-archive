-- Style_Minuit : style "Minuit" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("minuit", {
	label = "style.minuit.label", desc = "style.minuit.desc",
	c = { bg = "0A0E1AF2", panel = "10162AF2", inset = "060912FF", border = "26325AFF", text = "DCE6FFFF", dim = "7C8AB0FF", good = "4CD6A0FF", warn = "F0C050FF", bad = "F06070FF" },
	accent = "blue", font = "arial", outline = "none", fontScale = 1, bar = "flat",
	panel = "flat", edge = "thin", button = "flat", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.minuit.label"] = "Minuit",
	["style.minuit.desc"] = "Bleu nuit profond, bordures discretes, accent bleu clair.",
})

SUI.AddStrings("en", {
	["style.minuit.label"] = "Midnight",
	["style.minuit.desc"] = "Deep midnight blue, subtle borders, light blue accent.",
})
