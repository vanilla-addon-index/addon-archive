-- Locale_Esport : textes du module "esport" (francais sans accents, anglais). Une entree par ligne : ["cle"] = "texte".
-- Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.esport"] = "PvP esport",
	["opt.modules.esport"] = "PvP esport (ennemis + DR)",
	["tip.modules.esport"] = "Suivi de combat PvP : jusqu'a 5 ennemis recents (nom, classe, vie, marque), tries par vie croissante, avec suivi des diminishing returns par categorie (etourdissement, peur, racine, silence, disorientation, polymorphe, camouflage). Clic = cibler. Necessite SuperWoW pour les controles ; sinon le journal de combat. Commande : /sui esport.",
	["mod.esport.title"] = "PvP esport",
	["opt.esport.lowfirst"] = "Le plus faible d'abord",
	["tip.esport.lowfirst"] = "Trie les ennemis par vie croissante : le plus proche de la mort en haut de la liste.",
	["opt.esport.drwindow"] = "Fenetre des DR (s)",
	["tip.esport.drwindow"] = "Duree du diminishing returns : un 2e controle de la meme categorie dans cette fenetre n'a que la moitie d'effet, le 3e un quart, ensuite immunise.",
	["help.esport"] = "/sui esport [open|close] - suivi PvP (ennemis, DR, ciblage rapide)",
})

SUI.AddStrings("en", {
	["cat.esport"] = "PvP esport",
	["opt.modules.esport"] = "PvP esport (enemies + DR)",
	["tip.modules.esport"] = "PvP combat tracker: up to 5 recent enemies (name, class, health, mark), sorted by lowest health, with diminishing returns tracking per category (stun, fear, root, silence, disorient, polymorph, sap). Click = target. Needs SuperWoW for controls; otherwise combat log. Command: /sui esport.",
	["mod.esport.title"] = "PvP esport",
	["opt.esport.lowfirst"] = "Lowest health first",
	["tip.esport.lowfirst"] = "Sorts enemies by rising health: the closest to death at the top of the list.",
	["opt.esport.drwindow"] = "DR window (s)",
	["tip.esport.drwindow"] = "Diminishing returns duration: a 2nd control of the same category within this window has only 50% effect, 3rd 25%, then immune.",
	["help.esport"] = "/sui esport [open|close] - PvP tracking (enemies, DR, quick targeting)",
})
