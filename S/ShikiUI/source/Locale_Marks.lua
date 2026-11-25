-- Locale_Marks : textes du module "marks" (francais sans accents, anglais). Une entree par ligne : ["cle"] = "texte".
-- Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.marks"] = "Marques de raid",
	["opt.modules.marks"] = "Marques de raid (ciblage rapide)",
	["tip.modules.marks"] = "Barre des 8 marqueurs de raid : une icone s'allume quand un mob la porte, clic = cibler ce mob. Maj + clic sur une icone = poser le marqueur sur ta cible. Commande : /sui marks.",
	["mod.marks.title"] = "Marques de raid",
	["opt.marks.size"] = "Taille des icones",
	["tip.marks.size"] = "Taille de chaque icone de marqueur en pixels (16 a 40).",
	["opt.marks.vertical"] = "Barre verticale",
	["tip.marks.vertical"] = "Les icones s'empilent verticalement au lieu d'une ligne horizontale.",
	["opt.marks.border"] = "Encadrer les icones",
	["tip.marks.border"] = "Dessine un cadre autour de chaque icone de marqueur.",
	["help.marks"] = "/sui marks [open|close] - barre de ciblage des marques de raid",
})

SUI.AddStrings("en", {
	["cat.marks"] = "Raid marks",
	["opt.modules.marks"] = "Raid marks (quick target)",
	["tip.modules.marks"] = "Bar of the 8 raid target marks: an icon lights up when a mob carries it, click = target that mob. Shift + click on an icon = put that mark on your target. Command: /sui marks.",
	["mod.marks.title"] = "Raid marks",
	["opt.marks.size"] = "Icon size",
	["tip.marks.size"] = "Size of each mark icon in pixels (16 to 40).",
	["opt.marks.vertical"] = "Vertical bar",
	["tip.marks.vertical"] = "Icons stack vertically instead of one horizontal row.",
	["opt.marks.border"] = "Outline icons",
	["tip.marks.border"] = "Draws a frame around each mark icon.",
	["help.marks"] = "/sui marks [open|close] - raid mark targeting bar",
})
