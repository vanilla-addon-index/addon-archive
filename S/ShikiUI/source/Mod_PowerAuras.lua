-- ShikiUI PowerAuras : alertes visuelles creees par le joueur (esprit WeakAuras / PowerAuras, version simple pour WoW 1.12). Code ecrit pour
-- ShikiUI, rien de copie. Une ALERTE = un declencheur + un affichage :
--   aura   : buff / debuff sur moi ou sur la cible (nom du sort ou icone, present / absent, piles, duree restante) ;
--   cd     : temps de recharge d'un sort ou d'un objet (pret / en recharge / toujours visible) ;
--   power  : barre de vie, de ressource (rage, energie, mana) ou de points de combo ;
--   cond   : condition (ma vie < X %, mon mana < X %, vie de la cible < X %, points de combo >= X).
--   Option "proc" : quand l'alerte s'allume, une banniere (icone + texte) apparait au centre, un son joue et l'ecran peut clignoter.
--   Affichage : icone (taille, bordure, glow fixe ou pulsant, temps, piles, nom), barre ou texte ; 8 ZONES deplacables (SUI.Mover) dont
--   chacune empile ses alertes vers la droite / la gauche / le bas / le haut. Visibilite par alerte : combat, groupe, classe, specialisation.
--   Des PACKS par classe et par role s'installent en un clic ; un editeur simple dans la page du module cree, copie et regle les alertes.
-- API 1.12 relevees dans des addons installes (voir aussi Mod_Auras.lua) : GetPlayerBuff(i, "HELPFUL" | "HARMFUL") (i a partir de 0, -1 en fin),
--   GetPlayerBuffTexture / Applications / TimeLeft(indice), UnitBuff / UnitDebuff("target", i) -> texture, piles ; le NOM d'une aura se lit
--   par une infobulle cachee (SetPlayerBuff / SetUnitBuff / SetUnitDebuff, ligne 1) ; SuperWoW (SUI.Api.superwow) : GetPlayerBuffID + SpellInfo
--   donnent le nom sans infobulle. GetSpellName / GetSpellTexture / GetSpellCooldown(indice, "spell") ; GetContainerItemLink / Info / Cooldown ;
--   GetInventoryItemLink / Texture / Cooldown ; GetItemCount ; GetComboPoints() ; UnitHealth / UnitMana ; CooldownFrame_SetTimer (balayage).
-- Les durees des auras d'une CIBLE n'existent pas en 1.12 : une duree ESTIMEE (reglage "dur", en secondes) demarre quand l'aura apparait
--   sous nos yeux (jamais pour une aura deja posee a la selection de la cible).
-- Cout declare : LIGHT. Une seule minuterie partagee (SUI.Every) creee seulement s'il existe une alerte active ; evenements ecoutes seulement
--   dans ce cas (UNIT_AURA filtre sur "player" et "target") ; les listes d'auras ne sont relues qu'apres un evenement ; les noms d'auras
--   (infobulle) ne sont lus que pour les auras utiles et memorises jusqu'a la prochaine relecture ; tuiles et zones preparees hors combat,
--   jamais creees en combat ; aucune table creee dans la minuterie (fiches d'alertes et listes d'auras preallouees).
-- NON VERIFIE EN JEU : tout le rendu ; les noms anglais des sorts des packs (client non anglais : l'editeur signale "sort inconnu" ; on peut
--   alors prendre l'aura dans la liste des auras actuelles) ; la lecture de la ligne 1 de l'infobulle (ShikiUI_PATipTextLeft1) ; GetPlayerBuffID
--   et SpellInfo (SuperWoW) ; le modele "Cooldown" (CooldownFrame_SetTimer) ; PlaySound("MapPing" | "TellMessage" | "LEVELUP").
-- Lua 5.0 : pas de #, de %, de select ni de ... ; au plus 32 valeurs externes par fonction.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.PowerAuras = M

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, ceil, mmax, mmin = math.floor, math.ceil, math.max, math.min
local strfind, strsub, strlower, strformat, strlen, strgsub = string.find, string.sub, string.lower, string.format, string.len, string.gsub
local EMPTY = ""

M.on = false
M.MAXA = 24                  -- alertes au plus
M.NZONE = 8                  -- zones deplacables
M.GCD = 1.6                  -- un recharge de cette duree ou moins est le delai global, pas un vrai temps de recharge
M.QUIET_LOAD = 1             -- secondes sans declenchement apres un rechargement des alertes (edition, profil)
M.QUIET_WORLD = 3            -- idem apres une entree dans le monde (les auras deja presentes ne declenchent rien)
M.SOUND_GAP = 0.6
M.FLASHT = 0.35
M.UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
M.ZW, M.ZH = 40, 40          -- taille FIXE du cadre d'une zone : les alertes se rangent a partir de lui, vers la direction choisie

-- ---------------------------------------------------------------- valeurs permises
M.KINDS = { "aura", "cd", "power", "cond" }
M.ENUM = {
	kind = M.KINDS,
	unit = { "player", "target" },
	filt = { "buff", "debuff" },
	disp = { "icon", "bar", "text" },
	glow = { "none", "border", "pulse" },
	snd = { "none", "raid", "ping", "tell", "level" },
	col = { "accent", "good", "warn", "bad", "text" },
	vc = { "any", "combat", "nocombat" },
	grp = { "any", "solo", "grouped", "raid" },
	cls = { "ANY", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
}
M.WHEN = { aura = { "has", "missing" }, cd = { "ready", "cool", "always" }, power = { "always", "nonzero" }, cond = { "on" } }
M.RES = { power = { "health", "power", "combo" }, cond = { "hplow", "manalow", "targetlow", "combo" } }
M.SIZES = { 16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 80, 96 }
M.HOLDS = { 1, 2, 3, 4, 5, 8, 10 }
M.THR = { 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90 }
M.THRC = { 1, 2, 3, 4, 5 }
M.DURS = { 0, 6, 8, 10, 12, 15, 18, 20, 24, 30, 45, 60, 120, 300 }
M.MINST = { 1, 2, 3, 4, 5, 8, 10, 20 }
M.SPECS = { 0, 1, 2, 3 }
M.ZONES = { 1, 2, 3, 4, 5, 6, 7, 8 }
M.DIRS = { "r", "l", "d", "u" }
M.NUMLIST = { size = M.SIZES, hold = M.HOLDS, minst = M.MINST, dur = M.DURS, spec = M.SPECS, zone = M.ZONES }

-- Champs d'une alerte : { cle courte (sauvegarde), nom, type (s chaine, n nombre, b booleen), defaut }. Seuls les ecarts sont sauvegardes.
M.F = {
	{ "k", "kind", "s", "aura" }, { "i", "id", "n", 0 }, { "e", "on", "b", true }, { "u", "unit", "s", "player" },
	{ "f", "filt", "s", "buff" }, { "n", "name", "s", EMPTY }, { "t", "tex", "s", EMPTY }, { "w", "when", "s", "has" },
	{ "d", "disp", "s", "icon" }, { "z", "zone", "n", 1 }, { "s", "size", "n", 40 }, { "g", "glow", "s", "border" },
	{ "a", "snd", "s", "none" }, { "c", "col", "s", "accent" }, { "m", "minst", "n", 1 }, { "h", "thr", "n", 30 },
	{ "r", "res", "s", "health" }, { "v", "vc", "s", "any" }, { "q", "grp", "s", "any" }, { "l", "cls", "s", "ANY" },
	{ "p", "spec", "n", 0 }, { "x", "proc", "b", false }, { "o", "hold", "n", 3 }, { "j", "tm", "b", true },
	{ "b", "sk", "b", true }, { "L", "lb", "b", false }, { "D", "dur", "n", 0 }, { "I", "item", "b", false },
	{ "P", "pack", "s", EMPTY },
}
M.FS, M.FL = {}, {}
for i = 1, getn(M.F) do
	M.FS[M.F[i][1]] = M.F[i]
	M.FL[M.F[i][2]] = M.F[i]
end

-- ---------------------------------------------------------------- sons
M.SOUNDFILE = { raid = "Sound\\Interface\\RaidWarning.wav" }
M.SOUNDNAME = { ping = "MapPing", tell = "TellMessage", level = "LEVELUP" }

-- ---------------------------------------------------------------- etat
M.recs, M.alerts, M.nal, M.nact = {}, {}, 0, 0
M.tiles, M.zf, M.zd = {}, {}, {}
M.book = {}
M.cfg = { show = true, sound = true, flash = "soft", border = "color", sweep = true, tenths = true, alpha = 1, spacing = 4, tick = 0.2 }
M.need = { pb = false, pd = false, tb = false, td = false, book = false, items = false, names = false, banner = false, spec = false }
M.dA = { pb = false, pd = false, tb = false, td = false }
M.dBook, M.dItems, M.dSpec = false, false, false
M.A = {}
M.NA = { pb = 32, pd = 16, tb = 16, td = 16 }
M.gen = 1
M.spec = -1
M.class = EMPTY
M.demo = false
M.relayout = false
M.quietUntil = 0
M.lastSound = 0
M.bannerUntil, M.flashUntil = 0, 0
M.nfired, M.lastFired = 0, 0
M.raidN, M.partyN = 0, 0
M.nextId = 1
M.editId = 0
M.pick = false
M.allPacks = false
M.edit = { name = EMPTY }
M.cfgver = 1

for key, mx in pairs(M.NA) do
	local l = { n = 0, max = mx, tex = {}, cnt = {}, idx = {}, nm = {}, nml = {}, ng = {} }
	for i = 1, mx do l.tex[i], l.cnt[i], l.idx[i], l.nm[i], l.nml[i], l.ng[i] = EMPTY, 0, 0, EMPTY, EMPTY, 0 end
	M.A[key] = l
end
for i = 1, M.NZONE do M.zd[i] = "r" end

-- ---------------------------------------------------------------- fiches d'alertes (preallouees : aucune table creee ensuite)
function M.ResetRuntime(a)
	a.act, a.was, a.tile, a.shown = false, false, false, false
	a.left, a.hasleft, a.cnt, a.frac, a.tot, a.mx = 0, false, 0, 1, 0, 0
	a.start, a.dur0 = 0, 0
	a.dtex, a.texd, a.texr, a.namel = EMPTY, EMPTY, EMPTY, EMPTY
	a.idx, a.bag, a.slot, a.inv, a.icount = 0, -1, 0, 0, 0
	a.known, a.wp, a.sw, a.ts = false, false, false, 0
	a.incomplete, a.lk = false, EMPTY
	a.clsok, a.specok = true, true
	a.tsig, a.tkey = -1, -1
end

function M.Fresh(a)
	for i = 1, getn(M.F) do
		local f = M.F[i]
		a[f[2]] = f[4]
	end
	M.ResetRuntime(a)
end

for i = 1, M.MAXA do
	local r = {}
	M.Fresh(r)
	M.recs[i] = r
end

function M.InList(list, v)
	for i = 1, getn(list) do
		if list[i] == v then return true end
	end
	return false
end

-- Texte libre : sans les separateurs de la sauvegarde, sans espaces aux bords, 40 caracteres au plus.
function M.Clean(s)
	s = tostring(s or EMPTY)
	s = strgsub(s, "[;|=\n\r\t]", " ")
	s = strgsub(s, "^%s+", EMPTY)
	s = strgsub(s, "%s+$", EMPTY)
	if strlen(s) > 40 then s = strsub(s, 1, 40) end
	return s
end

function M.TexNorm(s)
	local t = strgsub(s or EMPTY, "\\", "/")
	return t
end

-- Corrige une fiche : valeurs permises, bornes, champs derives. Retourne true si la fiche est utilisable.
function M.Normalize(a)
	for key, list in pairs(M.ENUM) do
		if not M.InList(list, a[key]) then a[key] = M.FL[key][4] end
	end
	local wl = M.WHEN[a.kind]
	if not M.InList(wl, a.when) then a.when = wl[1] end
	local rl = M.RES[a.kind]
	if rl and not M.InList(rl, a.res) then a.res = rl[1] end
	if a.zone < 1 then a.zone = 1 end
	if a.zone > M.NZONE then a.zone = M.NZONE end
	a.zone = floor(a.zone)
	a.size = mmin(96, mmax(16, floor(a.size)))
	a.minst = mmin(99, mmax(1, floor(a.minst)))
	a.thr = mmin(100, mmax(0, floor(a.thr)))
	a.spec = mmin(3, mmax(0, floor(a.spec)))
	a.hold = mmin(10, mmax(1, a.hold))
	a.dur = mmin(3600, mmax(0, a.dur))
	a.id = mmax(0, floor(a.id))
	a.name = M.Clean(a.name)
	a.tex = M.TexNorm(M.Clean(a.tex))
	a.pack = M.Clean(a.pack)
	a.namel = strlower(a.name)
	a.texd = strgsub(a.tex, "/", "\\")
	a.texr = strlower(a.texd)
	a.incomplete = (a.kind == "aura" or a.kind == "cd") and a.name == EMPTY and a.tex == EMPTY
	if a.kind == "aura" then
		a.lk = (a.unit == "player") and ((a.filt == "buff") and "pb" or "pd") or ((a.filt == "buff") and "tb" or "td")
	else
		a.lk = EMPTY
	end
	if a.kind ~= "cd" then a.item = false end
	return true
end

-- ---------------------------------------------------------------- sauvegarde : "k=aura|i=3|n=Reaction;k=cd|..."
function M.DecodeInto(a, s)
	M.Fresh(a)
	local pos, n = 1, strlen(s)
	while pos <= n do
		local e = strfind(s, "|", pos, true)
		local piece
		if e then
			piece = strsub(s, pos, e - 1)
			pos = e + 1
		else
			piece = strsub(s, pos)
			pos = n + 1
		end
		local eq = strfind(piece, "=", 1, true)
		if eq and eq > 1 then
			local f = M.FS[strsub(piece, 1, eq - 1)]
			local val = strsub(piece, eq + 1)
			if f then
				if f[3] == "n" then
					local x = tonumber(val)
					if x then a[f[2]] = x end
				elseif f[3] == "b" then
					a[f[2]] = (val == "1")
				else
					a[f[2]] = val
				end
			end
		end
	end
	return M.Normalize(a)
end

function M.EncodeOne(a)
	local parts = {}
	for i = 1, getn(M.F) do
		local f = M.F[i]
		local v = a[f[2]]
		if f[1] == "i" or f[1] == "k" or v ~= f[4] then
			local sv
			if f[3] == "b" then sv = v and "1" or "0"
			elseif f[3] == "n" then sv = tostring(v)
			else sv = v end
			tinsert(parts, f[1] .. "=" .. sv)
		end
	end
	return table.concat(parts, "|")
end

function M.Save()
	local parts = {}
	for i = 1, M.nal do parts[i] = M.EncodeOne(M.alerts[i]) end
	C.SetBase("powerauras.data", table.concat(parts, ";"))
end

-- ---------------------------------------------------------------- chargement des alertes
function M.Load()
	M.ReleaseAll()
	if M.class == EMPTY and UnitClass then
		local _, cls = UnitClass("player")
		M.class = cls or EMPTY
	end
	local data = C.Get("powerauras.data") or EMPTY
	local pos, n = 1, strlen(data)
	local cnt = 0
	while pos <= n and cnt < M.MAXA do
		local e = strfind(data, ";", pos, true)
		local piece
		if e then
			piece = strsub(data, pos, e - 1)
			pos = e + 1
		else
			piece = strsub(data, pos)
			pos = n + 1
		end
		if piece ~= EMPTY then
			local rec = M.recs[cnt + 1]
			if M.DecodeInto(rec, piece) then
				cnt = cnt + 1
				M.alerts[cnt] = rec
			end
		end
	end
	for i = cnt + 1, getn(M.alerts) do M.alerts[i] = nil end
	M.nal = cnt
	-- identifiants uniques et non nuls
	local maxid = 0
	for i = 1, cnt do
		if M.alerts[i].id > maxid then maxid = M.alerts[i].id end
	end
	for i = 1, cnt do
		local a = M.alerts[i]
		local dup = (a.id == 0)
		for j = 1, i - 1 do
			if M.alerts[j].id == a.id then dup = true end
		end
		if dup then
			maxid = maxid + 1
			a.id = maxid
		end
	end
	M.nextId = maxid + 1
	M.cfgver = M.cfgver + 1
	M.Compile()
	M.quietUntil = GetTime() + M.QUIET_LOAD
	M.Sync()
	M.Refresh()
	if M.Rerender then M.Rerender() end
end

-- Besoins des alertes actives (quelles listes lire, faut-il le grimoire, les objets, les noms, la banniere...).
function M.Compile()
	local nd = M.need
	nd.pb, nd.pd, nd.tb, nd.td, nd.book, nd.items, nd.names, nd.banner, nd.spec = false, false, false, false, false, false, false, false, false
	M.nact = 0
	for i = 1, M.nal do
		local a = M.alerts[i]
		a.clsok = (a.cls == "ANY" or a.cls == M.class)
		a.specok = (a.spec == 0 or M.spec < 0 or M.spec == a.spec)
		if a.spec ~= 0 then nd.spec = true end
		if a.on then
			M.nact = M.nact + 1
			if a.kind == "aura" and not a.incomplete then
				nd[a.lk] = true
				if a.namel ~= EMPTY then nd.names = true end
				if a.tex == EMPTY then nd.book = true end
			elseif a.kind == "cd" and not a.incomplete then
				if a.item then nd.items = true else nd.book = true end
			end
			if a.proc then nd.banner = true end
		end
		M.ResetRuntime2(a)
	end
	M.dBook, M.dItems = nd.book, nd.items
	M.dSpec = nd.spec
	M.dA.pb, M.dA.pd, M.dA.tb, M.dA.td = nd.pb, nd.pd, nd.tb, nd.td
end

-- Remise a zero de l'etat d'execution d'une fiche rechargee (les champs derives ont ete recalcules par Normalize).
function M.ResetRuntime2(a)
	a.act, a.was, a.shown, a.tile = false, false, false, false
	a.left, a.hasleft, a.cnt, a.frac, a.tot, a.mx = 0, false, 0, 1, 0, 0
	a.idx, a.bag, a.slot, a.inv, a.icount, a.known = 0, -1, 0, 0, 0, false
	a.wp, a.sw, a.ts = false, false, 0
	a.dtex, a.tsig, a.tkey = EMPTY, -1, -1
end

-- ---------------------------------------------------------------- lecture des auras
function M.BT()
	return getglobal("BOOKTYPE_SPELL") or "spell"
end

function M.ScanAuras(key)
	M.dA[key] = false
	local l = M.A[key]
	local n = 0
	if key == "pb" or key == "pd" then
		local filter = (key == "pb") and "HELPFUL" or "HARMFUL"
		for i = 0, l.max - 1 do
			local idx = GetPlayerBuff(i, filter)
			if not idx or idx < 0 then break end
			n = n + 1
			l.tex[n] = strlower(GetPlayerBuffTexture(idx) or EMPTY)
			l.cnt[n] = mmax(1, GetPlayerBuffApplications(idx) or 0)
			l.idx[n] = idx
			l.ng[n] = 0
		end
	elseif UnitExists("target") then
		local fn = (key == "tb") and UnitBuff or UnitDebuff
		for i = 1, l.max do
			local tex, cnt = fn("target", i)
			if not tex then break end
			n = n + 1
			l.tex[n] = strlower(tex)
			l.cnt[n] = mmax(1, cnt or 0)
			l.idx[n] = i
			l.ng[n] = 0
		end
	end
	l.n = n
	M.gen = M.gen + 1
end

-- Nom (en minuscules) de l'aura numero i de la liste : SuperWoW sans infobulle pour le joueur, sinon infobulle cachee. Memorise par relecture.
function M.AuraName(key, i)
	local l = M.A[key]
	if l.ng[i] == M.gen then return l.nml[i] end
	l.ng[i] = M.gen
	local nm = nil
	if (key == "pb" or key == "pd") and SUI.Api.superwow then
		local gid, si = getglobal("GetPlayerBuffID"), getglobal("SpellInfo")
		if gid and si then
			local ok, id = pcall(gid, l.idx[i])
			if ok and id then
				local ok2, name = pcall(si, id)
				if ok2 and type(name) == "string" then nm = name end
			end
		end
	end
	if not nm and M.tip then
		M.tip:SetOwner(UIParent, "ANCHOR_NONE")
		if key == "pb" or key == "pd" then M.tip:SetPlayerBuff(l.idx[i])
		elseif key == "tb" then M.tip:SetUnitBuff("target", l.idx[i])
		else M.tip:SetUnitDebuff("target", l.idx[i]) end
		local fs = getglobal("ShikiUI_PATipTextLeft1")
		nm = fs and fs:GetText() or nil
	end
	l.nm[i] = nm or EMPTY
	l.nml[i] = nm and strlower(nm) or EMPTY
	return l.nml[i]
end

-- Rang (dans la liste) de l'aura qui correspond a l'alerte, ou 0. Icone connue : on ne lit le nom que des auras de cette icone.
function M.FindAura(a)
	local l = M.A[a.lk]
	local hasT, hasN = a.texr ~= EMPTY, a.namel ~= EMPTY
	local namesOk = (M.tip ~= nil) or SUI.Api.superwow
	for i = 1, l.n do
		local ok = false
		if hasT then
			if l.tex[i] == a.texr then
				if hasN and namesOk then ok = (M.AuraName(a.lk, i) == a.namel) else ok = true end
			end
		elseif hasN and namesOk then
			ok = (M.AuraName(a.lk, i) == a.namel)
		end
		if ok then return i end
	end
	return 0
end

-- ---------------------------------------------------------------- grimoire, objets, specialisation
function M.ScanBook()
	M.dBook = false
	if SUI.InCombat() then
		M.dBook = true
		return
	end
	local bk = M.book
	for k in pairs(bk) do bk[k] = nil end
	local bt = M.BT()
	local i = 1
	while i <= 400 do
		local name = GetSpellName(i, bt)
		if not name then break end
		bk[strlower(name)] = i
		i = i + 1
	end
	for j = 1, M.nal do
		local a = M.alerts[j]
		if (a.kind == "cd" and not a.item) or (a.kind == "aura" and a.namel ~= EMPTY) then
			local idx = bk[a.namel]
			if a.kind == "cd" then
				a.idx = idx or 0
				a.known = (idx ~= nil)
			end
			if idx and a.texd == EMPTY then a.dtex = GetSpellTexture(idx, bt) or a.dtex end
		end
	end
end

function M.LinkName(link)
	local _, _, nm = strfind(link, "%[(.-)%]")
	if nm then return strlower(nm) end
	return nil
end

function M.FoundItem(nm, bag, slot, inv, tex)
	for j = 1, M.nal do
		local a = M.alerts[j]
		if a.kind == "cd" and a.item and not a.known and a.namel == nm then
			a.known = true
			a.bag, a.slot, a.inv = bag, slot, inv
			if tex then a.dtex = tex end
		end
	end
end

function M.ScanItems()
	M.dItems = false
	local n = 0
	for j = 1, M.nal do
		local a = M.alerts[j]
		if a.kind == "cd" and a.item then
			a.bag, a.slot, a.inv, a.known = -1, 0, 0, false
			n = n + 1
		end
	end
	if n == 0 then return end
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local nm = M.LinkName(link)
			if nm then M.FoundItem(nm, -1, 0, slot, GetInventoryItemTexture("player", slot)) end
		end
	end
	for bag = 0, 4 do
		local ns = GetContainerNumSlots(bag) or 0
		for slot = 1, ns do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local nm = M.LinkName(link)
				if nm then
					local tex = GetContainerItemInfo(bag, slot)
					M.FoundItem(nm, bag, slot, 0, tex)
				end
			end
		end
	end
	local gic = getglobal("GetItemCount")
	for j = 1, M.nal do
		local a = M.alerts[j]
		if a.kind == "cd" and a.item then
			a.icount = (gic and a.name ~= EMPTY) and (gic(a.name) or 0) or 0
		end
	end
end

function M.ScanSpec()
	M.dSpec = false
	local sp = SUI.Specs
	if sp and sp.Scan then
		local s = sp.Scan()
		M.spec = (s and s.id) or -1
	else
		M.spec = -1
	end
	for i = 1, M.nal do
		local a = M.alerts[i]
		a.specok = (a.spec == 0 or M.spec < 0 or M.spec == a.spec)
	end
end

-- ---------------------------------------------------------------- evaluation des declencheurs
-- Les fonctions renvoient "l'alerte est allumee ?" et renseignent a.left / a.hasleft / a.cnt / a.frac.
function M.EvalAura(a, now)
	local unitOk
	if a.unit == "target" then
		unitOk = UnitExists("target") and not UnitIsDeadOrGhost("target")
		if unitOk and a.when == "missing" and a.filt == "debuff" and not UnitCanAttack("player", "target") then unitOk = false end
	else
		unitOk = not UnitIsDeadOrGhost("player")
	end
	if not unitOk then
		a.wp, a.hasleft = false, false
		return false
	end
	local i = M.FindAura(a)
	if i > 0 then
		local l = M.A[a.lk]
		a.cnt = l.cnt[i]
		if a.texd == EMPTY then a.dtex = l.tex[i] end
		if a.unit == "player" then
			local lt = GetPlayerBuffTimeLeft(l.idx[i])
			if lt and lt > 0 then
				a.left, a.hasleft = lt, true
				if lt > a.tot then a.tot = lt end
			else
				a.hasleft = false
			end
			a.wp = true
		else
			if not a.wp then
				a.wp = true
				if a.sw then a.ts = 0 else a.ts = now end
				a.sw = false
			end
			if a.dur > 0 and a.ts > 0 then
				local lt = a.dur - (now - a.ts)
				if lt > 0 then
					a.left, a.hasleft, a.tot = lt, true, a.dur
				else
					a.hasleft = false
				end
			else
				a.hasleft = false
			end
		end
		if a.hasleft and a.tot > 0 then a.frac = mmin(1, a.left / a.tot) else a.frac = 1 end
		return a.when == "has" and a.cnt >= a.minst
	end
	a.wp, a.sw, a.hasleft, a.tot, a.cnt, a.frac = false, false, false, 0, 0, 1
	return a.when == "missing"
end

function M.EvalCd(a, now)
	local start, dur
	if a.item then
		if a.bag >= 0 then
			start, dur = GetContainerItemCooldown(a.bag, a.slot)
		elseif a.inv > 0 then
			start, dur = GetInventoryItemCooldown("player", a.inv)
		else
			return false
		end
		a.cnt = a.icount
	else
		if a.idx <= 0 then return false end
		start, dur = GetSpellCooldown(a.idx, M.BT())
	end
	local left = 0
	if start and start > 0 and dur and dur > M.GCD then left = start + dur - now end
	if left > 0 then
		a.hasleft, a.left, a.start, a.dur0 = true, left, start, dur
		a.frac = mmin(1, left / dur)
	else
		a.hasleft, a.left, a.frac = false, 0, 1
	end
	if a.when == "ready" then return not a.hasleft end
	if a.when == "cool" then return a.hasleft end
	return true
end

function M.EvalPower(a)
	local cur, mx
	if a.res == "combo" then
		cur, mx = GetComboPoints() or 0, 5
	else
		local u = a.unit
		if not UnitExists(u) or UnitIsDeadOrGhost(u) then return false end
		if a.res == "health" then
			cur, mx = UnitHealth(u), UnitHealthMax(u)
		else
			cur, mx = UnitMana(u), UnitManaMax(u)
		end
	end
	if not mx or mx <= 0 then return false end
	a.cnt, a.mx, a.frac = cur, mx, mmin(1, cur / mx)
	return a.when == "always" or cur > 0
end

function M.EvalCond(a)
	local r = a.res
	local pct
	if r == "combo" then
		a.cnt = GetComboPoints() or 0
		a.frac = a.cnt / 5
		return a.cnt >= a.thr
	elseif r == "hplow" then
		local mx = UnitHealthMax("player")
		if not mx or mx <= 0 or UnitIsDeadOrGhost("player") then return false end
		pct = UnitHealth("player") * 100 / mx
	elseif r == "manalow" then
		local mx = UnitManaMax("player")
		if UnitPowerType("player") ~= 0 or not mx or mx <= 0 then return false end
		pct = UnitMana("player") * 100 / mx
	else
		if not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitCanAttack("player", "target") then return false end
		local mx = UnitHealthMax("target")
		if not mx or mx <= 0 then return false end
		pct = UnitHealth("target") * 100 / mx
	end
	a.cnt, a.frac = floor(pct), mmin(1, pct / 100)
	return pct < a.thr
end

function M.Eval(a, now)
	local k = a.kind
	if k == "aura" then return M.EvalAura(a, now) end
	if k == "cd" then return M.EvalCd(a, now) end
	if k == "power" then return M.EvalPower(a) end
	return M.EvalCond(a)
end

function M.Allowed(a, combat)
	if a.incomplete or not a.clsok or not a.specok then return false end
	local v = a.vc
	if v == "combat" and not combat then return false end
	if v == "nocombat" and combat then return false end
	local g = a.grp
	if g == "solo" and (M.raidN > 0 or M.partyN > 0) then return false end
	if g == "grouped" and M.raidN == 0 and M.partyN == 0 then return false end
	if g == "raid" and M.raidN == 0 then return false end
	return true
end

-- Valeurs d'exemple pour l'apercu (zones en cours de deplacement, bouton "Apercu").
function M.FakeValues(a)
	a.cnt, a.frac, a.mx = 3, 0.6, 100
	a.left, a.hasleft, a.tot = 8.3, true, 14
	if a.kind == "power" or a.kind == "cond" then a.hasleft = false end
end

-- ---------------------------------------------------------------- libelles et icones
function M.LabelOf(a)
	if a.name ~= EMPTY then return a.name end
	if a.kind == "power" then return L("mod.powerauras.res." .. a.res) end
	if a.kind == "cond" then return L("mod.powerauras.cond." .. a.res) end
	return L("mod.powerauras.k." .. a.kind)
end

function M.TexOf(a)
	if a.texd ~= EMPTY then return a.texd end
	if a.dtex ~= EMPTY then return a.dtex end
	return M.UNKNOWN
end

function M.TKey(left)
	if left >= 3600 then return 3000000 + floor(left / 3600 + 0.5) end
	if left >= 60 then return 2000000 + floor(left / 60) end
	if M.cfg.tenths and left < 5 then return floor(left * 10) end
	return 1000000 + ceil(left)
end

function M.TText(key)
	if key >= 3000000 then return strformat("%dh", key - 3000000) end
	if key >= 2000000 then return strformat("%dm", key - 2000000) end
	if key >= 1000000 then return strformat("%d", key - 1000000) end
	return strformat("%.1f", key / 10)
end

function M.Col(name)
	if name == "accent" then return T.Accent() end
	local c = T.c[name] or T.c.text
	return c[1], c[2], c[3]
end

-- ---------------------------------------------------------------- tuiles (une par alerte affichee)
function M.NewTile()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetWidth(40)
	f:SetHeight(40)
	f:EnableMouse(false)
	T.Backdrop(f, T.c.bg, T.c.border)
	local t = { f = f, owner = false, ver = 0, bkey = EMPTY, sig = -1, al = -1, sw = false, sws = 0, swd = 0, vh = -1, tex = EMPTY, glowOn = false, glowA = -1 }
	t.glow = f:CreateTexture(nil, "BACKGROUND")
	t.glow:SetTexture(T.tex.white)
	t.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
	t.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
	t.glow:Hide()
	t.icon = f:CreateTexture(nil, "ARTWORK")
	t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	t.shade = f:CreateTexture(nil, "ARTWORK")
	t.shade:SetTexture(T.tex.white)
	t.shade:SetVertexColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 0.7)
	t.shade:Hide()
	local okM, m = pcall(CreateFrame, "Model", nil, f, "CooldownFrameTemplate")
	if okM and m then
		m:SetAllPoints(f)
		m:SetFrameLevel(f:GetFrameLevel() + 1)
		m:EnableMouse(false)
		m:Hide()
		t.model = m
	end
	t.bar = T.Bar(f)
	t.bar:Hide()
	local tf = CreateFrame("Frame", nil, f)
	tf:SetAllPoints(f)
	tf:SetFrameLevel(f:GetFrameLevel() + 3)
	tf:EnableMouse(false)
	t.tf = tf
	t.time = T.Text(tf, 13, T.c.text, "CENTER", true)
	t.time:SetPoint("CENTER", f, "CENTER", 0, 0)
	t.cnt = T.Text(tf, 11, T.c.text, "RIGHT", true)
	t.cnt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	t.name = T.Text(tf, 10, T.c.text, "CENTER", true)
	t.big = T.Text(tf, 12, T.c.text, "CENTER", true)
	f:Hide()
	return t
end

function M.EnsureTiles()
	if not M.on then return end
	local need, nd = M.nact, M.need
	if SUI.InCombat() then
		local missing = getn(M.tiles) < need or (nd.names and not M.tip) or (nd.banner and not M.banner)
		if missing and not M.poolWait then
			M.poolWait = true
			SUI.WhenSafe(M.EnsureTiles)
		end
		return
	end
	M.poolWait = false
	while getn(M.tiles) < need do tinsert(M.tiles, M.NewTile()) end
	if nd.names and not M.tip then M.EnsureTip() end
	if nd.banner and not M.banner then M.EnsureBanner() end
	for i = 1, M.nal do
		local a = M.alerts[i]
		if a.on then M.EnsureZone(a.zone) end
	end
end

function M.EnsureTip()
	local ok, tip = pcall(CreateFrame, "GameTooltip", "ShikiUI_PATip", UIParent, "GameTooltipTemplate")
	if ok and tip then
		tip:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip = tip
	end
end

function M.TakeTile(a)
	for i = 1, getn(M.tiles) do
		local t = M.tiles[i]
		if not t.owner then
			t.owner = a
			a.tile = t
			return t
		end
	end
	return nil
end

function M.ReleaseTile(a)
	local t = a.tile
	if t then
		t.owner = false
		t.f:Hide()
		t.sig, t.al, t.bkey = -1, -1, EMPTY
		M.StopSweep(t)
	end
	a.tile, a.shown = false, false
end

function M.ReleaseAll()
	for i = 1, getn(M.tiles) do
		local t = M.tiles[i]
		if t.owner then
			t.owner.tile, t.owner.shown = false, false
			t.owner = false
		end
		t.f:Hide()
		t.sig, t.al, t.bkey = -1, -1, EMPTY
		M.StopSweep(t)
	end
	M.relayout = true
end

function M.TileDims(a)
	local s = a.size
	if a.disp == "icon" then return s, s end
	local w = mmin(s * 4, 320)
	if a.disp == "bar" then return w, mmax(14, floor(s * 0.45)) end
	return w, mmax(18, floor(s * 0.5))
end

-- Dessine la forme de la tuile selon l'alerte (icone / barre / texte), ses couleurs et sa bordure. Appelee a l'attribution, puis
-- seulement quand les reglages changent (version de configuration).
function M.ApplyTile(a, t)
	local f = t.f
	local w, h = M.TileDims(a)
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetAlpha(M.cfg.alpha)
	t.ver = M.cfgver
	local d = a.disp
	t.icon:ClearAllPoints()
	t.bar:ClearAllPoints()
	t.name:ClearAllPoints()
	local hasIcon = (d == "icon") or (d == "bar" and (a.kind == "aura" or a.kind == "cd"))
	if hasIcon then
		t.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		if d == "icon" then
			t.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		else
			t.icon:SetWidth(h - 2)
			t.icon:SetHeight(h - 2)
		end
		t.icon:Show()
	else
		t.icon:Hide()
	end
	if d == "bar" then
		t.bar:SetPoint("TOPLEFT", f, "TOPLEFT", hasIcon and (h + 1) or 1, -1)
		t.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		t.bar:SetMinMaxValues(0, 1)
		t.bar:Show()
		t.big:ClearAllPoints()
		t.big:SetPoint("CENTER", t.bar, "CENTER", 0, 0)
		t.big:Show()
	else
		t.bar:Hide()
		if d == "text" then
			t.big:ClearAllPoints()
			t.big:SetPoint("CENTER", f, "CENTER", 0, 0)
			t.big:Show()
		else
			t.big:Hide()
		end
	end
	if d == "icon" then
		t.time:Show()
		t.cnt:Show()
		if a.lb then
			t.name:SetPoint("BOTTOM", f, "TOP", 0, 2)
			t.name:SetText(M.LabelOf(a))
			t.name:Show()
		else
			t.name:Hide()
		end
	else
		t.time:Hide()
		t.cnt:Hide()
		t.name:Hide()
	end
	t.sig, t.al, t.bkey, t.vh = -1, -1, EMPTY, -1
	M.PaintColors(a, t)
end

function M.PaintColors(a, t)
	local r, g, b = M.Col(a.col)
	t.glow:SetVertexColor(r, g, b, 1)
	t.bar:SetStatusBarColor(r, g, b, 1)
	local mode = M.cfg.border
	if mode == "color" then
		t.f:SetBackdropBorderColor(r, g, b, 1)
	elseif mode == "none" then
		t.f:SetBackdropBorderColor(T.c.border[1], T.c.border[2], T.c.border[3], 0)
	else
		t.f:SetBackdropBorderColor(T.c.border[1], T.c.border[2], T.c.border[3], T.c.border[4])
	end
end

function M.OnAccent()
	for i = 1, getn(M.tiles) do
		local t = M.tiles[i]
		if t.owner then M.PaintColors(t.owner, t) end
	end
end

-- Balayage circulaire du jeu (facultatif) ; repli : voile qui se vide.
function M.StopSweep(t)
	if t.sw and t.model then
		t.sw = false
		local fn = getglobal("CooldownFrame_SetTimer")
		if fn then pcall(fn, t.model, 0, 0, 0) end
		t.model:Hide()
	end
end

function M.StartSweep(t, s, d)
	local fn = getglobal("CooldownFrame_SetTimer")
	if not t.model or not fn or not M.cfg.sweep then return false end
	if not t.sw or t.sws ~= s or t.swd ~= d then
		t.sw, t.sws, t.swd = true, s, d
		pcall(fn, t.model, s, d, 1)
		t.model:Show()
	end
	return true
end

-- Texte d'une barre ou d'une ligne de texte.
function M.BigText(a, key)
	local s = M.LabelOf(a)
	if a.kind == "power" then
		if a.res == "combo" then return strformat("%s %d", s, a.cnt) end
		return strformat("%s %d%%", s, floor(a.frac * 100 + 0.5))
	end
	if a.kind == "cond" then
		if a.res == "combo" then return strformat("%s %d", s, a.cnt) end
		return strformat("%s %d%%", s, a.cnt)
	end
	if a.cnt > 1 and a.sk then s = strformat("%s x%d", s, a.cnt) end
	if a.hasleft and a.tm then s = s .. " " .. M.TText(key) end
	return s
end

-- Met la tuile a jour. Chaque texte / texture n'est reecrit que s'il change.
function M.Paint(a, t, now)
	if t.ver ~= M.cfgver then M.ApplyTile(a, t) end
	local tex = M.TexOf(a)
	if t.tex ~= tex then
		t.tex = tex
		t.icon:SetTexture(tex)
	end
	local key = 0
	if a.hasleft then key = M.TKey(a.left) end
	local d = a.disp
	if d == "icon" then
		local sig = key * 1000 + mmin(a.cnt, 999)
		if t.sig ~= sig then
			t.sig = sig
			if a.hasleft and a.tm then t.time:SetText(M.TText(key)) else t.time:SetText(EMPTY) end
			if a.cnt > 1 and a.sk then t.cnt:SetText(strformat("%d", a.cnt)) else t.cnt:SetText(EMPTY) end
		end
		local sweeping = false
		if a.kind == "cd" and a.hasleft and not M.demo then sweeping = M.StartSweep(t, a.start, a.dur0) end
		if not sweeping then M.StopSweep(t) end
		local vh = 0
		if a.hasleft and not sweeping and (a.kind == "cd" or a.tot > 0) then vh = floor((a.size - 2) * a.frac + 0.5) end
		if vh ~= t.vh then
			t.vh = vh
			if vh > 0 then
				t.shade:ClearAllPoints()
				t.shade:SetPoint("BOTTOMLEFT", t.f, "BOTTOMLEFT", 1, 1)
				t.shade:SetPoint("BOTTOMRIGHT", t.f, "BOTTOMRIGHT", -1, 1)
				t.shade:SetHeight(vh)
				t.shade:Show()
			else
				t.shade:Hide()
			end
		end
	else
		local sig = key * 1000 + mmin(a.cnt, 999) + floor(a.frac * 100) * 100000000
		if t.sig ~= sig then
			t.sig = sig
			t.big:SetText(M.BigText(a, key))
			if d == "bar" then t.bar:SetValue(a.frac) end
		end
	end
	local alpha = 1
	if a.kind == "cd" and a.when == "always" and a.hasleft then alpha = 0.45 end
	if t.al ~= alpha then
		t.al = alpha
		t.icon:SetAlpha(alpha)
	end
	-- glow : fixe ou pulsant
	local g = a.glow
	if g == "none" then
		if t.glowOn then
			t.glowOn = false
			t.glow:Hide()
		end
	else
		if not t.glowOn then
			t.glowOn = true
			t.glow:Show()
		end
		if g == "pulse" then
			t.glowA = -1
			t.glow:SetAlpha(0.45 + 0.4 * math.sin(now * 5))
		elseif t.glowA ~= 0.6 then
			t.glowA = 0.6
			t.glow:SetAlpha(0.6)
		end
	end
end

-- ---------------------------------------------------------------- zones et mise en page
function M.ZoneDir(n)
	return M.zd[n] or "r"
end

function M.ZonePos(n)
	local p = M.ZPOS[n]
	return p[1], p[2], p[3]
end
M.ZPOS = { { "CENTER", -120, -120 }, { "CENTER", 120, -120 }, { "CENTER", -120, -190 }, { "CENTER", -120, -240 },
	{ "CENTER", 0, 120 }, { "CENTER", -100, 200 }, { "TOPLEFT", 40, -200 }, { "TOPRIGHT", -200, -200 } }

function M.EnsureZone(n)
	local z = M.zf[n]
	if z then return z end
	if SUI.InCombat() then return nil end
	z = CreateFrame("Frame", nil, UIParent)
	z:SetWidth(M.ZW)
	z:SetHeight(M.ZH)
	z:EnableMouse(false)
	local pt, x, y = M.ZonePos(n)
	z:Hide()
	M.zf[n] = z
	local label = L("msg.powerauras.zone", n)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("powerauras.z" .. n, z, { label = label, point = pt, x = x, y = y, preview = M.Preview })
	else
		SUI.Layout.Register(z, "powerauras.z" .. n, pt, x, y)
	end
	return z
end

-- Range les tuiles affichees de chaque zone, dans l'ordre des alertes, vers la direction de la zone.
function M.Reflow()
	M.relayout = false
	local sp = M.cfg.spacing
	for n = 1, M.NZONE do
		local off, used = 0, 0
		local dir = M.ZoneDir(n)
		local z = M.zf[n]
		for i = 1, M.nal do
			local a = M.alerts[i]
			if a.shown and a.zone == n and a.tile then
				z = z or M.EnsureZone(n)
				if z then
					local f = a.tile.f
					local w, h = f:GetWidth(), f:GetHeight()
					if f:GetParent() ~= z then f:SetParent(z) end
					f:ClearAllPoints()
					if dir == "r" then
						f:SetPoint("TOPLEFT", z, "TOPLEFT", off, 0)
						off = off + w + sp
					elseif dir == "l" then
						f:SetPoint("TOPRIGHT", z, "TOPRIGHT", -off, 0)
						off = off + w + sp
					elseif dir == "d" then
						f:SetPoint("TOPLEFT", z, "TOPLEFT", 0, -off)
						off = off + h + sp
					else
						f:SetPoint("BOTTOMLEFT", z, "BOTTOMLEFT", 0, off)
						off = off + h + sp
					end
					f:Show()
					used = used + 1
				end
			end
		end
		if z then
			if used > 0 then
				if not z:IsShown() then z:Show() end
			elseif z:IsShown() then
				z:Hide()
			end
		end
	end
end

function M.SetDemo(on)
	on = on and true or false
	if on == M.demo then return end
	M.demo = on
	if M.on and M.nact > 0 then M.Tick() end
end
M.Preview = M.SetDemo

-- ---------------------------------------------------------------- banniere (proc) et eclair d'ecran
function M.EnsureBanner()
	if M.banner or SUI.InCombat() then return end
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetWidth(280)
	f:SetHeight(76)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetWidth(60)
	f.icon:SetHeight(60)
	f.icon:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.text = T.Text(f, 20, T.c.text, "LEFT", true)
	f.text:SetPoint("LEFT", f, "LEFT", 76, 0)
	f.text:SetWidth(196)
	f.text:SetHeight(48)
	f:Hide()
	M.banner = f
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("powerauras.banner", f, { label = L("msg.powerauras.banner"), point = "CENTER", x = 0, y = 180 })
	else
		SUI.Layout.Register(f, "powerauras.banner", "CENTER", 0, 180)
	end
	local g = CreateFrame("Frame", nil, UIParent)
	g:SetAllPoints(UIParent)
	g:SetFrameStrata("BACKGROUND")
	g:EnableMouse(false)
	g.tex = g:CreateTexture(nil, "BACKGROUND")
	g.tex:SetAllPoints(g)
	g.tex:SetTexture(T.tex.white)
	g:Hide()
	M.flash = g
end

function M.Sound(name, now)
	if name == "none" or not M.cfg.sound then return end
	if now - M.lastSound < M.SOUND_GAP then return end
	M.lastSound = now
	local file = M.SOUNDFILE[name]
	if file then
		local pf = getglobal("PlaySoundFile")
		if pf then pf(file) end
	elseif M.SOUNDNAME[name] then
		local p = getglobal("PlaySound")
		if p then p(M.SOUNDNAME[name]) end
	end
end

function M.ShowBanner(a, now)
	local b = M.banner
	if not b then
		if not SUI.InCombat() then M.EnsureBanner() end
		b = M.banner
		if not b then return end
	end
	local r, g, bl = M.Col(a.col)
	b.icon:SetTexture(M.TexOf(a))
	b.text:SetText(M.LabelOf(a))
	b.text:SetTextColor(r, g, bl, 1)
	b:SetBackdropBorderColor(r, g, bl, 1)
	b:Show()
	M.bannerUntil = now + a.hold
	local fl = M.cfg.flash
	if fl ~= "off" and M.flash then
		M.flash.tex:SetVertexColor(r, g, bl, (fl == "strong") and 0.35 or 0.18)
		M.flash:Show()
		M.flashUntil = now + M.FLASHT
	end
end

-- Declenchement d'une alerte (son, banniere, eclair). test = vrai : depuis l'editeur.
function M.Fire(a, now)
	M.nfired = M.nfired + 1
	M.lastFired = a.id
	M.Sound(a.snd, now)
	if a.proc then M.ShowBanner(a, now) end
end

function M.Test(a)
	local now = GetTime()
	M.lastSound = 0
	M.Fire(a, now)
	if not a.proc then M.ShowBanner(a, now) end
end

-- ---------------------------------------------------------------- minuterie
function M.Tick()
	if not M.on or M.nact == 0 then return end
	local now = GetTime()
	local combat = UnitAffectingCombat("player") and true or false
	M.combat = combat
	M.raidN, M.partyN = GetNumRaidMembers(), GetNumPartyMembers()
	if M.dBook then M.ScanBook() end
	if M.dItems then M.ScanItems() end
	if M.dSpec and not combat then M.ScanSpec() end
	if M.dA.pb then M.ScanAuras("pb") end
	if M.dA.pd then M.ScanAuras("pd") end
	if M.dA.tb then M.ScanAuras("tb") end
	if M.dA.td then M.ScanAuras("td") end
	local show = M.cfg.show
	local quiet = now < M.quietUntil
	for i = 1, M.nal do
		local a = M.alerts[i]
		local act = false
		if a.on then
			if M.demo then
				act = true
				M.FakeValues(a)
			elseif M.Allowed(a, combat) then
				act = M.Eval(a, now)
			else
				a.wp, a.hasleft = false, false
			end
		end
		if act and not a.was and not quiet and not M.demo then M.Fire(a, now) end
		a.act, a.was = act, act
		local want = act and show
		if want and not a.tile then
			local t = M.TakeTile(a)
			if t then
				M.ApplyTile(a, t)
				a.shown = true
				M.relayout = true
			end
		elseif not want and a.tile then
			M.ReleaseTile(a)
			M.relayout = true
		end
		if a.shown and a.tile then M.Paint(a, a.tile, now) end
	end
	if M.relayout then M.Reflow() end
	if M.bannerUntil > 0 and now >= M.bannerUntil then
		M.bannerUntil = 0
		if M.banner then M.banner:Hide() end
	end
	if M.flashUntil > 0 and now >= M.flashUntil then
		M.flashUntil = 0
		if M.flash then M.flash:Hide() end
	end
end

-- ---------------------------------------------------------------- evenements
M.EVENTS = { "PLAYER_AURAS_CHANGED", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "SPELLS_CHANGED", "CHARACTER_POINTS_CHANGED", "BAG_UPDATE",
	"UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD" }

function M.OnEvent(ev, a1)
	local nd = M.need
	if ev == "UNIT_AURA" then
		if a1 == "player" then
			if nd.pb then M.dA.pb = true end
			if nd.pd then M.dA.pd = true end
		elseif a1 == "target" then
			if nd.tb then M.dA.tb = true end
			if nd.td then M.dA.td = true end
		end
	elseif ev == "PLAYER_AURAS_CHANGED" then
		if nd.pb then M.dA.pb = true end
		if nd.pd then M.dA.pd = true end
	elseif ev == "PLAYER_TARGET_CHANGED" then
		if nd.tb then M.dA.tb = true end
		if nd.td then M.dA.td = true end
		for i = 1, M.nal do
			local a = M.alerts[i]
			if a.kind == "aura" and a.unit == "target" then a.wp, a.sw = false, true end
		end
	elseif ev == "SPELLS_CHANGED" then
		if nd.book then M.dBook = true end
		if nd.spec then M.dSpec = true end
	elseif ev == "CHARACTER_POINTS_CHANGED" then
		if nd.spec then M.dSpec = true end
	elseif ev == "BAG_UPDATE" then
		if nd.items then M.dItems = true end
	elseif ev == "UNIT_INVENTORY_CHANGED" then
		if nd.items and a1 == "player" then M.dItems = true end
	elseif ev == "PLAYER_ENTERING_WORLD" then
		M.quietUntil = GetTime() + M.QUIET_WORLD
		if nd.pb then M.dA.pb = true end
		if nd.pd then M.dA.pd = true end
		if nd.tb then M.dA.tb = true end
		if nd.td then M.dA.td = true end
		if nd.book then M.dBook = true end
		if nd.items then M.dItems = true end
		if nd.spec then M.dSpec = true end
	end
end

function M.Hook(on)
	if on == M.hooked then return end
	M.hooked = on
	for i = 1, getn(M.EVENTS) do
		if on then SUI.On(M.EVENTS[i], M.OnEvent) else SUI.Off(M.EVENTS[i], M.OnEvent) end
	end
end

function M.HideAll()
	M.ReleaseAll()
	for n = 1, M.NZONE do
		if M.zf[n] then M.zf[n]:Hide() end
	end
	if M.banner then M.banner:Hide() end
	if M.flash then M.flash:Hide() end
	M.bannerUntil, M.flashUntil = 0, 0
end

-- Met la minuterie et les evenements en accord avec les alertes : rien tant qu'aucune alerte n'est active.
function M.Sync()
	local want = M.on and M.nact > 0
	if want then
		M.Hook(true)
		if not M.task then M.task = SUI.Every(M.cfg.tick, M.Tick, "powerauras.tick", true) end
		M.EnsureTiles()
		M.Tick()
	else
		M.Hook(false)
		if M.task then
			SUI.Cancel(M.task)
			M.task = nil
		end
		M.HideAll()
	end
end

-- ---------------------------------------------------------------- reglages
function M.ReadConfig()
	local c = M.cfg
	c.show = C.Get("powerauras.show")
	c.sound = C.Get("powerauras.sound")
	c.flash = C.Get("powerauras.flash")
	c.border = C.Get("powerauras.border")
	c.sweep = C.Get("powerauras.sweep")
	c.tenths = C.Get("powerauras.tenths")
	c.alpha = C.Get("powerauras.alpha")
	c.spacing = C.Get("powerauras.spacing")
	c.tick = C.Get("powerauras.tick")
	local zs = C.Get("powerauras.zones") or EMPTY
	for n = 1, M.NZONE do
		local ch = strsub(zs, n, n)
		M.zd[n] = M.InList(M.DIRS, ch) and ch or "r"
	end
end

function M.OnKey(key, value)
	M.ReadConfig()
	if key == nil or key == "powerauras.data" then
		M.Load()
		return
	end
	if not M.on then return end
	M.cfgver = M.cfgver + 1
	M.relayout = true
	if M.task and (key == "powerauras.tick") then
		SUI.Cancel(M.task)
		M.task = SUI.Every(M.cfg.tick, M.Tick, "powerauras.tick", true)
	end
	if M.nact > 0 then M.Tick() end
	M.Refresh()
end

-- Redessine la page du menu si elle est ouverte.
function M.Refresh()
	local Mn = SUI.Menu
	if Mn and Mn.frame and Mn.frame:IsShown() and Mn.page == "cat" and Mn.cat == "powerauras" and Mn.Render then Mn.Render() end
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	if not M.accentHooked then
		M.accentHooked = true
		T.OnAccent(M.OnAccent)
	end
	M.spec = -1
	M.Load()
	if M.nal == 0 and not M.hinted then
		M.hinted = true
		SUI.Print(L("msg.powerauras.hint"))
	end
end

function M.Disable()
	M.on = false
	M.Hook(false)
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	M.HideAll()
	M.demo = false
end

-- ---------------------------------------------------------------- edition des alertes (API utilisee par le menu, la commande et les tests)
function M.Find(id)
	for i = 1, M.nal do
		if M.alerts[i].id == id then return M.alerts[i], i end
	end
	return nil, 0
end

-- Les editions passent TOUJOURS par la sauvegarde (texte de profil) : le chargement (M.Load, appele par la surveillance des reglages)
-- reconstruit ensuite les fiches. Aucune fiche n'est deplacee a la main.
M.scratch = {}
M.Fresh(M.scratch)

-- Texte sauvegarde d'une alerte neuve construite a partir d'une table de champs (noms longs).
function M.Build(t, pack)
	local a = M.scratch
	M.Fresh(a)
	for k, v in pairs(t) do
		if M.FL[k] then a[k] = v end
	end
	if pack then a.pack = pack end
	a.id = M.nextId
	M.nextId = M.nextId + 1
	M.Normalize(a)
	return M.EncodeOne(a)
end

-- Textes sauvegardes des alertes actuelles, sans celles que filtre skip(fiche).
function M.Parts(skip)
	local parts = {}
	for i = 1, M.nal do
		local a = M.alerts[i]
		if not (skip and skip(a)) then tinsert(parts, M.EncodeOne(a)) end
	end
	return parts
end

function M.Write(parts)
	C.SetBase("powerauras.data", table.concat(parts, ";"))
end

function M.Add(t, pack)
	if M.nal >= M.MAXA then return nil, "full" end
	local parts = M.Parts()
	local id = M.nextId
	tinsert(parts, M.Build(t, pack))
	M.Write(parts)
	return M.Find(id)
end

function M.Remove(id)
	if not M.Find(id) then return false end
	if M.editId == id then M.editId = 0 end
	M.Write(M.Parts(function(a) return a.id == id end))
	return true
end

function M.RemovePack(pack)
	local n = M.PackCount(pack)
	if n > 0 then M.Write(M.Parts(function(a) return a.pack == pack end)) end
	if M.editId ~= 0 and not M.Find(M.editId) then M.editId = 0 end
	return n
end

function M.Clear()
	M.editId = 0
	M.Write({})
end

function M.Copy(id)
	local a = M.Find(id)
	if not a then return nil, "none" end
	if M.nal >= M.MAXA then return nil, "full" end
	local t = {}
	for i = 1, getn(M.F) do
		local f = M.F[i]
		if f[2] ~= "id" and f[2] ~= "pack" then t[f[2]] = a[f[2]] end
	end
	return M.Add(t)
end

-- Valeur suivante d'un champ (clic gauche : dir = 1, clic droit : -1).
function M.Cycle(a, field, dir)
	local list = M.ENUM[field]
	if field == "when" then list = M.WHEN[a.kind]
	elseif field == "res" then list = M.RES[a.kind]
	elseif field == "thr" then list = (a.res == "combo") and M.THRC or M.THR
	elseif not list then list = M.NUMLIST[field] end
	if not list then return false end
	local v = a[field]
	local pos = 0
	for i = 1, getn(list) do
		if list[i] == v then pos = i end
	end
	if pos == 0 then
		-- valeur hors liste (ancienne sauvegarde) : la plus proche
		pos = 1
		if type(v) == "number" then
			for i = 1, getn(list) do
				if list[i] <= v then pos = i end
			end
		end
	else
		pos = pos + dir
		if pos < 1 then pos = getn(list) end
		if pos > getn(list) then pos = 1 end
	end
	a[field] = list[pos]
	if field == "res" and a.kind == "cond" then
		a.thr = (list[pos] == "combo") and 3 or 30
	end
	M.Normalize(a)
	M.Save()
	return true
end

function M.Toggle(a, field)
	a[field] = not a[field]
	M.Normalize(a)
	M.Save()
end

function M.SetName(a, text, tex)
	a.name = M.Clean(text)
	if tex then a.tex = M.TexNorm(tex) elseif a.name == EMPTY then a.tex = EMPTY end
	M.Normalize(a)
	M.Save()
end

-- Choisit une aura dans la liste des auras actuelles de l'alerte (nom lu et icone).
function M.PickAura(a, rank)
	local l = M.A[a.lk]
	if not l or rank < 1 or rank > l.n then return false end
	M.AuraName(a.lk, rank)
	M.SetName(a, l.nm[rank], l.tex[rank])
	return true
end

function M.ZoneSet(n, dir)
	local s = C.Get("powerauras.zones") or EMPTY
	local out = EMPTY
	for i = 1, M.NZONE do
		local ch = strsub(s, i, i)
		if not M.InList(M.DIRS, ch) then ch = "r" end
		if i == n then ch = dir end
		out = out .. ch
	end
	C.SetBase("powerauras.zones", out)
end

function M.ZoneCycle(n, dir)
	local cur = M.ZoneDir(n)
	local pos = 1
	for i = 1, getn(M.DIRS) do
		if M.DIRS[i] == cur then pos = i end
	end
	pos = pos + dir
	if pos < 1 then pos = getn(M.DIRS) end
	if pos > getn(M.DIRS) then pos = 1 end
	M.ZoneSet(n, M.DIRS[pos])
end

function M.ZoneCount(n)
	local c = 0
	for i = 1, M.nal do
		if M.alerts[i].zone == n then c = c + 1 end
	end
	return c
end

-- Etat d'une alerte pour la liste : "off", "incomplete", "unknown" (sort ou objet introuvable), "ok".
function M.StatusOf(a)
	if not a.on then return "off" end
	if a.incomplete then return "incomplete" end
	if a.kind == "cd" and M.on and not M.dBook and not M.dItems and not a.known then return "unknown" end
	return "ok"
end

-- ---------------------------------------------------------------- modeles et packs
M.TEMPLATES = {
	{ id = "buff", t = { kind = "aura", unit = "player", filt = "buff", when = "has", zone = 1 } },
	{ id = "debuff", t = { kind = "aura", unit = "target", filt = "debuff", when = "has", zone = 2 } },
	{ id = "nobuff", t = { kind = "aura", unit = "player", filt = "buff", when = "missing", zone = 1, vc = "combat", glow = "pulse", col = "warn" } },
	{ id = "proc", t = { kind = "aura", unit = "player", filt = "buff", when = "has", zone = 1, proc = true, snd = "raid", size = 48, glow = "pulse" } },
	{ id = "spell", t = { kind = "cd", when = "always", zone = 3 } },
	{ id = "item", t = { kind = "cd", item = true, when = "always", zone = 3 } },
	{ id = "bar", t = { kind = "power", res = "power", unit = "player", disp = "bar", zone = 4, size = 24, when = "always" } },
	{ id = "combo", t = { kind = "power", res = "combo", unit = "target", disp = "bar", zone = 4, size = 24, when = "nonzero", col = "warn" } },
	{ id = "lowhp", t = { kind = "cond", res = "hplow", thr = 30, disp = "text", zone = 5, glow = "pulse", snd = "raid", col = "bad", vc = "combat" } },
	{ id = "execute", t = { kind = "cond", res = "targetlow", thr = 20, disp = "text", zone = 5, glow = "border", snd = "ping", col = "warn", vc = "combat" } },
}

function M.AddTemplate(id)
	for i = 1, getn(M.TEMPLATES) do
		if M.TEMPLATES[i].id == id then
			local a, why = M.Add(M.TEMPLATES[i].t)
			if a then M.editId, M.pick, M.edit.name = a.id, false, a.name end
			return a, why
		end
	end
	return nil, "none"
end

local function mk(kind, name, zone, ex)
	local t = { kind = kind, name = name, zone = zone }
	if ex then
		for k, v in pairs(ex) do t[k] = v end
	end
	return t
end
local function cdA(name, zone) return mk("cd", name, zone or 3, { when = "always", size = 36 }) end
local function missB(name, ex)
	local t = mk("aura", name, 1, { unit = "player", filt = "buff", when = "missing", vc = "combat", glow = "pulse", col = "warn", size = 36 })
	if ex then for k, v in pairs(ex) do t[k] = v end end
	return t
end
local function missD(name, zone) return mk("aura", name, zone or 2, { unit = "target", filt = "debuff", when = "missing", vc = "combat", glow = "pulse", col = "warn", size = 36 }) end
local function proc(name, ex)
	local t = mk("aura", name, 1, { unit = "player", filt = "buff", when = "has", proc = true, snd = "raid", size = 48, glow = "pulse", col = "good" })
	if ex then for k, v in pairs(ex) do t[k] = v end end
	return t
end
local function buffA(name, zone) return mk("aura", name, zone or 1, { unit = "player", filt = "buff", when = "has", size = 36 }) end
local function debA(name, zone) return mk("aura", name, zone or 2, { unit = "target", filt = "debuff", when = "has", size = 36 }) end
local function lowhp() return mk("cond", EMPTY, 5, { res = "hplow", thr = 30, disp = "text", glow = "pulse", snd = "raid", col = "bad", vc = "combat" }) end
local function lowmana() return mk("cond", EMPTY, 5, { res = "manalow", thr = 20, disp = "text", glow = "border", col = "warn", vc = "combat" }) end
local function execute(thr) return mk("cond", "Execute", 5, { res = "targetlow", thr = thr or 20, disp = "text", glow = "border", snd = "ping", col = "warn", vc = "combat" }) end
local function combo() return mk("power", EMPTY, 4, { res = "combo", unit = "target", disp = "bar", size = 24, when = "nonzero", col = "warn" }) end

-- Packs : { id = "CLASSE.role", class, role (tank | heal | dps | all), alerts = { ... } }. Noms de sorts ANGLAIS (Turtle WoW).
M.PACKS = {
	{ id = "ALL.all", class = "ALL", role = "all", alerts = { lowhp(), lowmana() } },
	{ id = "WARRIOR.tank", class = "WARRIOR", role = "tank", alerts = { cdA("Shield Block"), cdA("Shield Wall"), cdA("Last Stand"), cdA("Taunt"),
		cdA("Challenging Shout"), missD("Sunder Armor"), lowhp() } },
	{ id = "WARRIOR.dps", class = "WARRIOR", role = "dps", alerts = { cdA("Bloodthirst"), cdA("Mortal Strike"), cdA("Whirlwind"), cdA("Death Wish"),
		cdA("Recklessness"), missB("Battle Shout"), buffA("Flurry"), execute(20) } },
	{ id = "PALADIN.tank", class = "PALADIN", role = "tank", alerts = { cdA("Holy Shield"), cdA("Consecration"), cdA("Hand of Reckoning"),
		cdA("Divine Protection"), cdA("Lay on Hands"), missB("Righteous Fury"), lowhp() } },
	{ id = "PALADIN.heal", class = "PALADIN", role = "heal", alerts = { cdA("Divine Favor"), cdA("Holy Shock"), cdA("Lay on Hands"),
		buffA("Light's Grace"), lowmana(), lowhp() } },
	{ id = "PALADIN.dps", class = "PALADIN", role = "dps", alerts = { cdA("Judgement"), cdA("Crusader Strike"), cdA("Repentance"), proc("Vengeance"),
		execute(20) } },
	{ id = "DRUID.tank", class = "DRUID", role = "tank", alerts = { cdA("Growl"), cdA("Frenzied Regeneration"), cdA("Barkskin"), cdA("Bash"),
		cdA("Challenging Roar"), lowhp() } },
	{ id = "DRUID.dps", class = "DRUID", role = "dps", alerts = { combo(), proc("Clearcasting"), cdA("Tiger's Fury"), cdA("Nature's Swiftness"),
		cdA("Barkskin"), missD("Faerie Fire (Feral)") } },
	{ id = "DRUID.heal", class = "DRUID", role = "heal", alerts = { cdA("Innervate"), cdA("Nature's Swiftness"), cdA("Swiftmend"), proc("Clearcasting"),
		lowmana(), lowhp() } },
	{ id = "HUNTER.dps", class = "HUNTER", role = "dps", alerts = { cdA("Rapid Fire"), cdA("Intimidation"), cdA("Feign Death"), cdA("Bestial Wrath"),
		missD("Hunter's Mark"), lowmana() } },
	{ id = "MAGE.dps", class = "MAGE", role = "dps", alerts = { proc("Clearcasting"), cdA("Arcane Power"), cdA("Presence of Mind"), cdA("Evocation"),
		cdA("Combustion"), debA("Fire Vulnerability"), lowmana() } },
	{ id = "PRIEST.heal", class = "PRIEST", role = "heal", alerts = { cdA("Inner Focus"), cdA("Power Infusion"), cdA("Fear Ward"),
		mk("aura", "Weakened Soul", 1, { unit = "player", filt = "debuff", when = "has", size = 36, col = "bad" }), lowmana(), lowhp() } },
	{ id = "PRIEST.dps", class = "PRIEST", role = "dps", alerts = { missB("Shadowform"), cdA("Mind Blast"), cdA("Inner Focus"), debA("Shadow Weaving"),
		missD("Shadow Word: Pain"), lowmana() } },
	{ id = "ROGUE.dps", class = "ROGUE", role = "dps", alerts = { combo(), missB("Slice and Dice"), cdA("Adrenaline Rush"), cdA("Evasion"),
		cdA("Blade Flurry"), cdA("Vanish"), cdA("Kick"), cdA("Cold Blood") } },
	{ id = "SHAMAN.heal", class = "SHAMAN", role = "heal", alerts = { cdA("Nature's Swiftness"), cdA("Mana Tide Totem"), cdA("Reincarnation"),
		lowmana(), lowhp() } },
	{ id = "SHAMAN.dps", class = "SHAMAN", role = "dps", alerts = { cdA("Elemental Mastery"), cdA("Nature's Swiftness"), cdA("Stormstrike"), cdA("Earth Shock"),
		missB("Lightning Shield"), buffA("Flurry") } },
	{ id = "WARLOCK.dps", class = "WARLOCK", role = "dps", alerts = { proc("Shadow Trance"), proc("Backlash"), cdA("Death Coil"), cdA("Amplify Curse"),
		missD("Curse of Agony"), lowmana() } },
}

function M.PackFind(id)
	for i = 1, getn(M.PACKS) do
		if M.PACKS[i].id == id then return M.PACKS[i] end
	end
	return nil
end

function M.PackCount(id)
	local n = 0
	for i = 1, M.nal do
		if M.alerts[i].pack == id then n = n + 1 end
	end
	return n
end

-- Installe un pack (rien si deja installe). Retourne le nombre d'alertes ajoutees, ou nil et la raison.
function M.PackAdd(id)
	local p = M.PackFind(id)
	if not p then return nil, "none" end
	if M.PackCount(id) > 0 then return nil, "have" end
	if M.nal + getn(p.alerts) > M.MAXA then return nil, "full" end
	local parts = M.Parts()
	for i = 1, getn(p.alerts) do tinsert(parts, M.Build(p.alerts[i], id)) end
	M.Write(parts)
	return getn(p.alerts)
end

-- Pack conseille pour le joueur : sa classe et son role (tank / soigneur / degats), sinon le premier de sa classe.
function M.Recommended()
	local role = C.GetRole()
	if role == "pvp" or role == nil then role = "dps" end
	local first = nil
	for i = 1, getn(M.PACKS) do
		local p = M.PACKS[i]
		if p.class == M.class then
			if not first then first = p.id end
			if p.role == role then return p.id end
		end
	end
	return first
end

function M.PackNames(p)
	local out = EMPTY
	for i = 1, getn(p.alerts) do
		local a = p.alerts[i]
		local nm = a.name
		if nm == EMPTY then nm = L("mod.powerauras.cond." .. (a.res or "hplow")) end
		out = out .. (i > 1 and ", " or EMPTY) .. nm
	end
	return out
end

-- ---------------------------------------------------------------- page du menu : liste, editeur, modeles, packs, zones
-- Les sections sont ajoutees a la page de la categorie "powerauras" (Menu_Pages : P.cat enrobee ici, aucun fichier du socle modifie).
local function menuKind(name, factory)
	local Mn = SUI.Menu
	Mn.New[name] = factory
	local have = false
	for i = 1, getn(Mn.KINDS) do
		if Mn.KINDS[i] == name then have = true end
	end
	if not have then tinsert(Mn.KINDS, name) end
	if not Mn.pools[name] then Mn.pools[name] = {} end
	if not Mn.used[name] then Mn.used[name] = 0 end
end

local function newBtn()
	local Mn = SUI.Menu
	local b = T.Button(Mn.child, "", 100, 22, function(btn, mb)
		if btn.fn then btn.fn(btn, mb) end
	end)
	b:SetFrameLevel(Mn.lvl + 2)
	b:EnableMouseWheel(true)
	b:SetScript("OnMouseWheel", Mn.OnWheel)
	local e0, l0 = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if e0 then e0() end
		local x = this
		if x.tipT and x.tipT ~= EMPTY then SUI.Menu.TipShow(x, x.tipT, x.tipA, x.tipB) end
	end)
	b:SetScript("OnLeave", function()
		if l0 then l0() end
		SUI.Menu.TipHide()
	end)
	return b
end

local function newEdit()
	local Mn = SUI.Menu
	local f = CreateFrame("Frame", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 2)
	f.edit = T.Edit(f, 330, 24)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.edit:SetMaxLetters(40)
	f.edit:SetScript("OnTextChanged", function()
		local e = this
		if not e.silent then M.edit.name = e:GetText() or EMPTY end
	end)
	f.edit:SetScript("OnEnterPressed", function()
		this:ClearFocus()
		M.ApplyName()
	end)
	return f
end

local function newLabel()
	local Mn = SUI.Menu
	local f = CreateFrame("Frame", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", Mn.OnWheel)
	f.fs = T.Text(f, 11, T.c.text, "LEFT")
	f.fs:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.fs:SetWidth(200)
	f.fs:SetHeight(14)
	f.st = T.Text(f, 10, T.c.dim, "RIGHT")
	f.st:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	f.st:SetWidth(100)
	f.st:SetHeight(12)
	return f
end

-- Bouton place a la main (x, largeur) sur la ligne courante.
local function rowBtn(x, w, label, fn, tipT, tipA, selected)
	local Mn = SUI.Menu
	local b = Mn.Get("pa_btn")
	if not b then return nil end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", Mn.child, "TOPLEFT", x, -Mn.y)
	b:SetWidth(w)
	b:SetHeight(24)
	b:Show()
	b.y, b.h = Mn.y, 24
	T.SetButtonText(b, label)
	b.fn = fn
	b.tipT, b.tipA, b.tipB = tipT, tipA, nil
	T.SetSelected(b, selected)
	return b
end

-- Bouton dans la grille (cols colonnes).
local function gridBtn(cols, w, label, fn, tipT, tipA, selected)
	local Mn = SUI.Menu
	local b = Mn.Get("pa_btn")
	if not b then return nil end
	Mn.Flow(b, cols, w, 24, 12, 6)
	T.SetButtonText(b, label)
	b.fn = fn
	b.tipT, b.tipA, b.tipB = tipT, tipA, nil
	T.SetSelected(b, selected)
	return b
end

local function rerender()
	local Mn = SUI.Menu
	if Mn.frame and Mn.frame:IsShown() then Mn.Render() end
end

M.Rerender = rerender

local function say(key, a, b)
	SUI.Print(L(key, a, b))
end

function M.ApplyName()
	local a = M.Find(M.editId)
	if not a then return end
	local txt = M.edit.name or EMPTY
	if M.Clean(txt) == a.name then return end
	M.SetName(a, txt, nil)
	rerender()
end

-- Libelle et infobulle d'un champ cycle de l'editeur.
function M.FieldText(a, field)
	local v = a[field]
	local vt
	if type(v) == "boolean" then
		vt = L(v and "mod.powerauras.yes" or "mod.powerauras.no")
	elseif field == "thr" then
		vt = (a.res == "combo") and tostring(v) or (tostring(v) .. "%")
	elseif field == "spec" then
		vt = (v == 0) and L("mod.powerauras.v.spec.0") or L("mod.powerauras.v.spec.n", v)
	elseif field == "dur" then
		vt = (v == 0) and L("mod.powerauras.v.dur.0") or (tostring(v) .. " s")
	elseif field == "hold" then
		vt = tostring(v) .. " s"
	elseif field == "zone" then
		vt = L("mod.powerauras.v.zone", v)
	elseif type(v) == "number" then
		vt = tostring(v)
	elseif field == "cls" then
		vt = L("choice.powerauras.cls." .. v)
	else
		vt = L("mod.powerauras.v." .. field .. "." .. v)
	end
	return L("mod.powerauras.f." .. field) .. " : " .. vt
end

-- Champs du formulaire selon le genre d'alerte. basic : ceux de la vue Essentiel ; adv : ceux ajoutes en vue complete.
function M.FieldList(a, adv)
	local out = {}
	local k = a.kind
	if k == "aura" then
		tinsert(out, "unit")
		tinsert(out, "filt")
		tinsert(out, "when")
	elseif k == "cd" then
		tinsert(out, "when")
	elseif k == "power" then
		tinsert(out, "unit")
		tinsert(out, "res")
		tinsert(out, "when")
	else
		tinsert(out, "res")
		tinsert(out, "thr")
	end
	tinsert(out, "disp")
	tinsert(out, "zone")
	tinsert(out, "size")
	tinsert(out, "glow")
	tinsert(out, "snd")
	tinsert(out, "proc")
	if adv then
		tinsert(out, "col")
		if k == "aura" then
			tinsert(out, "minst")
			if a.unit == "target" then tinsert(out, "dur") end
		end
		if k == "aura" or k == "cd" then
			tinsert(out, "tm")
			tinsert(out, "sk")
		end
		tinsert(out, "lb")
		if a.proc then tinsert(out, "hold") end
		tinsert(out, "vc")
		tinsert(out, "grp")
		tinsert(out, "cls")
		tinsert(out, "spec")
	end
	return out
end

function M.Describe(a)
	local nm = a.name
	if nm == EMPTY then nm = (a.kind == "aura" or a.kind == "cd") and L("mod.powerauras.noname") or M.LabelOf(a) end
	return L("mod.powerauras.k." .. a.kind) .. "  " .. nm
end

local function listRow(a)
	local Mn = SUI.Menu
	local lab = Mn.Get("pa_lbl")
	if not lab then return end
	Mn.Flow(lab, 1, 300, 24, 0, 4)
	lab.fs:SetText(M.Describe(a))
	local stt = M.StatusOf(a)
	lab.st:SetText(stt == "ok" and EMPTY or L("mod.powerauras.st." .. stt))
	local col = (stt == "ok") and T.c.dim or T.c.warn
	lab.st:SetTextColor(col[1], col[2], col[3], 1)
	local id = a.id
	local x = 306
	rowBtn(x, 56, L(a.on and "mod.powerauras.on" or "mod.powerauras.off"), function()
		local r = M.Find(id)
		if r then
			M.Toggle(r, "on")
		end
	end, L("mod.powerauras.on.t"), L("tip.powerauras.on"), a.on)
	rowBtn(x + 60, 80, L("mod.powerauras.editbtn"), function()
		if M.editId == id then M.editId = 0 else M.editId = id end
		M.pick = false
		M.edit.name = (M.Find(id) or a).name
		rerender()
	end, L("mod.powerauras.editbtn"), L("tip.powerauras.editbtn"), M.editId == id)
	rowBtn(x + 144, 64, L("mod.powerauras.copy"), function()
		local r, why = M.Copy(id)
		if not r then say("msg.powerauras.full") end
	end, L("mod.powerauras.copy"), L("tip.powerauras.copy"))
	local del = rowBtn(x + 212, 80, L("mod.powerauras.del"), nil, L("mod.powerauras.del"), L("tip.powerauras.del"))
	if del then
		local label = L("mod.powerauras.del")
		del.fn = function(b)
			Mn.ConfirmClick(b, "pa:del:" .. id, label, function() M.Remove(id) end)
		end
	end
	Mn.EndRow(4)
end

local function sectionList()
	local Mn = SUI.Menu
	Mn.Section(L("mod.powerauras.sec.list"), strformat("%d / %d", M.nal, M.MAXA))
	if M.nal == 0 then
		Mn.Para(L("mod.powerauras.empty"), 30)
	end
	for i = 1, M.nal do listRow(M.alerts[i]) end
	if M.nal > 0 then
		gridBtn(3, 208, L(M.demo and "mod.powerauras.demo.stop" or "mod.powerauras.demo.start"), function()
			M.SetDemo(not M.demo)
			rerender()
		end, L("mod.powerauras.demo.start"), L("tip.powerauras.demo"), M.demo)
		local b = gridBtn(3, 208, L("mod.powerauras.moveall"), function()
			if SUI.Mover then SUI.Mover.Enter() end
		end, L("mod.powerauras.moveall"), L("tip.powerauras.moveall"))
		local c = gridBtn(3, 208, L("mod.powerauras.clear"), nil, L("mod.powerauras.clear"), L("tip.powerauras.clear"))
		if c then
			local label = L("mod.powerauras.clear")
			c.fn = function(bt)
				Mn.ConfirmClick(bt, "pa:clear", label, function() M.Clear() end)
			end
		end
		Mn.EndRow(6)
	end
end

-- Liste des auras actuelles pour "prendre une aura qui existe".
local function sectionPick(a)
	local Mn = SUI.Menu
	local key = a.lk
	M.ScanAuras(key)
	local l = M.A[key]
	Mn.Para(L("mod.powerauras.pick.help"), 30)
	if l.n == 0 then
		Mn.Para(L("mod.powerauras.pick.none"), 18)
		return
	end
	for i = 1, l.n do
		M.AuraName(key, i)
		local shown = l.nm[i]
		local rank = i
		gridBtn(3, 208, shown ~= EMPTY and shown or L("mod.powerauras.pick.unnamed", i), function()
			local r = M.Find(M.editId)
			if r and M.PickAura(r, rank) then
				M.edit.name = r.name
				M.pick = false
				rerender()
			end
		end, L("mod.powerauras.pick.one"), L("tip.powerauras.pick.one"))
	end
	Mn.EndRow(6)
end

local function sectionEditor()
	local Mn = SUI.Menu
	local a = M.Find(M.editId)
	if not a then return end
	Mn.Section(L("mod.powerauras.sec.edit", M.Describe(a)))
	-- nom / aura / sort / objet suivi
	local nameKey = (a.kind == "aura" or a.kind == "cd") and ("mod.powerauras.name." .. a.kind .. (a.item and ".item" or EMPTY)) or "mod.powerauras.name.label"
	Mn.Para(L(nameKey) .. "  -  " .. L("tip.powerauras.name"), 30)
	local ed = Mn.Get("pa_edit")
	if ed then
		Mn.Flow(ed, 1, 330, 24, 0, 6)
		ed.edit.silent = true
		if (ed.edit:GetText() or EMPTY) ~= M.edit.name then ed.edit:SetText(M.edit.name) end
		ed.edit.silent = false
		rowBtn(338, 90, L("mod.powerauras.apply"), function() M.ApplyName() end, L("mod.powerauras.apply"), L("tip.powerauras.apply"))
		if a.kind == "aura" then
			rowBtn(432, 216, L(M.pick and "mod.powerauras.pick.close" or "mod.powerauras.pick.open"), function()
				M.pick = not M.pick
				rerender()
			end, L("mod.powerauras.pick.open"), L("tip.powerauras.pick.tip"), M.pick)
		end
		Mn.EndRow(6)
	end
	if M.pick and a.kind == "aura" then sectionPick(a) end
	-- etat du suivi
	local stt = M.StatusOf(a)
	if stt ~= "ok" and stt ~= "off" then Mn.Para(L("mod.powerauras.st.long." .. stt), 30, T.c.warn) end
	-- champs
	local fields = M.FieldList(a, Mn.mode == "all")
	for i = 1, getn(fields) do
		local field = fields[i]
		gridBtn(3, 208, M.FieldText(a, field), function(b, mb)
			local r = M.Find(M.editId)
			if not r then return end
			local dir = (mb == "RightButton") and -1 or 1
			if type(r[field]) == "boolean" then M.Toggle(r, field) else M.Cycle(r, field, dir) end
		end, L("mod.powerauras.f." .. field), L("tip.powerauras.f." .. field) .. "  " .. L("tip.powerauras.cycle"))
	end
	Mn.EndRow(6)
	-- actions
	gridBtn(3, 208, L("mod.powerauras.test"), function()
		local r = M.Find(M.editId)
		if r then M.Test(r) end
	end, L("mod.powerauras.test"), L("tip.powerauras.test"))
	gridBtn(3, 208, L("mod.powerauras.done"), function()
		M.editId = 0
		rerender()
	end, L("mod.powerauras.done"), L("tip.powerauras.done"))
	Mn.EndRow(6)
	if Mn.mode ~= "all" then
		local n = Mn.Get("note")
		if n then
			Mn.Flow(n, 1, 648, 38, 0, 10)
			n.fs:SetText(L("mod.powerauras.more"))
			T.SetButtonText(n.btn, L("mod.menu.showall"))
			n.btn.fn = function() Mn.SetMode("all") end
			Mn.EndRow(10)
		end
	end
end

local function sectionTemplates()
	local Mn = SUI.Menu
	Mn.Section(L("mod.powerauras.sec.new"))
	Mn.Para(L("mod.powerauras.new.help"), 30)
	for i = 1, getn(M.TEMPLATES) do
		local id = M.TEMPLATES[i].id
		gridBtn(3, 208, L("mod.powerauras.tpl." .. id), function()
			local a, why = M.AddTemplate(id)
			if not a then say("msg.powerauras.full") end
			rerender()
		end, L("mod.powerauras.tpl." .. id), L("tip.powerauras.tpl." .. id))
	end
	Mn.EndRow(6)
end

local function packRow(p)
	local Mn = SUI.Menu
	local lab = Mn.Get("pa_lbl")
	if not lab then return end
	Mn.Flow(lab, 1, 380, 24, 0, 4)
	local cn = (p.class == "ALL") and L("mod.powerauras.pack.all") or L("choice.powerauras.cls." .. p.class)
	lab.fs:SetWidth(260)
	lab.fs:SetText(cn .. " - " .. L("mod.powerauras.role." .. p.role))
	local have = M.PackCount(p.id)
	local rec = (p.id == M.Recommended())
	lab.st:SetWidth(110)
	if have > 0 then
		lab.st:SetText(L("mod.powerauras.pack.have", have))
		lab.st:SetTextColor(T.c.good[1], T.c.good[2], T.c.good[3], 1)
	elseif rec then
		lab.st:SetText(L("mod.powerauras.pack.rec"))
		lab.st:SetTextColor(T.c.warn[1], T.c.warn[2], T.c.warn[3], 1)
	else
		lab.st:SetText(EMPTY)
	end
	local id = p.id
	local names = M.PackNames(p)
	rowBtn(386, 120, L("mod.powerauras.pack.add"), function()
		local n, why = M.PackAdd(id)
		if n then say("msg.powerauras.pack.added", n)
		elseif why == "have" then say("msg.powerauras.pack.have")
		else say("msg.powerauras.full") end
	end, L("mod.powerauras.pack.add"), L("tip.powerauras.pack.add") .. " " .. names, nil, rec and have == 0)
	local rm = rowBtn(510, 120, L("mod.powerauras.pack.remove"), nil, L("mod.powerauras.pack.remove"), L("tip.powerauras.pack.remove"))
	if rm then
		rm.fn = function()
			local n = M.RemovePack(id)
			say("msg.powerauras.pack.removed", n)
		end
	end
	Mn.EndRow(4)
end

local function sectionPacks()
	local Mn = SUI.Menu
	Mn.Section(L("mod.powerauras.sec.packs"))
	Mn.Para(L("mod.powerauras.packs.help"), 30)
	for i = 1, getn(M.PACKS) do
		local p = M.PACKS[i]
		if M.allPacks or p.class == M.class or p.class == "ALL" then packRow(p) end
	end
	gridBtn(3, 208, L(M.allPacks and "mod.powerauras.packs.mine" or "mod.powerauras.packs.every"), function()
		M.allPacks = not M.allPacks
		rerender()
	end, L("mod.powerauras.packs.every"), L("tip.powerauras.packs.every"))
	Mn.EndRow(6)
end

local function sectionZones()
	local Mn = SUI.Menu
	Mn.Section(L("mod.powerauras.sec.zones"))
	Mn.Para(L("mod.powerauras.zones.help"), 44)
	for n = 1, M.NZONE do
		local zn = n
		local cnt = M.ZoneCount(n)
		gridBtn(4, 150, L("mod.powerauras.zone.line", n, L("mod.powerauras.dir." .. M.ZoneDir(n)), cnt), function(b, mb)
			M.ZoneCycle(zn, (mb == "RightButton") and -1 or 1)
		end, L("mod.powerauras.zone.t", n), L("tip.powerauras.zone"))
	end
	Mn.EndRow(6)
end

function M.Page()
	local Mn = SUI.Menu
	local mod = SUI.modules.powerauras
	if not mod or not mod.enabled then Mn.Para(L("mod.powerauras.disabled"), 34, T.c.warn) end
	Mn.Para(L("mod.powerauras.intro"), 44)
	sectionList()
	sectionEditor()
	sectionTemplates()
	sectionPacks()
	sectionZones()
	Mn.Section(L("mod.powerauras.sec.opts"))
end

function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked2 then return end
	M.hooked2 = true
	menuKind("pa_btn", newBtn)
	menuKind("pa_edit", newEdit)
	menuKind("pa_lbl", newLabel)
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "powerauras" then M.Page() end
		orig()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("powerauras", 66)

local function opt(key, typ, order, def, extra)
	local o = { key = "powerauras." .. key, type = typ, cat = "powerauras", label = "opt.powerauras." .. key, tip = "tip.powerauras." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

SUI.RegisterModule("powerauras", {
	default = false,
	cost = "light",
	options = {
		opt("show", "bool", 10, true, { simple = true }),
		opt("sound", "bool", 20, true, { simple = true }),
		opt("flash", "choice", 30, "soft", { choices = { "off", "soft", "strong" }, simple = true }),
		opt("border", "choice", 40, "color", { choices = { "color", "style", "none" } }),
		opt("sweep", "bool", 50, true),
		opt("tenths", "bool", 60, true),
		opt("alpha", "number", 70, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("spacing", "number", 80, 4, { min = 0, max = 20, step = 1 }),
		opt("tick", "number", 90, 0.2, { min = 0.1, max = 0.5, step = 0.05 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : les alertes et la direction de chaque zone.
SUI.Config.Register({ ["powerauras.data"] = EMPTY, ["powerauras.zones"] = "rrrddrdd" })

M.HookMenu()
C.Watch("powerauras.", M.OnKey)

-- Mode Raid : relecture plus lente.
SUI.Config.AddPreset("raid", "*", { ["powerauras.tick"] = 0.3 })

-- Aucun module pfUI equivalent (pfUI n'a pas d'alertes d'auras) : pas d'entree dans Migrate.MAP.

-- ---------------------------------------------------------------- commande /sui powerauras
function M.Command(rest)
	local _, _, sub, arg = strfind(rest or EMPTY, "^%s*(%S*)%s*(.-)%s*$")
	sub = strlower(sub or EMPTY)
	if sub == "list" then
		if M.nal == 0 then say("msg.powerauras.none") end
		for i = 1, M.nal do
			local a = M.alerts[i]
			local stt = M.StatusOf(a)
			SUI.Print(strformat("%d. %s (%s)", i, M.Describe(a), stt == "ok" and L("mod.powerauras.on") or L("mod.powerauras.st." .. stt)))
		end
	elseif sub == "test" then
		local n = tonumber(arg)
		local a = n and M.alerts[n] or M.alerts[1]
		if a then M.Test(a) else say("msg.powerauras.none") end
	elseif sub == "demo" then
		M.SetDemo(not M.demo)
		say(M.demo and "msg.powerauras.demo.on" or "msg.powerauras.demo.off")
	elseif sub == "pack" then
		if arg == EMPTY then arg = M.Recommended() or EMPTY end
		local n, why = M.PackAdd(arg)
		if n then say("msg.powerauras.pack.added", n)
		elseif why == "have" then say("msg.powerauras.pack.have")
		elseif why == "full" then say("msg.powerauras.full")
		else say("msg.powerauras.pack.unknown", arg) end
	elseif sub == "on" or sub == "off" then
		C.SetBase("modules.powerauras", sub == "on")
	else
		local Mn = SUI.Menu
		if Mn and Mn.Show then
			Mn.Show("powerauras")
		else
			say("msg.powerauras.status", M.nal, M.nact)
		end
	end
end

SUI.RegisterCommand("powerauras", function(rest) M.Command(rest or EMPTY) end, "help.powerauras")
