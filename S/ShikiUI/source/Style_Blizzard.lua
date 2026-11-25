-- Style_Blizzard : style "Blizzard classique" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("blizzard", {
	label = "style.blizzard.label", desc = "style.blizzard.desc",
	c = { bg = "1A1A30F0", panel = "262640F0", inset = "000000CC", border = "CCCCCCFF", text = "FFFFFFFF", dim = "9D9D9DFF", good = "1EFF00FF", warn = "FFD100FF", bad = "FF2020FF" },
	accent = "FFD100", font = "frizqt", outline = "none", fontScale = 1, bar = "blizzard",
	panel = "tooltip", edge = "rounded", button = "blizzard", alpha = 1,
})

SUI.AddStrings("fr", {
	["style.blizzard.label"] = "Blizzard classique",
	["style.blizzard.desc"] = "Le look d'origine du jeu : infobulles a bordure arrondie, police du jeu, boutons classiques, accent or.",
})

SUI.AddStrings("en", {
	["style.blizzard.label"] = "Blizzard classic",
	["style.blizzard.desc"] = "The game's original look: rounded-border tooltips, the game font, classic buttons, gold accent.",
})
