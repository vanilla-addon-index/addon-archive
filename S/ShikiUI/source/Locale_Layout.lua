-- ShikiUI Locale_Layout : textes des mises en page (Layouts.lua). Ajoutes par SUI.AddStrings.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.layout"] = "Mises en page",
	["opt.layout.followrole"] = "La mise en page suit le role",
	["tip.layout.followrole"] = "Quand tu changes de role (tank, soigneur, DPS, PvP), la mise en page choisie se reapplique avec la variante de ce role.",
	["opt.layout.links"] = "Liens entre modules",
	["tip.layout.links"] = "Les modules lies (joueur + incantation + buffs, cible + incantation, barres d'action...) se placent ensemble : deplacer le principal deplace les autres avec leur decalage. Decoche pour tout liberer sans perdre tes liens.",
	["mod.layout.name.classic"] = "Classique",
	["mod.layout.name.shiki"] = "Shiki : classique (bas centre)",
	["mod.layout.name.shikiheal"] = "Shiki : soigneur (raid pres du centre)",
	["mod.layout.name.shikitank"] = "Shiki : tank (grande fenetre de menace)",
	["mod.layout.name.shikicompact"] = "Shiki : compact",
	["msg.layout.unknown"] = "Mise en page inconnue : %s",
	["msg.layout.badrole"] = "Role inconnu : %s. Roles : tank, heal, dps, pvp.",
	["msg.layout.applied"] = "Mise en page appliquee : %s (%d reglages, %d ignores).",
	["msg.layout.reset"] = "Positions reinitialisees.",
	["msg.layout.line"] = "%s %s - %s",
	["help.layout"] = "/sui layout [list | use <id> [role] | reset] - mises en page (positions et tailles, separees du style)",
})

SUI.AddStrings("en", {
	["cat.layout"] = "Layouts",
	["opt.layout.followrole"] = "Layout follows the role",
	["tip.layout.followrole"] = "When you change role (tank, healer, DPS, PvP), the chosen layout is applied again with that role's variant.",
	["opt.layout.links"] = "Links between modules",
	["tip.layout.links"] = "Linked modules (player + cast bar + buffs, target + cast bar, action bars...) are placed together: moving the main one moves the others with their offset. Untick to free everything without losing your links.",
	["mod.layout.name.classic"] = "Classic",
	["mod.layout.name.shiki"] = "Shiki: classic (bottom centre)",
	["mod.layout.name.shikiheal"] = "Shiki: healer (raid near the centre)",
	["mod.layout.name.shikitank"] = "Shiki: tank (large threat window)",
	["mod.layout.name.shikicompact"] = "Shiki: compact",
	["msg.layout.unknown"] = "Unknown layout: %s",
	["msg.layout.badrole"] = "Unknown role: %s. Roles: tank, heal, dps, pvp.",
	["msg.layout.applied"] = "Layout applied: %s (%d settings, %d ignored).",
	["msg.layout.reset"] = "Positions reset.",
	["msg.layout.line"] = "%s %s - %s",
	["help.layout"] = "/sui layout [list | use <id> [role] | reset] - layouts (positions and sizes, separate from the style)",
})
