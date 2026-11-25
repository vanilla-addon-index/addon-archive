-- Locale_Ghosts : textes du module "ghosts" (francais sans accents, anglais). Une entree par ligne : ["cle"] = "texte".
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["mod.ghosts.title"] = "Fantomes",
	["cat.ghosts"] = "Fantomes (Perdus)",
	["mod.ghosts.desc"] = "Compte les fantomes invoques par le set Possessions of the Lost (20 s chacun) : combien sont actifs en ce moment, sans limite, avec le temps restant du plus ancien.",
	["opt.modules.ghosts"] = "Fantomes (necropaladin)",
	["tip.modules.ghosts"] = "Compteur des fantomes du set Possessions of the Lost : nombre actif et temps restant.",
	["opt.ghosts.hide"] = "Cacher a zero",
	["tip.ghosts.hide"] = "Masque la fenetre quand aucun fantome n'est actif. Decoche : elle reste visible, grisee.",
	["opt.ghosts.size"] = "Taille de l'icone",
	["tip.ghosts.size"] = "Cote de l'icone en pixels (20 a 64).",
	["opt.ghosts.duration"] = "Duree d'un fantome (s)",
	["tip.ghosts.duration"] = "Duree de vie d'un fantome invoque (20 s pour le set Lost). A changer seulement si le serveur modifie le set.",
	["help.ghosts"] = "Fantomes : /sui ghosts = etat, /sui ghosts reset = remet le compteur a zero.",
	["msg.ghosts.reset"] = "Compteur de fantomes remis a zero.",
	["msg.ghosts.status"] = "Fantomes actifs : %d (invoques depuis la connexion : %d, record simultane : %d).",
})

SUI.AddStrings("en", {
	["mod.ghosts.title"] = "Ghosts",
	["cat.ghosts"] = "Ghosts (the Lost)",
	["mod.ghosts.desc"] = "Counts the ghosts summoned by the Possessions of the Lost set (20 s each): how many are active right now, no cap, with the time left on the oldest.",
	["opt.modules.ghosts"] = "Ghosts (necropaladin)",
	["tip.modules.ghosts"] = "Possessions of the Lost ghost counter: active count and time left.",
	["opt.ghosts.hide"] = "Hide at zero",
	["tip.ghosts.hide"] = "Hides the window when no ghost is active. Unticked: it stays visible, grayed.",
	["opt.ghosts.size"] = "Icon size",
	["tip.ghosts.size"] = "Icon side in pixels (20 to 64).",
	["opt.ghosts.duration"] = "Ghost duration (s)",
	["tip.ghosts.duration"] = "Lifetime of a summoned ghost (20 s for the Lost set). Only change it if the server changes the set.",
	["help.ghosts"] = "Ghosts: /sui ghosts = status, /sui ghosts reset = zero the counter.",
	["msg.ghosts.reset"] = "Ghost counter reset.",
	["msg.ghosts.status"] = "Active ghosts: %d (summoned since login: %d, best at once: %d).",
})
