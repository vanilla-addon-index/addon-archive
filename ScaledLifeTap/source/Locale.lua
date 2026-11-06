-- ScaledLifeTap 4.1 - localization
-- Gear patterns are ported from BonusScanner v1.2 (Crowley), trimmed to the
-- bonuses Life Tap cares about: generic spell damage ("D") and shadow damage ("S").

local LOCALES = {}

LOCALES.enUS = {
	LIFETAP      = "Life Tap",
	IMP_LIFETAP  = "Improved Life Tap",
	EQUIP        = "Equip: ",
	SET          = "Set: ",
	PASSIVE = {
		{ "Increases damage done by Shadow spells and effects by up to (%d+)%.", "S" },
		{ "Increases damage and healing done by magical spells and effects by up to (%d+)%.", "D" },
	},
	LOOKUP = {
		["Healing and Spell Damage"]  = "D",
		["Damage and Healing Spells"] = "D",
		["Spell Damage and Healing"]  = "D",
		["Spell Damage"]              = "D",
		["Damage"]                    = "D",
	},
	STAGE1 = { { "Arcane", "ARCANE" }, { "Fire", "FIRE" }, { "Frost", "FROST" }, { "Holy", "HOLY" }, { "Shadow", "SHADOW" }, { "Nature", "NATURE" } },
	STAGE2 = { "Damage", "Effects" },
	OTHER = {
		{ "Minor Wizard Oil", 8 },
		{ "Lesser Wizard Oil", 16 },
		{ "Wizard Oil", 24 },
		{ "Brilliant Wizard Oil", 36 },
		{ "Spell Damage %+15 and %+1%% Spell Critical Strike", 15 },
	},
}
LOCALES.enGB = LOCALES.enUS

LOCALES.deDE = {
	LIFETAP      = "Aderlass",
	IMP_LIFETAP  = "Verbesserter Aderlass",
	EQUIP        = "Anlegen: ",
	SET          = "Set: ",
	PASSIVE = {
		{ "Erhöht durch Schattenzauber und Schatteneffekte zugefügten Schaden um bis zu (%d+)%.", "S" },
		{ "Erhöht durch Zauber und magische Effekte zugefügten Schaden und Heilung um bis zu (%d+)%.", "D" },
	},
	LOOKUP = {
		["Zauberschaden erhöhen"]         = "D",
		["Zauberschaden"]                 = "D",
		["Heilung und Zauberschaden"]     = "D",
		["Zauberschaden und Heilung"]     = "D",
		["Schadenszauber und Heilzauber"] = "D",
		["Schadens- und Heilzauber"]      = "D",
	},
	STAGE1 = { { "Arkan", "ARCANE" }, { "Feuer", "FIRE" }, { "Frost", "FROST" }, { "Heilig", "HOLY" }, { "Schatten", "SHADOW" }, { "Natur", "NATURE" } },
	STAGE2 = { "schaden", "effekte" },
	OTHER = {
		{ "Schwaches Zauberöl", 8 },
		{ "Geringes Zauberöl", 16 },
		{ "Zauberöl", 24 },
		{ "Hervorragendes Zauberöl", 36 },
		{ "Zauberschaden %+15 und %+1%% kritische Zaubertreffer", 15 },
	},
}

LOCALES.frFR = {
	LIFETAP      = "Connexion",
	IMP_LIFETAP  = "Connexion améliorée",
	EQUIP        = "Equipé : ",
	SET          = "Complet : ",
	PASSIVE = {
		{ "Augmente les points de dégâts infligés par les sorts et les effets d'ombre de (%d+)% au maximum.", "S" },
		{ "(%d+)% aux dégâts des sorts d'ombres.", "S" },
		{ "Augmente les soins et dégâts produits par les sorts et effets magiques de (%d+) au maximum.", "D" },
		{ "Augmente les dégâts et les soins produits par les sorts et effets magiques de (%d+) au maximum.", "D" },
	},
	LOOKUP = {
		["Sorts de Dommages"]              = "D",
		["dégâts des sorts"]               = "D",
		["dégâts et les effets des sorts"] = "D",
		["Dégâts et soins"]                = "D",
		["Dommage"]                        = "D",
	},
	STAGE1 = { { "Arcane", "ARCANE" }, { "Feu", "FIRE" }, { "Givre", "FROST" }, { "Sacré", "HOLY" }, { "Ombre", "SHADOW" }, { "Nature", "NATURE" },
	           { "arcanes", "ARCANE" }, { "feu", "FIRE" }, { "givre", "FROST" }, { "ombre", "SHADOW" }, { "nature", "NATURE" } },
	STAGE2 = { "dégâts", "effets" },
	OTHER = {},
}

local L = LOCALES[GetLocale()] or LOCALES.enUS

-- pre-anchor patterns once instead of concatenating "^" .. pattern on every line
for i = 1, table.getn(L.PASSIVE) do L.PASSIVE[i][1] = "^" .. L.PASSIVE[i][1] end
for i = 1, table.getn(L.OTHER) do L.OTHER[i][1] = "^" .. L.OTHER[i][1] end
L.SETNAME = "^(.*) %(%d+/%d+%)$"

SCALEDLIFETAP_L = L
