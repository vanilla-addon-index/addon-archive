-- ShikiUI Macros : macros a conditions (facon CleveRoidMacros / CleverMacro) + editeur de macros ameliore (surcouche de MacroFrame).
-- Comportement REECRIT (aucun code de CleveRoidMacros / CleverMacro / Roid-Macros / SuperMacro copie : seule la SYNTAXE visible de ces
-- addons est reprise, relevee dans leur README et leurs commentaires). Ce module ne touche a AUCUNE rotation Shiki* (ShikiwaRotation,
-- ShikiwaHeal, ShikaSwap, ShikatoRotation) : il ne lit ni n'appelle aucune de leurs globales.
-- Cout declare : LIGHT. Aucune minuterie hors editeur ouvert (SUI.Every 0,5 s tant que la fenetre est visible), aucun OnUpdate maison.
-- Une ligne de macro executee = une consultation du cache d'analyse (table indexee par le texte) + l'evaluation de ses conditions
-- (boucles sur des tableaux prealloues, aucun objet cree). Le cache est rechauffe a la connexion / a chaque UPDATE_MACROS hors combat.
--
-- ACCROCHE A L'EXECUTION (releve dans l'addon installe SuperCleveRoidMacros : Console.lua, Core.lua) :
--   le client 1.12 envoie chaque ligne d'une macro comme si elle etait tapee dans le chat : "/cast ..." arrive donc dans
--   SlashCmdList["CAST"], "/use" dans SlashCmdList["USE"], etc. Ce module REMPLACE ces entrees par un enveloppeur : si la ligne contient
--   un crochet "[" (ou si la commande n'existe pas dans le jeu : /castsequence, /cancelaura...), il l'analyse lui-meme ; sinon il rend la
--   main au gestionnaire d'origine, intact. Les lignes "#showtooltip" que le client envoie au chat sont avalees par un petit enveloppeur de
--   SendChatMessage. RunMacro (si present) est enveloppe pour remettre a zero le drapeau de /stopmacro.
--   Les commandes absentes du jeu sont enregistrees par setglobal("SLASH_...") : seule entorse a la regle "pas de SLASH_ personnel"
--   (aucune autre voie n'existe pour offrir /castsequence ; voir le rapport).
-- ANTI-DOUBLON : si CleveRoidMacros / CleverMacro / Roid-Macros est charge, ce module ne pose AUCUN enveloppeur (un message clair le dit) ;
--   l'editeur, /sui macros check|list|help restent disponibles. SuperMacro est signale (son RunLine contourne /cast).
-- SYNTAXE : voir help.macros et /sui macros help. Anatomie : /commande [cond,cond][autre] arg ; [cond] arg2 ; arg3
-- NON VERIFIE EN JEU : tout (rien n'a ete lance dans le client) ; en particulier que le client route bien les lignes de macro vers
--   SlashCmdList["CAST"] et consorts (c'est ce que fait CleveRoidMacros), l'existence de RunMacro comme global, CastSpellByName(sort, unite)
--   (SuperWoW), UnitBuff/UnitDebuff -> identifiant de sort (SuperWoW), la lecture par infobulle sans SuperWoW, AttackTarget (bascule ?),
--   EditMacro / CreateMacro (signature et indice d'icone), les evenements SPELLCAST_* / PLAYER_ENTER_COMBAT, IsMounted / IsSwimming.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind, ssub, slen, slower, supper, sformat, sgsub = string.find, string.sub, string.len, string.lower, string.upper, string.format, string.gsub
local floor = math.floor

local M = {}
SUI.Macros = M

M.MAXLEN = 255
M.on = false
M.exec = false              -- les enveloppeurs de commandes sont-ils poses (et actifs) ?
M.conflict = nil            -- nom de l'addon equivalent detecte (alors rien n'est pose)
M.warnSM = false            -- SuperMacro charge : ses macros contournent /cast
M.cache = {}                -- commande -> { texte -> plan | false }
M.errs = {}                 -- commande -> { texte -> { cle, arg } }
M.cacheN = 0
M.wrapped = {}              -- cle SlashCmdList -> { orig, mine, cmd }
M.book = {}                 -- nom en minuscules -> { idx, tex, name, rank, gen }
M.spellList = {}            -- noms affichables du grimoire (tries)
M.gen = 0
M.bookPending = false
M.castName = nil            -- sort en cours d'incantation / de canalisation (evenements SPELLCAST_*)
M.chanName = nil
M.attacking = false
M.stopT = nil               -- heure du dernier /stopmacro vrai
M.epoch = 0                 -- change a chaque sortie de combat (remise a zero des /castsequence)
M.lastMsg = 0
M.last = ""                 -- derniere action lancee (texte), pour /sui macros et le mode bavard
M.eqName = {}               -- emplacement 16..18 -> nom / sous-type en minuscules (rafraichi par evenement)
M.eqSub = {}
M.eqSub2 = {}
M.sidName = {}              -- identifiant de sort (SuperWoW) -> nom en minuscules
M.texSlot = {}              -- texture -> emplacement de barre d'action (aptitudes reactives)
M.actDirty = true
M.seq = {}                  -- etats des /castsequence : cle -> { i, t, epoch, tgt }

local STOPWIN = 0.04        -- repli si RunMacro n'est pas enveloppable : un /stopmacro vrai vaut pour la meme image
local MOUNTS = { "Ability_Mount_", "_Horse", "Mount_", "Nightsaber", "Kodo", "Raptor", "Wolf", "Mechanostrider", "Ram", "Skeletal" }

-- ---------------------------------------------------------------- petits utilitaires
local function trim(s)
	local _, _, t = sfind(s or "", "^%s*(.-)%s*$")
	return t or ""
end
M.Trim = trim

local function split(s, sep)
	local t, p = {}, 1
	while true do
		local a = sfind(s, sep, p, true)
		if not a then
			tinsert(t, ssub(s, p))
			break
		end
		tinsert(t, ssub(s, p, a - 1))
		p = a + slen(sep)
	end
	return t
end

local function clean(s)
	s = trim(s)
	local _, _, q = sfind(s, '^"(.*)"$')
	if q then s = q end
	s = sgsub(s, "_", " ")
	return slower(s)
end

local function say(key, a, b)
	local now = GetTime()
	if now - M.lastMsg < 2 then return end
	M.lastMsg = now
	SUI.Print(L(key, a, b))
end

-- ---------------------------------------------------------------- unites
local NUMBERED = { party = 4, raid = 40, partypet = 4, raidpet = 40 }
local PLAIN = { player = true, target = true, mouseover = true, focus = true, pet = true }

-- u : jeton d'unite en minuscules (@player, @party2, @mouseovertarget, @raid7target...). Renvoie true si la forme est valide.
function M.CheckUnit(u)
	local _, _, base, num, rest = sfind(u, "^(%a+)(%d+)(%a*)$")
	if base then
		local mx = NUMBERED[base]
		if not mx then return false end
		num = tonumber(num)
		if num < 1 or num > mx then return false end
		while rest ~= "" do
			if ssub(rest, 1, 6) == "target" then rest = ssub(rest, 7) else return false end
		end
		return true
	end
	if not sfind(u, "^%a+$") then return false end
	while slen(u) > 6 and ssub(u, -6) == "target" do u = ssub(u, 1, slen(u) - 6) end
	return PLAIN[u] and true or false
end

-- ---------------------------------------------------------------- grimoire (noms de sorts connus, indices, textures)
function M.Scan()
	if SUI.InCombat() then
		M.bookPending = true
		return
	end
	M.bookPending = false
	local gn = getglobal("GetSpellName")
	if not gn then return end
	local bk = getglobal("BOOKTYPE_SPELL") or "spell"
	local gt = getglobal("GetSpellTexture")
	M.gen = M.gen + 1
	local list = M.spellList
	for i = getn(list), 1, -1 do list[i] = nil end
	for i = 1, 1000 do
		local name, rank = gn(i, bk)
		if not name then break end
		local key = slower(name)
		local b = M.book[key]
		if not b then
			b = { idx = i, name = name, rank = "", gen = 0 }
			M.book[key] = b
		end
		if b.gen ~= M.gen then
			b.gen = M.gen
			tinsert(list, name)
		end
		b.idx = i                                        -- le dernier indice rencontre = le rang le plus haut
		b.rank = rank or ""
		b.tex = gt and gt(i, bk) or nil
	end
	table.sort(list)
	M.actDirty = true
end

-- Entree du grimoire pour un nom saisi (avec ou sans "(Rank n)" / "(Rang n)"), ou nil.
function M.Lookup(name)
	if not name or name == "" then return nil end
	local key = slower(name)
	local a = sfind(key, "%(")
	if a then key = trim(ssub(key, 1, a - 1)) end
	local b = M.book[key]
	if b and b.gen == M.gen then return b end
	return nil
end

function M.IsKnown(name)
	return M.Lookup(name) ~= nil
end

-- ---------------------------------------------------------------- auras (noms)
-- Nom (minuscules) de l'aura i de l'unite : identifiant SuperWoW -> SpellInfo, sinon lecture de l'infobulle cachee.
function M.AuraName(sid, unit, i, debuff)
	if sid and SpellInfo then
		local n = M.sidName[sid]
		if n then return n end
		local nm = SpellInfo(sid)
		if nm then
			n = slower(nm)
			M.sidName[sid] = n
			return n
		end
	end
	local tip, left = M.tip, M.tipLeft
	if not tip or not left then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	if debuff then tip:SetUnitDebuff(unit, i) else tip:SetUnitBuff(unit, i) end
	local txt = left:GetText()
	if not txt or txt == "" then return nil end
	return slower(txt)
end

-- Minuscules memorisees dans la condition : recalcule seulement si le texte change (aucune allocation en regime etabli).
local function lowerMemo(c, s)
	if s ~= c.mraw then
		c.mraw = s
		c.mlow = slower(s)
	end
	return c.mlow
end

local function stackOf(st)
	if st and st > 0 then return st end
	return 1
end

-- ---------------------------------------------------------------- comparaisons numeriques
local function cmp(op, a, b)
	if op == 1 then return a < b end
	if op == 2 then return a > b end
	if op == 3 then return a <= b end
	if op == 4 then return a >= b end
	if op == 5 then return a == b end
	return a ~= b
end

local OPCODE = { ["<"] = 1, [">"] = 2, ["<="] = 3, [">="] = 4, ["="] = 5, ["=="] = 5, ["~="] = 6, ["!="] = 6 }

local function parseTerm(t)
	local _, _, op, num = sfind(trim(t), "^([<>=~!]*)%s*(%-?[%d%.]+)$")
	if not num then return nil end
	if op == "" then op = "=" end
	local code = OPCODE[op]
	if not code then return nil end
	return code, tonumber(num)
end

-- Groupes OU separes par "/", termes ET par "&" : "<30", ">20&<50", "10/>80".
local function parseNum(arg)
	local gs = {}
	local alts = split(arg, "/")
	for i = 1, getn(alts) do
		local terms = split(alts[i], "&")
		local g = { n = 0, o = {}, v = {} }
		for j = 1, getn(terms) do
			local op, v = parseTerm(terms[j])
			if not op then return nil end
			g.n = g.n + 1
			g.o[g.n] = op
			g.v[g.n] = v
		end
		tinsert(gs, g)
	end
	return gs
end

local function numTest(c, x)
	for g = 1, c.ng do
		local gr = c.g[g]
		local ok = true
		for i = 1, gr.n do
			if not cmp(gr.o[i], x, gr.v[i]) then
				ok = false
				break
			end
		end
		if ok then return true end
	end
	return false
end

local function pct(cur, max)
	if not max or max <= 0 then return 0 end
	return cur * 100 / max
end

-- ---------------------------------------------------------------- conditions : fn(c, unite) -> booleen
local COND = {}
M.COND = COND
local ALIAS = { notarget = { c = "hastarget", neg = true }, alive = { c = "dead", neg = true } }
M.ALIAS = ALIAS

local function def(name, kind, fn)
	COND[name] = { kind = kind, fn = fn }
end

local function auraTest(c, unit, debuff)
	if not UnitExists(unit) then return false end
	if c.n == 0 then
		if debuff then return UnitDebuff(unit, 1) ~= nil end
		return UnitBuff(unit, 1) ~= nil
	end
	local max = debuff and 16 or 32
	for i = 1, max do
		local tex, st, x, y
		if debuff then tex, st, x, y = UnitDebuff(unit, i) else tex, st, x = UnitBuff(unit, i) end
		if not tex then break end
		local nm = M.AuraName(debuff and y or x, unit, i, debuff)
		if nm then
			for k = 1, c.n do
				if c.s[k] == nm then
					local ok = true
					if c.sop[k] then ok = cmp(c.sop[k], stackOf(st), c.sv[k]) end
					if ok and c.top[k] then
						ok = false
						if unit == "player" and GetPlayerBuff then
							local idx = GetPlayerBuff(i - 1, debuff and "HARMFUL" or "HELPFUL")
							if idx and idx >= 0 and GetPlayerBuffTimeLeft then ok = cmp(c.top[k], GetPlayerBuffTimeLeft(idx), c.tv[k]) end
						end
					end
					if ok then return true end
				end
			end
		end
	end
	return false
end

local function texHas(unit, pats, np)
	for i = 1, 32 do
		local tex = UnitBuff(unit, i)
		if not tex then break end
		for k = 1, np do
			if sfind(tex, pats[k], 1, true) then return true end
		end
	end
	return false
end

local STEALTH = { "Ability_Stealth", "Ability_Ambush", "Ability_Vanish" }

local function spellCd(key)
	local b = M.book[key]
	if not b or b.gen ~= M.gen then return nil end
	local start, dur = GetSpellCooldown(b.idx, "spell")
	if not start or start == 0 or not dur or dur <= 1.5 then return 0 end
	local r = start + dur - GetTime()
	if r < 0 then r = 0 end
	return r
end

-- Aptitude reactive : utilisable si une case de barre d'action portant l'icone du sort l'est (limite connue : elle doit etre sur une barre).
local function reactive(key)
	local b = M.book[key]
	if not b or b.gen ~= M.gen or not b.tex then return false end
	if M.actDirty then
		M.actDirty = false
		for k in pairs(M.texSlot) do M.texSlot[k] = nil end
		for s = 1, 120 do
			local tex = GetActionTexture(s)
			if tex and not M.texSlot[tex] then M.texSlot[tex] = s end
		end
	end
	local slot = M.texSlot[b.tex]
	if not slot then return false end
	local usable, nomana = IsUsableAction(slot)
	if not usable or nomana then return false end
	local start, dur = GetActionCooldown(slot)
	if start and start > 0 and dur and dur > 1.5 then return false end
	return true
end

function M.RefreshEquip()
	for slot = 16, 18 do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		M.eqName[slot], M.eqSub[slot], M.eqSub2[slot] = nil, nil, nil
		if link then
			local _, _, id = sfind(link, "item:(%d+)")
			local name, sub
			if id and GetItemInfo then
				local n, _, _, _, _, _, st = GetItemInfo(tonumber(id))
				name, sub = n, st
			end
			if not name then
				local _, _, nm = sfind(link, "%[(.-)%]")
				name = nm
			end
			if name then M.eqName[slot] = slower(name) end
			if sub then
				sub = slower(sub)
				M.eqSub[slot] = sub
				M.eqSub2[slot] = (ssub(sub, -1) == "s") and ssub(sub, 1, slen(sub) - 1) or sub
			end
		end
	end
end

local function hpOf(u) return pct(UnitHealth(u), UnitHealthMax(u)) end

def("exists", "none", function(c, u) return UnitExists(u) and true or false end)
def("dead", "none", function(c, u) return (UnitExists(u) and UnitIsDeadOrGhost(u)) and true or false end)
def("help", "none", function(c, u) return (UnitExists(u) and UnitIsFriend("player", u)) and true or false end)
def("harm", "none", function(c, u) return (UnitExists(u) and UnitCanAttack("player", u)) and true or false end)
def("isplayer", "none", function(c, u) return (UnitExists(u) and UnitIsPlayer(u)) and true or false end)
def("isnpc", "none", function(c, u) return (UnitExists(u) and not UnitIsPlayer(u)) and true or false end)
def("hp", "num", function(c, u) return UnitExists(u) and numTest(c, hpOf(u)) end)
def("rawhp", "num", function(c, u) return UnitExists(u) and numTest(c, UnitHealth(u)) end)
def("power", "num", function(c, u) return UnitExists(u) and numTest(c, pct(UnitMana(u), UnitManaMax(u))) end)
def("rawpower", "num", function(c, u) return UnitExists(u) and numTest(c, UnitMana(u)) end)
def("level", "num", function(c, u) return UnitExists(u) and numTest(c, UnitLevel(u)) end)
def("distance", "num", function(c, u)
	if not UnitExists(u) or not SUI.Api or not SUI.Api.Distance then return false end
	local d = SUI.Api.Distance(u)
	return d ~= nil and numTest(c, d)
end)
def("class", "list", function(c, u)
	if not UnitExists(u) then return false end
	local loc, eng = UnitClass(u)
	if not loc then return false end
	for i = 1, c.n do
		if c.u[i] == eng then return true end
	end
	loc = lowerMemo(c, loc)
	for i = 1, c.n do
		if c.s[i] == loc then return true end
	end
	return false
end)
def("type", "list", function(c, u)
	local t = UnitExists(u) and UnitCreatureType and UnitCreatureType(u)
	if not t then return false end
	t = lowerMemo(c, t)
	for i = 1, c.n do
		if c.s[i] == t then return true end
	end
	return false
end)
def("name", "list", function(c, u)
	local nm = UnitExists(u) and UnitName(u)
	if not nm then return false end
	nm = lowerMemo(c, nm)
	for i = 1, c.n do
		if c.s[i] == nm then return true end
	end
	return false
end)
def("buff", "aura", function(c, u) return auraTest(c, u, false) end)
def("debuff", "aura", function(c, u) return auraTest(c, u, true) end)
def("mybuff", "aura", function(c, u) return auraTest(c, "player", false) end)
def("mydebuff", "aura", function(c, u) return auraTest(c, "player", true) end)
def("myhp", "num", function(c, u) return numTest(c, hpOf("player")) end)
def("myrawhp", "num", function(c, u) return numTest(c, UnitHealth("player")) end)
def("mypower", "num", function(c, u) return numTest(c, pct(UnitMana("player"), UnitManaMax("player"))) end)
def("myrawpower", "num", function(c, u) return numTest(c, UnitMana("player")) end)
def("mylevel", "num", function(c, u) return numTest(c, UnitLevel("player")) end)
def("combo", "num", function(c, u) return numTest(c, GetComboPoints and GetComboPoints() or 0) end)
def("combat", "none", function(c, u) return UnitAffectingCombat("player") and true or false end)
def("hastarget", "none", function(c, u) return UnitExists("target") and true or false end)
def("pet", "none", function(c, u) return UnitExists("pet") and true or false end)
def("attacking", "none", function(c, u) return M.attacking end)
def("resting", "none", function(c, u) return (IsResting and IsResting()) and true or false end)
def("swimming", "none", function(c, u)
	local f = getglobal("IsSwimming")
	return (f and f()) and true or false
end)
def("mounted", "none", function(c, u)
	local f = getglobal("IsMounted")
	if f then return f() and true or false end
	return texHas("player", MOUNTS, getn(MOUNTS))
end)
def("stealth", "none", function(c, u) return texHas("player", STEALTH, getn(STEALTH)) end)
def("group", "none", function(c, u) return (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) and true or false end)
def("party", "none", function(c, u) return (GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0) and true or false end)
def("raid", "none", function(c, u) return GetNumRaidMembers() > 0 end)
def("mod", "olist", function(c, u)
	if c.n == 0 then return (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) and true or false end
	for i = 1, c.n do
		local k = c.s[i]
		if k == "shift" then
			if IsShiftKeyDown() then return true end
		elseif k == "ctrl" or k == "control" then
			if IsControlKeyDown() then return true end
		elseif k == "alt" then
			if IsAltKeyDown() then return true end
		end
	end
	return false
end)
local function stance(c, u)
	local f = GetShapeshiftForm and GetShapeshiftForm() or 0
	if c.n == 0 then return f > 0 end
	for i = 1, c.n do
		if c.nums[i] then
			if c.nums[i] == f then return true end
		elseif f > 0 and GetShapeshiftFormInfo then
			local _, nm = GetShapeshiftFormInfo(f)
			if nm and lowerMemo(c, nm) == c.s[i] then return true end
		end
	end
	return false
end
def("stance", "olist", stance)
def("form", "olist", stance)
def("equipped", "list", function(c, u)
	for slot = 16, 18 do
		for i = 1, c.n do
			if M.eqSub[slot] == c.s[i] or M.eqSub2[slot] == c.s2[i] or M.eqName[slot] == c.s[i] then return true end
		end
	end
	return false
end)
def("known", "list", function(c, u)
	for i = 1, c.n do
		local b = M.book[c.s[i]]
		if b and b.gen == M.gen then return true end
	end
	return false
end)
def("cooldown", "list", function(c, u)
	for i = 1, c.n do
		local r = spellCd(c.s[i])
		if r and r > 0 then return true end
	end
	return false
end)
def("reactive", "list", function(c, u)
	for i = 1, c.n do
		if reactive(c.s[i]) then return true end
	end
	return false
end)
def("casting", "olist", function(c, u)
	local n = M.castName
	if not n then return false end
	if c.n == 0 then return true end
	n = lowerMemo(c, n)
	for i = 1, c.n do
		if c.s[i] == n then return true end
	end
	return false
end)
def("channeled", "olist", function(c, u)
	local n = M.chanName
	if not n then return false end
	if c.n == 0 then return true end
	n = lowerMemo(c, n)
	for i = 1, c.n do
		if c.s[i] == n then return true end
	end
	return false
end)

-- Liste ordonnee des noms de conditions (aide, completion, validation).
M.condNames = {}
for k in pairs(COND) do tinsert(M.condNames, k) end
tinsert(M.condNames, "notarget")
tinsert(M.condNames, "alive")
table.sort(M.condNames)

-- Cherche une condition (avec prefixe "no" optionnel). Renvoie l'entree et la negation, ou nil.
local function lookup(name)
	local e = COND[name]
	if e then return e, false end
	local a = ALIAS[name]
	if a then return COND[a.c], a.neg end
	if ssub(name, 1, 2) == "no" then
		local n2 = ssub(name, 3)
		e = COND[n2]
		if e then return e, true end
		a = ALIAS[n2]
		if a then return COND[a.c], not a.neg end
	end
	return nil
end
M.LookupCond = lookup

-- ---------------------------------------------------------------- analyse d'un groupe "[...]" et d'une ligne
local function readArg(s, p)
	local len = slen(s)
	local q, inq = p, false
	while q <= len do
		local ch = ssub(s, q, q)
		if ch == '"' then
			inq = not inq
		elseif not inq and (ch == "," or ch == " " or ch == "\t") then
			break
		end
		q = q + 1
	end
	return ssub(s, p, q - 1), q
end

local function buildCond(name, arg, ent, neg)
	local c = { fn = ent.fn, neg = neg, name = name, kind = ent.kind, n = 0 }
	local k = ent.kind
	if k == "none" then
		if arg then return nil, "noarg", name end
		return c
	end
	if not arg or arg == "" then
		if k == "olist" or k == "aura" then return c end
		return nil, "needarg", name
	end
	if k == "num" then
		c.g = parseNum(arg)
		if not c.g then return nil, "badnum", name end
		c.ng = getn(c.g)
	elseif k == "aura" then
		c.s, c.sop, c.sv, c.top, c.tv = {}, {}, {}, {}, {}
		local alts = split(arg, "/")
		for i = 1, getn(alts) do
			local a = trim(alts[i])
			local nm, suffix
			local _, _, q1, rest = sfind(a, '^"(.-)"(.*)$')
			if q1 then
				nm, suffix = q1, rest
			else
				local _, _, n1, r1 = sfind(a, "^([^<>=~!#]+)(.*)$")
				nm, suffix = n1, r1
			end
			if not nm or trim(nm) == "" then return nil, "badarg", name end
			c.n = c.n + 1
			c.s[c.n] = clean(nm)
			if suffix and suffix ~= "" then
				local _, _, op, hash, num = sfind(suffix, "^([<>=~!]+)(#?)(%d+)$")
				local code = op and OPCODE[op]
				if not code then return nil, "badarg", name end
				if hash == "#" then c.sop[c.n], c.sv[c.n] = code, tonumber(num) else c.top[c.n], c.tv[c.n] = code, tonumber(num) end
			end
		end
	else
		c.s, c.s2, c.u, c.nums = {}, {}, {}, {}
		local alts = split(arg, "/")
		for i = 1, getn(alts) do
			local w = clean(alts[i])
			if w == "" then return nil, "badarg", name end
			c.n = c.n + 1
			c.s[c.n] = w
			c.s2[c.n] = (ssub(w, -1) == "s") and ssub(w, 1, slen(w) - 1) or w
			c.u[c.n] = supper(w)
			c.nums[c.n] = tonumber(w)
		end
	end
	return c
end

-- Renvoie le groupe { n, unit, [i] = condition } ou nil, cle d'erreur, argument.
local function parseGroup(s)
	local g = { n = 0 }
	local p, len = 1, slen(s)
	while true do
		local _, e = sfind(s, "^[%s,]*", p)
		p = e + 1
		if p > len then break end
		local ch = ssub(s, p, p)
		if ch == "@" then
			local _, e2, u = sfind(s, "^@([%w_]+)", p)
			if not u then return nil, "unit", "@" end
			u = slower(u)
			if not M.CheckUnit(u) then return nil, "unit", u end
			g.unit = u
			p = e2 + 1
		else
			local _, e2, name = sfind(s, "^([%a_]+)", p)
			if not name then return nil, "syntax", ssub(s, p, p) end
			name = slower(name)
			p = e2 + 1
			local nx = ssub(s, p, p)
			if nx == "=" and name == "target" then
				local _, e3, u = sfind(s, "^=([%w_]+)", p)
				if not u then return nil, "unit", "target=" end
				u = slower(u)
				if not M.CheckUnit(u) then return nil, "unit", u end
				g.unit = u
				p = e3 + 1
			else
				local arg
				if nx == ":" then
					arg, p = readArg(s, p + 1)
				end
				local ent, neg = lookup(name)
				if not ent then return nil, "unk", name end
				local c, key, a = buildCond(name, arg, ent, neg)
				if not c then return nil, key, a end
				g.n = g.n + 1
				g[g.n] = c
			end
		end
	end
	return g
end

-- Description d'une commande : exec(plan, clause, groupe, cmd) ; arg = vrai si le texte apres les crochets compte ;
-- always = analysee meme sans crochet ; extra = n'existe pas dans le jeu (enregistree par ce module) ; slash = textes "/xxx".
local CMD = {}
M.CMD = CMD
M.cmdOrder = {}
local function cmd(name, slash, keys, always, extra, argKind)
	local d = { name = name, slash = slash, keys = keys, always = always, extra = extra, argKind = argKind }
	CMD[name] = d
	tinsert(M.cmdOrder, name)
	return d
end

-- Analyse le texte apres la commande. Renvoie plan | nil, cle d'erreur, argument d'erreur.
function M.Parse(cname, text)
	text = text or ""
	local d = CMD[cname]
	local plan = { n = 0 }
	local clauses = split(text, ";")
	-- un ";" dans un crochet ne coupe pas : on recolle les morceaux dont les crochets sont ouverts
	local joined, cur = {}, nil
	for i = 1, getn(clauses) do
		local piece = clauses[i]
		if cur then piece = cur .. ";" .. piece end
		local opens, closes = 0, 0
		local q = 1
		while true do
			local a = sfind(piece, "[", q, true)
			if not a then break end
			opens = opens + 1
			q = a + 1
		end
		q = 1
		while true do
			local a = sfind(piece, "]", q, true)
			if not a then break end
			closes = closes + 1
			q = a + 1
		end
		if opens > closes and i < getn(clauses) then cur = piece else
			cur = nil
			tinsert(joined, piece)
		end
	end
	for i = 1, getn(joined) do
		local piece = trim(joined[i])
		local cl = { ng = 0, arg = "" }
		local p = 1
		while ssub(piece, p, p) == "[" do
			local close = sfind(piece, "]", p, true)
			if not close then return nil, "bracket", piece end
			local g, key, a = parseGroup(ssub(piece, p + 1, close - 1))
			if not g then return nil, key, a end
			cl.ng = cl.ng + 1
			cl[cl.ng] = g
			p = close + 1
			local _, e = sfind(piece, "^%s*", p)
			p = e + 1
		end
		local rest = trim(ssub(piece, p))
		if sfind(rest, "[%[%]]") then return nil, "bracket", rest end
		cl.arg = rest
		if d and d.parseArg then
			local ok, key, a = d.parseArg(cl, rest)
			if not ok then return nil, key, a end
		end
		if rest == "" and d and d.needArg and (cl.ng == 0) then return nil, "needspell", cname end
		plan.n = plan.n + 1
		plan[plan.n] = cl
	end
	if plan.n == 0 then
		plan.n = 1
		plan[1] = { ng = 0, arg = "" }
	end
	return plan
end

-- Plan en cache : la premiere fois seulement on alloue. Renvoie plan | nil, cle, arg.
function M.GetPlan(cname, text)
	local ct = M.cache[cname]
	if not ct then
		ct = {}
		M.cache[cname] = ct
		M.errs[cname] = {}
	end
	local p = ct[text]
	if p then return p end
	if p == false then
		local e = M.errs[cname][text]
		return nil, e[1], e[2]
	end
	if M.cacheN > 800 then M.ClearCache() ; ct = M.cache[cname] or ct end
	local plan, key, a = M.Parse(cname, text)
	M.cacheN = M.cacheN + 1
	if not plan then
		M.cache[cname] = ct
		ct[text] = false
		M.errs[cname][text] = { key, a }
		return nil, key, a
	end
	ct[text] = plan
	return plan
end

function M.ClearCache()
	M.cache = {}
	M.errs = {}
	M.cacheN = 0
end

-- ---------------------------------------------------------------- evaluation (aucune allocation)
local function evalGroup(g)
	local u = g.unit
	if u and not UnitExists(u) then return false end
	u = u or "target"
	for k = 1, g.n do
		local c = g[k]
		local ok = c.fn(c, u)
		if c.neg then ok = not ok end
		if not ok then return false end
	end
	return true
end

-- Premiere alternative dont une des conditions groupees est vraie. Renvoie clause, groupe (nil si la clause n'a pas de crochet).
function M.Select(plan)
	for i = 1, plan.n do
		local cl = plan[i]
		if cl.ng == 0 then return cl, nil end
		for j = 1, cl.ng do
			if evalGroup(cl[j]) then return cl, cl[j] end
		end
	end
	return nil, nil
end

-- ---------------------------------------------------------------- actions
function M.CastOn(spell, unit)
	if not unit or unit == "target" then
		CastSpellByName(spell)
		return
	end
	if unit == "player" then
		CastSpellByName(spell, 1)
		return
	end
	if SUI.Api and SUI.Api.superwow then
		CastSpellByName(spell, unit)
		return
	end
	local had = UnitExists("target") and true or false
	local same = had and UnitIsUnit("target", unit)
	if not same then TargetUnit(unit) end
	CastSpellByName(spell)
	if SpellIsTargeting() then SpellTargetUnit(unit) end
	if not same then
		if had then TargetLastTarget() else ClearTarget() end
	end
end

-- what : sort / objet / ordre (chaine deja existante) ; aucune concatenation en dehors du mode bavard.
local function note(what, unit, label)
	M.last = what
	M.lastUnit = unit
	if C.Get("macros.verbose") then
		SUI.Print(L("msg.macros.run", (label and (label .. " ") or "") .. what .. (unit and (" @" .. unit) or "")))
	end
end

-- Objets : cache par nom (minuscules) ; l'emplacement n'est relu que s'il ne contient plus l'objet (aiguille "[Nom]" a la casse du jeu).
M.itemBag, M.itemSlot, M.itemNeedle = {}, {}, {}
M.wornSlot, M.wornNeedle = {}, {}
function M.FindItem(key)
	local b, s0, nd = M.itemBag[key], M.itemSlot[key], M.itemNeedle[key]
	if b and nd then
		local link = GetContainerItemLink(b, s0)
		if link and sfind(link, nd, 1, true) then return b, s0 end
	end
	for bag = 0, 4 do
		local n = GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, _, nm = sfind(link, "%[(.-)%]")
				if nm and slower(nm) == key then
					M.itemBag[key], M.itemSlot[key], M.itemNeedle[key] = bag, slot, "[" .. nm .. "]"
					return bag, slot
				end
			end
		end
	end
	M.itemBag[key], M.itemSlot[key], M.itemNeedle[key] = nil, nil, nil
	return nil
end

function M.FindWorn(key)
	local w, nd = M.wornSlot[key], M.wornNeedle[key]
	if w and nd then
		local link = GetInventoryItemLink("player", w)
		if link and sfind(link, nd, 1, true) then return w end
	end
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local _, _, nm = sfind(link, "%[(.-)%]")
			if nm and slower(nm) == key then
				M.wornSlot[key], M.wornNeedle[key] = slot, "[" .. nm .. "]"
				return slot
			end
		end
	end
	M.wornSlot[key], M.wornNeedle[key] = nil, nil
	return nil
end

-- cl.ikind : "slot" (emplacement porte), "bagslot" (sac + case) ou "name" (cl.key = nom en minuscules) ; prepare par parseItem.
local function useItem(cl, equip)
	local k = cl.ikind
	if k == "bagslot" then
		UseContainerItem(cl.ibag, cl.islot)
		return true
	end
	if k == "slot" then
		if not equip then UseInventoryItem(cl.islot) end
		return true
	end
	local bag, slot = M.FindItem(cl.key)
	if bag then
		UseContainerItem(bag, slot)
		return true
	end
	if not equip then
		local w = M.FindWorn(cl.key)
		if w then
			UseInventoryItem(w)
			return true
		end
	end
	say("msg.macros.noitem", cl.arg)
	return false
end

local function runCast(cl, g)
	local arg = cl.arg
	if arg == "" then return end
	if cl.bang and M.AuraActive(cl.spellKey) then return end
	M.CastOn(arg, g and g.unit)
	note(arg, g and g.unit)
end

-- true si le joueur porte une aura de ce nom (pour le prefixe "!" : ne pas relancer une posture / un bouclier deja actifs).
function M.AuraActive(key)
	if not key then return false end
	for i = 1, 32 do
		local tex, st, sid = UnitBuff("player", i)
		if not tex then break end
		if M.AuraName(sid, "player", i, false) == key then return true end
	end
	return false
end

-- Etat d'une sequence /castsequence : cle = texte de la clause ; remise a zero selon reset=...
local function seqState(cl)
	local s = M.seq[cl]
	if not s then
		s = { i = 1, t = 0, epoch = M.epoch, tgt = nil }
		M.seq[cl] = s
	end
	return s
end

local function targetKey()
	if not UnitExists("target") then return "" end
	local _, guid = UnitExists("target")
	return guid or UnitName("target") or ""
end

local function runSeq(cl, g)
	local n = cl.nseq
	if not n or n == 0 then return end
	local s = seqState(cl)
	local now = GetTime()
	local r = cl.reset
	if r then
		if r.time and s.t > 0 and now - s.t > r.time then s.i = 1 end
		if r.combat and s.epoch ~= M.epoch then s.i = 1 end
		if r.target and s.tgt ~= targetKey() then s.i = 1 end
		if r.shift and IsShiftKeyDown() then s.i = 1 end
		if r.ctrl and IsControlKeyDown() then s.i = 1 end
		if r.alt and IsAltKeyDown() then s.i = 1 end
	end
	if s.i > n then s.i = 1 end
	local step = cl.seq[s.i]
	M.CastOn(step, g and g.unit)
	note(step, g and g.unit)
	s.i = s.i + 1
	if s.i > n then s.i = 1 end
	s.t = now
	s.epoch = M.epoch
	s.tgt = targetKey()
end

local function runTarget(cl, g)
	local arg = cl.arg
	if arg ~= "" then
		TargetByName(arg, true)
		note(arg, nil, "target")
	elseif g and g.unit then
		TargetUnit(g.unit)
		note(g.unit, nil, "target")
	end
end

local function runAssist(cl, g)
	local arg = cl.arg
	if arg ~= "" then AssistByName(arg) else AssistUnit((g and g.unit) or "target") end
end

local function startAttack()
	if not UnitExists("target") or UnitIsDeadOrGhost("target") then return end
	if not M.attacking and UnitCanAttack("player", "target") then AttackTarget() end
end

local function stopAttack()
	if M.attacking then AttackTarget() end
end

local function runCancelAura(cl)
	local key = cl.key
	if not key or key == "" then return end
	for i = 1, 32 do
		local tex, st, sid = UnitBuff("player", i)
		if not tex then break end
		if M.AuraName(sid, "player", i, false) == key then
			local idx = GetPlayerBuff(i - 1, "HELPFUL")
			if idx and idx >= 0 then CancelPlayerBuff(idx) end
			return
		end
	end
end

local function cancelForm()
	local f = GetShapeshiftForm and GetShapeshiftForm() or 0
	if f > 0 then CastShapeshiftForm(f) end
end

local function parseSeq(cl, rest)
	local _, e, opts = sfind(rest, "^reset=(%S+)%s*")
	local body = rest
	if opts then
		body = trim(ssub(rest, e + 1))
		local r = {}
		local parts = split(opts, "/")
		for i = 1, getn(parts) do
			local w = slower(parts[i])
			local t = tonumber(w)
			if t then r.time = t
			elseif w == "target" or w == "combat" or w == "shift" or w == "ctrl" or w == "alt" then r[w] = true
			else return false, "badreset", w end
		end
		cl.reset = r
	end
	cl.seq = {}
	cl.nseq = 0
	if body ~= "" then
		local steps = split(body, ",")
		for i = 1, getn(steps) do
			local st = trim(steps[i])
			if st ~= "" then
				cl.nseq = cl.nseq + 1
				cl.seq[cl.nseq] = st
			end
		end
	end
	if cl.nseq == 0 and cl.ng == 0 then return false, "needspell", "castsequence" end
	cl.arg = body
	return true
end

local function parseCast(cl, rest)
	if ssub(rest, 1, 1) == "!" then
		cl.bang = true
		cl.arg = trim(ssub(rest, 2))
		cl.spellKey = clean(cl.arg)
	end
	return true
end

local function parseItem(cl, rest)
	cl.arg = rest
	local _, _, a, b = sfind(rest, "^(%d+)%s+(%d+)$")
	if a then
		cl.ikind, cl.ibag, cl.islot = "bagslot", tonumber(a), tonumber(b)
	elseif sfind(rest, "^%d+$") then
		cl.ikind, cl.islot = "slot", tonumber(rest)
	else
		cl.ikind, cl.key = "name", slower(rest)
	end
	return true
end

local function parseAura(cl, rest)
	cl.key = clean(rest)
	return true
end

local function d(name, slash, keys, always, extra, run, needArg, parseArg)
	local x = cmd(name, slash, keys, always, extra)
	x.run = run
	x.needArg = needArg
	x.parseArg = parseArg
	return x
end

d("cast", "/cast", { "CAST" }, false, false, runCast, false, parseCast)
d("castsequence", "/castsequence", { "CASTSEQUENCE", "SHIKIMACROS_CASTSEQUENCE" }, true, true, runSeq, false, parseSeq)
d("use", "/use", { "USE", "PFUSE" }, false, false, function(cl) if cl.arg ~= "" then useItem(cl, false); note(cl.arg, nil, "use") end end, false, parseItem)
d("equip", "/equip", { "EQUIP", "PFEQUIP", "SMEQUIP" }, false, false, function(cl) if cl.arg ~= "" then useItem(cl, true); note(cl.arg, nil, "equip") end end, false, parseItem)
d("target", "/target", { "TARGET" }, false, false, runTarget, false, nil)
d("assist", "/assist", { "ASSIST" }, false, false, runAssist, false, nil)
d("startattack", "/startattack", { "STARTATTACK" }, false, false, function() startAttack(); note("startattack") end, false, nil)
d("stopattack", "/stopattack", { "STOPATTACK" }, false, false, function() stopAttack(); note("stopattack") end, false, nil)
d("stopcasting", "/stopcasting", { "STOPCASTING" }, false, false, function() SpellStopCasting(); note("stopcasting") end, false, nil)
d("cleartarget", "/cleartarget", { "CLEARTARGET" }, false, false, function() ClearTarget(); note("cleartarget") end, false, nil)
d("petattack", "/petattack", { "PETATTACK" }, false, false, function() PetAttack(); note("petattack") end, false, nil)
d("petfollow", "/petfollow", { "PETFOLLOW" }, false, false, function() PetFollow(); note("petfollow") end, false, nil)
d("petwait", "/petwait", { "PETWAIT" }, false, false, function() PetWait(); note("petwait") end, false, nil)
d("petpassive", "/petpassive", { "PETPASSIVE" }, false, false, function() PetPassiveMode(); note("petpassive") end, false, nil)
d("petdefensive", "/petdefensive", { "PETDEFENSIVE" }, false, false, function() PetDefensiveMode(); note("petdefensive") end, false, nil)
d("petaggressive", "/petaggressive", { "PETAGGRESSIVE" }, false, false, function() PetAggressiveMode(); note("petaggressive") end, false, nil)
d("cancelaura", "/cancelaura", { "CANCELAURA", "SHIKIMACROS_CANCELAURA" }, true, true, runCancelAura, false, parseAura)
d("cancelform", "/cancelform", { "CANCELFORM", "SHIKIMACROS_CANCELFORM" }, true, true, function() cancelForm(); note("cancelform") end, false, nil)
d("stopmacro", "/stopmacro", { "STOPMACRO", "SHIKIMACROS_STOPMACRO" }, true, true, function() M.stopT = GetTime(); note("stopmacro") end, false, nil)

-- texte "/xxx" (minuscules) -> nom de commande
M.byText = {}
for i = 1, getn(M.cmdOrder) do
	local x = CMD[M.cmdOrder[i]]
	M.byText[x.slash] = x.name
end
M.byText["/unbuff"] = "cancelaura"
M.byText["/unshift"] = "cancelform"

-- ---------------------------------------------------------------- execution d'une ligne / enveloppeurs
function M.Stopped()
	local t = M.stopT
	if not t then return false end
	return GetTime() - t < STOPWIN
end

-- Execute le texte d'une commande. Renvoie true si ce module l'a prise en charge (meme si aucune condition n'etait vraie).
function M.Run(cname, text)
	local plan, key, a = M.GetPlan(cname, text)
	if not plan then
		say("msg.macros.err." .. key, a, cname)
		return true
	end
	local cl, g = M.Select(plan)
	if cl then CMD[cname].run(cl, g) end
	return true
end

local function makeWrapper(key, cname)
	local orig = SlashCmdList[key]
	local w = {}
	w.orig = orig
	w.cmd = cname
	local d0 = CMD[cname]
	w.mine = function(msg)
		if M.exec then
			if M.Stopped() then return end
			msg = msg or ""
			if d0.always or sfind(msg, "[", 1, true) or not w.orig then
				M.Run(cname, msg)
				return
			end
		end
		if w.orig then w.orig(msg) end
	end
	return w
end

-- Cle de SlashCmdList qui porte deja le texte "/xxx" (un autre addon l'a peut-etre pris), ou nil.
local function keyFor(text)
	for key in pairs(SlashCmdList) do
		for i = 1, 4 do
			if getglobal("SLASH_" .. key .. i) == text then return key end
		end
	end
	return nil
end

local function place(key, cname, own)
	if M.wrapped[key] then return end
	local w = makeWrapper(key, cname)
	if own then w.orig = nil end
	M.wrapped[key] = w
	SlashCmdList[key] = w.mine
end

function M.Install()
	for i = 1, getn(M.cmdOrder) do
		local x = CMD[M.cmdOrder[i]]
		local placed = false
		for k = 1, getn(x.keys) do
			local key = x.keys[k]
			if SlashCmdList[key] then
				place(key, x.name, false)
				placed = true
			end
		end
		if not placed then
			local other = keyFor(x.slash)
			if other then
				place(other, x.name, false)
			else
				local key = x.keys[getn(x.keys)]
				if ssub(key, 1, 12) ~= "SHIKIMACROS_" then key = "SHIKIMACROS_" .. supper(x.name) end
				place(key, x.name, true)
				setglobal("SLASH_" .. key .. "1", x.slash)
			end
		end
	end
	M.HookChat()
	M.HookRun()
end

function M.Uninstall()
	M.exec = false
	for key, w in pairs(M.wrapped) do
		if SlashCmdList[key] == w.mine then
			SlashCmdList[key] = w.orig          -- nil pour une commande que ce module avait ajoutee
			M.wrapped[key] = nil
		end
	end
end

-- Avale "#showtooltip" / "#show" que le client envoie au chat quand une macro est lancee.
function M.HookChat()
	local prev = getglobal("SendChatMessage")
	if M.chatHooked or type(prev) ~= "function" then return end
	M.chatHooked = true
	M.chatPrev = prev
	local mine = function(msg, ctype, lang, chan)
		if M.exec and msg and sfind(msg, "^#show") and C.Get("macros.hidehint") then return end
		return prev(msg, ctype, lang, chan)
	end
	M.chatMine = mine
	setglobal("SendChatMessage", mine)
end

function M.HookRun()
	local f = getglobal("RunMacro")
	if M.runHooked or type(f) ~= "function" then return end
	M.runHooked = true
	local prev = f
	M.runPrev = prev
	local mine = function(a, b)
		M.stopT = nil
		return prev(a, b)
	end
	M.runMine = mine
	setglobal("RunMacro", mine)
end

-- ---------------------------------------------------------------- detection d'un addon equivalent
local EQUIV_ADDONS = { "SuperCleveRoidMacros", "CleveRoidMacros", "CleverMacro", "Roid-Macros", "RoidMacros" }
local EQUIV_GLOBALS = { "CleveRoids", "CleveRoidMacros", "CleverMacro", "Roids" }

function M.DetectConflict()
	for i = 1, getn(EQUIV_GLOBALS) do
		if getglobal(EQUIV_GLOBALS[i]) then return EQUIV_GLOBALS[i] end
	end
	local f = getglobal("IsAddOnLoaded")
	if f then
		for i = 1, getn(EQUIV_ADDONS) do
			local ok, r = pcall(f, EQUIV_ADDONS[i])
			if ok and r then return EQUIV_ADDONS[i] end
		end
	end
	return nil
end

function M.DetectSuperMacro()
	if getglobal("SuperMacro_RunMacro") or getglobal("SM_ReplaceAlias") then return true end
	local f = getglobal("IsAddOnLoaded")
	if f then
		local ok, r = pcall(f, "SuperMacro")
		if ok and r then return true end
	end
	return false
end

-- ---------------------------------------------------------------- analyse pour l'editeur et les commandes (aucune action n'est lancee ici)
-- "/cast [..] Sort" -> "cast", "[..] Sort" ; nil si la ligne n'est pas une commande que ce module connait.
function M.SplitLine(line)
	local _, _, word, rest = sfind(line, "^%s*(/%S+)%s*(.*)$")
	if not word then return nil end
	local cname = M.byText[slower(word)]
	if not cname then return nil end
	return cname, rest
end

-- Statut d'une ligne : "empty" | "comment" | "chat" | "other" | "ok" | "warn" | "error", puis cle et argument du message.
function M.CheckLine(line)
	line = trim(line)
	if line == "" then return "empty" end
	local c1 = ssub(line, 1, 1)
	if c1 == "#" or ssub(line, 1, 2) == "--" then return "comment" end
	if c1 ~= "/" then return "chat" end
	local cname, rest = M.SplitLine(line)
	if not cname then return "other" end
	local plan, key, a = M.GetPlan(cname, rest)
	if not plan then return "error", key, a end
	if M.gen > 0 and (cname == "cast" or cname == "castsequence") then
		for i = 1, plan.n do
			local cl = plan[i]
			if cname == "cast" then
				if cl.arg ~= "" and not M.IsKnown(cl.arg) then return "warn", "spell", cl.arg end
			else
				for k = 1, (cl.nseq or 0) do
					if not M.IsKnown(cl.seq[k]) then return "warn", "spell", cl.seq[k] end
				end
			end
		end
	end
	return "ok"
end

function M.ErrText(key, arg)
	return L("msg.macros.err." .. key, arg or "")
end

-- Analyse un corps de macro. Remplit et renvoie M.an : { n, st = {}, key = {}, arg = {}, errs, warns, first }.
M.an = { n = 0, st = {}, key = {}, arg = {}, errs = 0, warns = 0, first = nil }
function M.Analyze(body)
	local an = M.an
	an.errs, an.warns, an.first = 0, 0, nil
	local lines = split(body or "", "\n")
	an.n = getn(lines)
	for i = 1, an.n do
		local st, key, a = M.CheckLine(lines[i])
		an.st[i], an.key[i], an.arg[i] = st, key, a
		if st == "error" then
			an.errs = an.errs + 1
			if not an.first then an.first = L("msg.macros.lineerr", i, M.ErrText(key, a)) end
		elseif st == "warn" then
			an.warns = an.warns + 1
			if not an.first then an.first = L("msg.macros.linewarn", i, M.ErrText(key, a)) end
		end
	end
	for i = an.n + 1, getn(an.st) do an.st[i], an.key[i], an.arg[i] = nil, nil, nil end
	return an
end

-- Ce que la ligne ferait maintenant (texte), sans rien lancer. nil si ce n'est pas une commande de ce module.
function M.DescribeLine(line)
	local cname, rest = M.SplitLine(trim(line))
	if not cname then return nil end
	local plan = M.GetPlan(cname, rest)
	if not plan then return nil end
	local cl, g = M.Select(plan)
	if not cl then return L("msg.macros.pv.none") end
	local what = cl.arg
	if cname == "castsequence" and cl.nseq and cl.nseq > 0 then
		local s = M.seq[cl]
		local i = s and s.i or 1
		if i > cl.nseq then i = 1 end
		what = cl.seq[i]
	end
	local out = cname
	if what and what ~= "" then out = out .. " " .. what end
	if g and g.unit then out = out .. " @" .. g.unit end
	return out
end

-- Apercu : une ligne de texte par commande reconnue. Renvoie le tableau (nouveau) et son nombre de lignes.
function M.Preview(body)
	local out = {}
	local lines = split(body or "", "\n")
	for i = 1, getn(lines) do
		local d = M.DescribeLine(lines[i])
		if d then tinsert(out, L("msg.macros.pv.line", i, d)) end
	end
	return out
end

-- Sort (ou objet) dont l'icone est montree par #showtooltip : nom, texture, entree du grimoire.
function M.TooltipSpell(body)
	local lines = split(body or "", "\n")
	local name
	for i = 1, getn(lines) do
		local _, _, arg = sfind(trim(lines[i]), "^#show[tooltip]*%s*(.*)$")
		if arg and arg ~= "" then
			name = arg
			break
		end
	end
	if not name then
		for i = 1, getn(lines) do
			local cname, rest = M.SplitLine(trim(lines[i]))
			if cname == "cast" or cname == "castsequence" or cname == "use" or cname == "equip" then
				local plan = M.GetPlan(cname, rest)
				if plan then
					local cl = M.Select(plan)
					if cl then
						local w = cl.arg
						if cname == "castsequence" and cl.nseq and cl.nseq > 0 then
							local s = M.seq[cl]
							local k = s and s.i or 1
							if k > cl.nseq then k = 1 end
							w = cl.seq[k]
						end
						if w and w ~= "" then
							name = w
							break
						end
					end
				end
			end
		end
	end
	if not name then return nil end
	local b = M.Lookup(name)
	if b then return b.name, b.tex, b end
	local tex
	if GetItemInfo then
		local _, _, _, _, _, _, _, _, _, t = GetItemInfo(name)
		tex = t
	end
	return name, tex, nil
end

-- Sorts du grimoire cites par la macro (sans doublon, 6 au plus). out : tableau reutilise ; renvoie le nombre.
function M.SpellsIn(body, out)
	for i = getn(out), 1, -1 do out[i] = nil end
	local lines = split(body or "", "\n")
	local function add(name)
		local b = M.Lookup(name)
		if not b or getn(out) >= 6 then return end
		for i = 1, getn(out) do
			if out[i] == b then return end
		end
		tinsert(out, b)
	end
	for i = 1, getn(lines) do
		local line = trim(lines[i])
		local _, _, arg = sfind(line, "^#show[tooltip]*%s*(.*)$")
		if arg then add(arg) end
		local cname, rest = M.SplitLine(line)
		if cname == "cast" or cname == "castsequence" then
			local plan = M.GetPlan(cname, rest)
			if plan then
				for k = 1, plan.n do
					local cl = plan[k]
					if cname == "cast" then add(cl.arg) else
						for s = 1, (cl.nseq or 0) do add(cl.seq[s]) end
					end
				end
			end
		end
	end
	return getn(out)
end

-- ---------------------------------------------------------------- mise en forme : version compactee et coloration
-- Version plus courte (255 caracteres maximum au jeu) : espaces en trop, commentaires "--", lignes vides, espaces dans les crochets.
function M.Compact(body)
	local out = {}
	local lines = split(body or "", "\n")
	for i = 1, getn(lines) do
		local line = trim(sgsub(lines[i], "\r", ""))
		if line ~= "" and ssub(line, 1, 2) ~= "--" then
			line = sgsub(line, "%s+", " ")
			if ssub(line, 1, 1) == "/" then
				line = sgsub(line, "%[(.-)%]", function(inner)
					inner = sgsub(inner, "%s*:%s*", ":")
					inner = sgsub(inner, "%s*,%s*", ",")
					inner = sgsub(inner, "target=", "@")
					return "[" .. trim(inner) .. "]"
				end)
				line = sgsub(line, "%]%s+%[", "][")
				line = sgsub(line, "%s*;%s*", ";")
				line = sgsub(line, "%s*,%s*", ",")
			end
			tinsert(out, line)
		end
	end
	return table.concat(out, "\n")
end

local function hex(c)
	return sformat("|cff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

local function accentHex()
	local r, g, b = T.Accent()
	return hex({ r, g, b })
end

-- Texte colore (|cffRRGGBB) d'un corps de macro : commandes = accent, conditions = orange, sorts connus = vert, commentaires = gris,
-- ligne en erreur = commande en rouge. Les barres verticales du texte sont doublees (elles ne doivent pas ouvrir un code couleur).
function M.Colorize(body)
	local an = M.Analyze(body)
	local cA, cW, cG, cD, cB, cT = accentHex(), hex(T.c.warn), hex(T.c.good), hex(T.c.dim), hex(T.c.bad), hex(T.c.text)
	local lines = split(body or "", "\n")
	local out = {}
	for i = 1, getn(lines) do
		local line = sgsub(sgsub(lines[i], "\r", ""), "|", "||")
		local t = trim(line)
		if ssub(t, 1, 1) == "#" or ssub(t, 1, 2) == "--" then
			tinsert(out, cD .. line .. "|r")
		elseif ssub(t, 1, 1) ~= "/" then
			tinsert(out, cT .. line .. "|r")
		else
			local _, e, word = sfind(line, "^(%s*/%S+)")
			local cname = M.SplitLine(t)
			local s = ((an.st[i] == "error") and cB or cA) .. word .. "|r"
			local p, len = e + 1, slen(line)
			while p <= len do
				local ch = ssub(line, p, p)
				if ch == "[" then
					local close = sfind(line, "]", p, true) or len
					s = s .. cW .. ssub(line, p, close) .. "|r"
					p = close + 1
				elseif ch == ";" then
					s = s .. cD .. ";|r"
					p = p + 1
				else
					local nxt = sfind(line, "[%[;]", p) or (len + 1)
					local seg = ssub(line, p, nxt - 1)
					p = nxt
					local _, _, lead, name, tail = sfind(seg, "^(%s*)(.-)(%s*)$")
					local col = cT
					if name ~= "" and cname == "cast" and M.IsKnown((sgsub(name, "^!", ""))) then col = cG end
					s = s .. lead .. col .. name .. "|r" .. tail
				end
			end
			tinsert(out, s)
		end
	end
	return table.concat(out, "\n")
end

-- ---------------------------------------------------------------- completion et insertion
M.snippets = { "mod:shift", "mod:ctrl", "mod:alt", "@mouseover", "@player", "help", "harm", "combat", "nocombat", "stance:1", "buff:", "nobuff:",
	"hp:<30", "mypower:>30" }
local COND_SPELLARG = { known = true, cooldown = true, reactive = true, buff = true, debuff = true, mybuff = true, mydebuff = true, casting = true }

-- Lit la derniere ligne du texte : renvoie le contexte ("spell" | "cond" | "arg" | nil), le fragment saisi, et le nom de la condition.
function M.Context(text)
	local _, _, line = sfind(text or "", "([^\n]*)$")
	line = line or ""
	if ssub(line, 1, 1) ~= "/" then return nil, "" end
	local _, e, word = sfind(line, "^(/%S+)")
	if not word then return nil, "" end
	local cname = M.byText[slower(word)]
	local rest = ssub(line, e + 1)
	local lb, lc = 0, 0
	local q = 1
	while true do
		local a = sfind(rest, "[", q, true)
		if not a then break end
		lb = a
		q = a + 1
	end
	q = 1
	while true do
		local a = sfind(rest, "]", q, true)
		if not a then break end
		lc = a
		q = a + 1
	end
	if lb > lc then
		local inner = ssub(rest, lb + 1)
		local _, _, frag = sfind(inner, "([^,%s]*)$")
		frag = frag or ""
		local ca = sfind(frag, ":", 1, true)
		if ca then
			local cn = slower(ssub(frag, 1, ca - 1))
			cn = sgsub(cn, "^no", "")
			if COND_SPELLARG[cn] then
				local _, _, af = sfind(ssub(frag, ca + 1), "([^/]*)$")
				return "arg", af or "", cn
			end
			return nil, ""
		end
		return "cond", frag
	end
	if cname ~= "cast" and cname ~= "castsequence" then return nil, "" end
	local tailStart = 1
	local a = sfind(rest, "[;%]]")
	if a then
		local last = a
		local b = a
		while b do
			last = b
			b = sfind(rest, "[;%]]", b + 1)
		end
		tailStart = last + 1
	end
	if cname == "castsequence" then
		local c2 = sfind(rest, ",[^,]*$")
		if c2 and c2 + 1 > tailStart then tailStart = c2 + 1 end
	end
	local tail = ssub(rest, tailStart)
	local _, _, frag = sfind(tail, "^%s*(.-)$")
	frag = sgsub(frag or "", "^!", "")
	if sfind(frag, "^reset=") then return nil, "" end
	return "spell", frag
end

-- Propositions pour le texte : tableau reutilise de { text, kind, flen } (6 au plus).
M.sug = {}
function M.Suggest(text)
	local out = M.sug
	for i = getn(out), 1, -1 do out[i] = nil end
	local ctx, frag, cn = M.Context(text)
	if not ctx then return out end
	local low = slower(frag)
	local fl = slen(frag)
	if ctx == "cond" then
		if fl < 1 then return out end
		for i = 1, getn(M.condNames) do
			local n = M.condNames[i]
			if getn(out) < 6 and ssub(n, 1, fl) == low and n ~= low then tinsert(out, { text = n, kind = "cond", flen = fl }) end
		end
		return out
	end
	if fl < 2 then return out end
	local list = M.spellList
	for pass = 1, 2 do
		for i = 1, getn(list) do
			if getn(out) < 6 then
				local nm = list[i]
				local ln = slower(nm)
				local hit = (pass == 1) and (ssub(ln, 1, fl) == low) or (pass == 2 and ssub(ln, 1, fl) ~= low and sfind(ln, low, 1, true))
				if hit and ln ~= low then
					local dup = false
					for k = 1, getn(out) do
						if out[k].text == nm then dup = true end
					end
					if not dup then tinsert(out, { text = nm, kind = "spell", flen = fl }) end
				end
			end
		end
	end
	return out
end

-- Remplace le fragment saisi (fin du texte) par la proposition.
function M.ApplySuggestion(text, s)
	local base = ssub(text, 1, slen(text) - s.flen)
	if s.kind == "cond" then
		local e = COND[s.text]
		if e and e.kind ~= "none" then return base .. s.text .. ":" end
		return base .. s.text .. "]"
	end
	return base .. s.text
end

-- Ajoute un sort a la derniere ligne (ou cree une ligne /cast).
function M.AppendSpell(text, name)
	text = text or ""
	local _, _, line = sfind(text, "([^\n]*)$")
	if text == "" then return "/cast " .. name end
	if ssub(line, 1, 1) ~= "/" then return text .. "\n/cast " .. name end
	local last = ssub(line, -1)
	if last == " " or last == "]" or last == ";" then return text .. (last == "]" and " " or "") .. name end
	if sfind(line, "^/%S+$") then return text .. " " .. name end
	return text .. "; " .. name
end

-- Insere une condition "mod:shift" dans la derniere ligne : dans le premier groupe s'il y en a un, sinon devant le sort.
function M.AddCond(text, cond)
	text = text or ""
	if text == "" then return "/cast [" .. cond .. "] " end
	local _, _, line = sfind(text, "([^\n]*)$")
	local pre = ssub(text, 1, slen(text) - slen(line))
	local _, e, word = sfind(line, "^(/%S+)")
	if not word then return text .. "\n/cast [" .. cond .. "] " end
	local rest = trim(ssub(line, e + 1))
	if ssub(rest, 1, 1) == "[" then
		local close = sfind(rest, "]", 1, true)
		if close then
			local inner = ssub(rest, 2, close - 1)
			local join = (inner == "") and "" or ","
			return pre .. word .. " [" .. inner .. join .. cond .. "]" .. ssub(rest, close + 1)
		end
	end
	return pre .. word .. " [" .. cond .. "] " .. rest
end

-- Cherche l'indice d'icone de macro (liste du jeu) d'une texture ; 1 si introuvable.
function M.IconIndex(tex)
	local n = getglobal("GetNumMacroIcons")
	local g = getglobal("GetMacroIconInfo")
	if not n or not g or not tex then return 1 end
	for i = 1, n() do
		if g(i) == tex then return i end
	end
	return 1
end

-- ---------------------------------------------------------------- macros du jeu
M.MAXACC, M.MAXCHAR = 18, 18
function M.Count()
	local a, c = GetNumMacros()
	return a or 0, c or 0
end

-- Rechauffe le cache d'analyse avec toutes les lignes de toutes les macros (hors combat).
function M.Prewarm()
	if SUI.InCombat() then
		M.prewarmPending = true
		return
	end
	M.prewarmPending = false
	for idx = 1, M.MAXACC + M.MAXCHAR do
		local _, _, body = GetMacroInfo(idx)
		if body then
			local lines = split(body, "\n")
			for i = 1, getn(lines) do
				local cname, rest = M.SplitLine(lines[i])
				if cname then M.GetPlan(cname, rest) end
			end
		end
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Apply()
	M.exec = (M.on and not M.conflict and C.Get("macros.exec")) and true or false
	if M.ui and M.ui.hookBtn then M.HookMacroFrame() end
	if M.ui and M.ui.frame and M.ui.frame:IsShown() then M.UIRefresh() end
end

function M.OnCast(ev, a1, a2)
	if ev == "SPELLCAST_START" then M.castName = a1
	elseif ev == "SPELLCAST_CHANNEL_START" then M.chanName = a2
	elseif ev == "SPELLCAST_CHANNEL_STOP" then M.chanName = nil
	else M.castName = nil end
end

function M.OnCombatFlag(ev)
	M.attacking = (ev == "PLAYER_ENTER_COMBAT")
end

function M.OnRegen()
	M.epoch = M.epoch + 1
	if M.bookPending then M.Scan() end
	if M.prewarmPending then M.Prewarm() end
end

function M.OnInventory(ev, a1)
	if a1 == "player" then M.RefreshEquip() end
end

function M.OnAction()
	M.actDirty = true
end

function M.OnMacros()
	M.Prewarm()
	if M.ui and M.ui.frame and M.ui.frame:IsShown() then M.UIRefreshList() end
end

function M.OnAddon(ev, a1)
	if a1 == "Blizzard_MacroUI" then SUI.WhenSafe(M.HookMacroFrame) end
end

-- Apres le chargement de tous les addons : un autre addon a-t-il repris nos entrees ?
function M.Verify()
	if not M.exec then return end
	for key, w in pairs(M.wrapped) do
		if SlashCmdList[key] ~= w.mine then
			if not M.warnedOver then
				M.warnedOver = true
				SUI.Print(L("msg.macros.overridden", key))
			end
			return
		end
	end
end

function M.Enable()
	M.on = true
	M.conflict = M.DetectConflict()
	M.warnSM = M.DetectSuperMacro()
	M.Scan()
	M.RefreshEquip()
	SUI.On("SPELLS_CHANGED", M.Scan)
	SUI.On("LEARNED_SPELL_IN_TAB", M.Scan)
	SUI.On("UPDATE_MACROS", M.OnMacros)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.On("SPELLCAST_START", M.OnCast)
	SUI.On("SPELLCAST_STOP", M.OnCast)
	SUI.On("SPELLCAST_FAILED", M.OnCast)
	SUI.On("SPELLCAST_INTERRUPTED", M.OnCast)
	SUI.On("SPELLCAST_CHANNEL_START", M.OnCast)
	SUI.On("SPELLCAST_CHANNEL_STOP", M.OnCast)
	SUI.On("PLAYER_ENTER_COMBAT", M.OnCombatFlag)
	SUI.On("PLAYER_LEAVE_COMBAT", M.OnCombatFlag)
	SUI.On("UNIT_INVENTORY_CHANGED", M.OnInventory)
	SUI.On("ACTIONBAR_SLOT_CHANGED", M.OnAction)
	SUI.On("ACTIONBAR_PAGE_CHANGED", M.OnAction)
	SUI.On("UPDATE_BONUS_ACTIONBAR", M.OnAction)
	SUI.On("PLAYER_ENTERING_WORLD", M.Verify)
	SUI.On("ADDON_LOADED", M.OnAddon)
	if M.conflict then
		if not M.conflictShown then
			M.conflictShown = true
			SUI.Print(L("msg.macros.conflict", M.conflict))
		end
	else
		M.Install()
		if M.warnSM and not M.smShown then
			M.smShown = true
			SUI.Print(L("msg.macros.supermacro"))
		end
	end
	if not M.watching then
		M.watching = true
		C.Watch("macros.", function(key, value) M.Apply() end)
	end
	M.Apply()
	M.Prewarm()
	SUI.WhenSafe(M.BuildTip)
	SUI.WhenSafe(M.HookMacroFrame)
end

function M.Disable()
	M.on = false
	M.exec = false
	M.Uninstall()
	SUI.Off("SPELLS_CHANGED", M.Scan)
	SUI.Off("LEARNED_SPELL_IN_TAB", M.Scan)
	SUI.Off("UPDATE_MACROS", M.OnMacros)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.Off("SPELLCAST_START", M.OnCast)
	SUI.Off("SPELLCAST_STOP", M.OnCast)
	SUI.Off("SPELLCAST_FAILED", M.OnCast)
	SUI.Off("SPELLCAST_INTERRUPTED", M.OnCast)
	SUI.Off("SPELLCAST_CHANNEL_START", M.OnCast)
	SUI.Off("SPELLCAST_CHANNEL_STOP", M.OnCast)
	SUI.Off("PLAYER_ENTER_COMBAT", M.OnCombatFlag)
	SUI.Off("PLAYER_LEAVE_COMBAT", M.OnCombatFlag)
	SUI.Off("UNIT_INVENTORY_CHANGED", M.OnInventory)
	SUI.Off("ACTIONBAR_SLOT_CHANGED", M.OnAction)
	SUI.Off("ACTIONBAR_PAGE_CHANGED", M.OnAction)
	SUI.Off("UPDATE_BONUS_ACTIONBAR", M.OnAction)
	SUI.Off("PLAYER_ENTERING_WORLD", M.Verify)
	SUI.Off("ADDON_LOADED", M.OnAddon)
	if M.ui and M.ui.frame then M.ui.frame:Hide() end
	if M.ui and M.ui.hookBtn then M.ui.hookBtn:Hide() end
end

-- Infobulle cachee pour lire le nom des auras sans SuperWoW (creee une fois, hors combat).
function M.BuildTip()
	if M.tip or not CreateFrame then return end
	local tip = CreateFrame("GameTooltip", "ShikiUI_MacroTip", UIParent, "GameTooltipTemplate")
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	M.tip = tip
	M.tipLeft = getglobal("ShikiUI_MacroTipTextLeft1")
end

-- ---------------------------------------------------------------- editeur de macros (fenetre ShikiUI_MacroEditor)
-- Surcouche : le MacroFrame du jeu reste intact (un bouton "Editeur ShikiUI" y est ajoute) ; l'editeur lit et ecrit les macros par
-- GetMacroInfo / EditMacro / CreateMacro / DeleteMacro. Limite du client 1.12 : on ne peut pas savoir quel mot est sous la souris dans une
-- zone de saisie ni colorer une zone de saisie -> les infobulles de sorts sont portees par des pastilles (sorts cites par la macro,
-- propositions, parcours du grimoire) et la coloration par une vue en lecture seule sous la zone de saisie.
M.ui = { items = {}, off = 0, rows = {}, chips = {}, sugs = {}, snips = {}, spellsTmp = {}, browse = 0, sel = nil, loading = false }
local U = M.ui
local ROWS, CHIPS, SUGS = 12, 6, 6
local HELPN = 14
M.HELPN = HELPN

local function setIf(fs, key, text)
	if U[key] ~= text then
		U[key] = text
		fs:SetText(text)
	end
end

local function setColor(fs, c)
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function tipSpell(btn, entry)
	local gt = getglobal("GameTooltip")
	if not gt or not entry then return end
	gt:SetOwner(btn, "ANCHOR_RIGHT")
	gt:SetSpell(entry.idx, "spell")
	gt:Show()
end

local function tipHide()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

-- Bouton avec icone a gauche et infobulle de sort (b.entry = entree du grimoire).
local function spellButton(parent, w, h, onclick)
	local b = T.Button(parent, "", w, h, onclick)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetWidth(h - 4)
	b.icon:SetHeight(h - 4)
	b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", b, "LEFT", h, 0)
	b.label:SetWidth(w - h - 4)
	b.label:SetJustifyH("LEFT")
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oe then oe() end
		local e = this.entry
		if e then tipSpell(this, e) end
	end)
	b:SetScript("OnLeave", function()
		if ol then ol() end
		tipHide()
	end)
	return b
end

local function fillSpellButton(b, entry, label)
	b.entry = entry
	T.SetButtonText(b, label)
	if entry and entry.tex then
		b.icon:SetTexture(entry.tex)
		b.icon:Show()
	else
		b.icon:Hide()
	end
end

local function btn(parent, label, w, h, x, y, fn)
	local b = T.Button(parent, label, w, h, fn)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	return b
end

-- ---------------------------------------------------------------- liste des macros
function M.UIRefreshList()
	if not U.frame then return end
	local items = U.items
	for i = getn(items), 1, -1 do items[i] = nil end
	for idx = 1, M.MAXACC + M.MAXCHAR do
		local name = GetMacroInfo(idx)
		if name then tinsert(items, idx) end
	end
	local n = getn(items)
	if U.off > n - ROWS then U.off = n - ROWS end
	if U.off < 0 then U.off = 0 end
	for r = 1, ROWS do
		local row = U.rows[r]
		local idx = items[U.off + r]
		row.idx = idx
		if idx then
			local name, tex = GetMacroInfo(idx)
			row.icon:SetTexture(tex)
			T.SetButtonText(row, (name or "?") .. ((idx > M.MAXACC) and " *" or ""))
			T.SetSelected(row, idx == U.sel)
			row:Show()
		else
			row:Hide()
		end
	end
	local a, c = M.Count()
	setIf(U.count, "lastCount", L("msg.macros.counts", a, M.MAXACC, c, M.MAXCHAR))
end

-- ---------------------------------------------------------------- contenu
function M.UIDynamic()
	if not U.frame then return end
	local text = U.edit:GetText() or ""
	local name, tex, entry = M.TooltipSpell(text)
	U.iconEntry = entry
	U.iconName = name
	if tex then
		U.iconTex:SetTexture(tex)
		U.iconTex:Show()
	else
		U.iconTex:Hide()
	end
	if C.Get("macros.preview") then
		local lines = M.Preview(text)
		local s = ""
		for i = 1, getn(lines) do
			if i <= 5 then s = s .. (i > 1 and "\n" or "") .. lines[i] end
		end
		if s == "" then s = L("msg.macros.pv.empty") end
		setIf(U.pv, "lastPv", L("msg.macros.pv.title") .. "\n" .. s)
		U.pv:Show()
	else
		U.pv:Hide()
	end
end

function M.UIRefresh()
	if not U.frame or U.loading then return end
	local text = U.edit:GetText() or ""
	local len = slen(text)
	setIf(U.counter, "lastCounter", len .. "/" .. M.MAXLEN)
	if len > M.MAXLEN then setColor(U.counter, T.c.bad)
	elseif len > C.Get("macros.lenwarn") then setColor(U.counter, T.c.warn)
	else setColor(U.counter, T.c.dim) end
	-- vue coloree / aide
	local an
	if U.showHelp then
		local s = ""
		for i = 1, HELPN do s = s .. L("msg.macros.help." .. i) .. "\n" end
		setIf(U.view, "lastView", s)
		an = M.Analyze(text)
	elseif C.Get("macros.syntax") then
		setIf(U.view, "lastView", M.Colorize(text))
		an = M.an
	else
		setIf(U.view, "lastView", (sgsub(text, "|", "||")))
		an = M.Analyze(text)
	end
	-- etat
	if len > M.MAXLEN then
		setIf(U.status, "lastStatus", L("msg.macros.toolong", len - M.MAXLEN))
		setColor(U.status, T.c.bad)
	elseif an.errs > 0 then
		setIf(U.status, "lastStatus", an.first)
		setColor(U.status, T.c.bad)
	elseif an.warns > 0 then
		setIf(U.status, "lastStatus", an.first)
		setColor(U.status, T.c.warn)
	else
		setIf(U.status, "lastStatus", L("msg.macros.syntaxok"))
		setColor(U.status, T.c.good)
	end
	-- pastilles : sorts cites
	local n = M.SpellsIn(text, U.spellsTmp)
	for i = 1, CHIPS do
		local b = U.chips[i]
		local e = U.spellsTmp[i]
		if e then
			fillSpellButton(b, e, e.name)
			b:Show()
		else
			b.entry = nil
			b:Hide()
		end
	end
	-- propositions (completion) ou parcours du grimoire
	for i = 1, SUGS do
		local b = U.sugs[i]
		b.sText = nil
		b.entry = nil
		b:Hide()
	end
	if U.browse > 0 then
		local list = M.spellList
		local first = (U.browse - 1) * SUGS
		for i = 1, SUGS do
			local nm = list[first + i]
			if nm then
				local b = U.sugs[i]
				b.sText, b.sKind = nm, "browse"
				fillSpellButton(b, M.Lookup(nm), nm)
				b:Show()
			end
		end
	elseif C.Get("macros.autocomplete") then
		local sg = M.Suggest(text)
		for i = 1, getn(sg) do
			local b = U.sugs[i]
			local s = sg[i]
			b.sText, b.sKind, b.sFlen = s.text, s.kind, s.flen
			fillSpellButton(b, (s.kind == "spell") and M.Lookup(s.text) or nil, s.text)
			if s.kind == "cond" then b.icon:Hide() end
			b:Show()
		end
	end
	M.UIDynamic()
end

function M.UILoad(idx)
	if not U.frame then return end
	local name, tex, body = GetMacroInfo(idx)
	if not name then return end
	U.sel = idx
	U.name0 = name
	U.tex = tex
	U.base = body or ""
	U.loading = true
	U.nameEdit:SetText(name)
	U.edit:SetText(body or "")
	U.loading = false
	U.lastView = nil
	M.UIRefreshList()
	M.UIRefresh()
end

function M.UISave()
	if not U.frame or not U.sel then return false end
	local text = U.edit:GetText() or ""
	if slen(text) > M.MAXLEN then
		SUI.Print(L("msg.macros.toolong", slen(text) - M.MAXLEN))
		return false
	end
	local name = trim(U.nameEdit:GetText() or "")
	if name == "" then name = U.name0 end
	local ok, err
	if name == U.name0 then
		ok, err = pcall(EditMacro, U.sel, nil, nil, text)
	else
		ok, err = pcall(EditMacro, U.sel, name, M.IconIndex(U.tex), text)
	end
	if not ok then
		SUI.Report("macros save", err)
		SUI.Print(L("msg.macros.saveerr"))
		return false
	end
	U.base = text
	U.name0 = name
	SUI.Print(L("msg.macros.saved", name))
	M.Prewarm()
	M.UIRefreshList()
	return true
end

function M.UINew()
	if not U.frame then return end
	if SUI.InCombat() then
		SUI.Print(L("msg.macros.combat"))
		return
	end
	local a, c = M.Count()
	if a >= M.MAXACC and c >= M.MAXCHAR then
		SUI.Print(L("msg.macros.full"))
		return
	end
	local perChar = (c < M.MAXCHAR) and 1 or nil
	local ok, idx = pcall(CreateMacro, L("msg.macros.newname"), 1, "", 1, perChar)
	if not ok or not idx then
		SUI.Print(L("msg.macros.saveerr"))
		return
	end
	M.UIRefreshList()
	M.UILoad(idx)
end

function M.UIDelete()
	if not U.frame or not U.sel then return end
	local now = GetTime()
	if not U.delArm or now - U.delArm > 3 then
		U.delArm = now
		T.SetButtonText(U.delBtn, L("msg.macros.confirm"))
		return
	end
	U.delArm = nil
	T.SetButtonText(U.delBtn, L("msg.macros.delete"))
	local idx = U.sel
	local ok = pcall(DeleteMacro, idx)
	if not ok then
		SUI.Print(L("msg.macros.saveerr"))
		return
	end
	U.sel = nil
	U.loading = true
	U.nameEdit:SetText("")
	U.edit:SetText("")
	U.loading = false
	M.UIRefreshList()
	if U.items[1] then M.UILoad(U.items[1]) else M.UIRefresh() end
end

function M.UICompact()
	if not U.frame then return end
	local text = U.edit:GetText() or ""
	local short = M.Compact(text)
	if short == text then
		SUI.Print(L("msg.macros.compact0"))
		return
	end
	U.edit:SetText(short)
	SUI.Print(L("msg.macros.compact", slen(text), slen(short)))
end

function M.UISuggest(b)
	if not U.frame or not b.sText then return end
	local text = U.edit:GetText() or ""
	if b.sKind == "browse" then
		U.edit:SetText(M.AppendSpell(text, b.sText))
	else
		U.edit:SetText(M.ApplySuggestion(text, { text = b.sText, kind = b.sKind, flen = b.sFlen or 0 }))
	end
	U.edit:SetFocus()
end

function M.UIToggleHelp()
	U.showHelp = not U.showHelp
	T.SetSelected(U.helpBtn, U.showHelp)
	U.lastView = nil
	M.UIRefresh()
end

function M.UIBrowse(delta)
	local pages = floor((getn(M.spellList) + SUGS - 1) / SUGS)
	if delta == 0 then
		U.browse = (U.browse > 0) and 0 or 1
	else
		U.browse = U.browse + delta
		if U.browse < 1 then U.browse = 1 end
		if U.browse > pages then U.browse = pages end
		if U.browse < 1 then U.browse = 0 end
	end
	T.SetSelected(U.spellBtn, U.browse > 0)
	M.UIRefresh()
end

function M.UITick()
	if U.frame and U.frame:IsShown() then M.UIDynamic() end
end

-- ---------------------------------------------------------------- construction (une seule fois, hors combat)
function M.BuildUI()
	if U.frame then return end
	local f = CreateFrame("Frame", "ShikiUI_MacroEditor", UIParent)
	f:SetWidth(700)
	f:SetHeight(580)
	f:SetFrameStrata("DIALOG")
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	U.frame = f
	tinsert(UISpecialFrames, "ShikiUI_MacroEditor")

	local title = T.Text(f, 13, T.c.text, "LEFT")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
	title:SetText(L("msg.macros.title"))
	local close = btn(f, "X", 22, 20, 700 - 34, -10, function() f:Hide() end)

	-- liste
	for r = 1, ROWS do
		local row = T.Button(f, "", 180, 22, function(b)
			if b.idx then M.UILoad(b.idx) end
		end)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36 - (r - 1) * 23)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(18)
		row.icon:SetHeight(18)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", row, "LEFT", 24, 0)
		row.label:SetWidth(150)
		row.label:SetJustifyH("LEFT")
		U.rows[r] = row
	end
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function()
		U.off = U.off - (arg1 or 0)
		M.UIRefreshList()
	end)
	U.count = T.Text(f, 10, T.c.dim, "LEFT")
	U.count:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -316)
	btn(f, L("msg.macros.new"), 88, 20, 12, -334, function() M.UINew() end)
	U.delBtn = btn(f, L("msg.macros.delete"), 88, 20, 104, -334, function() M.UIDelete() end)
	local legend = T.Text(f, 10, T.c.dim, "LEFT")
	legend:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -360)
	legend:SetText(L("msg.macros.legend"))

	-- nom, compteur, icone
	U.nameEdit = T.Edit(f, 250, 20)
	U.nameEdit:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -34)
	U.nameEdit:SetMaxLetters(16)
	U.counter = T.Text(f, 12, T.c.dim, "RIGHT")
	U.counter:SetWidth(120)
	U.counter:SetPoint("TOPLEFT", f, "TOPLEFT", 470, -38)
	local ib = CreateFrame("Button", "ShikiUI_MacroEditorIcon", f)
	ib:SetWidth(34)
	ib:SetHeight(34)
	ib:SetPoint("TOPLEFT", f, "TOPLEFT", 700 - 52, -34)
	T.Backdrop(ib, T.c.inset, T.c.border)
	U.iconTex = ib:CreateTexture(nil, "ARTWORK")
	U.iconTex:SetPoint("TOPLEFT", ib, "TOPLEFT", 2, -2)
	U.iconTex:SetPoint("BOTTOMRIGHT", ib, "BOTTOMRIGHT", -2, 2)
	ib:SetScript("OnEnter", function()
		if U.iconEntry then
			tipSpell(this, U.iconEntry)
		else
			local gt = getglobal("GameTooltip")
			if gt and U.iconName then
				gt:SetOwner(this, "ANCHOR_RIGHT")
				gt:SetText(U.iconName)
				gt:Show()
			end
		end
	end)
	ib:SetScript("OnLeave", function() tipHide() end)
	U.iconBtn = ib

	-- zone de saisie
	local e = T.Edit(f, 482, 140)
	e:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -64)
	e:SetMultiLine(true)
	e:SetMaxLetters(1000)
	e:SetTextInsets(4, 4, 4, 4)
	e:SetScript("OnTextChanged", function()
		if not U.loading then M.UIRefresh() end
	end)
	U.edit = e
	U.status = T.Text(f, 11, T.c.good, "LEFT")
	U.status:SetWidth(482)
	U.status:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -208)

	-- pastilles : sorts cites
	for i = 1, CHIPS do
		local b = spellButton(f, 78, 20, function() end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 206 + (i - 1) * 81, -226)
		b:Hide()
		U.chips[i] = b
	end

	-- vue coloree / aide
	local vp = T.Panel(f, 482, 94)
	vp:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -250)
	T.Backdrop(vp, T.c.inset, T.c.border)
	U.view = T.Text(vp, 11, T.c.text, "LEFT")
	U.view:SetWidth(470)
	U.view:SetHeight(86)
	U.view:SetJustifyV("TOP")
	U.view:SetPoint("TOPLEFT", vp, "TOPLEFT", 6, -4)

	-- actions
	btn(f, L("msg.macros.save"), 82, 20, 206, -350, function() M.UISave() end)
	btn(f, L("msg.macros.compactbtn"), 82, 20, 292, -350, function() M.UICompact() end)
	btn(f, L("msg.macros.revert"), 82, 20, 378, -350, function()
		if U.sel then M.UILoad(U.sel) end
	end)
	U.helpBtn = btn(f, L("msg.macros.helpbtn"), 82, 20, 464, -350, function() M.UIToggleHelp() end)
	U.spellBtn = btn(f, L("msg.macros.spellsbtn"), 82, 20, 550, -350, function() M.UIBrowse(0) end)
	btn(f, "<", 22, 20, 636, -350, function() M.UIBrowse(-1) end)
	btn(f, ">", 22, 20, 660, -350, function() M.UIBrowse(1) end)

	-- propositions
	for i = 1, SUGS do
		local col = (i - 1) - 2 * floor((i - 1) / 2)
		local row = floor((i - 1) / 2)
		local b = spellButton(f, 238, 20, function(bb) M.UISuggest(bb) end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 206 + col * 244, -376 - row * 22)
		b:Hide()
		U.sugs[i] = b
	end

	-- insertion de conditions
	for i = 1, getn(M.snippets) do
		local col = (i - 1) - 7 * floor((i - 1) / 7)
		local row = floor((i - 1) / 7)
		local sn = M.snippets[i]
		local b = btn(f, sn, 66, 18, 206 + col * 69, -448 - row * 20, function()
			U.edit:SetText(M.AddCond(U.edit:GetText() or "", sn))
			U.edit:SetFocus()
		end)
		U.snips[i] = b
	end

	-- apercu
	U.pv = T.Text(f, 11, T.c.dim, "LEFT")
	U.pv:SetWidth(482)
	U.pv:SetHeight(76)
	U.pv:SetJustifyV("TOP")
	U.pv:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -492)

	f:SetScript("OnShow", function()
		if not U.task then U.task = SUI.Every(0.5, M.UITick, "macros.ui", true) end
		M.UIRefreshList()
		M.UIRefresh()
	end)
	f:SetScript("OnHide", function()
		SUI.Cancel(U.task)
		U.task = nil
		tipHide()
	end)
end

function M.OpenEditor(idx)
	if not M.on then
		SUI.Print(L("msg.macros.off"))
		return false
	end
	if SUI.InCombat() then
		SUI.Print(L("msg.macros.combat"))
		return false
	end
	M.BuildUI()
	local mf = getglobal("MacroFrame")
	if mf and mf.IsShown and mf:IsShown() and getglobal("HideUIPanel") then HideUIPanel(mf) end
	U.frame:Show()
	M.UIRefreshList()
	if idx and GetMacroInfo(idx) then M.UILoad(idx)
	elseif not U.sel or not GetMacroInfo(U.sel) then
		if U.items[1] then M.UILoad(U.items[1]) else M.UIRefresh() end
	end
	return true
end

-- Bouton "Editeur ShikiUI" ajoute a la fenetre de macros du jeu (Blizzard_MacroUI se charge a la demande).
function M.HookMacroFrame()
	local mf = getglobal("MacroFrame")
	if not mf then return end
	if not U.hookBtn then
		local b = T.Button(mf, L("msg.macros.mfbtn"), 120, 20, function()
			M.OpenEditor(mf.selectedMacro)
		end)
		b:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -70, -14)
		U.hookBtn = b
	end
	if M.on and C.Get("macros.mfbutton") then U.hookBtn:Show() else U.hookBtn:Hide() end
end

-- ---------------------------------------------------------------- commandes /sui macros
function M.CmdCheck(arg)
	arg = trim(arg or "")
	if arg == "" then
		SUI.Print(L("msg.macros.usage"))
		return
	end
	if ssub(arg, 1, 1) ~= "/" then arg = "/cast " .. arg end
	local st, key, a = M.CheckLine(arg)
	if st == "error" then
		SUI.Print(L("msg.macros.check.err", M.ErrText(key, a)))
	elseif st == "warn" then
		SUI.Print(L("msg.macros.check.warn", M.ErrText(key, a)))
	elseif st == "ok" then
		SUI.Print(L("msg.macros.check.ok", M.DescribeLine(arg) or "-"))
	else
		SUI.Print(L("msg.macros.check.other"))
	end
end

function M.CmdList()
	local n = 0
	for idx = 1, M.MAXACC + M.MAXCHAR do
		local name, tex, body = GetMacroInfo(idx)
		if name then
			n = n + 1
			local an = M.Analyze(body or "")
			local sum
			if an.errs > 0 or an.warns > 0 then sum = L("msg.macros.list.bad", an.errs, an.warns) else sum = L("msg.macros.list.ok") end
			SUI.Print(L("msg.macros.list.line", idx, name, slen(body or ""), sum))
		end
	end
	if n == 0 then SUI.Print(L("msg.macros.list.none")) end
end

function M.CmdStatus()
	local s
	if not M.on then s = L("msg.macros.off")
	elseif M.conflict then s = L("msg.macros.status.conflict", M.conflict)
	elseif M.exec then s = L("msg.macros.status.on")
	else s = L("msg.macros.status.paused") end
	SUI.Print(s)
	SUI.Print(L("msg.macros.usage"))
end

function M.Command(rest)
	local _, _, sub, arg = sfind(rest or "", "^%s*(%S*)%s*(.-)%s*$")
	sub = slower(sub or "")
	if sub == "help" then
		for i = 1, HELPN do SUI.Print(L("msg.macros.help." .. i)) end
	elseif sub == "check" then
		M.CmdCheck(arg)
	elseif sub == "list" then
		M.CmdList()
	elseif sub == "edit" or sub == "editor" then
		M.OpenEditor(tonumber(arg))
	else
		M.CmdStatus()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("macros", 60)

local function opt(key, typ, order, def0, extra)
	local o = { key = "macros." .. key, type = typ, cat = "macros", label = "opt.macros." .. key, tip = "tip.macros." .. key, default = def0, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("macros", {
	default = false,
	cost = "light",
	options = {
		opt("exec", "bool", 10, true, { simple = true }),
		opt("hidehint", "bool", 20, true, { simple = true }),
		opt("mfbutton", "bool", 30, true, { simple = true }),
		opt("autocomplete", "bool", 40, true, { simple = true }),
		opt("syntax", "bool", 50, true),
		opt("preview", "bool", 60, true),
		opt("lenwarn", "number", 70, 230, { min = 100, max = 255, step = 5 }),
		opt("verbose", "bool", 80, false),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("macros", function(rest) M.Command(rest) end, "help.macros")
