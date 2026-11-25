-- Locale_BuffWatch : textes du module "buffwatch" (francais sans accents, anglais). Une entree par ligne :
-- ["cle"] = "texte". Les toggles par buff (opt.buffwatch.off.<key>) sont ecrits au chargement par Mod_BuffWatch.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["mod.buffwatch.title"] = "Buffs surveilles",
	["cat.buffwatch"] = "Buffs surveilles",
	["mod.buffwatch.desc"] = "Icones grises = buff absent, icone vive = present avec la duree restante. Coche dans les reglages les buffs a suivre pour ta classe.",
	["opt.modules.buffwatch"] = "Buffs surveilles",
	["tip.modules.buffwatch"] = "Suivi des buffs entretenus : icone grise = absent, icone vive = present avec la duree.",
	["opt.buffwatch.on"] = "Activer le suivi",
	["tip.buffwatch.on"] = "Affiche la fenetre de suivi des buffs entretenus.",
	["opt.buffwatch.size"] = "Taille des icones",
	["tip.buffwatch.size"] = "Cote d'une icone en pixels (16 a 48).",
	["opt.buffwatch.timers"] = "Afficher les durees",
	["tip.buffwatch.timers"] = "Temps restant sous chaque icone presente.",
	["opt.buffwatch.scan"] = "Interval de verification (s)",
	["tip.buffwatch.scan"] = "Frequence de lecture des buffs (0,2 a 2 s). Une valeur haute economise le processeur.",
	["tip.buffwatch.off"] = "Coche : ce buff n'est pas surveille (icone cachee).",
	["help.buffwatch"] = "Ouvre la fenetre de suivi des buffs.",
})

SUI.AddStrings("en", {
	["mod.buffwatch.title"] = "Watched buffs",
	["cat.buffwatch"] = "Watched buffs",
	["mod.buffwatch.desc"] = "Gray icons = missing buff, lit icon = present with time left. Tick the buffs to watch for your class in the settings.",
	["opt.modules.buffwatch"] = "Watched buffs",
	["tip.modules.buffwatch"] = "Maintained-buff tracking: gray icon = missing, lit icon = present with time left.",
	["opt.buffwatch.on"] = "Enable tracking",
	["tip.buffwatch.on"] = "Shows the maintained-buff tracking window.",
	["opt.buffwatch.size"] = "Icon size",
	["tip.buffwatch.size"] = "Icon side in pixels (16 to 48).",
	["opt.buffwatch.timers"] = "Show durations",
	["tip.buffwatch.timers"] = "Time left under each present icon.",
	["opt.buffwatch.scan"] = "Check interval (s)",
	["tip.buffwatch.scan"] = "How often buffs are read (0.2 to 2 s). Higher values save CPU.",
	["tip.buffwatch.off"] = "Ticked: this buff is not watched (icon hidden).",
	["help.buffwatch"] = "Opens the buff tracking window.",
})
