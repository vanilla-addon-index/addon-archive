-- Locale_Bulletin : textes du module "bulletin" (integration de DifficultBulletinBoard ; francais sans accents, anglais).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.bulletin"] = "Recherche de groupe (DBB)",
	["opt.modules.bulletin"] = "Integration de DifficultBulletinBoard",
	["tip.modules.bulletin"] = "Ouvre la fenetre de DifficultBulletinBoard (/sui dbb), l'habille au style ShikiUI et peut memoriser sa position. Ne fait rien si l'addon est absent.",
	["opt.bulletin.skin"] = "Habiller la fenetre de DBB",
	["tip.bulletin.skin"] = "Applique le fond et la bordure du style ShikiUI a la fenetre principale de DifficultBulletinBoard (rien ne change dans son code).",
	["opt.bulletin.rememberpos"] = "Memoriser la position",
	["tip.bulletin.rememberpos"] = "Garde la position de la fenetre de DBB a sa fermeture et la remet a chaque ouverture.",
	["mod.bulletin.sec"] = "DifficultBulletinBoard",
	["mod.bulletin.found"] = "DifficultBulletinBoard est installe : la commande /sui dbb (ou le bouton ci-dessous) ouvre et ferme sa fenetre.",
	["mod.bulletin.missing"] = "DifficultBulletinBoard n'est pas installe ou pas encore charge : ce module ne fait rien.",
	["mod.bulletin.open"] = "Ouvrir / fermer DBB",
	["msg.bulletin.absent"] = "DifficultBulletinBoard (DBB) n'est pas installe ou pas active.",
	["msg.bulletin.nowindow"] = "DBB est charge mais sa fenetre n'existe pas encore.",
	["msg.bulletin.status"] = "DBB present %d, fenetre %d, module actif %d, habillage %d.",
	["help.bulletin"] = "/sui dbb [open|close|status] - ouvre ou ferme DifficultBulletinBoard",
})

SUI.AddStrings("en", {
	["cat.bulletin"] = "Group finder (DBB)",
	["opt.modules.bulletin"] = "DifficultBulletinBoard integration",
	["tip.modules.bulletin"] = "Opens the DifficultBulletinBoard window (/sui dbb), skins it with the ShikiUI style and can remember its position. Does nothing if the addon is missing.",
	["opt.bulletin.skin"] = "Skin the DBB window",
	["tip.bulletin.skin"] = "Applies the ShikiUI style background and border to the main DifficultBulletinBoard window (its code is not modified).",
	["opt.bulletin.rememberpos"] = "Remember the position",
	["tip.bulletin.rememberpos"] = "Keeps the DBB window position when it closes and restores it every time it opens.",
	["mod.bulletin.sec"] = "DifficultBulletinBoard",
	["mod.bulletin.found"] = "DifficultBulletinBoard is installed: the /sui dbb command (or the button below) opens and closes its window.",
	["mod.bulletin.missing"] = "DifficultBulletinBoard is not installed or not loaded yet: this module does nothing.",
	["mod.bulletin.open"] = "Open / close DBB",
	["msg.bulletin.absent"] = "DifficultBulletinBoard (DBB) is not installed or not enabled.",
	["msg.bulletin.nowindow"] = "DBB is loaded but its window does not exist yet.",
	["msg.bulletin.status"] = "DBB present %d, window %d, module on %d, skin %d.",
	["help.bulletin"] = "/sui dbb [open|close|status] - opens or closes DifficultBulletinBoard",
})
