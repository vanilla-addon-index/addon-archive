-- ShikiUI ClickHeal : soins / sorts au clic sur les cadres de groupe et de raid (facon Puppeteer : liaisons bouton + modificateur).
-- Comportement REECRIT (aucun code de Puppeteer copie ; Puppeteer n'a pas de licence dans son dossier). Ce module ne touche a AUCUNE
-- rotation Shiki* (ShikiwaRotation / ShikiwaHeal / ShikaSwap / ShikatoRotation) : il ne lit ni n'appelle aucune de leurs globales.
-- Cout declare : LIGHT (aucune minuterie, aucun evenement frequent ; une table de 20 liaisons preallouee et relue seulement quand un
-- reglage ou le grimoire change ; un clic = une consultation de table, aucun objet cree).
--
-- LIAISONS : 4 etats de modificateur (aucun, Maj, Ctrl, Alt ; priorite Maj > Ctrl > Alt) x 5 gestes (clic gauche, droit, milieu, roulette
--   haut, roulette bas) = 20 reglages "clickheal.<modificateur>.<geste>". Une valeur : "auto" (liaison de depart de la classe, voir
--   DEFAULTS), "default" (comportement du cadre : cibler / menu), "none" (ne rien faire), "target", "menu", "dispel" (meilleur sort de
--   dissipation connu pour le premier debuff de l'unite), "res" (resurrection de la classe) ou un NOM DE SORT. La liste des sorts proposes
--   est reduite a ceux de la classe du joueur a l'activation.
-- RANGS : "clickheal.rank.<sort>" (0 = rang maximum connu ; N = rang N, ou le plus haut connu en dessous). Le texte de rang envoye au
--   jeu est celui que le GRIMOIRE donne (GetSpellName -> "Rank 3" ou son equivalent local), jamais reconstruit : pas de souci de langue.
-- LANCEMENT : "direct" = CastSpellByName(sort, unite) (SuperWoW) ; "swap" = on cible l'unite, on lance, on rend la cible d'avant
--   (TargetLastTarget / ClearTarget) comme Puppeteer le fait dans core/Bindings.lua (RunTargetedAction) ; "auto" = direct si SuperWoW.
-- RINSE : le jeton "rinse" appelle l'addon Rinse s'il est charge (/rinse = SlashCmdList.RINSE, sinon l'objet Rinse appelable) : il
--   decurse selon SA liste de priorite (pas forcement l'unite cliquee) ; son travail n'est pas duplique. Sans Rinse : repli sur "dispel".
-- HoT : apres un lancement sans SuperWoW, la fin du HoT est notee pour les cadres (SUI.GroupEngine.NoteHot) ; avec SuperWoW c'est
--   UNIT_CASTEVENT (Mod_Group.lua) qui s'en charge.
-- Resurrection automatique (option autores) : un sort lie sur un allie mort devient la resurrection de la classe.
-- SOURCES (relevees dans les addons installes) : CastSpellByName(sort, unite) avec SuperWoW (Puppeteer Bindings.lua), TargetUnit /
--   TargetLastTarget / ClearTarget (idem), sorts de depart par classe, resurrections par classe (Puppeteer Util.lua), sorts de dissipation
--   (Puppeteer PuppeteerSettings.lua, Rinse.lua). Les sorts marques "memoire" dans SPELLS ne figurent dans aucun addon installe : a
--   verifier sur Turtle (un sort inconnu du grimoire est simplement refuse avec un message).
-- GRIMOIRE : bouton "Soins au clic" (enfant de SpellBookFrame, cree par ce module) qui ouvre la page du module ; les sorts qui ont une
--   liaison sont surlignes (bandeau d'accent sous l'icone, option clickheal.mark) et leur infobulle liste les gestes. SpellBookFrame_Update
--   est enveloppee a la main (pas de hooksecurefunc) ; l'enveloppe ne fait plus rien module coupe.
-- NON VERIFIE EN JEU : tout (aucun lancement n'a eu lieu dans le client) ; CastSpellByName(sort, unite) avec SuperWoW ; le retour de cible
--   apres un sort a temps d'incantation ; IsShiftKeyDown / IsControlKeyDown / IsAltKeyDown ; la roulette sur un cadre ; le rang du grimoire.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind, slen, ssub, slower, sgsub = string.find, string.len, string.sub, string.lower, string.gsub

local M = {}
SUI.ClickHeal = M

-- Noms FR officiels des sorts (client frFR depuis OctoWow) : le grimoire FR est indexe vers le nom EN canonique
-- (cles des options / liaisons), et l'incantation utilise le NOM REEL du grimoire (k.bookName). Les noms douteux
-- ont plusieurs candidats : le grimoire decidera (seul le nom reellement present est retenu).
local FRNAMES = {
	PRIEST = { ["Mot de pouvoir : Bouclier"] = "Power Word: Shield", ["Renaissance"] = "Renew", ["Renaissancer"] = "Renew",
		["Soins superieurs"] = "Greater Heal", ["Soins"] = "Heal", ["Soins inferieurs"] = "Lesser Heal", ["Soins rapides"] = "Flash Heal",
		["Priere de soins"] = "Prayer of Healing", ["Nova sacree"] = "Holy Nova", ["Dissipation de la magie"] = "Dispel Magic",
		["Guerison des maladies"] = "Cure Disease", ["Abolir les maladies"] = "Abolish Disease", ["Abolir maladie"] = "Abolish Disease",
		["Mot de pouvoir : Robustesse"] = "Power Word: Fortitude", ["Esprit divin"] = "Divine Spirit",
		["Protection contre l'Ombre"] = "Shadow Protection", ["Gardien contre la peur"] = "Fear Ward",
		["Resurrection"] = "Resurrection" },
	DRUID = { ["Rejuvenation"] = "Rejuvenation", ["Retablissement"] = "Regrowth", ["Toucher guerisseur"] = "Healing Touch",
		["Delivrance de la malediction"] = "Remove Curse", ["Guerison du poison"] = "Cure Poison",
		["Abolir le poison"] = "Abolish Poison", ["Marque du fauve"] = "Mark of the Wild", ["Epines"] = "Thorns",
		["Invocation sylvestre"] = "Innervate", ["Innervation"] = "Innervate", ["Renaissance"] = "Rebirth" },
	PALADIN = { ["Eclair lumineux"] = "Flash of Light", ["Horion sacre"] = "Holy Shock",
		["Lumiere sacree"] = "Holy Light", ["Purification"] = "Cleanse",
		["Purifier"] = "Purify", ["Benediction de Puissance"] = "Blessing of Might", ["Benediction de Sagesse"] = "Blessing of Wisdom",
		["Benediction de Salut"] = "Blessing of Salvation", ["Benediction des Rois"] = "Blessing of Kings",
		["Benediction de Sacrifice"] = "Hand of Sacrifice", ["Benediction de Protection"] = "Hand of Protection",
		["Benediction de Liberte"] = "Hand of Freedom",
		["Main de sacrifice"] = "Hand of Sacrifice", ["Main de protection"] = "Hand of Protection", ["Main de liberte"] = "Hand of Freedom", ["Imposition des mains"] = "Lay on Hands",
		["Redemption"] = "Redemption" },
	SHAMAN = { ["Vague de soins"] = "Healing Wave", ["Vague de soins inferieurs"] = "Lesser Healing Wave",
		["Salve de guerison"] = "Chain Heal", ["Guerison des maladies"] = "Cure Disease", ["Guerison du poison"] = "Cure Poison" },
	MAGE = { ["Delivrance de la malediction mineure"] = "Remove Lesser Curse", ["Intellect des arcanes"] = "Arcane Intellect",
		["Affaiblissement de la magie"] = "Dampen Magic", ["Amplification de la magie"] = "Amplify Magic" },
}

-- Pliage d'accents (UTF-8 FR -> lettres pures) : la casse de Lua ne plie pas les accents, et le grimoire
-- ecrira "Eclair" ou "Eclair" accentue selon le client.
local PLAIN = { ["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i", ["\195\180"] = "o",
	["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u", ["\195\138"] = "e", ["\195\137"] = "e",
	["\195\136"] = "e", ["\195\139"] = "e", ["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o",
	["\195\150"] = "o", ["\195\153"] = "u", ["\195\156"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a",
	["\195\147"] = "o", ["\195\155"] = "u", ["\195\132"] = "a" }
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "[\195\197][\128-\191]", function(seq) return PLAIN[seq] or seq end)
	return out
end

-- FRKEY[fold(nom fr)] = nom EN canonique (toutes classes confondues ; les collisions entre classes sont resolues
-- a la collecte : seul le sort reellement dans le grimoire du joueur est retenu).
M.FRKEY = {}
for _, cls in pairs(FRNAMES) do
	for fr, en in pairs(cls) do M.FRKEY[fold(fr)] = en end
end

-- Turtle / octowow (base du serveur verifiee) : les sorts s'appellent "Hand of Protection / Sacrifice / Freedom" (les "Blessing of ..."
-- n'existent pas) ; c'est donc le nom canonique. L'ancien nom (client vanilla, anciennes liaisons enregistrees) y est rattache.
local ALIAS = { ["Blessing of Sacrifice"] = "Hand of Sacrifice", ["Blessing of Protection"] = "Hand of Protection",
	["Blessing of Freedom"] = "Hand of Freedom" }
M.on = false
M.hasWheel = false
M.known = {}              -- nom de sort -> { max = rang max, txt = { [rang] = "Rank n" }, gen = generation }
M.gen = 0
M.class = nil
M.map = {}                -- 20 liaisons : { kind, spell, cast } (tables reutilisees)
M.bookPending = false
M.lastMsg = 0
M.bound = {}              -- nom de sort -> liste des gestes qui le lancent (surlignage du grimoire et infobulle)

local MODS = { "none", "shift", "ctrl", "alt" }
local BTNS = { "left", "right", "middle", "up", "down" }
local BTN_OF = { LeftButton = 1, RightButton = 2, MiddleButton = 3 }
local TOKENS = { "auto", "default", "none", "target", "menu", "dispel", "rinse", "res" }
M.MODS, M.BTNS, M.TOKENS = MODS, BTNS, TOKENS

-- Sorts proposes par classe. [Puppeteer] / [Rinse] = releve dans l'addon installe ; [memoire] = connaissance du jeu, non relevee ici.
local SPELLS = {
	PRIEST = { "Power Word: Shield", "Renew", "Greater Heal", "Heal", "Lesser Heal", "Flash Heal", "Prayer of Healing", "Holy Nova",
		"Dispel Magic", "Cure Disease", "Abolish Disease", "Power Word: Fortitude", "Divine Spirit", "Shadow Protection",
		"Fear Ward" },                                                                             -- Flash Heal, Priere, Nova : [memoire]
	DRUID = { "Rejuvenation", "Regrowth", "Healing Touch", "Remove Curse", "Cure Poison", "Abolish Poison", "Mark of the Wild",
		"Thorns", "Innervate" },                                                                            -- Regrowth, Innervate : [memoire]
	PALADIN = { "Flash of Light", "Holy Shock", "Holy Light", "Cleanse", "Purify", "Blessing of Might", "Blessing of Wisdom",
		"Blessing of Salvation", "Blessing of Kings", "Hand of Sacrifice", "Hand of Protection", "Hand of Freedom",
		"Lay on Hands" },                                                       -- Lay on Hands, Sacrifice, Protection, Liberte : [memoire]
	SHAMAN = { "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Cure Disease", "Cure Poison" },
	MAGE = { "Remove Lesser Curse", "Arcane Intellect", "Dampen Magic", "Amplify Magic" },                  -- les 3 derniers : [memoire]
}
local CLASS_ORDER = { "PRIEST", "DRUID", "PALADIN", "SHAMAN", "MAGE" }
-- Sorts qui ont des rangs reglables (une option "clickheal.rank.<slug>" chacun).
local RANKED = { "Flash of Light", "Holy Shock", "Holy Light", "Lesser Heal", "Heal", "Greater Heal", "Flash Heal", "Renew", "Power Word: Shield",
	"Rejuvenation", "Regrowth", "Healing Touch", "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Prayer of Healing", "Holy Nova",
	"Hand of Sacrifice", "Hand of Protection" }
M.RANKED = RANKED
-- Resurrections par classe [Puppeteer Util.lua]
local RES = { PRIEST = "Resurrection", PALADIN = "Redemption", SHAMAN = "Ancestral Spirit", DRUID = "Rebirth" }
-- Sorts de dissipation, du plus general au plus precis, et types retires [Puppeteer PuppeteerSettings.lua, Rinse.lua]
local CURE_ORDER = { "Cleanse", "Purify", "Dispel Magic", "Abolish Disease", "Cure Disease", "Abolish Poison", "Cure Poison",
	"Remove Curse", "Remove Lesser Curse" }
local CURES = {
	["Cleanse"] = { Poison = true, Disease = true, Magic = true }, ["Purify"] = { Poison = true, Disease = true },
	["Dispel Magic"] = { Magic = true }, ["Abolish Disease"] = { Disease = true }, ["Cure Disease"] = { Disease = true },
	["Abolish Poison"] = { Poison = true }, ["Cure Poison"] = { Poison = true }, ["Remove Curse"] = { Curse = true },
	["Remove Lesser Curse"] = { Curse = true },
}
-- Liaisons de depart ("auto") : [classe][modificateur][geste] = jeton, nom de sort ou liste (premier sort connu). Inspirees des
-- liaisons de depart de Puppeteer (core/Bindings.lua) ; modifiables a volonte, rien d'autre n'est pose par defaut.
local DEFAULTS = {
	PRIEST = { none = { left = "Power Word: Shield", middle = "Renew", right = { "Greater Heal", "Heal", "Lesser Heal" } },
		shift = { left = "target", right = "menu" }, ctrl = { left = "Power Word: Fortitude", right = "dispel" } },
	DRUID = { none = { left = "Rejuvenation", middle = "Regrowth", right = "Healing Touch" },
		shift = { left = "target", right = "menu" }, ctrl = { left = "Mark of the Wild", right = "dispel" } },
	PALADIN = { none = { left = "Flash of Light", middle = "Holy Shock", right = "Holy Light" },
		shift = { left = "target", right = "menu" }, ctrl = { right = "dispel" } },
	SHAMAN = { none = { left = { "Healing Wave", "Lesser Healing Wave" }, right = "Chain Heal" },
		shift = { left = "target", right = "menu" }, ctrl = { right = "dispel" } },
	MAGE = { shift = { left = "target", right = "menu" }, ctrl = { right = "dispel" } },
}
M.DEFAULTS = DEFAULTS

-- ---------------------------------------------------------------- utilitaires
local function slug(name)
	return string.lower((string.gsub(name, "[^%a]", "")))
end
M.Slug = slug

local function slotKey(mi, bi)
	return "clickheal." .. MODS[mi] .. "." .. BTNS[bi]
end

-- Liste partagee des choix des 20 liaisons (modifiee sur place par SetChoices : le menu et Validate la relisent).
M.choices = {}
local function fillChoices(list)
	for i = getn(M.choices), 1, -1 do M.choices[i] = nil end
	for i = 1, getn(TOKENS) do tinsert(M.choices, TOKENS[i]) end
	for i = 1, getn(list) do tinsert(M.choices, list[i]) end
end

function M.SetChoices(class)
	local list = {}
	if class and SPELLS[class] then
		for i = 1, getn(SPELLS[class]) do tinsert(list, SPELLS[class][i]) end
	elseif not class then
		for c = 1, getn(CLASS_ORDER) do
			local s = SPELLS[CLASS_ORDER[c]]
			for i = 1, getn(s) do
				local dup = false
				for j = 1, getn(list) do
					if list[j] == s[i] then dup = true end
				end
				if not dup then tinsert(list, s[i]) end
			end
		end
	end
	if class and RES[class] then
		tinsert(list, RES[class])
	elseif not class then
		-- toutes les resurrections : une liaison enregistree sur "Resurrection" doit rester valide module coupe (relecture de la config)
		for c = 1, getn(CLASS_ORDER) do
			if RES[CLASS_ORDER[c]] then tinsert(list, RES[CLASS_ORDER[c]]) end
		end
	end
	fillChoices(list)
end
M.SetChoices(nil)

-- ---------------------------------------------------------------- grimoire
function M.Scan()
	if SUI.InCombat() then
		M.bookPending = true
		return
	end
	M.bookPending = false
	local gn = getglobal("GetSpellName")
	if not gn then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	M.gen = M.gen + 1
	M.nSpells = 0
	for i = 1, 1000 do
		local name, rank = gn(i, book)
		if not name then break end
		M.nSpells = i
		-- grimoire FR : le nom reel du grimoire est rattache a son nom EN canonique (cles des options) ;
		-- l'incantation utilisera toujours le nom reel du grimoire (k.bookName)
		local en = M.FRKEY[fold(name)] or ALIAS[name] or name
		local k = M.known[en]
		if not k then
			k = { max = 0, txt = {}, idx = {}, cost = {}, gen = 0 }
			M.known[en] = k
		end
		if k.gen ~= M.gen then
			k.gen = M.gen
			k.max = 0
			for r in pairs(k.txt) do k.txt[r] = nil end
			for r in pairs(k.idx) do k.idx[r] = nil end
			for r in pairs(k.cost) do k.cost[r] = nil end
		end
		local _, _, n = sfind(rank or "", "(%d+)")
		n = tonumber(n) or 0
		if n > k.max then k.max = n end
		k.txt[n] = rank or ""
		k.idx[n] = i                    -- indice du grimoire de ce rang (lecture du cout en mana)
		k.bookName = name
	end
	M.EnsureCostTip()
	M.Rebuild()
end

-- Relecture ponctuelle du grimoire depuis un clic (hors combat, au plus une par seconde).
function M.Recheck()
	local now = GetTime()
	if SUI.InCombat() or now - (M.lastCheck or -10) < 1 then return end
	M.lastCheck = now
	M.Scan()
end

-- Changement de grimoire (respec, nouveau sort) : un balayage tout de suite, un second apres 2 s (le client envoie la rafale
-- d'evenements avant d'avoir fini de mettre le grimoire a jour ; sans ce second passage les sorts restaient "inconnus" jusqu'a /reload).
function M.OnBook()
	M.bookStale = true
	M.Scan()
	if M.bookTask then SUI.Cancel(M.bookTask) end
	M.bookTask = SUI.After(2, function()
		M.bookTask = nil
		if M.on then M.Scan() end
		M.bookStale = (M.nSpells or 0) == 0     -- toujours vide apres 2 s : on retentera au prochain clic
	end, "clickheal.book")
end

function M.IsKnown(name)
	local k = M.known[name]
	return (k and k.gen == M.gen) and true or false
end

-- Texte a envoyer a CastSpellByName pour 'name' selon le rang demande (0 = maximum : le nom seul).
-- Le NOM REEL du grimoire est utilise (frFR : "Eclair lumineux(Rang 2)") ; 'name' reste la cle EN des options.
function M.CastString(name)
	local k = M.known[name]
	if not k or k.gen ~= M.gen then return name end
	local castName = k.bookName or name
	local want = 0
	local key = "clickheal.rank." .. slug(name)
	if C.meta[key] ~= nil then want = C.Get(key) end
	if want <= 0 or k.max <= 0 then return castName end
	for r = want, 1, -1 do
		local t = k.txt[r]
		if t and t ~= "" then return castName .. "(" .. t .. ")" end
	end
	return castName
end

-- ---------------------------------------------------------------- liaisons
local function setEntry(e, kind, spell)
	e.kind = kind
	e.spell = spell
	e.cast = spell and M.CastString(spell) or nil
end

-- Premier sort connu d'une liste (ou le nom seul) ; nil si aucun.
local function firstKnown(v)
	if type(v) == "table" then
		for i = 1, getn(v) do
			if M.IsKnown(v[i]) then return v[i] end
		end
		return nil
	end
	if M.IsKnown(v) then return v end
	return nil
end

local function resolveValue(e, value, mi, bi)
	local auto = false
	if value == "auto" then
		auto = true
		local d = M.class and DEFAULTS[M.class]
		d = d and d[MODS[mi]]
		value = d and d[BTNS[bi]] or "default"
		if type(value) == "table" then
			local s = firstKnown(value)
			if s then
				setEntry(e, "spell", s)
				return
			end
			value = "default"
		end
	end
	if value == "default" or value == "none" or value == "target" or value == "menu" or value == "dispel" or value == "res"
		or value == "rinse" then
		setEntry(e, value, nil)
	elseif auto and not M.IsKnown(value) then
		setEntry(e, "default", nil)           -- liaison de depart d'un sort pas encore appris
	else
		setEntry(e, "spell", value)           -- choix de l'utilisateur : garde meme inconnu, le clic le signale
	end
end

local MODLABEL = { none = "", shift = "mod.clickheal.mod.shift", ctrl = "mod.clickheal.mod.ctrl", alt = "mod.clickheal.mod.alt" }

local function addBound(bound, name, label)
	if not name then return end
	local l = bound[name]
	if not l then
		l = {}
		bound[name] = l
	end
	tinsert(l, label)
end

function M.GestureLabel(mi, bi)
	local pre = MODLABEL[MODS[mi]]
	return (pre ~= "" and L(pre) or "") .. L("choice.clickheal.btn." .. BTNS[bi])
end

function M.Rebuild()
	local wheel = false
	local bound = {}
	for mi = 1, 4 do
		for bi = 1, 5 do
			local idx = (mi - 1) * 5 + bi
			local e = M.map[idx]
			if not e then
				e = { kind = "default" }
				M.map[idx] = e
			end
			local key = slotKey(mi, bi)
			local v = (C.meta[key] ~= nil) and C.Get(key) or "auto"
			resolveValue(e, v, mi, bi)
			if e.kind == "spell" then
				addBound(bound, e.spell, M.GestureLabel(mi, bi))
			elseif e.kind == "dispel" then
				for k = 1, getn(CURE_ORDER) do
					if M.IsKnown(CURE_ORDER[k]) then addBound(bound, CURE_ORDER[k], M.GestureLabel(mi, bi)) end
				end
			elseif e.kind == "res" then
				addBound(bound, RES[M.class or ""], M.GestureLabel(mi, bi))
			end
			if bi >= 4 and e.kind ~= "default" then wheel = true end
		end
	end
	M.hasWheel = wheel
	M.bound = bound
	if SUI.GroupEngine and SUI.GroupEngine.SyncWheel then SUI.GroupEngine.SyncWheel() end
	if SUI.GroupEngine and SUI.GroupEngine.SyncClicks then SUI.GroupEngine.SyncClicks() end
	if SUI.Units and SUI.Units.SyncWheel then SUI.Units.SyncWheel() end
	M.MarkAll()
end

local function modIndex()
	if IsShiftKeyDown() then return 2 end
	if IsControlKeyDown() then return 3 end
	if IsAltKeyDown() then return 4 end
	return 1
end

function M.Label(e)
	if e.kind == "spell" then return e.cast or e.spell or "?" end
	return L("choice.clickheal.tok." .. e.kind)
end

-- ---------------------------------------------------------------- lancement
local function say(key, a)
	local now = GetTime()
	if now - M.lastMsg < 2 then return end
	M.lastMsg = now
	SUI.Print(L(key, a))
end

function M.UseDirect()
	local m = C.Get("clickheal.method")
	if m == "swap" then return false end
	return SUI.Api.superwow and true or false
end

-- Lance 'spell' sur 'unit' (sans toucher a la cible avec SuperWoW ; sinon cible puis rend la cible d'avant).
function M.CastOn(unit, spell)
	local E = SUI.GroupEngine
	if E and E.NoteCast then E.NoteCast(spell, unit) end      -- cible annoncee au cadre pour la barre de soin entrant (mes soins)
	if M.UseDirect() then
		CastSpellByName(spell, unit)
		return
	end
	local had = UnitExists("target") and true or false
	local same = had and UnitIsUnit("target", unit)
	if not same then TargetUnit(unit) end
	CastSpellByName(spell)
	if SpellIsTargeting() then SpellTargetUnit(unit) end
	if not same and C.Get("clickheal.retarget") then
		if had then TargetLastTarget() else ClearTarget() end
	end
end

-- Meilleur sort de dissipation connu pour le premier debuff type de l'unite ; sinon le premier sort connu.
function M.PickCure(unit)
	for i = 1, 16 do
		local tex, _, dt = UnitDebuff(unit, i)
		if not tex then break end
		if dt and dt ~= "" then
			for k = 1, getn(CURE_ORDER) do
				local n = CURE_ORDER[k]
				if M.IsKnown(n) and CURES[n][dt] then return n end
			end
		end
	end
	for k = 1, getn(CURE_ORDER) do
		if M.IsKnown(CURE_ORDER[k]) then return CURE_ORDER[k] end
	end
	return nil
end

-- Appelle Rinse (decurse selon sa liste de priorite). true si Rinse est present et a ete appele.
function M.RinseCall()
	local sl = getglobal("SlashCmdList")
	local fn = sl and sl["RINSE"]
	if type(fn) == "function" then
		pcall(fn, "")
		return true
	end
	local r = getglobal("Rinse")
	if type(r) == "table" then
		local mt = getmetatable(r)
		if mt and mt.__call then
			pcall(r)
			return true
		end
	end
	return false
end

function M.HasRinse()
	local sl = getglobal("SlashCmdList")
	if sl and type(sl["RINSE"]) == "function" then return true end
	return false
end

local function targetUnit(unit)
	if SpellIsTargeting() then SpellTargetUnit(unit) else TargetUnit(unit) end
end

-- Execute la liaison 'e' sur 'unit'. Renvoie true si le clic est traite (sinon le cadre applique son comportement normal).
function M.Run(e, unit, f)
	local kind = e.kind
	if kind == "default" then return false end
	if kind == "none" then return true end
	if kind == "target" then
		targetUnit(unit)
		return true
	end
	if kind == "menu" then
		if f and f.g and SUI.GroupEngine then SUI.GroupEngine.OpenMenu(f)
		elseif f and SUI.Units and SUI.Units.OpenMenu then SUI.Units.OpenMenu(f) end
		return true
	end
	local spell = e.cast
	local base = e.spell
	if kind == "rinse" then
		if M.RinseCall() then return true end
		kind = "dispel"                       -- Rinse absent : fonction equivalente sur l'unite cliquee
	end
	if kind == "dispel" then
		local n = M.PickCure(unit)
		if not n then
			say("msg.clickheal.nocure")
			return false                      -- rien a lancer : le clic reste un clic normal (cibler / menu), jamais avale
		end
		base = n
		spell = M.CastString(n)
	elseif kind == "res" then
		local r = RES[M.class or ""]
		if not r or not M.IsKnown(r) then
			say("msg.clickheal.nores")
			return false
		end
		base = r
		spell = M.CastString(r)
	else
		if not M.IsKnown(e.spell) then
			M.Recheck()                       -- grimoire peut-etre perime (apres une respec) : une relecture avant de conclure
		end
		if not M.IsKnown(e.spell) then
			M.warned = M.warned or {}
			if not M.warned[e.spell] then          -- une seule fois par sort (sinon le message revenait a chaque clic)
				M.warned[e.spell] = true
				say("msg.clickheal.unknown", e.spell)
			end
			return false                      -- sort desappris (respec) : le clic cible quand meme au lieu d'etre avale
		end
		spell = e.cast
		if C.Get("clickheal.autores") and UnitIsDeadOrGhost(unit) and UnitIsFriend("player", unit) then
			local r = RES[M.class or ""]
			if r and M.IsKnown(r) and e.spell ~= r then
				base = r
				spell = M.CastString(r)
			end
		end
	end
	M.CastOn(unit, spell)
	local E = SUI.GroupEngine
	if base and E and E.NoteHot and not SUI.Api.superwow then E.NoteHot(UnitName(unit), base) end
	return true
end

function M.Click(unit, button, f)
	if not M.on then return false end
	if M.bookStale then M.Recheck() end   -- juste apres une respec : le grimoire lu peut etre vide ou incomplet
	local bi = BTN_OF[button]
	if not bi then return false end
	local e = M.map[(modIndex() - 1) * 5 + bi]
	if not e then return false end
	return M.Run(e, unit, f)
end

-- Cadres JOUEUR et CIBLE de Units.lua : memes liaisons, options clickheal.self / clickheal.target. Cible hostile : clic normal.
function M.SoloOn(unit)
	if unit == "player" then return C.Get("clickheal.self") and true or false end
	if unit == "target" then return C.Get("clickheal.target") and true or false end
	return false
end

function M.ClickSolo(unit, button, f)
	if not M.on or not M.SoloOn(unit) then return false end
	if unit == "target" and not (UnitExists("target") and UnitIsFriend("player", "target")) then return false end
	return M.Click(unit, button, f)
end

function M.WheelSolo(unit, delta, f)
	if not M.SoloOn(unit) then return false end
	if unit == "target" and not (UnitExists("target") and UnitIsFriend("player", "target")) then return false end
	return M.Wheel(unit, delta, f)
end

function M.Wheel(unit, delta, f)
	if not M.on or not delta or delta == 0 then return false end
	local bi = (delta > 0) and 4 or 5
	local e = M.map[(modIndex() - 1) * 5 + bi]
	if not e then return false end
	return M.Run(e, unit, f)
end

-- Touches de soin au clavier (Bindings.xml SHIKIUI_CLICKHEAL_1..5 = clic gauche, droit, milieu, roulette haut, roulette bas) : la touche
-- lance la liaison du geste pour l'etat Maj / Ctrl / Alt tenu avec elle, sur le cadre survole (groupe, raid) ou, sans cadre survole,
-- sur la cible amie (option keytarget). Meme chemin que le clic : memes liaisons, memes rangs, meme methode de lancement.
function M.Key(bi)
	if not M.on or not bi then return false end
	local f = SUI.GroupEngine and SUI.GroupEngine.hover
	local unit = f and f.unit
	if unit and not UnitExists(unit) then unit, f = nil, nil end
	if not unit and C.Get("clickheal.keytarget") and UnitExists("target") and UnitIsFriend("player", "target") then unit = "target" end
	if not unit then return false end
	local e = M.map[(modIndex() - 1) * 5 + bi]
	if not e or e.kind == "default" then return false end
	return M.Run(e, unit, f)
end

-- Noms affiches dans la fenetre des raccourcis du jeu (sans cela le client montrerait le nom interne).
function M.NameBindings()
	setglobal("BINDING_HEADER_SHIKIUI_CLICKHEAL", L("mod.clickheal.bind.header"))
	for i = 1, 5 do setglobal("BINDING_NAME_SHIKIUI_CLICKHEAL_" .. i, L("mod.clickheal.bind." .. i)) end
end

-- Infobulle cachee qui sert a lire le cout en mana d'un sort du grimoire (option hintcost). Creee hors combat seulement (Scan l'appelle).
function M.EnsureCostTip()
	if M.costTip or not C.Get("clickheal.hintcost") or SUI.InCombat() then return M.costTip end
	local ex = getglobal("ShikiUI_CHCostTip")
	if ex then M.costTip = ex return ex end
	local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_CHCostTip", UIParent, "GameTooltipTemplate")
	if ok and t then M.costTip = t end
	return M.costTip
end

-- Cout en mana (nombre) du sort 'name' (cle EN) au rang choisi par l'option de rang ; nil si inconnu / sans mana / lecture impossible.
-- Le resultat est garde par rang jusqu'au prochain balayage du grimoire (talents, respec) : une lecture d'infobulle par rang et par balayage.
function M.ManaCost(name)
	local k = M.known[name]
	local tip = M.costTip
	if not (k and k.gen == M.gen and tip) then return nil end
	local n = k.max
	local key = "clickheal.rank." .. slug(name)
	local want = (C.meta[key] ~= nil) and C.Get(key) or 0
	if want > 0 and k.max > 0 then
		for r = want, 1, -1 do
			if k.idx[r] then n = r break end
		end
	end
	local c = k.cost[n]
	if c == nil then
		c = false
		local idx = k.idx[n]
		if idx then
			tip:SetOwner(UIParent, "ANCHOR_NONE")
			tip:SetSpell(idx, getglobal("BOOKTYPE_SPELL") or "spell")
			for i = 2, 4 do
				local fs = getglobal("ShikiUI_CHCostTipTextLeft" .. i)
				local t = fs and fs:GetText()
				if t then
					local _, _, v = sfind(t, "(%d+)%s+[Mm]ana")
					if v then c = tonumber(v) break end
				end
			end
		end
		k.cost[n] = c
	end
	return c or nil
end

-- Lignes d'aide ajoutees a l'infobulle d'un cadre (option hints) : les trois clics de l'etat de modificateur courant ; avec l'option
-- hintcost, le cout en mana du sort lie est ajoute apres son nom.
function M.AddHints(tip, f)
	if not M.on or not C.Get("clickheal.hints") or not tip or not tip.AddLine then return end
	local mi = modIndex()
	local cost = C.Get("clickheal.hintcost")
	if cost and not M.costTip then M.EnsureCostTip() end
	for bi = 1, 3 do
		local e = M.map[(mi - 1) * 5 + bi]
		if e and e.kind ~= "default" then
			local lbl = M.Label(e)
			local mana = cost and e.kind == "spell" and e.spell and M.ManaCost(e.spell)
			if mana then lbl = L("msg.clickheal.hintcost", lbl, mana) end
			tip:AddLine(L("msg.clickheal.hint", L("choice.clickheal.btn." .. BTNS[bi]), lbl))
		end
	end
end

-- ---------------------------------------------------------------- grimoire : bouton "Soins au clic" et sorts surlignes
-- Bouton cree par ce module, enfant de SpellBookFrame (jamais en combat : SUI.WhenSafe), ancre au cadre Blizzard. Clic = page du module ;
-- clic droit = surligner / ne plus surligner les sorts lies. Son niveau est recale a l'affichage et au survol (le client change le
-- niveau du contenu d'un cadre apres coup : sans cela le bouton passerait sous le cadre qui capte la souris).
M.BOOKPOS = {
	top = { "TOPRIGHT", "TOPRIGHT", -62, -14 },
	bottom = { "BOTTOMLEFT", "BOTTOMLEFT", 24, 84 },
	side = { "TOPLEFT", "TOPRIGHT", -2, -150 },
}
M.BOOKW = { label = 98, count = 122, compact = 40 }
M.NBOOK = 12                         -- boutons de sort du grimoire (SpellButton1..12)

local function tipOn(b, fn, pre)
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oe then oe() end
		if pre then pre() end
		if not GameTooltip then return end
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		fn(b)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if ol then ol() end
		if GameTooltip then GameTooltip:Hide() end
	end)
end

local function tipLine(text, c)
	if GameTooltip then GameTooltip:AddLine(text, c[1], c[2], c[3], 1) end
end

-- Nombre de liaisons actives (geste qui fait autre chose que le comportement normal du cadre).
function M.CountBinds()
	local n = 0
	for i = 1, 20 do
		local e = M.map[i]
		if e and e.kind ~= "default" then n = n + 1 end
	end
	return n
end

function M.BookLevel()
	local b, par = M.bbtn, M.bpar
	if not b or not par then return end
	local lv = par:GetFrameLevel()
	if type(lv) == "number" then b:SetFrameLevel(lv + 8) end
end

function M.BookLevelTick()
	M.bLvlTask = nil
	M.BookLevel()
end

function M.BookLabel()
	local b = M.bbtn
	if not b then return end
	local style = C.Get("clickheal.btnstyle")
	local text
	if style == "compact" then
		text = L("mod.clickheal.btn.compact")
	elseif style == "count" then
		text = L("mod.clickheal.btn.count", M.CountBinds())
	else
		text = L("mod.clickheal.btn.label")
	end
	if b.txt ~= text then
		b.txt = text
		T.SetButtonText(b, text)
	end
	T.SetSelected(b, C.Get("clickheal.mark") and true or false)
end

function M.TipBook(b)
	M.BookLevel()
	GameTooltip:AddLine(L("mod.clickheal.btn.tiptitle"))
	tipLine(L("mod.clickheal.btn.state", M.CountBinds(), M.class or "?"), T.c.text)
	tipLine(C.Get("clickheal.mark") and L("mod.clickheal.btn.markon") or L("mod.clickheal.btn.markoff"), T.c.dim)
	tipLine(L("mod.clickheal.btn.tipbody"), T.c.dim)
end

function M.BookClick(mouse)
	if mouse == "RightButton" then
		C.Set("clickheal.mark", not C.Get("clickheal.mark"))
	elseif SUI.Menu and SUI.Menu.Show then
		SUI.Menu.Show("clickheal")
	end
end

function M.BuildBook()
	if M.bbtn then return end
	local sb = getglobal("SpellBookFrame")
	if not sb then return end               -- pas d'interface Blizzard (hors jeu) : pas de bouton
	M.bpar = sb
	local b = T.Button(sb, L("mod.clickheal.btn.label"), M.BOOKW.label, 16, function(btn, mouse) M.BookClick(mouse) end)
	b.healBtn = true
	M.bbtn = b
	b:SetScript("OnShow", function()
		M.BookLevel()
		M.BookLabel()
		M.MarkAll()
		if not M.bLvlTask then M.bLvlTask = SUI.After(0.2, M.BookLevelTick, "clickheal.lvl") end
	end)
	tipOn(b, M.TipBook, M.BookLevel)       -- le niveau est recale au survol meme sans infobulle
	M.BookApply()
end

function M.BookApply()
	if not M.bbtn then
		if not (M.on and C.Get("clickheal.btn")) or not getglobal("SpellBookFrame") then return end
		SUI.WhenSafe(M.BuildBook)
		return
	end
	local b = M.bbtn
	local pos = M.BOOKPOS[C.Get("clickheal.btnpos")] or M.BOOKPOS.top
	b:ClearAllPoints()
	b:SetPoint(pos[1], M.bpar, pos[2], pos[3], pos[4])
	b:SetWidth(M.BOOKW[C.Get("clickheal.btnstyle")] or M.BOOKW.label)
	b.txt = nil
	M.BookLevel()
	if M.on and C.Get("clickheal.btn") then b:Show() else b:Hide() end
	M.BookLabel()
end

-- Nom du sort que montre le bouton `b` du grimoire (nil : case vide, livre du familier, API absente).
function M.BookSpellName(b)
	local gn = getglobal("GetSpellName")
	if type(gn) ~= "function" or not b.GetID then return nil end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	local sb = getglobal("SpellBookFrame")
	if sb and sb.bookType and sb.bookType ~= book then return nil end     -- sorts du familier : pas de liaison
	local id = b:GetID()
	if type(id) ~= "number" then return nil end
	local conv = getglobal("SpellBook_GetSpellID")
	if type(conv) == "function" then id = conv(id) end
	if type(id) ~= "number" then return nil end
	return (gn(id, book))
end

-- Surligne (ou efface) le bandeau d'un bouton du grimoire.
function M.MarkButton(b)
	local t = b.healMark
	local name
	if M.on and C.Get("clickheal.mark") then
		name = M.BookSpellName(b)
		if name then
			local en = M.FRKEY[fold(name)] or ALIAS[name] or name   -- grimoire FR : le nom reel est rattache a sa cle EN
			if not M.bound[en] then name = nil end
		end
	end
	b.healName = name
	if name then
		if not t then
			if SUI.InCombat() then
				M.markPending = true            -- rien n'est cree en combat : repris a la fin du combat
				return
			end
			t = b:CreateTexture(nil, "OVERLAY")
			t:SetTexture(T.panelTex)
			t:SetHeight(3)
			t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
			t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
			b.healMark = t
		end
		local r, g, bl = T.Accent()
		t:SetVertexColor(r, g, bl, 1)
		t:Show()
	elseif t then
		t:Hide()
	end
end

-- Infobulle d'un sort du grimoire : ajoute les gestes qui le lancent (apres l'infobulle de Blizzard).
function M.BookTip(b)
	if not (M.on and GameTooltip and b) then return end
	local name = M.BookBoundName(b)
	if not name then return end
	tipLine(L("mod.clickheal.book.tip"), T.c.text)
	tipLine(table.concat(M.bound[name], ", "), T.c.dim)
	GameTooltip:Show()
end

-- Nom (cle EN) du sort du bouton `b` s'il a une liaison, sinon nil. Independant du surlignage : l'infobulle ne depend plus de l'option "mark".
function M.BookBoundName(b)
	local name = M.BookSpellName(b)
	if not name then return nil end
	local en = M.FRKEY[fold(name)] or ALIAS[name] or name
	if M.bound[en] then return en end
	return nil
end

-- Blizzard rappelle SpellButton_OnEnter (fonction globale) a intervalles reguliers tant que la souris reste sur le sort : l'infobulle est
-- alors reconstruite et nos lignes disparaissaient apres un instant. On enveloppe donc la fonction globale, pas le script du bouton.
function M.WrapEnter()
	if M.enterOrig then return end
	local orig = getglobal("SpellButton_OnEnter")
	if type(orig) ~= "function" then return end
	M.enterOrig = orig
	M.enterWrap = function()
		orig()
		if M.on then
			local ok = pcall(M.BookTip, this)
			if not ok then M.markErr = (M.markErr or 0) + 1 end
		end
	end
	setglobal("SpellButton_OnEnter", M.enterWrap)
end

function M.UnwrapEnter()
	if not M.enterOrig then return end
	if getglobal("SpellButton_OnEnter") == M.enterWrap then
		setglobal("SpellButton_OnEnter", M.enterOrig)
		M.enterOrig, M.enterWrap = nil, nil
	end
end

function M.MarkAll()
	for i = 1, M.NBOOK do
		local b = getglobal("SpellButton" .. i)
		if b then
			if not M.enterOrig and not b.healTip and M.on and not SUI.InCombat() then
				b.healTip = true
				local oe = b:GetScript("OnEnter")
				b:SetScript("OnEnter", function()
					if oe then oe() end
					M.BookTip(this)
				end)
			end
			M.MarkButton(b)
		end
	end
end

-- SpellBookFrame_Update est enveloppee a la main (pas de hooksecurefunc en 1.12) : apres Blizzard, les bandeaux sont remis a jour.
function M.WrapBook()
	if M.bookOrig then return end
	local orig = getglobal("SpellBookFrame_Update")
	if type(orig) ~= "function" then return end
	M.bookOrig = orig
	M.bookWrap = function(a, b, c)
		local r1, r2 = orig(a, b, c)
		if M.on then
			local ok = pcall(M.MarkAll)
			if not ok then M.markErr = (M.markErr or 0) + 1 end     -- jamais d'erreur dans le grimoire a cause de nous
		end
		return r1, r2
	end
	setglobal("SpellBookFrame_Update", M.bookWrap)
end

function M.UnwrapBook()
	if not M.bookOrig then return end
	if getglobal("SpellBookFrame_Update") == M.bookWrap then
		setglobal("SpellBookFrame_Update", M.bookOrig)
		M.bookOrig, M.bookWrap = nil, nil
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	if not M.on then return end
	if key == nil or sfind(key, "^clickheal%.") then M.Rebuild() end
	if key == nil or key == "clickheal.btn" or key == "clickheal.btnpos" or key == "clickheal.btnstyle" or key == "clickheal.mark" then
		M.BookApply()
	end
end

function M.OnRegen()
	if M.bookPending then M.Scan() end
	if M.markPending then
		M.markPending = false
		M.MarkAll()
	end
end

-- Anciennes liaisons enregistrees avec "Blessing of ..." -> noms reels du serveur
function M.MigrateNames()
	local mi, bi
	for mi = 1, getn(MODS) do
		for bi = 1, getn(BTNS) do
			local key = "clickheal." .. MODS[mi] .. "." .. BTNS[bi]
			local v = C.Get(key)
			if v and ALIAS[v] then C.Set(key, ALIAS[v]) end
		end
	end
end

function M.Enable()
	M.on = true
	M.MigrateNames()
	M.NameBindings()
	local _, class = UnitClass("player")
	M.class = class
	M.SetChoices(class)
	if not M.watching then
		M.watching = true
		C.Watch("", function(key, value)
			if key == nil or sfind(key, "^clickheal%.") then M.OnKey(key, value) end
		end)
	end
	SUI.On("SPELLS_CHANGED", M.OnBook)
	SUI.On("LEARNED_SPELL_IN_TAB", M.OnBook)
	SUI.On("CHARACTER_POINTS_CHANGED", M.OnBook)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	M.WrapEnter()
	M.Scan()
	M.Rebuild()
	M.WrapBook()
	M.BookApply()
end

function M.Disable()
	M.on = false
	M.hasWheel = false
	SUI.Off("SPELLS_CHANGED", M.OnBook)
	SUI.Off("LEARNED_SPELL_IN_TAB", M.OnBook)
	SUI.Off("CHARACTER_POINTS_CHANGED", M.OnBook)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	if M.bookTask then SUI.Cancel(M.bookTask) end
	M.bookTask = nil
	M.SetChoices(nil)
	if SUI.GroupEngine and SUI.GroupEngine.SyncWheel then SUI.GroupEngine.SyncWheel() end
	if SUI.GroupEngine and SUI.GroupEngine.SyncClicks then SUI.GroupEngine.SyncClicks() end
	if SUI.Units and SUI.Units.SyncWheel then SUI.Units.SyncWheel() end
	if M.bLvlTask then SUI.Cancel(M.bLvlTask) end
	M.bLvlTask = nil
	M.markPending = false
	M.MarkAll()                          -- module coupe : plus aucun bandeau
	if M.bbtn then M.bbtn:Hide() end
	M.UnwrapBook()
	M.UnwrapEnter()
end

-- ---------------------------------------------------------------- commandes
local function find(list, text)
	local low = string.lower(text)
	for i = 1, getn(list) do
		if string.lower(list[i]) == low then return list[i] end
	end
	return nil
end

function M.Command(rest)
	local w = {}
	for x in string.gfind(rest or "", "%S+") do tinsert(w, x) end
	local sub = w[1]
	if sub == "set" then
		local mi, bi
		for i = 1, 4 do
			if MODS[i] == w[2] then mi = i end
		end
		for i = 1, 5 do
			if BTNS[i] == w[3] then bi = i end
		end
		if not mi or not bi or not w[4] then
			SUI.Print(L("msg.clickheal.usage"))
			return
		end
		local action = w[4]
		for i = 5, getn(w) do action = action .. " " .. w[i] end
		local match = find(M.choices, action)
		if not match then
			SUI.Print(L("msg.clickheal.badaction", action))
			return
		end
		C.Set(slotKey(mi, bi), match)
		SUI.Print(L("msg.clickheal.set", MODS[mi] .. "+" .. BTNS[bi], match))
	elseif sub == "reset" then
		for mi = 1, 4 do
			for bi = 1, 5 do C.Reset(slotKey(mi, bi)) end
		end
		SUI.Print(L("msg.clickheal.reset"))
	elseif sub == "scan" then
		M.Scan()
		SUI.Print(L("msg.clickheal.scanned"))
	elseif sub == "rinse" then
		if M.RinseCall() then SUI.Print(L("msg.clickheal.rinseok")) else SUI.Print(L("msg.clickheal.norinse")) end
	elseif sub == "list" then
		local n = 0
		for mi = 1, 4 do
			for bi = 1, 5 do
				local e = M.map[(mi - 1) * 5 + bi]
				if e and e.kind ~= "default" then
					n = n + 1
					SUI.Print(L("msg.clickheal.line", MODS[mi] .. "+" .. BTNS[bi], M.Label(e)))
				end
			end
		end
		if n == 0 then SUI.Print(L("msg.clickheal.none")) end
	else
		SUI.Print(L("msg.clickheal.info", M.class or "?", M.hasWheel and 1 or 0, C.Get("clickheal.method")))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("clickheal", 44)

local function opt(key, typ, order, def, extra)
	local o = { key = "clickheal." .. key, type = typ, cat = "clickheal", label = "opt.clickheal." .. key, tip = "tip.clickheal." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function labelOf(o, v)
	if v == "auto" or v == "default" or v == "none" or v == "target" or v == "menu" or v == "dispel" or v == "res" or v == "rinse" then
		return L("choice.clickheal.tok." .. v)
	end
	return tostring(v)
end

local options = {}
local simpleSlots = { ["none.left"] = true, ["none.right"] = true, ["none.middle"] = true, ["shift.left"] = true, ["shift.right"] = true,
	["ctrl.left"] = true, ["ctrl.right"] = true }
for mi = 1, 4 do
	for bi = 1, 5 do
		local k = MODS[mi] .. "." .. BTNS[bi]
		local o = opt(k, "choice", 10 + (mi - 1) * 20 + bi, "auto", { choices = M.choices, choiceText = labelOf, simple = simpleSlots[k] and true or nil })
		tinsert(options, o)
	end
end
tinsert(options, opt("method", "choice", 100, "auto", { choices = { "auto", "swap", "direct" }, simple = true }))
tinsert(options, opt("autores", "bool", 110, true, { simple = true }))
tinsert(options, opt("retarget", "bool", 120, true))
tinsert(options, opt("hints", "bool", 130, true))
tinsert(options, opt("hintcost", "bool", 131, true))
tinsert(options, opt("keytarget", "bool", 133, true))
tinsert(options, opt("clickon", "choice", 129, "up", { choices = { "up", "down" } }))
tinsert(options, opt("self", "bool", 131, true, { simple = true }))
tinsert(options, opt("target", "bool", 132, true, { simple = true }))
tinsert(options, opt("btn", "bool", 140, true, { simple = true }))
tinsert(options, opt("mark", "bool", 141, true, { simple = true }))
tinsert(options, opt("btnpos", "choice", 142, "top", { choices = { "top", "bottom", "side" } }))
tinsert(options, opt("btnstyle", "choice", 143, "label", { choices = { "label", "count", "compact" } }))
for i = 1, getn(RANKED) do
	tinsert(options, opt("rank." .. slug(RANKED[i]), "number", 200 + i, 0, { min = 0, max = 12, step = 1 }))
end

SUI.RegisterModule("clickheal", {
	default = false,
	cost = "light",
	options = options,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Mode Raid : pas de lignes d'aide dans les infobulles (infobulles plus courtes quand on survole 40 cadres).
SUI.Config.AddPreset("raid", "*", { ["clickheal.hints"] = false })

SUI.RegisterCommand("clickheal", function(rest) M.Command(rest) end, "help.clickheal")
