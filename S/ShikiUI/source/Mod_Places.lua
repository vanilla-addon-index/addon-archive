-- ShikiUI Places : lieux utiles sur la carte du monde et la minicarte (module "places", avec le module Codex). Services (reparateur, hotel des ventes, banque,
-- boite aux lettres, marchand, ecurie), deplacements (maitre de vol, aubergiste, maitre de bataille, pierre de rencontre, guerisseur d'esprit), entraineurs
-- (ta classe, tes metiers) et ressources (herbes, minerais, poissons, coffres). Donnees : ShikiCodexData_Places (LoadOnDemand, charge a la premiere pose ;
-- tools/build_places.js depuis pfQuest). Les lieux d'une meme famille proches l'un de l'autre sont regroupes (un clic : la liste). Un fournisseur du Codex
-- (Cx.PinTrack(fn, "places")) : memes epingles, meme fenetre de clic, meme minicarte que les quetes ; aucune minuterie propre.
-- NON VERIFIE EN JEU : GetSkillLineInfo (metiers sous un titre replie : invisibles pour l'API, donc ressources / entraineurs montres si aucun metier n'est lu).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local slower, sfind, sformat = string.lower, string.find, string.format
local floor = math.floor

local M = {}
SUI.Places = M

M.on = false
M.ADDON = "ShikiCodexData_Places"
M.CELL = 4.5                 -- cote (en % de la carte) d'une cellule de regroupement
M.TIPMAX = 8                 -- lignes de l'infobulle d'une epingle
M.ENTMAX = 40                -- entrees gardees par epingle (la fenetre de clic en montre 8)

-- famille, marque (une lettre ASCII), groupe de couleur, active par defaut
M.KINDS = {
	{ "repair", "R", "svc", true },
	{ "auctioneer", "A", "svc", true },
	{ "banker", "B", "svc", true },
	{ "mailbox", "M", "svc", true },
	{ "vendor", "V", "svc", false },
	{ "stablemaster", "S", "svc", false },
	{ "flight", "F", "trv", true },
	{ "innkeeper", "I", "trv", true },
	{ "battlemaster", "W", "trv", false },
	{ "meetingstone", "P", "trv", false },
	{ "spirithealer", "+", "trv", false },
	{ "trainer", "T", "trn", true },
	{ "herbs", "h", "res", true },
	{ "mines", "m", "res", true },
	{ "fish", "f", "res", false },
	{ "chests", "c", "res", false },
}
M.KIND = {}
for i = 1, getn(M.KINDS) do M.KIND[M.KINDS[i][1]] = M.KINDS[i] end

-- metiers : numero de categorie des entraineurs (101...), motifs (Lua) du nom du metier, anglais et francais sans accents (un point = un octet d'accent)
M.PROF = {
	{ 101, { "alchem", "alchimie" } },
	{ 102, { "blacksmith", "forge" } },
	{ 103, { "cooking", "cuisine" } },
	{ 104, { "enchant" } },
	{ 105, { "engineer", "ing..nierie" } },
	{ 106, { "first aid", "secourisme" } },
	{ 107, { "fishing", "p..che" } },
	{ 108, { "herbal", "herbor" } },
	{ 109, { "jewelcraft", "joaill" } },
	{ 110, { "leatherwork", "cuir" } },
	{ 111, { "mining", "minage" } },
	{ 112, { "skinning", "d..pe" } },
	{ 113, { "tailor", "couture" } },
	{ 114, { "survival", "survie" } },
}
-- Icones des familles (fichiers de ShikiUIMediaIcons, pfQuest MIT) ; entraineurs : icone de classe du client ou icone de metier
M.ICONFILE = { repair = "repair", auctioneer = "auctioneer", banker = "banker", mailbox = "mailbox", vendor = "vendor", stablemaster = "stablemaster",
	flight = "flight", innkeeper = "innkeeper", battlemaster = "battlemaster", meetingstone = "meetingstone", spirithealer = "spirithealer",
	trainer = "icon_npc", herbs = "herbs", mines = "mines", fish = "fish", chests = "chests" }
M.CLASSTC = {
	[1] = { 0, 0.25, 0, 0.25 }, [8] = { 0.25, 0.49609375, 0, 0.25 }, [4] = { 0.49609375, 0.7421875, 0, 0.25 }, [11] = { 0.7421875, 0.98828125, 0, 0.25 },
	[3] = { 0, 0.25, 0.25, 0.5 }, [7] = { 0.25, 0.49609375, 0.25, 0.5 }, [5] = { 0.49609375, 0.7421875, 0.25, 0.5 }, [9] = { 0.7421875, 0.98828125, 0.25, 0.5 },
	[2] = { 0, 0.25, 0.5, 0.75 }, [20] = { 0, 0.25, 0.25, 0.5 },
}
M.CLASSTEX = "Interface\\WorldStateFrame\\Icons-Classes"
M.PROFICON = { [101] = "Trade_Alchemy", [102] = "Trade_BlackSmithing", [103] = "INV_Misc_Food_15", [104] = "Trade_Engraving", [105] = "Trade_Engineering",
	[106] = "Spell_Holy_SealOfSacrifice", [107] = "Trade_Fishing", [108] = "Spell_Nature_NatureTouchGrow", [109] = "INV_Misc_Gem_01",
	[110] = "Trade_LeatherWorking", [111] = "Trade_Mining", [112] = "INV_Misc_Pelt_Wolf_01", [113] = "Trade_Tailoring", [115] = "Ability_Poisons" }

-- Icone (chemin, rognage) d'une famille ; pour un entraineur selon sa categorie
function M.IconOf(key, tag)
	local Cx = SUI.Codex
	local dir = Cx and Cx.ICONDIR or "Interface\\AddOns\\ShikiUI\\Media\\Icons\\"
	if key == "trainer" and tag then
		if M.CLASSTC[tag] then return M.CLASSTEX, M.CLASSTC[tag] end
		if M.PROFICON[tag] then return "Interface\\Icons\\" .. M.PROFICON[tag], nil end
	end
	return dir .. (M.ICONFILE[key] or "icon_npc"), nil
end

M.CLASSID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local function glob(name)
	return getglobal(name)
end

local function codex()
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.P and Cx.PinTrack then return Cx end
	return nil
end

local function lang()
	if SUI.locale then return SUI.locale == "fr" and "fr" or "en" end
	return "en"
end

-- ---------------------------------------------------------------- le joueur : faction, classe, metiers
function M.Me()
	if M.me then return M.me end
	local me = { fbit = nil, cls = nil, prof = {}, nprof = 0 }
	local fg = glob("UnitFactionGroup")
	if fg then
		local ok, f = pcall(fg, "player")
		if ok and f == "Alliance" then me.fbit = 1 elseif ok and f == "Horde" then me.fbit = 2 end
	end
	local uc = glob("UnitClass")
	if uc then
		local ok, _, tok = pcall(uc, "player")
		if ok and type(tok) == "string" then me.cls = M.CLASSID[tok] end
	end
	local gn, gi = glob("GetNumSkillLines"), glob("GetSkillLineInfo")
	if gn and gi then
		local ok, n = pcall(gn)
		if ok and type(n) == "number" then
			for i = 1, n do
				local ok2, name, header = pcall(gi, i)
				if ok2 and type(name) == "string" and not header then
					local low = slower(name)
					for k = 1, getn(M.PROF) do
						local pats = M.PROF[k][2]
						for j = 1, getn(pats) do
							if sfind(low, pats[j]) and not me.prof[M.PROF[k][1]] then
								me.prof[M.PROF[k][1]] = true
								me.nprof = me.nprof + 1
							end
						end
					end
				end
			end
		end
	end
	local key = tostring(me.fbit) .. "|" .. tostring(me.cls)
	for k = 1, getn(M.PROF) do
		if me.prof[M.PROF[k][1]] then key = key .. "," .. M.PROF[k][1] end
	end
	me.key = key
	M.me = me
	return me
end

function M.OnSkills()
	M.me = nil
	M.Refresh()
end

-- ---------------------------------------------------------------- donnees
function M.Load()
	local pl = glob("ShikiCodexPlaces")
	if type(pl) ~= "table" then
		local la = glob("LoadAddOn")
		if la then pcall(la, M.ADDON) end
		pl = glob("ShikiCodexPlaces")
	end
	if type(pl) ~= "table" or type(pl.z) ~= "table" then
		if not M.warned then
			M.warned = true
			SUI.Print(L("msg.places.missing"))
		end
		return nil
	end
	return pl
end

function M.Name(pl, id)
	local t = lang() == "fr" and pl.fr and pl.fr[id] or nil
	return t or (pl.en and pl.en[id]) or ("#" .. tostring(id))
end

-- Enregistrement { zones = { g } } d'une zone de donnees (nil si les noms de zones des quetes ne sont pas chargeables)
function M.ZRec(Cx, zid, ctx)
	M.zrec = M.zrec or {}
	local zkey = zid .. (ctx or "")
	local r = M.zrec[zkey]
	if r ~= nil then return r end
	local P = Cx.P
	local en, fr
	if P.LoadQuests() then en, fr = P.ZoneBoth(zid) end
	if en then
		r = { id = -2, t = L("msg.places.title"), cap = Cx.PIN_POOL, n = 0, zones = { { en = en, fr = fr, map = P.ZoneMap(zid), zid = zid, n = 0, pins = {} } } }
	else
		r = false
	end
	M.zrec[zkey] = r
	return r
end

-- Zone de donnees affichee par la carte (c, z), ou nil
function M.ZoneOf(Cx, pl, c, z)
	M.zcur = M.zcur or {}
	local key = c .. "." .. z
	local v = M.zcur[key]
	if v ~= nil then return v or nil end
	for zid in pairs(pl.z) do
		local r = M.ZRec(Cx, zid)
		if r and Cx.PinHere(r, c, z) then
			M.zcur[key] = zid
			return zid
		end
	end
	M.zcur[key] = false
	return nil
end

-- ---------------------------------------------------------------- ressources : icone et choix par ressource
SUI.Config.Register({ ["places.hide"] = "" })
-- nom anglais (sans "Rich", "Small", "Ooze Covered", "Hakkari") -> objet ramasse (l'icone est celle de l'objet, lue par le Codex)
M.RESITEM = {
	["Peacebloom"] = 2447, ["Silverleaf"] = 765, ["Earthroot"] = 2449, ["Mageroyal"] = 785, ["Briarthorn"] = 2450, ["Stranglekelp"] = 3820,
	["Bruiseweed"] = 2453, ["Wild Steelbloom"] = 3355, ["Kingsblood"] = 3356, ["Liferoot"] = 3357, ["Fadeleaf"] = 3818, ["Goldthorn"] = 3821,
	["Khadgar's Whisker"] = 3358, ["Wintersbite"] = 3819, ["Firebloom"] = 4625, ["Purple Lotus"] = 8831, ["Arthas' Tears"] = 8836,
	["Sungrass"] = 8838, ["Blindweed"] = 8839, ["Ghost Mushroom"] = 8845, ["Gromsblood"] = 8846, ["Grave Moss"] = 3369, ["Golden Sansam"] = 13464,
	["Dreamfoil"] = 13463, ["Mountain Silversage"] = 13465, ["Plaguebloom"] = 13466, ["Icecap"] = 13467, ["Black Lotus"] = 13468,
	["Copper Vein"] = 2770, ["Tin Vein"] = 2771, ["Iron Deposit"] = 2772, ["Silver Vein"] = 2775, ["Gold Vein"] = 2776, ["Mithril Deposit"] = 3858,
	["Truesilver Deposit"] = 7911, ["Thorium Vein"] = 10620, ["Dark Iron Deposit"] = 11370, ["Incendicite Mineral Vein"] = 3340,
	["Indurium Mineral Vein"] = 5833, ["Lesser Bloodstone Deposit"] = 4278,
}
M.RESPRE = { "Ooze Covered ", "Rich ", "Small ", "Hakkari " }

function M.ResKey(en)
	local s = en or ""
	for i = 1, getn(M.RESPRE) do
		local p = M.RESPRE[i]
		if string.sub(s, 1, string.len(p)) == p then s = string.sub(s, string.len(p) + 1) end
	end
	return s
end

-- Ressources masquees (cles ResKey, separees par |) ; l'ensemble est relu seulement quand la chaine change
function M.Hidden()
	local s = C.Get("places.hide") or ""
	if M.hidS ~= s then
		M.hidS = s
		local set = {}
		for k in string.gfind(s, "[^|]+") do set[k] = true end
		M.hidSet = set
	end
	return M.hidSet
end

function M.SetHidden(set)
	local list = {}
	for k in pairs(set) do tinsert(list, k) end
	tsort(list)
	local s = ""
	for i = 1, getn(list) do s = s .. (i > 1 and "|" or "") .. list[i] end
	C.Set("places.hide", s)
end

-- Icone de l'objet ramasse (chemin complet) ou nil (inconnue ou pas encore en memoire : on reessaie un peu plus tard)
function M.ResIcon(rk)
	local id = M.RESITEM[rk]
	local Cx = SUI.Codex
	if not id or not Cx or not Cx.ItemIcon then return nil end
	local tex = Cx.ItemIcon(id)
	if type(tex) ~= "string" or tex == "" then
		M.iconWait = true
		return nil
	end
	if not sfind(tex, string.char(92), 1, true) then tex = "Interface" .. string.char(92) .. "Icons" .. string.char(92) .. tex end
	return tex
end

-- ---------------------------------------------------------------- filtres
function M.KindOn(key, ctx)
	return C.Get((ctx == "mini" and "places.m." or "places.") .. key) and true or false
end

-- Un lieu (famille, faction, categorie) est-il a montrer pour ce joueur ?
function M.Wanted(key, fac, tag, me)
	if C.Get("places.faction") and me.fbit and fac ~= 3 and fac ~= me.fbit then return false end
	local mine = C.Get("places.mine")
	if key == "trainer" then
		if tag == 20 or tag == 21 or tag == 22 then return C.Get("places.mounts") and true or false end
		if not mine then return true end
		if tag == 99 then return false end
		if tag > 100 then return me.nprof == 0 or me.prof[tag] == true end
		return me.cls == nil or tag == me.cls
	end
	if mine and me.nprof > 0 then
		if key == "herbs" then return me.prof[108] == true end
		if key == "mines" then return me.prof[111] == true end
		if key == "fish" then return me.prof[107] == true end
	end
	return true
end

-- ---------------------------------------------------------------- regroupement
local function optSig(ctx)
	local s = lang() .. (ctx or "")
	for i = 1, getn(M.KINDS) do
		s = s .. (M.KindOn(M.KINDS[i][1], ctx) and "1" or "0")
	end
	return s .. (C.Get("places.faction") and "1" or "0") .. (C.Get("places.mine") and "1" or "0") .. (C.Get("places.mounts") and "1" or "0") .. "|" .. (C.Get("places.hide") or "")
end

local function entryList(pins)
	for i = 1, getn(pins) do
		local pin = pins[i]
		pin.x, pin.y = pin.sx / pin.n, pin.sy / pin.n
		local list = pin.ents
		tsort(list, function(a, b)
			if a.title ~= b.title then return a.title < b.title end
			return a.id < b.id
		end)
		local q, lines = {}, {}
		for k = 1, getn(list) do
			local e = list[k]
			local title = e.title
			if e.cnt > 1 then title = title .. " x" .. e.cnt end
			if k <= M.ENTMAX then tinsert(q, { place = true, title = title, sub = e.sub }) end
			if k <= M.TIPMAX then
				tinsert(lines, title .. (e.sub and (" - " .. e.sub) or ""))
			elseif k == M.TIPMAX + 1 then
				tinsert(lines, L("msg.places.more", getn(list) - M.TIPMAX))
			end
		end
		pin.q, pin.lines = q, lines
		pin.title = L("msg.places.k." .. pin.kind)
		pin.head = pin.title .. " (" .. getn(list) .. ")"
		pin.sx, pin.sy, pin.ents, pin.n, pin.by = nil, nil, nil, nil, nil
	end
end

-- Epingles (regroupees) de la zone de donnees zid pour ce joueur
function M.BuildPins(pl, zid, me, ctx)
	local zd = pl.z[zid]
	local pins, cells = {}, {}
	if not zd then return pins end
	M.iconWait = false
	local hid = M.Hidden()
	for ki = 1, getn(M.KINDS) do
		local key = M.KINDS[ki][1]
		local arr = zd[key]
		if arr and M.KindOn(key, ctx) then
			local vk = "P" .. key
			for i = 1, getn(arr), 4 do
				local packed, id, fac, tag = arr[i], arr[i + 1], arr[i + 2], arr[i + 3]
				local rk
				if key == "herbs" or key == "mines" then rk = M.ResKey(pl.en and pl.en[id]) end
				if M.Wanted(key, fac, tag, me) and not (rk and hid[rk]) then
					local xi = floor(packed / 1024)
					local x, y = xi / 10, (packed - xi * 1024) / 10
					local ck = key .. ":" .. (key == "trainer" and tag or rk or 0) .. ":" .. floor(x / M.CELL) * 1000 + floor(y / M.CELL)
					local pin = cells[ck]
					if not pin then
						pin = { k = "P", vk = vk, kind = key, x = x, y = y, sx = 0, sy = 0, n = 0, ents = {}, by = {} }
						pin.icon, pin.tc = M.IconOf(key, tag)
						if rk then
							local ri = M.ResIcon(rk)
							if ri then pin.icon, pin.tc = ri, nil end
						end
						cells[ck] = pin
						tinsert(pins, pin)
					end
					pin.sx, pin.sy, pin.n = pin.sx + x, pin.sy + y, pin.n + 1
					local e = pin.by[id]
					if e then
						e.cnt = e.cnt + 1
					else
						local sub
						if key == "trainer" then
							sub = L("msg.places.t." .. tag)
						elseif tag and tag > 0 and (key == "herbs" or key == "mines") then
							sub = L("msg.places.skill", tag)
						end
						e = { id = id, title = M.Name(pl, id), sub = sub, cnt = 1 }
						pin.by[id] = e
						tinsert(pin.ents, e)
					end
				end
			end
		end
	end
	entryList(pins)
	return pins
end

-- Les icones d'objets ramasses arrivent quand le client les a vues : on repose les epingles quelques secondes plus tard
function M.IconRetry()
	M.iconTask = nil
	M.zsig = nil
	M.Refresh()
end

-- Fournisseur du Codex : enregistrements de la zone affichee (c, z) ; ctx "mini" : minicarte (option propre)
function M.Recs(c, z, ctx)
	local Cx = codex()
	if not Cx or not M.on or not C.Get("places.show") or not c or not z or z <= 0 then return {} end
	if ctx == "mini" and not C.Get("places.mini") then return {} end
	if ctx ~= "mini" then M.FilterButtons() end
	local pl = M.Load()
	if not pl then return {} end
	local zid = M.ZoneOf(Cx, pl, c, z)
	if not zid then return {} end
	local cx = ctx == "mini" and "mini" or "map"
	local rec = M.ZRec(Cx, zid, cx)
	if not rec then return {} end
	local me = M.Me()
	local sig = optSig(cx) .. "|" .. me.key
	M.zsig = M.zsig or {}
	if M.zsig[zid .. cx] ~= sig then
		M.zsig[zid .. cx] = sig
		local g = rec.zones[1]
		g.pins = M.BuildPins(pl, zid, me, cx)
		g.n = getn(g.pins)
		rec.n = g.n
		if M.iconWait and not M.iconTask and (M.iconTries or 0) < 4 then
			M.iconTries = (M.iconTries or 0) + 1
			M.iconTask = SUI.After(3, M.IconRetry, "places.icons")
		end
	end
	local out = {}
	if rec.zones[1].n > 0 then tinsert(out, rec) end
	local f = M.focus
	if f and f.zid == zid then
		if not M.focusRec then
			M.focusRec = { id = -3, t = L("msg.places.title"), cap = 1, n = 1, zones = { { en = rec.zones[1].en, fr = rec.zones[1].fr, map = rec.zones[1].map, zid = zid, n = 1,
				pins = { { k = "P", vk = "P" .. f.kind, kind = f.kind, icon = M.IconOf(f.kind, nil), x = f.x, y = f.y, title = L("msg.places.nearest", f.name), head = f.name,
					lines = { f.name }, q = { { place = true, title = f.name } } } } } } }
		end
		tinsert(out, M.focusRec)
	end
	return out
end

-- ---------------------------------------------------------------- le plus proche
M.ALIASES = {
	repair = "repair", reparateur = "repair", repar = "repair",
	auctioneer = "auctioneer", ah = "auctioneer", hdv = "auctioneer", hotel = "auctioneer",
	banker = "banker", bank = "banker", banque = "banker",
	mailbox = "mailbox", mail = "mailbox", courrier = "mailbox", boite = "mailbox",
	vendor = "vendor", marchand = "vendor",
	stablemaster = "stablemaster", stable = "stablemaster", ecurie = "stablemaster",
	flight = "flight", vol = "flight", gryphon = "flight",
	innkeeper = "innkeeper", inn = "innkeeper", auberge = "innkeeper",
	battlemaster = "battlemaster", bg = "battlemaster",
	meetingstone = "meetingstone", pierre = "meetingstone",
	spirithealer = "spirithealer", esprit = "spirithealer",
	trainer = "trainer", entraineur = "trainer",
	herbs = "herbs", herbes = "herbs", herbo = "herbs",
	mines = "mines", mine = "mines", minerai = "mines", minerais = "mines",
	fish = "fish", peche = "fish",
	chests = "chests", coffres = "chests",
}

function M.Nearest(word)
	local key = M.ALIASES[slower(word or "")]
	if not key then
		SUI.Print(L("msg.places.nokind"))
		return
	end
	local Cx = codex()
	if not Cx or not M.on then
		SUI.Print(L("msg.places.off"))
		return
	end
	local pl = M.Load()
	local gp = glob("GetPlayerMapPosition")
	if not pl or not gp then return end
	local c, z = Cx.MapCur()
	local px, py = gp("player")
	if not c or not z or z <= 0 or not px or (px == 0 and py == 0) then
		SUI.Print(L("msg.places.nopos"))
		return
	end
	local zid = M.ZoneOf(Cx, pl, c, z)
	local zd = zid and pl.z[zid]
	local arr = zd and zd[key]
	if not arr then
		SUI.Print(L("msg.places.nonear", L("msg.places.k." .. key)))
		return
	end
	local me = M.Me()
	local sz = SUI.QuestTrack and SUI.QuestTrack.YARDS and SUI.QuestTrack.YARDS[zid] or { 1000, 1000 }
	px, py = px * 100, py * 100
	local best, bd, bx, by
	for i = 1, getn(arr), 4 do
		if M.Wanted(key, arr[i + 2], arr[i + 3], me) then
			local xi = floor(arr[i] / 1024)
			local x, y = xi / 10, (arr[i] - xi * 1024) / 10
			local dx, dy = (x - px) / 100 * sz[1], (y - py) / 100 * sz[2]
			local d = dx * dx + dy * dy
			if not bd or d < bd then best, bd, bx, by = arr[i + 1], d, x, y end
		end
	end
	if not best then
		SUI.Print(L("msg.places.nonear", L("msg.places.k." .. key)))
		return
	end
	M.focus = { zid = zid, kind = key, x = bx, y = by, name = M.Name(pl, best) }
	M.focusRec = nil
	SUI.Print(sformat(L("msg.places.near"), L("msg.places.k." .. key), M.focus.name, floor(bx) .. ", " .. floor(by), floor(math.sqrt(bd) + 0.5)))
	Cx.PinOnMapEvent()
	if SUI.QuestTrack and SUI.QuestTrack.MiniSync then SUI.QuestTrack.MiniSync() end
end

-- ---------------------------------------------------------------- choix de ce qui est affiche (carte et minicarte)
-- Une fenetre de cases a cocher, une ligne par famille (icone, nom, case Carte, case Mini). Deux exemplaires : sur la carte du monde (bouton Filtres en haut
-- a droite de la carte) et sous la minicarte (petit bouton). Les cases lisent et ecrivent les memes options que le menu ; aucune minuterie.
M.FROW = 22
M.FW = 280
M.panels = {}
M.fbtn = {}

function M.FilterRows()
	if M.frows then return M.frows end
	local rows = {}
	tinsert(rows, { head = "msg.places.f.quests" })
	tinsert(rows, { file = "available_c", label = "msg.places.f.givers", map = "questtrack.givers", mini = "questtrack.minigivers" })
	tinsert(rows, { file = "cluster_mob", label = "msg.places.f.objectives", map = "questtrack.pins", mini = "questtrack.mini" })
	tinsert(rows, { head = "msg.places.f.places" })
	for i = 1, getn(M.KINDS) do
		local k = M.KINDS[i][1]
		tinsert(rows, { kind = k, label = "msg.places.k." .. k, map = "places." .. k, mini = "places.m." .. k })
	end
	M.frows = rows
	return rows
end

local function mkCheck(f, key, x, y)
	local b = T.Check(f, function(on) C.Set(key, on and true or false) end)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y + 2)
	return b
end

local function mkMode(f, mode, x, y)
	local b = T.Button(f, L("msg.places.f." .. mode), 70, 20, function() M.FilterSet(mode) end)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
end

-- Liste des ressources de la zone affichee : une case par ressource (herbes ou minerais), icone de l'objet
M.RESMAX = 36
M.RESCOL = 18

function M.ResRow(f, i)
	local col = floor((i - 1) / M.RESCOL)
	local line = (i - 1) - col * M.RESCOL
	local row = CreateFrame("Frame", nil, f)
	row:SetWidth(200)
	row:SetHeight(M.FROW)
	row:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + col * 206, -34 - line * M.FROW)
	row.ic = row:CreateTexture(nil, "ARTWORK")
	row.ic:SetWidth(16)
	row.ic:SetHeight(16)
	row.ic:SetPoint("LEFT", row, "LEFT", 2, 0)
	row.txt = T.Text(row, 11, T.c.text, "LEFT")
	row.txt:SetPoint("LEFT", row, "LEFT", 24, 0)
	row.txt:SetWidth(140)
	row.cb = T.Check(row, function(on) M.ResSet(row.rk, on) end)
	row.cb:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	row:Hide()
	return row
end

function M.ResBuild()
	if M.respanel then return M.respanel end
	local parent = glob("WorldMapButton")
	if not parent or SUI.InCombat() then return nil end
	local f = CreateFrame("Frame", nil, parent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(parent:GetFrameLevel() + 22)
	f:EnableMouse(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
	local close = T.Button(f, "x", 18, 18, function() f:Hide() end)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	f.none = T.Text(f, 11, T.c.dim, "LEFT")
	f.none:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
	f.none:SetText(L("msg.places.f.res.none"))
	f.rows = {}
	for i = 1, M.RESMAX do f.rows[i] = M.ResRow(f, i) end
	f.bAll = T.Button(f, L("msg.places.f.all"), 70, 20, function() M.ResAll(true) end)
	f.bNone = T.Button(f, L("msg.places.f.none"), 70, 20, function() M.ResAll(false) end)
	f:Hide()
	M.respanel = f
	return f
end

-- Ressources du type kind dans la zone affichee : liste { rk, nom, icone, competence } triee par competence puis nom
function M.ResList(kind)
	local Cx = codex()
	local pl = M.Load()
	local out = {}
	if not Cx or not pl then return out end
	local c, z = Cx.MapCur()
	local zid = c and z and z > 0 and M.ZoneOf(Cx, pl, c, z)
	local arr = zid and pl.z[zid] and pl.z[zid][kind]
	if not arr then return out end
	local seen = {}
	for i = 1, getn(arr), 4 do
		local id = arr[i + 1]
		local rk = M.ResKey(pl.en and pl.en[id])
		if not seen[rk] then
			seen[rk] = true
			tinsert(out, { rk = rk, name = M.Name(pl, id), skill = arr[i + 3] or 0 })
		end
	end
	tsort(out, function(a, b)
		if a.skill ~= b.skill then return a.skill < b.skill end
		return a.name < b.name
	end)
	return out
end

function M.ResRefresh()
	local f = M.respanel
	if not f or not f:IsShown() then return end
	local hid = M.Hidden()
	for i = 1, M.RESMAX do
		local row = f.rows[i]
		if row:IsShown() then T.SetCheck(row.cb, not hid[row.rk]) end
	end
end

function M.ResOpen(kind)
	local f = M.ResBuild()
	if not f then return end
	local list = M.ResList(kind)
	M.reslist = list
	local n = getn(list)
	if n > M.RESMAX then n = M.RESMAX end
	f.title:SetText(L("msg.places.f.res.title", L("msg.places.k." .. kind)))
	M.reskind = kind
	local miss = false
	for i = 1, M.RESMAX do
		local row = f.rows[i]
		if i <= n then
			local it = list[i]
			row.rk = it.rk
			row.txt:SetText(it.name)
			local path = M.ResIcon(it.rk)
			if not path then
				path = M.IconOf(kind, nil)
				if M.RESITEM[it.rk] then miss = true end
			end
			row.ic:SetTexture(path)
			row:Show()
		else
			row:Hide()
		end
	end
	local cols = n > M.RESCOL and 2 or 1
	local lines = n > M.RESCOL and M.RESCOL or n
	if lines < 1 then lines = 1 end
	f.none:SetText(L("msg.places.f.res.none"))
	if n == 0 then f.none:Show() else f.none:Hide() end
	f:SetWidth(16 + cols * 206)
	f:SetHeight(72 + lines * M.FROW)
	f.bAll:ClearAllPoints()
	f.bAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.bNone:ClearAllPoints()
	f.bNone:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 86, 8)
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", glob("WorldMapButton"), "TOPRIGHT", -(M.FW + 24), -38)
	f:Show()
	M.ResRefresh()
	-- icones d'objets pas encore en memoire du client : on relit la liste dans deux secondes (trois essais au plus)
	if miss and (M.resTries or 0) < 3 and not M.resTask then
		M.resTries = (M.resTries or 0) + 1
		M.resTask = SUI.After(2, M.ResReopen, "places.resicons")
	elseif not miss then
		M.resTries = 0
	end
end

function M.ResReopen()
	M.resTask = nil
	if M.respanel and M.respanel:IsShown() and M.reskind then M.ResOpen(M.reskind) end
end

function M.ResSet(rk, on)
	if not rk then return end
	local set = {}
	for k in pairs(M.Hidden()) do set[k] = true end
	if on then set[rk] = nil else set[rk] = true end
	M.SetHidden(set)
end

function M.ResAll(on)
	local set = {}
	for k in pairs(M.Hidden()) do set[k] = true end
	local list = M.reslist or {}
	for i = 1, getn(list) do
		if on then set[list[i].rk] = nil else set[list[i].rk] = true end
	end
	M.SetHidden(set)
end

function M.ResBtn(f, kind, x, y)
	local b = T.Button(f, L("msg.places.f.list"), 48, 18, function() M.ResOpen(kind) end)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y + 1)
end

function M.FilterBuild(where)
	local pn = M.panels[where]
	if pn then return pn end
	local parent = glob(where == "map" and "WorldMapButton" or "UIParent")
	if not parent or SUI.InCombat() then return nil end
	local Cx = SUI.Codex
	local dir = Cx and Cx.ICONDIR or "Interface\\AddOns\\ShikiUI\\Media\\Icons\\"
	local rows = M.FilterRows()
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(M.FW)
	f:SetHeight(86 + getn(rows) * M.FROW)
	f:EnableMouse(true)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(parent:GetFrameLevel() + 20)
	T.Backdrop(f, T.c.bg, T.c.border)
	local title = T.Text(f, 12, T.c.text, "LEFT")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
	title:SetText(L("msg.places.f.title"))
	local x1, x2 = M.FW - 86, M.FW - 44
	local h1 = T.Text(f, 10, T.c.dim, "CENTER")
	h1:SetPoint("TOP", f, "TOPLEFT", x1 + 8, -30)
	h1:SetText(L("msg.places.f.map"))
	local h2 = T.Text(f, 10, T.c.dim, "CENTER")
	h2:SetPoint("TOP", f, "TOPLEFT", x2 + 8, -30)
	h2:SetText(L("msg.places.f.mini"))
	local close = T.Button(f, "x", 18, 18, function() f:Hide() end)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	f.ent = {}
	for i = 1, getn(rows) do
		local r = rows[i]
		local y = -48 - (i - 1) * M.FROW
		if r.head then
			local t = T.Text(f, 11, T.c.dim, "LEFT")
			t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y - 2)
			t:SetText(L(r.head))
		else
			local ic = f:CreateTexture(nil, "ARTWORK")
			ic:SetWidth(18)
			ic:SetHeight(18)
			ic:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y + 1)
			local path, tc
			if r.kind then path, tc = M.IconOf(r.kind, nil) else path = dir .. r.file end
			ic:SetTexture(path)
			if tc then ic:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
			local t = T.Text(f, 11, T.c.text, "LEFT")
			t:SetPoint("TOPLEFT", f, "TOPLEFT", 36, y - 2)
			t:SetText(L(r.label))
			if where == "map" and (r.kind == "herbs" or r.kind == "mines") then M.ResBtn(f, r.kind, 132, y) end
			tinsert(f.ent, { row = r, cm = mkCheck(f, r.map, x1, y), cn = mkCheck(f, r.mini, x2, y) })
		end
	end
	local by = -(48 + getn(rows) * M.FROW + 6)
	local modes = { "all", "none", "default" }
	for i = 1, 3 do mkMode(f, modes[i], 10 + (i - 1) * 76, by) end
	f:SetScript("OnHide", M.ResClose)
	f:Hide()
	M.panels[where] = f
	return f
end

function M.FilterRefresh(f)
	if not f or not f.ent then return end
	for i = 1, getn(f.ent) do
		local e = f.ent[i]
		T.SetCheck(e.cm, C.Get(e.row.map) and true or false)
		T.SetCheck(e.cn, C.Get(e.row.mini) and true or false)
	end
end

function M.FilterRefreshAll()
	for _, f in pairs(M.panels) do
		if f:IsShown() then M.FilterRefresh(f) end
	end
	M.ResRefresh()
end

function M.ResClose()
	if M.respanel then M.respanel:Hide() end
end

-- Tout / rien / defaut pour les lieux (les deux colonnes)
function M.FilterSet(mode)
	for i = 1, getn(M.KINDS) do
		local k = M.KINDS[i]
		local v
		if mode == "all" then v = true elseif mode == "none" then v = false else v = k[4] end
		C.Set("places." .. k[1], v)
		C.Set("places.m." .. k[1], v)
	end
end

function M.FilterToggle(where)
	if not M.on then
		SUI.Print(L("msg.places.f.nomod"))
		return
	end
	local f = M.FilterBuild(where)
	if not f then return end
	if f:IsShown() then
		f:Hide()
		return
	end
	f:ClearAllPoints()
	if where == "map" then
		f:SetPoint("TOPRIGHT", glob("WorldMapButton"), "TOPRIGHT", -12, -38)
	else
		local mm = glob("Minimap")
		f:SetPoint("TOPRIGHT", mm, "BOTTOMRIGHT", 0, -22)
	end
	M.FilterRefresh(f)
	f:Show()
end

-- Boutons Filtres : sur la carte (toujours) et sous la minicarte (option) ; crees hors combat, caches quand le module est coupe
function M.FilterButtons()
	local want = M.on and true or false
	local b = M.fbtn.map
	if not b and want then
		local btn = glob("WorldMapButton")
		if btn and not SUI.InCombat() then
			b = T.Button(btn, L("msg.places.f.btn"), 72, 20, function() M.FilterToggle("map") end)
			b:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -12, -12)
			b:SetFrameLevel(btn:GetFrameLevel() + 15)
			M.fbtn.map = b
		end
	end
	if b then
		if want then b:Show() else b:Hide() end
	end
	local m = M.fbtn.mini
	local wantMini = want and C.Get("places.minibutton") and true or false
	if not m and wantMini then
		local mm = glob("Minimap")
		if mm and not SUI.InCombat() then
			m = T.Button(mm, L("msg.places.f.btn"), 56, 18, function() M.FilterToggle("mini") end)
			m.suiOwn = true
			m:SetFrameStrata("HIGH")
			m:SetFrameLevel((mm:GetFrameLevel() or 0) + 12)
			SUI.MiniRing.Drag(m, "places.angle", 305)
			M.fbtn.mini = m
		end
	end
	if m then
		if wantMini then
			if not m.ringDrag then SUI.MiniRing.Place(m, "places.angle", 305) end
			m:Show()
		else
			m:Hide()
		end
	end
	if not want then
		for _, f in pairs(M.panels) do f:Hide() end
	end
end

-- ---------------------------------------------------------------- branchement
function M.MiniWanted()
	return M.on and C.Get("places.show") and C.Get("places.mini") and true or false
end

function M.Refresh()
	M.zsig = nil
	M.focusRec = nil
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
end

-- Branche / debranche le fournisseur selon l'etat du module, du Codex et de l'option (a rappeler a chaque changement)
function M.Sync()
	local Cx = SUI.Codex
	if not Cx or not Cx.PinTrack then return end
	local want = M.on and Cx.on and C.Get("places.show") and true or false
	if want and Cx.providers.places ~= M.Recs then
		Cx.PinTrack(M.Recs, "places")
	elseif not want and Cx.providers.places == M.Recs then
		Cx.PinTrack(nil, "places")
	end
	if SUI.QuestTrack and SUI.QuestTrack.MiniSync then SUI.QuestTrack.MiniSync() end
end

function M.OnKey()
	if not M.on then return end
	M.Sync()
	M.Refresh()
	M.FilterButtons()
	M.FilterRefreshAll()
end

function M.OnQKey()
	if M.on then M.FilterRefreshAll() end
end

function M.Enable()
	M.on = true
	M.warned = false
	SUI.On("SKILL_LINES_CHANGED", M.OnSkills)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnSkills)
	if not M.watching then
		M.watching = true
		C.Watch("places.", M.OnKey)
		C.Watch("questtrack.", M.OnQKey)
	end
	M.Sync()
	M.FilterButtons()
end

function M.Disable()
	M.on = false
	SUI.Off("SKILL_LINES_CHANGED", M.OnSkills)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnSkills)
	M.Sync()
	M.FilterButtons()
	M.me, M.zsig, M.zrec, M.zcur, M.focus, M.focusRec = nil, nil, nil, nil, nil, nil
end

function M.Command(rest)
	local _, _, a, b = sfind(rest or "", "^%s*(%S*)%s*(%S*)")
	a = slower(a or "")
	if a == "near" or a == "proche" then
		M.Nearest(b)
		return
	end
	if a == "filters" or a == "filtres" then
		local wm = glob("WorldMapFrame")
		M.FilterToggle(wm and wm:IsShown() and "map" or "mini")
		return
	end
	if a == "off" or a == "clear" then
		M.focus, M.focusRec = nil, nil
		M.Refresh()
		return
	end
	SUI.Print(L("msg.places.status", C.Get("places.show") and "1" or "0"))
end

local function opt(key, typ, order, def, extra)
	local o = { key = "places." .. key, type = typ, cat = "places", label = "opt.places." .. key, tip = "tip.places." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local OPTS = {
	opt("show", "bool", 10, true, { simple = true }),
	opt("mini", "bool", 12, true, { simple = true }),
	opt("faction", "bool", 14, true),
	opt("mine", "bool", 16, true, { simple = true }),
	opt("mounts", "bool", 18, false),
	opt("minibutton", "bool", 19, true),
	opt("angle", "number", 19.5, 305, { min = 0, max = 355, step = 5 }),
}
for i = 1, getn(M.KINDS) do
	local k = M.KINDS[i]
	tinsert(OPTS, opt(k[1], "bool", 30 + i, k[4], { simple = (k[4] and true or false) }))
	tinsert(OPTS, opt("m." .. k[1], "bool", 60 + i, k[4]))
end

SUI.RegisterCategory("places", 81)

SUI.RegisterModule("places", {
	default = true,
	cost = "light",
	options = OPTS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("places", function(rest) M.Command(rest or "") end, "help.places")
