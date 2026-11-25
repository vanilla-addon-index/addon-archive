-- Locale_Cooldowns : textes du module "cooldowns" (francais sans accents, anglais). Une entree par ligne :
-- ["cle"] = "texte". La cle de commande (help.cooldowns) est ici aussi.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["mod.cooldowns.title"] = "Compteurs de recharge",
	["cat.cooldowns"] = "Compteurs de recharge",
	["mod.cooldowns.desc"] = "Affiche le temps restant directement sur les cadres de recharge de Blizzard (barres par defaut, formes, familier, bijoux). Les barres ShikiUI ont deja leurs compteurs : aucun doublon.",
	["opt.modules.cooldowns"] = "Compteurs de recharge",
	["tip.modules.cooldowns"] = "Temps restant affiche au centre des icones de recharge de Blizzard.",
	["opt.cooldowns.min"] = "Duree minimale affichee (s)",
	["tip.cooldowns.min"] = "Les recharges plus courtes que cette duree ne sont pas annotees.",
	["opt.cooldowns.yellow"] = "Seuil orange (s)",
	["tip.cooldowns.yellow"] = "Sous cette duree restante, le chiffre passe en orange.",
	["opt.cooldowns.red"] = "Seuil rouge (s)",
	["tip.cooldowns.red"] = "Sous cette duree restante, le chiffre passe en rouge (fin de recharge proche).",
	["help.cooldowns"] = "Active le module des compteurs de recharge.",
})

SUI.AddStrings("en", {
	["mod.cooldowns.title"] = "Cooldown sweep",
	["cat.cooldowns"] = "Cooldown sweep",
	["mod.cooldowns.desc"] = "Shows the remaining time right on Blizzard cooldown frames (default bars, stances, pet, trinkets). ShikiUI action bars already have their own texts: no duplicates.",
	["opt.modules.cooldowns"] = "Cooldown sweep",
	["tip.modules.cooldowns"] = "Remaining time drawn on Blizzard cooldown icons.",
	["opt.cooldowns.min"] = "Minimum shown duration (s)",
	["tip.cooldowns.min"] = "Cooldowns shorter than this are not annotated.",
	["opt.cooldowns.yellow"] = "Orange threshold (s)",
	["tip.cooldowns.yellow"] = "Below this remaining time the number turns orange.",
	["opt.cooldowns.red"] = "Red threshold (s)",
	["tip.cooldowns.red"] = "Below this remaining time the number turns red (cooldown ending).",
	["help.cooldowns"] = "Enables the cooldown sweep module.",
})
