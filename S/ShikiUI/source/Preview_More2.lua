-- ShikiUI Preview_More2 : apercus 2D supplementaires (voir Preview_Basic.lua pour le moteur P.Register).
-- Modules couverts (positions impaires de la liste alphabetique des modules sans apercu) : auction, buffwatch, charstats, clickheal, cursor,
-- esport, groupfx, loot, mail, messages, powerauras, social, tracker, windows. Chaque maquette est dessinee avec des textures / textes
-- PREALLOUES a la construction (pools par couche), puis repositionnes dans update : aucune creation de cadre hors build, rien en combat.
-- Les zones cliquables menent a la cle de reglage du module ; les textes sont dans Locale_Preview.lua (cles "mod.preview.m2.<module>.*").
-- Les faux contenus (noms, prix, valeurs) sont des DONNEES D'EXEMPLE fixes. NON VERIFIE EN JEU : voir les NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config
local P = SUI.Preview

local getn = table.getn
local floor, mmin, mmax = math.floor, math.min, math.max
local sformat, supper, ssub = string.format, string.upper, string.sub

-- ---------------------------------------------------------------- lecture des reglages
local function num(key, d)
	local v = C.Get(key)
	if type(v) ~= "number" then return d end
	return v
end

local function flag(key, d)
	local v = C.Get(key)
	if v == nil then return d end
	return v and true or false
end

local function chv(key, d)
	local v = C.Get(key)
	if type(v) ~= "string" then return d end
	return v
end

local function md(a, m) return a - floor(a / m) * m end

local function S(id, nm) return L("mod.preview.m2." .. id .. "." .. nm) end

-- Couleurs de DONNEES DE JEU (qualite d'objet) et de classe : pas des jetons de style.
local QUAL = {
	{ 0.62, 0.62, 0.62, 1 }, { 1, 1, 1, 1 }, { 0.12, 1, 0, 1 }, { 0, 0.44, 0.87, 1 }, { 0.64, 0.21, 0.93, 1 }, { 1, 0.5, 0, 1 },   -- style:ok qualites du jeu
}

local CLS = {}
local function cls(class)
	local c = CLS[class]
	if not c then
		local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if col then c = { col.r, col.g, col.b, 1 } else c = T.c.dim end
		CLS[class] = c
	end
	return c
end

local function tcol(fs, tok, a)
	fs:SetTextColor(tok[1], tok[2], tok[3], a or tok[4] or 1)
end

-- ---------------------------------------------------------------- moteur de dessin a pools
-- Couches : 1 = fonds, 2 = contenu, 3 = details. Dans une couche on dessine dans l'ordre d'appel (ordre de creation = ordre d'empilement).
local POOL = { 44, 70, 28 }
local NFS = 40
local LAYNAME = { "BACKGROUND", "ARTWORK", "OVERLAY" }

local function newState(root, spec)
	local st = { root = root, t = { {}, {}, {} }, n = { 0, 0, 0 }, np = {}, f = {}, nf = 0, nfs = spec.nfs or NFS, z = {}, over = 0,
		acc = { 0, 0, 0, 1 } }
	local pool = spec.pool or POOL
	for l = 1, 3 do
		st.np[l] = pool[l]
		for i = 1, pool[l] do
			local tx = P.NewTex(root, LAYNAME[l])
			tx:Hide()
			st.t[l][i] = tx
		end
	end
	for i = 1, st.nfs do
		local fs = T.Text(root, 10, T.c.text, "LEFT", true)
		fs:Hide()
		st.f[i] = fs
	end
	for i = 1, getn(spec.ids) do st.z[spec.ids[i]] = P.Zone(root, spec.ids[i]) end
	st.hint = T.Text(root, 10, T.c.dim, "LEFT", true)
	return st
end

local function reset(st)
	for l = 1, 3 do
		local tl = st.t[l]
		for i = 1, st.n[l] do tl[i]:Hide() end
		st.n[l] = 0
	end
	for i = 1, st.nf do st.f[i]:Hide() end
	st.nf = 0
	for _, z in pairs(st.z) do z:Hide() end
	st.over = 0
end

-- Rectangle plein (x, y depuis le coin haut gauche du volet).
local function rc(st, lay, tok, x, y, w, h, a)
	local n = st.n[lay] + 1
	if n > st.np[lay] then
		st.over = st.over + 1
		return
	end
	st.n[lay] = n
	local tx = st.t[lay][n]
	P.Fill(tx, tok, a)
	P.Box(tx, st.root, x, y, w, h)
end

-- Cadre : bordure 1 px + fond (couche 1).
local function bx(st, x, y, w, h, fill, edge, fa)
	rc(st, 1, edge, x, y, w, h)
	rc(st, 1, fill, x + 1, y + 1, w - 2, h - 2, fa)
end

local function tx(st, str, x, y, size, tok, just, wd)
	local n = st.nf + 1
	if n > st.nfs then
		st.over = st.over + 1
		return
	end
	st.nf = n
	local fs = st.f[n]
	P.Font(fs, size)
	fs:SetText(str)
	fs:SetJustifyH(just or "LEFT")
	tcol(fs, tok or T.c.text)
	fs:SetWidth(wd or 200)
	fs:SetHeight(size + 3)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", st.root, "TOPLEFT", x, -y)
	fs:Show()
end

local function zn(st, id, x, y, w, h)
	local z = st.z[id]
	if z then P.PlaceZone(z, st.root, x, y, w, h) end
end

-- Pastille : cadre + texte centre (on = bordure d'accent) + zone.
local function chip(st, id, x, y, w, h, str, on)
	bx(st, x, y, w, h, T.c.inset, on and st.acc or T.c.border)
	tx(st, str, x, y + floor((h - 9) / 2), 9, on and T.c.text or T.c.dim, "CENTER", w)
	if id then zn(st, id, x, y, w, h) end
end

-- Case a cocher + libelle (zone sur l'ensemble).
local function ckb(st, id, x, y, on, str, wd)
	bx(st, x, y, 10, 10, T.c.inset, T.c.border)
	if on then rc(st, 2, st.acc, x + 2, y + 2, 6, 6) end
	tx(st, str, x + 14, y - 1, 9, on and T.c.text or T.c.dim, "LEFT", wd)
	if id then zn(st, id, x, y - 1, wd + 14, 12) end
end

local function swatch(st, tok, x, y, w, h, a)
	rc(st, 2, tok, x, y, w, h, a)
end

-- ---------------------------------------------------------------- enregistrement
local function register(id, spec)
	local def = {
		watch = spec.watch or { id .. "." },
		build = function(parent, w, h)
			local root = CreateFrame("Frame", nil, parent)
			root.st = newState(root, spec)
			return root
		end,
		update = function(root, w, h, key, value)
			local st = root.st
			reset(st)
			local r, g, b = T.Accent()
			st.acc[1], st.acc[2], st.acc[3] = r, g, b
			local ch = h - 44
			if ch < 60 then ch = 60 end
			spec.draw(st, w, ch)
			local hi = st.hint
			hi:ClearAllPoints()
			hi:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(ch + 6))
			hi:SetWidth(w - 8)
			hi:SetHeight(36)
			P.Font(hi, 10)
			hi:SetText(S(id, "hint"))
			hi:Show()
		end,
		click = function(zone)
			if spec.click then return spec.click(zone) end
			return spec.keys[zone]
		end,
	}
	if spec.label then def.label = spec.label end
	P.Register(id, def)
end

-- ================================================================ auction
local AUCT = { "search", "sell", "sales", "analysis" }
local AUCI = {
	{ 4, "48g 20s", 32, "Dorgan" }, { 3, "12g 5s", 18, "Mira" }, { 2, "3g 80s", 4, "Kaeli" }, { 5, "210g", 9, "Brann" },
	{ 1, "55s", 22, "Tolu" }, { 3, "7g 40s", 41, "Zara" }, { 2, "1g 90s", 12, "Odo" },
}

local function drawAuction(st, w, ch)
	local A = st.acc
	local panel = flag("auction.panel", true)
	local rows, minq = num("auction.rows", 10), floor(num("auction.quality", 0))
	local dens, start = chv("auction.density", "comfort"), chv("auction.starttab", "search")
	local dealpct, dstyle = num("auction.dealpct", 15), chv("auction.dealstyle", "both")
	local icons, ctot, csel = flag("auction.icons", true), flag("auction.showtotal", true), flag("auction.showseller", true)
	bx(st, 0, 0, w, ch, T.c.bg, panel and A or T.c.border)
	local tw = floor((w - 76) / 4)
	for i = 1, 4 do
		local on = (start == AUCT[i]) or (start == "last" and i == 1)
		chip(st, "tab" .. i, 4 + (i - 1) * tw, 4, tw - 2, 16, S("auction", "tab" .. i), on)
	end
	chip(st, "panelz", w - 68, 4, 64, 16, S("auction", panel and "panelon" or "paneloff"), panel)
	bx(st, 4, 24, 62, 14, T.c.inset, QUAL[minq + 1] or QUAL[1])
	tx(st, sformat(S("auction", "qual"), minq), 4, 26, 9, T.c.text, "CENTER", 62)
	zn(st, "qual", 4, 24, 62, 14)
	chip(st, "dens", 70, 24, 70, 14, S("auction", dens == "compact" and "compact" or "comfort"), false)
	chip(st, "uiz", 144, 24, 70, 14, S("auction", chv("auction.ui", "shikiui") == "blizzard" and "uib" or "uis"), false)
	local rh = 18
	if dens == "compact" then rh = 13 end
	local hy = 42
	local nx = 6
	if icons then nx = 6 + rh end
	local tcx = w - 8 - 54
	local scx = tcx
	if csel then tcx = tcx - 54 end
	tx(st, S("auction", "hname"), nx, hy, 9, T.c.dim, "LEFT", 90)
	if ctot then tx(st, S("auction", "htotal"), tcx, hy, 9, T.c.dim, "RIGHT", 52) end
	if csel then tx(st, S("auction", "hsell"), scx, hy, 9, T.c.dim, "RIGHT", 52) end
	rc(st, 2, T.c.border, 4, hy + 12, w - 8, 1)
	zn(st, "icz", 4, hy - 1, rh, 14)
	zn(st, "colt", tcx - 2, hy - 1, 56, 14)
	zn(st, "cols", scx - 2, hy - 1, 56, 14)
	local ry = hy + 15
	local fit = floor((ch - ry - 14) / rh)
	local nr = mmin(rows, fit)
	local drawn, j, dealRow = 0, 0, nil
	while drawn < nr and j < 60 do
		j = j + 1
		local it = AUCI[md(j - 1, 7) + 1]
		if it[1] >= minq then
			local y = ry + drawn * rh
			local deal = it[3] >= dealpct
			if md(drawn, 2) == 1 then rc(st, 2, T.c.inset, 4, y, w - 8, rh, 0.7) end
			if deal and (dstyle == "row" or dstyle == "both") then rc(st, 2, T.c.good, 4, y, w - 8, rh, 0.22) end
			local q = QUAL[it[1] + 1] or QUAL[1]
			if icons then
				rc(st, 2, q, 6, y + 2, rh - 4, rh - 4, 1)
				rc(st, 3, T.c.panel, 7, y + 3, rh - 6, rh - 6, 1)
			end
			tx(st, S("auction", "i" .. (md(j - 1, 7) + 1)), nx, y + floor((rh - 9) / 2), 9, q, "LEFT", tcx - nx - 38)
			if ctot then tx(st, it[2], tcx, y + floor((rh - 9) / 2), 9, T.c.text, "RIGHT", 52) end
			if csel then tx(st, it[4], scx, y + floor((rh - 9) / 2), 9, T.c.dim, "RIGHT", 52) end
			if deal and (dstyle == "text" or dstyle == "both") then
				tx(st, "-" .. it[3] .. "%", tcx - 38, y + floor((rh - 9) / 2), 9, T.c.good, "RIGHT", 34)
				if not dealRow then
					zn(st, "pctz", tcx - 38, y, 34, rh)
				end
			end
			if deal and not dealRow then
				dealRow = y
				zn(st, "dealz", 4, y, tcx - 42, rh)
			end
			drawn = drawn + 1
		end
	end
	zn(st, "rowsz", 4, ry, w - 8, mmax(drawn, 1) * rh)
	tx(st, sformat(S("auction", "rowsinfo"), rows), 6, ch - 14, 9, T.c.dim, "LEFT", w - 12)
end

register("auction", {
	ids = { "rowsz", "dealz", "pctz", "icz", "colt", "cols", "tab1", "tab2", "tab3", "tab4", "panelz", "qual", "dens", "uiz" },
	keys = { rowsz = "auction.rows", dealz = "auction.dealstyle", pctz = "auction.dealpct", icz = "auction.icons", colt = "auction.showtotal",
		cols = "auction.showseller", tab1 = "auction.starttab", tab2 = "auction.starttab", tab3 = "auction.starttab", tab4 = "auction.starttab",
		panelz = "auction.panel", qual = "auction.quality", dens = "auction.density", uiz = "auction.ui" },
	draw = drawAuction, pool = { 56, 120, 40 }, nfs = 80,
})

-- ================================================================ buffwatch
local BWK = {}
local BWC = { T.c.good, T.c.warn, T.c.bad }

local function drawBuffWatch(st, w, ch)
	local A = st.acc
	local on = flag("buffwatch.on", true)
	local size, timers = num("buffwatch.size", 26), flag("buffwatch.timers", true)
	local scan = num("buffwatch.scan", 0.5)
	local m = SUI.BuffWatch
	local list = (m and m.LIST) or {}
	chip(st, "onz", 4, 4, 90, 16, S("buffwatch", on and "on" or "off"), on)
	chip(st, "scanz", 98, 4, 80, 16, sformat(S("buffwatch", "scan"), scan), false)
	for i = 1, 12 do BWK[i] = nil end
	local k = 0
	for i = 1, getn(list) do
		if not C.Get("buffwatch.off." .. list[i].key) and k < 12 then
			k = k + 1
			BWK[k] = list[i].key
		end
	end
	bx(st, 0, 28, w, mmin(ch - 30, 120), T.c.bg, on and A or T.c.border)
	if k == 0 then
		tx(st, S("buffwatch", "none"), 8, 44, 10, T.c.dim, "LEFT", w - 16)
		return
	end
	local per = size + 6
	local s = 1
	if k * per > w - 12 then s = (w - 12) / (k * per) end
	local cs = floor(size * s + 0.5)
	local gap = floor(6 * s + 0.5)
	local y = 40
	local x0 = floor((w - (k * cs + (k - 1) * gap)) / 2)
	local ta = 1
	if not on then ta = 0.35 end
	for i = 1, k do
		local x = x0 + (i - 1) * (cs + gap)
		local present = md(i, 3) ~= 0
		if present then
			rc(st, 2, BWC[md(i, 3)], x, y, cs, cs, 0.9 * ta)
			rc(st, 3, T.c.bg, x + 2, y + cs - floor(cs * 0.42) - 2, cs - 4, floor(cs * 0.42), 0.35 * ta)
		else
			rc(st, 2, T.c.dim, x, y, cs, cs, 0.22 * ta)
		end
		tx(st, supper(ssub(BWK[i], 1, 2)), x, y + floor((cs - 10) / 2), 10, present and T.c.text or T.c.dim, "CENTER", cs)
		if timers and present then
			tx(st, md(i, 5) .. ":" .. (10 + md(i * 7, 49)), x - 6, y + cs + 2, 8, T.c.text, "CENTER", cs + 12)
			if i == 1 then zn(st, "tmz", x - 4, y + cs + 1, cs + 8, 11) end
		end
		zn(st, "b" .. i, x, y, cs, cs)
	end
	local wd = k * cs + (k - 1) * gap
	rc(st, 3, A, x0, y + cs + 16, wd, 2)
	zn(st, "sizez", x0, y + cs + 14, wd, 6)
	tx(st, size .. " px", x0, y + cs + 22, 9, T.c.dim, "LEFT", 80)
end

register("buffwatch", {
	ids = { "onz", "scanz", "sizez", "tmz", "b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", "b9", "b10", "b11", "b12" },
	keys = { onz = "buffwatch.on", scanz = "buffwatch.scan", sizez = "buffwatch.size", tmz = "buffwatch.timers" },
	click = function(zone)
		local i = tonumber(ssub(zone, 2))
		if ssub(zone, 1, 1) == "b" and i and BWK[i] then return "buffwatch.off." .. BWK[i] end
		if zone == "onz" then return "buffwatch.on" end
		if zone == "scanz" then return "buffwatch.scan" end
		if zone == "sizez" then return "buffwatch.size" end
		if zone == "tmz" then return "buffwatch.timers" end
		return nil
	end,
	label = function(zone)
		local i = tonumber(ssub(zone, 2))
		if ssub(zone, 1, 1) == "b" and i and BWK[i] then return "opt.buffwatch.off." .. BWK[i] end
		return nil
	end,
	draw = drawBuffWatch,
})

-- ================================================================ charstats
local CSR = { { "r1", "312" }, { "r2", "148" }, { "r3", "401" }, { "r4", "96" }, { "r5", "120" }, { "r6", "2840" }, { "r7", 5.4231 }, { "r8", 7.8187 } }

local function drawChar(st, w, ch)
	local A = st.acc
	local show, side = flag("charstats.show", true), chv("charstats.side", "right")
	local width, dec = num("charstats.width", 290), floor(num("charstats.dec", 2))
	local ww = floor(w * 0.34)
	local pw = floor((w - ww - 14) * width / 360)
	local total = ww + pw + 2
	local x0 = floor((w - total) / 2)
	local wx, px = x0, x0 + ww + 2
	if side == "left" then
		px = x0
		wx = x0 + pw + 2
	end
	local ph = ch - 30
	bx(st, wx, 2, ww, ph, T.c.panel, T.c.border)
	tx(st, S("charstats", "win"), wx, 6, 9, T.c.dim, "CENTER", ww)
	rc(st, 2, T.c.dim, wx + floor(ww / 2) - 6, 24, 12, 12, 0.5)
	rc(st, 2, T.c.dim, wx + floor(ww / 2) - 10, 38, 20, 34, 0.4)
	zn(st, "sidez", wx, 2, ww, ph)
	if show then
		bx(st, px, 2, pw, ph, T.c.bg, A)
		tx(st, S("charstats", "sect"), px + 4, 5, 9, A, "LEFT", pw - 8)
		local rh = mmin(15, floor((ph - 20) / 8))
		for i = 1, 8 do
			local r = CSR[i]
			local y = 19 + (i - 1) * rh
			if md(i, 2) == 0 then rc(st, 2, T.c.inset, px + 2, y, pw - 4, rh, 0.6) end
			tx(st, S("charstats", r[1]), px + 4, y + floor((rh - 9) / 2), 9, T.c.dim, "LEFT", pw - 50)
			local v = r[2]
			if type(v) == "number" then v = sformat("%." .. dec .. "f", v) .. "%" end
			tx(st, v, px + pw - 50, y + floor((rh - 9) / 2), 9, T.c.text, "RIGHT", 46)
			if i == 7 then zn(st, "decz", px + 2, y, pw - 4, rh * 2) end
		end
		local ex = px + pw - 3
		if side == "left" then ex = px end
		rc(st, 3, A, ex, 2, 3, ph)
		zn(st, "widthz", ex - 3, 2, 9, ph)
	else
		bx(st, px, 2, pw, ph, T.c.bg, T.c.border, 0.4)
		tx(st, S("charstats", "hidden"), px, 2 + floor(ph / 2) - 5, 10, T.c.dim, "CENTER", pw)
	end
	zn(st, "panelz", px, 2, pw, 14)
	local y = ch - 22
	chip(st, "combatz", 4, y, 92, 16, S("charstats", flag("charstats.combat", true) and "live" or "frozen"), flag("charstats.combat", true))
	chip(st, "visz", 100, y, 92, 16, sformat(S("charstats", "vis"), chv("charstats.vis", "always")), false)
	chip(st, "fadez", 196, y, 84, 16, sformat(S("charstats", "fade"), num("charstats.fade", 0.15)), false)
end

register("charstats", {
	ids = { "sidez", "panelz", "decz", "widthz", "combatz", "visz", "fadez" },
	keys = { sidez = "charstats.side", panelz = "charstats.show", decz = "charstats.dec", widthz = "charstats.width",
		combatz = "charstats.combat", visz = "charstats.vis", fadez = "charstats.fade" },
	draw = drawChar,
})

-- ================================================================ clickheal
local CHB = { "left", "right", "middle", "up", "down" }
local CHM = { "none", "shift", "ctrl", "alt" }
local CHK = {}
for r = 1, 4 do
	for c = 1, 5 do CHK["c" .. r .. c] = "clickheal." .. CHM[r] .. "." .. CHB[c] end
end

local function chShort(v)
	if type(v) ~= "string" then return "?" end
	if v == "auto" then return "auto" end
	if v == "default" then return "def." end
	if v == "none" then return "-" end
	return ssub(v, 1, 7)
end

local function drawClickHeal(st, w, ch)
	local A = st.acc
	local fw = floor((w - 12) / 4)
	local selfOn, tgtOn = flag("clickheal.self", true), flag("clickheal.target", true)
	-- cadres Moi / Cible
	local names = { "me", "tg" }
	local ons = { selfOn, tgtOn }
	for i = 1, 2 do
		local x = 4 + (i - 1) * (fw + 4)
		bx(st, x, 2, fw, 24, T.c.bg, ons[i] and A or T.c.border)
		rc(st, 2, T.c.good, x + 2, 12, floor((fw - 4) * (i == 1 and 0.8 or 0.55)), 8, ons[i] and 0.9 or 0.25)
		tx(st, S("clickheal", names[i]), x + 3, 3, 9, ons[i] and T.c.text or T.c.dim, "LEFT", fw - 6)
		zn(st, i == 1 and "selfz" or "tgtz", x, 2, fw, 24)
	end
	-- info-bulle d'aide
	local hx = 4 + 2 * (fw + 4)
	local hw = w - hx - 4
	local hints = flag("clickheal.hints", true)
	bx(st, hx, 2, hw, 24, T.c.panel, hints and A or T.c.border, hints and 1 or 0.4)
	if hints then
		tx(st, S("clickheal", "tip1"), hx + 3, 3, 8, T.c.text, "LEFT", hw - 6)
		if flag("clickheal.hintcost", true) then
			tx(st, S("clickheal", "tip2"), hx + 3, 13, 8, T.c.dim, "LEFT", hw - 6)
			zn(st, "costz", hx, 14, hw, 12)
		end
	else
		tx(st, S("clickheal", "nohint"), hx, 8, 8, T.c.dim, "CENTER", hw)
	end
	zn(st, "hintz", hx, 2, hw, 12)
	-- reglages de lancement
	local cw = floor((w - 8 - 12) / 4)
	chip(st, "methz", 4, 30, cw, 14, sformat(S("clickheal", "method"), chv("clickheal.method", "auto")), false)
	chip(st, "clickonz", 4 + (cw + 4), 30, cw, 14, sformat(S("clickheal", "clickon"), chv("clickheal.clickon", "up")), false)
	chip(st, "resz", 4 + 2 * (cw + 4), 30, cw, 14, S("clickheal", "autores"), flag("clickheal.autores", true))
	chip(st, "retz", 4 + 3 * (cw + 4), 30, cw, 14, S("clickheal", "retarget"), flag("clickheal.retarget", true))
	-- grille modificateur x bouton
	local gx = 4 + 30
	local cell = floor((w - gx - 4) / 5)
	local gy = 50
	for c = 1, 5 do tx(st, S("clickheal", "col" .. c), gx + (c - 1) * cell, gy, 8, T.c.dim, "CENTER", cell) end
	local rh = mmin(16, floor((ch - gy - 12 - 38) / 4))
	for r = 1, 4 do
		local y = gy + 11 + (r - 1) * rh
		tx(st, S("clickheal", "mod" .. r), 4, y + 3, 8, T.c.dim, "LEFT", 28)
		for c = 1, 5 do
			local v = C.Get(CHK["c" .. r .. c])
			local x = gx + (c - 1) * cell
			bx(st, x + 1, y, cell - 2, rh - 2, T.c.inset, (v == "auto" or v == "none") and T.c.border or A)
			tx(st, chShort(v), x + 1, y + floor((rh - 2 - 8) / 2), 8, (v == "auto" or v == "none") and T.c.dim or T.c.text, "CENTER", cell - 2)
			zn(st, "c" .. r .. c, x + 1, y, cell - 2, rh - 2)
		end
	end
	-- bouton dans le grimoire
	local by = gy + 11 + 4 * rh + 4
	local btn, pos, bstyle = flag("clickheal.btn", true), chv("clickheal.btnpos", "top"), chv("clickheal.btnstyle", "label")
	local bh = 34
	bx(st, 4, by, w - 8, bh, T.c.bg, T.c.border)
	for i = 1, 3 do
		local mark = flag("clickheal.mark", true) and i ~= 2
		rc(st, 2, mark and A or T.c.dim, 10, by + 5 + (i - 1) * 9, mark and 70 or 54, 4, mark and 0.8 or 0.35)
	end
	zn(st, "markz", 8, by + 3, 76, 29)
	if btn then
		local bw = 78
		local bxx, byy = 90, by + 3
		if pos == "bottom" then
			byy = by + bh - 15
		elseif pos == "side" then
			bxx = w - 12 - bw
			byy = by + 10
		end
		bx(st, bxx, byy, bw, 12, T.c.inset, A)
		tx(st, S("clickheal", "b" .. bstyle), bxx, byy + 1, 8, T.c.text, "CENTER", bw)
		zn(st, "btnz", bxx, byy, bw, 12)
		zn(st, "stylez", bxx + 14, byy, bw - 28, 12)
	else
		tx(st, S("clickheal", "nobtn"), 90, by + 12, 9, T.c.dim, "LEFT", w - 100)
		zn(st, "btnz", 90, by + 4, w - 100, 26)
	end
	chip(st, "posz", w - 4 - 56, by + 2, 52, 12, pos, false)
end

do
	local ids = { "selfz", "tgtz", "hintz", "costz", "methz", "clickonz", "resz", "retz", "markz", "btnz", "stylez", "posz" }
	local keys = { selfz = "clickheal.self", tgtz = "clickheal.target", hintz = "clickheal.hints", costz = "clickheal.hintcost",
		methz = "clickheal.method", clickonz = "clickheal.clickon", resz = "clickheal.autores", retz = "clickheal.retarget",
		markz = "clickheal.mark", btnz = "clickheal.btn", stylez = "clickheal.btnstyle", posz = "clickheal.btnpos" }
	for r = 1, 4 do
		for c = 1, 5 do
			table.insert(ids, "c" .. r .. c)
			keys["c" .. r .. c] = CHK["c" .. r .. c]
		end
	end
	register("clickheal", { ids = ids, keys = keys, draw = drawClickHeal, nfs = 64, pool = { 112, 50, 28 } })
end

-- ================================================================ cursor
local RING = {}
for i = 0, 23 do RING[i + 1] = { math.cos(i * math.pi / 12), math.sin(i * math.pi / 12) } end

local function dot(st, tok, x, y, a)
	rc(st, 2, tok, x - 1, y - 1, 2, 2, a)
end

local function ringDots(st, tok, cx, cy, r, step, a)
	local i = 1
	while i <= 24 do
		dot(st, tok, cx + r * RING[i][1], cy + r * RING[i][2], a)
		i = i + step
	end
end

local function shape(st, kind, tok, cx, cy, r, a)
	if kind == "ring" then
		ringDots(st, tok, cx, cy, r, 1, a)
	elseif kind == "ringdot" then
		ringDots(st, tok, cx, cy, r, 1, a)
		rc(st, 2, tok, cx - 2, cy - 2, 4, 4, a)
	elseif kind == "star" then
		local i = 1
		while i <= 24 do
			for k = 1, 3 do dot(st, tok, cx + r * k / 3 * RING[i][1], cy + r * k / 3 * RING[i][2], a) end
			i = i + 3
		end
		rc(st, 2, tok, cx - 2, cy - 2, 4, 4, a)
	elseif kind == "cross" then
		local g, l = floor(r * 0.25), floor(r * 0.7)
		rc(st, 2, tok, cx - g - l, cy - 1, l, 2, a)
		rc(st, 2, tok, cx + g, cy - 1, l, 2, a)
		rc(st, 2, tok, cx - 1, cy - g - l, 2, l, a)
		rc(st, 2, tok, cx - 1, cy + g, 2, l, a)
	elseif kind == "chevrons" then
		local l = floor(r * 0.5)
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				rc(st, 2, tok, sx > 0 and (cx + r - l) or (cx - r), sy > 0 and (cy + r - 2) or (cy - r), l, 2, a)
				rc(st, 2, tok, sx > 0 and (cx + r - 2) or (cx - r), sy > 0 and (cy + r - l) or (cy - r), 2, l, a)
			end
		end
	else
		ringDots(st, tok, cx, cy, r, 1, a)
		ringDots(st, tok, cx, cy, r * 0.5, 2, a)
		rc(st, 2, tok, cx - 1, cy - 1, 2, 2, a)
	end
end

local function cursorColor(st, name)
	if name == "accent" then return st.acc end
	if name == "class" then
		local _, class = UnitClass("player")
		if class then return cls(class) end
		return st.acc
	end
	return T.c[name] or T.c.text
end

local function cursorPanel(st, x, y, pw, ph, p, isChar)
	local on = flag("cursor." .. p, true)
	local kind, size = chv("cursor." .. p .. "style", "ring"), num("cursor." .. p .. "size", 56)
	local col, al = chv("cursor." .. p .. "color", "accent"), num("cursor." .. p .. "alpha", 80)
	local combat = flag("cursor." .. p .. "combat", false)
	local ids = isChar and "c" or "m"
	chip(st, ids .. "on", x, y, pw, 14, S("cursor", isChar and "char" or "mouse") .. " : " .. S("cursor", on and "on" or "off"), on)
	local by = y + 18
	bx(st, x, by, pw, ph, T.c.inset, T.c.border)
	local cx, cy = x + floor(pw / 2), by + floor(ph / 2)
	local r = mmin(size / 2 * 0.9, pw / 2 - 6, ph / 2 - 6)
	local a = (al / 100)
	if not on then a = a * 0.2 end
	shape(st, kind, cursorColor(st, col), cx, cy, r, a)
	if isChar then
		local _, class = UnitClass("player")
		rc(st, 3, cls(class or "PALADIN"), cx - 4, cy - 4, 8, 12, 1)
		rc(st, 3, T.c.text, cx - 3, cy - 11, 6, 6, 1)
	else
		rc(st, 3, T.c.text, cx - 1, cy - 1, 2, 10, 1)
		rc(st, 3, T.c.text, cx - 1, cy - 1, 7, 2, 1)
	end
	zn(st, ids .. "sh", x, by, pw, ph)
	local yy = by + ph + 4
	local q = floor((pw - 6) / 4)
	swatch(st, cursorColor(st, col), x + 2, yy + 1, 10, 10)
	zn(st, ids .. "col", x, yy, q, 12)
	tx(st, size .. "px", x + q, yy + 1, 9, T.c.text, "CENTER", q)
	zn(st, ids .. "sz", x + q, yy, q, 12)
	tx(st, al .. "%", x + 2 * q, yy + 1, 9, T.c.text, "CENTER", q)
	zn(st, ids .. "al", x + 2 * q, yy, q, 12)
	chip(st, ids .. "cb", x + 3 * q, yy - 1, q + 6, 14, S("cursor", "combat"), combat)
end

local function drawCursor(st, w, ch)
	local pw = floor((w - 12) / 2)
	local ph = mmin(ch - 18 - 24, 130)
	cursorPanel(st, 4, 2, pw, ph, "mouse", false)
	cursorPanel(st, 8 + pw, 2, pw, ph, "char", true)
end

do
	local ids, keys = {}, {}
	local sfx = { on = "", sh = "style", col = "color", sz = "size", al = "alpha", cb = "combat" }
	local pre = { m = "mouse", c = "char" }
	for id, p in pairs(pre) do
		for sf, opt in pairs(sfx) do
			table.insert(ids, id .. sf)
			if sf == "on" then keys[id .. sf] = "cursor." .. p else keys[id .. sf] = "cursor." .. p .. opt end
		end
	end
	register("cursor", { ids = ids, keys = keys, draw = drawCursor, pool = { 20, 110, 28 } })
end

-- ================================================================ esport
local ESE = {
	{ "Thorgrim", "WARRIOR", 0.85, 8 }, { "Elaria", "PRIEST", 0.2, 5 }, { "Kaelith", "MAGE", 0.55, 0 }, { "Brannor", "ROGUE", 0.35, 0 },
}
local ESDR = { { 2, 1, 2 }, { 4, 3, 1 } }       -- ennemi, categorie (etourdissement / peur / racine), compte

local function drawEsport(st, w, ch)
	local A = st.acc
	local low, win = flag("esport.lowfirst", true), num("esport.drwindow", 15)
	chip(st, "sortz", 4, 2, 130, 14, S("esport", low and "sortlow" or "sortseen"), low)
	tx(st, sformat(S("esport", "win"), win), w - 124, 4, 9, T.c.dim, "RIGHT", 120)
	zn(st, "drwz", w - 124, 2, 120, 14)
	local order = { 1, 2, 3, 4 }
	if low then
		for i = 1, 3 do
			for j = i + 1, 4 do
				if ESE[order[j]][3] < ESE[order[i]][3] then order[i], order[j] = order[j], order[i] end
			end
		end
	end
	local rh = mmin(34, floor((ch - 26) / 4))
	local ew = floor((w - 8) * 0.55)
	for i = 1, 4 do
		local e = ESE[order[i]]
		local y = 20 + (i - 1) * rh
		bx(st, 4, y, ew, rh - 3, T.c.bg, T.c.border)
		local c = cls(e[2])
		rc(st, 2, c, 6, y + rh - 3 - 9, floor((ew - 4) * e[3]), 6, 0.9)
		tx(st, e[1], 8, y + 2, 10, c, "LEFT", ew - 30)
		if e[4] > 0 then rc(st, 3, e[4] == 8 and T.c.warn or T.c.bad, 4 + ew - 14, y + 3, 9, 9, 1) end
		-- diminishing returns de cet ennemi
		for k = 1, 2 do
			local d = ESDR[k]
			if d[1] == order[i] then
				local dx = 4 + ew + 6
				bx(st, dx, y + 2, rh - 7, rh - 7, T.c.inset, d[3] >= 2 and T.c.warn or T.c.good)
				tx(st, S("esport", "dr" .. d[2]), dx + rh - 4, y + 2, 9, T.c.text, "LEFT", 60)
				tx(st, d[3] == 1 and "50%" or "25%", dx + rh - 4, y + 12, 9, d[3] == 1 and T.c.good or T.c.warn, "LEFT", 40)
				tx(st, win .. "s", dx + rh + 28, y + 12, 8, T.c.dim, "LEFT", 30)
				zn(st, "drz" .. k, dx, y, w - dx - 4, rh - 3)
			end
		end
	end
	zn(st, "listz", 4, 20, ew, rh * 4 - 3)
end

register("esport", {
	ids = { "listz", "drz1", "drz2", "sortz", "drwz" },
	keys = { listz = "esport.lowfirst", sortz = "esport.lowfirst", drz1 = "esport.drwindow", drz2 = "esport.drwindow", drwz = "esport.drwindow" },
	draw = drawEsport,
})

-- ================================================================ groupfx
local GFN = { { "Shikiwa", "WARRIOR" }, { "Elaria", "PRIEST" }, { "Kaelith", "MAGE" }, { "Brannor", "ROGUE" }, { "Thorgrim", "HUNTER" } }
local GFC = { T.c.warn, T.c.bad, T.c.good, T.c.text }

local function drawGroupFx(st, w, ch)
	local A = st.acc
	local fxon, ficon, ftint = flag("groupfx.fx.on", true), flag("groupfx.fx.icon", true), flag("groupfx.fx.tint", true)
	local ftimer, fmax = flag("groupfx.fx.timer", true), floor(num("groupfx.fx.max", 2))
	local amode = chv("groupfx.aggromode", "target")
	local afr, aic, atk = flag("groupfx.aggro.frame", true), flag("groupfx.aggro.icon", true), flag("groupfx.aggro.tank", false)
	local alert = { false, flag("groupfx.aggro.heal", true), flag("groupfx.aggro.caster", true), flag("groupfx.aggro.dps", true), false }
	local gap = 4
	local fw = floor((w - 8 - 4 * gap) / 5)
	local fh = mmin(66, ch - 70)
	for i = 1, 5 do
		local x = 4 + (i - 1) * (fw + gap)
		local y = 4
		local c = cls(GFN[i][2])
		local aggro = amode ~= "off" and alert[i] and i > 1 and i < 5
		bx(st, x, y, fw, fh, T.c.bg, T.c.border)
		rc(st, 2, c, x + 2, y + 14, fw - 4, floor(fh * 0.28), 0.85)
		tx(st, GFN[i][1], x + 2, y + 2, 9, c, "LEFT", fw - 4)
		tx(st, S("groupfx", "role" .. i), x + 2, y + fh - 12, 8, T.c.dim, "LEFT", fw - 4)
		if i == 2 and fxon then
			if ftint then rc(st, 3, T.c.warn, x + 1, y + 1, fw - 2, fh - 2, 0.3) end
			if ficon then
				for k = 1, mmin(fmax, 4) do
					rc(st, 3, GFC[k], x + fw - 3 - k * 11, y + 15, 10, 10, 1)
				end
				zn(st, "icz", x + fw - 3 - mmin(fmax, 4) * 11, y + 15, mmin(fmax, 4) * 11, 10)
			end
			if ftimer then
				tx(st, "8", x + fw - 14, y + 26, 9, T.c.text, "RIGHT", 12)
				zn(st, "tmz", x + fw - 22, y + 26, 20, 11)
			end
			zn(st, "tntz", x + 2, y + 28 + 10, fw - 4, fh - 28 - 22)
		end
		if aggro then
			if afr then
				rc(st, 3, T.c.bad, x, y, fw, 2)
				rc(st, 3, T.c.bad, x, y + fh - 2, fw, 2)
				rc(st, 3, T.c.bad, x, y, 2, fh)
				rc(st, 3, T.c.bad, x + fw - 2, y, 2, fh)
				zn(st, "frz", x, y + fh - 8, fw, 8)
			end
			if aic then
				rc(st, 3, T.c.bad, x + fw - 13, y + 3, 10, 10, 1)
				tx(st, "!", x + fw - 13, y + 2, 10, T.c.text, "CENTER", 10)
				zn(st, "aicz", x + fw - 13, y + 3, 10, 10)
			end
		end
		if i == 1 and atk then
			rc(st, 3, A, x + fw - 12, y + 3, 9, 9, 1)
			tx(st, "T", x + fw - 12, y + 2, 8, T.c.bg, "CENTER", 9)
		end
		if i == 1 then zn(st, "tkz", x + fw - 14, y + 2, 12, 12) end
		if i == 2 then zn(st, "fxz", x, y, fw - 14, 13) end
		if i == 3 then zn(st, "hlz", x, y, fw - 14, 13) end
		if i == 4 then zn(st, "caz", x, y, fw - 14, 13) end
		if i == 5 then zn(st, "dpz", x, y, fw, 13) end
	end
	if not fxon then tx(st, S("groupfx", "fxoff"), 4 + fw + gap, 4 + 26, 9, T.c.dim, "LEFT", fw) end
	local y = fh + 12
	local cw = floor((w - 8 - 3 * gap) / 4)
	chip(st, "mdz", 4, y, cw, 16, sformat(S("groupfx", "mode"), chv("groupfx.aggromode", "target")), amode ~= "off")
	chip(st, "ftz", 4 + (cw + gap), y, cw, 16, sformat(S("groupfx", "filter"), chv("groupfx.aggrofilter", "boss")), false)
	chip(st, "rgz", 4 + 2 * (cw + gap), y, cw, 16, S("groupfx", "guess"), flag("groupfx.roleguess", true))
	chip(st, "mxz", 4 + 3 * (cw + gap), y, cw, 16, sformat(S("groupfx", "max"), fmax), false)
	chip(st, "sdz", 4, y + 20, cw + 20, 16, sformat(S("groupfx", "sound"), chv("groupfx.fx.sound", "auto")), false)
	chip(st, "msz", 4 + cw + 24, y + 20, cw + 20, 16, sformat(S("groupfx", "msg"), chv("groupfx.fx.msgself", "screen")), false)
	chip(st, "asz", 4 + 2 * cw + 48, y + 20, cw + 20, 16, sformat(S("groupfx", "asound"), chv("groupfx.aggro.sound", "raid")), false)
end

register("groupfx", {
	ids = { "tntz", "icz", "tmz", "fxz", "hlz", "caz", "dpz", "tkz", "frz", "aicz", "mdz", "ftz", "rgz", "mxz", "sdz", "msz", "asz" },
	keys = { tntz = "groupfx.fx.tint", icz = "groupfx.fx.icon", tmz = "groupfx.fx.timer", fxz = "groupfx.fx.on", hlz = "groupfx.aggro.heal",
		caz = "groupfx.aggro.caster", dpz = "groupfx.aggro.dps", tkz = "groupfx.aggro.tank", frz = "groupfx.aggro.frame",
		aicz = "groupfx.aggro.icon", mdz = "groupfx.aggromode", ftz = "groupfx.aggrofilter", rgz = "groupfx.roleguess", mxz = "groupfx.fx.max",
		sdz = "groupfx.fx.sound", msz = "groupfx.fx.msgself", asz = "groupfx.aggro.sound" },
	draw = drawGroupFx,
})

-- ================================================================ loot
local LTN = { "Shikiwa", "Thorgrim", "Elaria", "Kaelith" }

local function drawLoot(st, w, ch)
	local A = st.acc
	local win, btns = flag("loot.window", true), flag("loot.buttons", true)
	local rows, rtime, minq = floor(num("loot.rows", 10)), num("loot.rolltime", 15), floor(num("loot.minquality", 2))
	local rf, rmax, rsc = flag("loot.rollframe", true), floor(num("loot.rollmax", 4)), num("loot.rollscale", 100)
	local lf, lrows, lsc = flag("loot.lootframe", true), floor(num("loot.lootrows", 8)), num("loot.lootscale", 100)
	local q = QUAL[minq + 1] or QUAL[3]
	local tc = win and T.c.text or T.c.dim
	-- A : fenetre des jets
	local y = 0
	local nA = mmin(6, rows)
	local hA = 18 + 9 + nA * 11 + 20
	bx(st, 0, y, w, hA, T.c.bg, win and A or T.c.border)
	tx(st, S("loot", "item"), 6, y + 3, 9, q, "LEFT", w - 60)
	zn(st, "winz", 0, y, w - 50, 14)
	tx(st, rtime .. "s", w - 46, y + 3, 9, tc, "RIGHT", 42)
	zn(st, "timez", w - 48, y, 46, 14)
	rc(st, 2, T.c.border, 6, y + 16, w - 12, 5)
	rc(st, 2, A, 6, y + 16, floor((w - 12) * 0.6), 5, win and 1 or 0.3)
	local tags = { "SR", "MS", "OS", "TM" }
	local caps = { num("loot.cap.sr", 101), num("loot.cap.ms", 100), num("loot.cap.os", 99), num("loot.cap.tm", 50) }
	for i = 1, nA do
		local ry = y + 24 + (i - 1) * 11
		local ti = md(i - 1, 4) + 1
		tx(st, LTN[ti], 8, ry, 9, tc, "LEFT", 90)
		tx(st, tags[ti], 100, ry, 9, T.c.dim, "LEFT", 24)
		tx(st, tostring(floor(caps[ti] * (1 - i * 0.12))), w - 44, ry, 9, tc, "RIGHT", 36)
	end
	zn(st, "rowsz", 4, y + 23, w - 8, nA * 11)
	if btns then
		local bw = floor((w - 12 - 4 * 3) / 5)
		for i = 1, 4 do
			chip(st, "cap" .. i, 6 + (i - 1) * (bw + 3), y + hA - 17, bw, 14, tags[i] .. " " .. caps[i], win)
		end
		chip(st, "btnz", 6 + 4 * (bw + 3), y + hA - 17, bw, 14, S("loot", "pass"), false)
	else
		tx(st, S("loot", "nobtn"), 6, y + hA - 15, 9, T.c.dim, "LEFT", w - 12)
		zn(st, "btnz", 4, y + hA - 17, w - 8, 14)
	end
	y = y + hA + 5
	-- B : fenetre des jets de groupe
	local nB = mmin(rmax, 3)
	local hB = 14 + nB * 17
	if y + hB > ch then return end
	local bwid = floor((w - 8) * mmin(rsc, 150) / 150) + 8
	if bwid > w then bwid = w end
	tx(st, S("loot", "rollframe") .. " (" .. rmax .. ")", 2, y, 9, rf and T.c.text or T.c.dim, "LEFT", w - 80)
	zn(st, "rfz", 0, y - 1, w - 80, 12)
	tx(st, rsc .. "%", w - 70, y, 9, T.c.dim, "RIGHT", 66)
	zn(st, "rscz", w - 70, y - 1, 70, 12)
	if rf then
		for i = 1, nB do
			local ry = y + 13 + (i - 1) * 17
			bx(st, 0, ry, bwid, 15, T.c.panel, T.c.border)
			rc(st, 2, QUAL[mmin(2 + i, 5)], 2, ry + 2, 11, 11, 1)
			rc(st, 2, A, 15, ry + 11, floor((bwid - 60) * (1 - i * 0.22)), 3, 0.8)
			tx(st, S("loot", "item" .. i), 16, ry + 1, 8, T.c.text, "LEFT", bwid - 70)
			rc(st, 2, T.c.good, bwid - 42, ry + 3, 10, 9, 0.9)
			rc(st, 2, T.c.warn, bwid - 29, ry + 3, 10, 9, 0.9)
			rc(st, 2, T.c.bad, bwid - 16, ry + 3, 10, 9, 0.9)
		end
		zn(st, "rmaxz", 0, y + 13, bwid, nB * 17)
	end
	y = y + hB + 5
	-- C : fenetre de butin compacte
	local nC = mmin(lrows, 4)
	local hC = 14 + nC * 12
	if y + hC > ch then return end
	local lw = floor((w - 8) * mmin(lsc, 150) / 150 * 0.7) + 40
	tx(st, S("loot", "lootframe"), 2, y, 9, lf and T.c.text or T.c.dim, "LEFT", 120)
	zn(st, "lfz", 0, y - 1, 120, 12)
	tx(st, lrows .. " / " .. lsc .. "%", 124, y, 9, T.c.dim, "LEFT", 80)
	zn(st, "lsz", 124, y - 1, 80, 12)
	if lf then
		bx(st, 0, y + 12, lw, nC * 12 + 2, T.c.panel, T.c.border)
		for i = 1, nC do
			rc(st, 2, QUAL[mmin(i + 1, 5)], 3, y + 14 + (i - 1) * 12, 9, 9, 1)
			tx(st, S("loot", "item" .. mmin(i, 3)), 15, y + 14 + (i - 1) * 12, 8, T.c.text, "LEFT", lw - 18)
		end
		zn(st, "lrz", 0, y + 12, lw, nC * 12 + 2)
	end
	chip(st, "mqz", w - 70, y + 12, 70, 14, sformat(S("loot", "minq"), minq), false)
	if flag("loot.history", true) then
		chip(st, "hisz", w - 70, y + 28, 70, 14, S("loot", "history"), true)
	else
		chip(st, "hisz", w - 70, y + 28, 70, 14, S("loot", "nohistory"), false)
	end
end

register("loot", {
	ids = { "rowsz", "winz", "timez", "cap1", "cap2", "cap3", "cap4", "btnz", "rfz", "rscz", "rmaxz", "lfz", "lsz", "lrz", "mqz", "hisz" },
	keys = { rowsz = "loot.rows", winz = "loot.window", timez = "loot.rolltime", cap1 = "loot.cap.sr", cap2 = "loot.cap.ms", cap3 = "loot.cap.os",
		cap4 = "loot.cap.tm", btnz = "loot.buttons", rfz = "loot.rollframe", rscz = "loot.rollscale", rmaxz = "loot.rollmax",
		lfz = "loot.lootframe", lsz = "loot.lootscale", lrz = "loot.lootrows", mqz = "loot.minquality", hisz = "loot.history" },
	draw = drawLoot,
})

-- ================================================================ mail
-- type : 1 = hotel des ventes, 2 = joueur ; argent, objet
local MLR = { { 1, true, false }, { 1, false, true }, { 2, false, true }, { 2, true, false }, { 2, false, false } }

local function mailMatch(filter, r)
	if filter == "ah" then return r[1] == 1 end
	if filter == "noah" then return r[1] ~= 1 end
	if filter == "money" then return r[2] end
	return true
end

local function drawMail(st, w, ch)
	local A = st.acc
	local panel, filter = flag("mail.panel", true), chv("mail.filter", "all")
	local tmoney, titems = flag("mail.takemoney", true), flag("mail.takeitems", true)
	local autot, keep, delempty = flag("mail.autotake", false), floor(num("mail.keepfree", 0)), flag("mail.deleteempty", false)
	local multi = flag("mail.multi", true)
	bx(st, 0, 0, w, 122, T.c.bg, T.c.border)
	tx(st, S("mail", "inbox"), 6, 3, 9, T.c.dim, "LEFT", 80)
	chip(st, "filt", w - 150, 2, 146, 14, sformat(S("mail", "filter"), S("mail", "f" .. filter)), filter ~= "all")
	for i = 1, 5 do
		local r = MLR[i]
		local y = 19 + (i - 1) * 14
		local ok = mailMatch(filter, r)
		local a = ok and 1 or 0.3
		if md(i, 2) == 0 then rc(st, 2, T.c.inset, 3, y, w - 6, 13, 0.7) end
		tx(st, S("mail", "s" .. i), 8, y + 2, 9, ok and T.c.text or T.c.dim, "LEFT", 130)
		if r[2] then
			tx(st, "124g", w - 130, y + 2, 9, tmoney and T.c.warn or T.c.dim, "RIGHT", 40)
		end
		if r[3] then rc(st, 2, titems and QUAL[4] or T.c.dim, w - 80, y + 2, 9, 9, a) end
		if not r[2] and not r[3] then
			tx(st, S("mail", delempty and "willdel" or "empty"), w - 120, y + 2, 8, delempty and T.c.bad or T.c.dim, "RIGHT", 100)
		end
		zn(st, "m" .. i, 3, y, w - 6, 13)
	end
	-- panneau ramasser
	local py = 126
	local ph = 52
	bx(st, 0, py, w, ph, T.c.bg, panel and A or T.c.border)
	tx(st, S("mail", "takeall"), 6, py + 3, 9, panel and T.c.text or T.c.dim, "LEFT", 120)
	zn(st, "panelz", 0, py, 120, 14)
	ckb(st, "takem", 6, py + 18, tmoney, S("mail", "money"), 40)
	ckb(st, "takei", 74, py + 18, titems, S("mail", "items"), 40)
	ckb(st, "autoz", 140, py + 18, autot, S("mail", "auto"), 70)
	chip(st, "keepz", w - 94, py + 16, 90, 14, sformat(S("mail", "keep"), keep), keep > 0)
	ckb(st, "delz", 6, py + 34, delempty, S("mail", "delempty"), 100)
	-- envoi multiple
	local my = py + ph + 4
	if my + 36 > ch + 12 then return end
	bx(st, 0, my, w, 36, T.c.bg, multi and A or T.c.border)
	tx(st, S("mail", "multi"), 6, my + 3, 9, multi and T.c.text or T.c.dim, "LEFT", 100)
	zn(st, "multiz", 0, my, 110, 14)
	for i = 1, 5 do rc(st, 2, multi and QUAL[mmin(i, 5)] or T.c.dim, 6 + (i - 1) * 13, my + 17, 11, 11, multi and 0.9 or 0.3) end
	tx(st, sformat(S("mail", "gold"), num("mail.multigold", 0)), 78, my + 17, 9, T.c.text, "LEFT", 90)
	zn(st, "goldz", 74, my + 15, 94, 14)
	tx(st, sformat(S("mail", "delay"), num("mail.multidelay", 1)), 172, my + 17, 9, T.c.dim, "LEFT", 60)
	zn(st, "delayz", 170, my + 15, 64, 14)
	ckb(st, "confz", w - 76, my + 17, flag("mail.confirmsend", true), S("mail", "confirm"), 52)
end

register("mail", {
	ids = { "m1", "m2", "m3", "m4", "m5", "filt", "panelz", "takem", "takei", "autoz", "keepz", "delz", "multiz", "goldz", "delayz", "confz" },
	keys = { m1 = "mail.filter", m2 = "mail.filter", m3 = "mail.filter", m4 = "mail.filter", m5 = "mail.filter", filt = "mail.filter",
		panelz = "mail.panel", takem = "mail.takemoney", takei = "mail.takeitems", autoz = "mail.autotake", keepz = "mail.keepfree",
		delz = "mail.deleteempty", multiz = "mail.multi", goldz = "mail.multigold", delayz = "mail.multidelay", confz = "mail.confirmsend" },
	draw = drawMail,
})

-- ================================================================ messages
local MSC = { "Thorgrim", "Elaria", "Kaelith", "Brannor" }

local function drawMessages(st, w, ch)
	local A = st.acc
	local toast, badge, mode = flag("messages.toast", true), flag("messages.badge", true), chv("messages.mode", "windows")
	local maxwin, winw, winh = floor(num("messages.maxwin", 4)), num("messages.winw", 320), num("messages.winh", 200)
	local stamp, fmt, blink = flag("messages.stamp", true), chv("messages.stampfmt", "hm"), flag("messages.blink", true)
	-- pastille de notification
	if toast then
		bx(st, 4, 2, floor(w * 0.6), 20, T.c.panel, A)
		tx(st, S("messages", "toast"), 8, 7, 9, T.c.text, "LEFT", floor(w * 0.6) - 8)
	else
		tx(st, S("messages", "notoast"), 6, 7, 9, T.c.dim, "LEFT", floor(w * 0.6))
	end
	zn(st, "toastz", 4, 2, floor(w * 0.6), 20)
	-- bouton de discussion + compteur
	local bxx = w - 36
	bx(st, bxx, 2, 30, 20, T.c.inset, T.c.border)
	tx(st, "...", bxx, 6, 10, T.c.dim, "CENTER", 30)
	if badge then
		rc(st, 3, T.c.bad, bxx + 20, 0, 13, 11, 1)
		tx(st, "3", bxx + 20, -1, 9, T.c.text, "CENTER", 13)
	end
	zn(st, "badgez", bxx, 0, 34, 22)
	-- fenetres
	local sc = (w - 12) / 2 / 320
	local fw = mmin(floor(winw * sc * (mode == "tabs" and 2 or 1)), w - 8)
	local fh = mmin(floor(winh * sc * 1.2), ch - 50)
	if fh < 70 then fh = 70 end
	local nw = 1
	if mode == "windows" then nw = mmin(maxwin, 2) end
	for k = 1, nw do
		local x = 4 + (k - 1) * (fw + 4)
		if x + fw > w then fw = w - x - 2 end
		local y = 28 + (k - 1) * 6
		bx(st, x, y, fw, fh, T.c.bg, T.c.border)
		rc(st, 2, T.c.panel, x + 1, y + 1, fw - 2, 14, 1)
		if mode == "tabs" then
			for i = 1, 3 do
				local tw = floor((fw - 4) / 3)
				local hot = (i == 2 and blink)
				rc(st, 2, i == 1 and A or (hot and T.c.warn or T.c.inset), x + 2 + (i - 1) * tw, y + 2, tw - 2, 12, i == 1 and 0.5 or (hot and 0.6 or 1))
				tx(st, MSC[i], x + 2 + (i - 1) * tw, y + 3, 8, T.c.text, "CENTER", tw - 2)
			end
			zn(st, "blinkz", x + 2 + floor((fw - 4) / 3), y + 2, floor((fw - 4) / 3) - 2, 12)
		else
			tx(st, MSC[k], x + 4, y + 3, 9, T.c.text, "LEFT", fw - 8)
		end
		local ts = ""
		if stamp then ts = (fmt == "hms") and "[14:32:08] " or "[14:32] " end
		tx(st, ts .. MSC[k] .. " : " .. S("messages", "l1"), x + 4, y + 18, 8, T.c.dim, "LEFT", fw - 8)
		tx(st, ts .. S("messages", "me") .. " : " .. S("messages", "l2"), x + 4, y + 29, 8, T.c.text, "LEFT", fw - 8)
		bx(st, x + 3, y + fh - 14, fw - 6, 11, T.c.inset, T.c.border)
		if k == 1 then
			zn(st, "stampz", x + 4, y + 17, fw - 8, 11)
			zn(st, "titlez", x, y, fw, 15)
			zn(st, "inputz", x + 3, y + fh - 14, fw - 6, 11)
			zn(st, "winwz", x + fw - 5, y + 16, 8, fh - 20)
			zn(st, "winhz", x + 6, y + fh - 3, fw - 12, 8)
			rc(st, 3, A, x + fw - 3, y + 16, 3, fh - 20)
			rc(st, 3, A, x + 6, y + fh - 2, fw - 12, 3)
		end
	end
	local cy = 28 + fh + 10
	if cy + 16 > ch + 10 then return end
	local cw = floor((w - 8 - 9) / 4)
	chip(st, "modez", 4, cy, cw, 16, S("messages", mode == "tabs" and "tabs" or "windows"), false)
	chip(st, "fmtz", 4 + (cw + 3), cy, cw, 16, fmt == "hms" and "hh:mm:ss" or "hh:mm", stamp)
	chip(st, "dragz", 4 + 2 * (cw + 3), cy, cw, 16, sformat(S("messages", "drag"), chv("messages.dragmod", "shift")), false)
	chip(st, "sndz", 4 + 3 * (cw + 3), cy, cw, 16, S("messages", flag("messages.sound", true) and "sndon" or "sndoff"), flag("messages.sound", true))
end

register("messages", {
	ids = { "toastz", "badgez", "blinkz", "stampz", "titlez", "inputz", "winwz", "winhz", "modez", "fmtz", "dragz", "sndz" },
	keys = { toastz = "messages.toast", badgez = "messages.badge", blinkz = "messages.blink", stampz = "messages.stamp", titlez = "messages.maxwin",
		inputz = "messages.focus", winwz = "messages.winw", winhz = "messages.winh", modez = "messages.mode", fmtz = "messages.stampfmt",
		dragz = "messages.dragmod", sndz = "messages.sound" },
	draw = drawMessages,
})

-- ================================================================ powerauras
local PAC = { T.c.bad, T.c.warn, T.c.good }

local function drawPowerAuras(st, w, ch)
	local A = st.acc
	local show, flash, border = flag("powerauras.show", true), chv("powerauras.flash", "soft"), chv("powerauras.border", "color")
	local sweep, tenths = flag("powerauras.sweep", true), flag("powerauras.tenths", true)
	local alpha, spacing = num("powerauras.alpha", 1), num("powerauras.spacing", 4)
	local sy = 2
	local sh = ch - 28
	bx(st, 0, sy, w, sh, T.c.inset, T.c.border)
	tx(st, S("powerauras", "screen"), 6, sy + 3, 8, T.c.dim, "LEFT", 100)
	if flash ~= "off" then
		local th = (flash == "strong") and 12 or 6
		local fa = (flash == "strong") and 0.4 or 0.2
		rc(st, 3, T.c.warn, 1, sy + 1, w - 2, th, fa)
		rc(st, 3, T.c.warn, 1, sy + sh - 1 - th, w - 2, th, fa)
		rc(st, 3, T.c.warn, 1, sy + 1, th, sh - 2, fa)
		rc(st, 3, T.c.warn, w - 1 - th, sy + 1, th, sh - 2, fa)
	end
	zn(st, "flashz", 1, sy + 1, w - 2, 10)
	local isz = 36
	local gap = floor(spacing * 1.5)
	local x0 = floor((w - (3 * isz + 2 * gap)) / 2)
	local y = sy + floor((sh - isz) / 2)
	local va = show and alpha or alpha * 0.25
	local secs = { 6.4, 3.1, 12 }
	for i = 1, 3 do
		local x = x0 + (i - 1) * (isz + gap)
		local bt = PAC[i]
		if border == "style" then bt = A end
		if border ~= "none" then rc(st, 2, bt, x - 2, y - 2, isz + 4, isz + 4, va) end
		rc(st, 2, T.c.panel, x, y, isz, isz, va)
		rc(st, 2, PAC[i], x + 6, y + 6, isz - 12, isz - 12, 0.55 * va)
		if sweep then rc(st, 3, T.c.bg, x, y, isz, floor(isz * (0.15 + 0.25 * i)), 0.65 * va) end
		local ts = tenths and sformat("%.1f", secs[i]) or tostring(floor(secs[i]))
		tx(st, ts, x, y + floor((isz - 10) / 2), 10, T.c.text, "CENTER", isz)
		zn(st, "a" .. i, x - 2, y - 2, isz + 4, isz + 4)
	end
	zn(st, "alz", x0, y + isz + 2, 3 * isz + 2 * gap, 6)
	rc(st, 3, A, x0, y + isz + 4, 3 * isz + 2 * gap, 2, va)
	zn(st, "gapz", x0 + isz + 2, y, gap > 4 and gap - 4 or 2, isz)
	local cy = sy + sh + 4
	chip(st, "showz", 4, cy, 80, 16, S("powerauras", show and "on" or "off"), show)
	chip(st, "sndz", 88, cy, 80, 16, S("powerauras", flag("powerauras.sound", true) and "sndon" or "sndoff"), flag("powerauras.sound", true))
	chip(st, "tickz", 172, cy, 80, 16, sformat(S("powerauras", "tick"), num("powerauras.tick", 0.2)), false)
end

register("powerauras", {
	ids = { "flashz", "a1", "a2", "a3", "alz", "gapz", "showz", "sndz", "tickz" },
	keys = { flashz = "powerauras.flash", a1 = "powerauras.border", a2 = "powerauras.sweep", a3 = "powerauras.tenths", alz = "powerauras.alpha",
		gapz = "powerauras.spacing", showz = "powerauras.show", sndz = "powerauras.sound", tickz = "powerauras.tick" },
	draw = drawPowerAuras,
})

-- ================================================================ social
local SOA = { "invite", "decline", "duel", "guild", "summon", "rez" }

local function drawSocial(st, w, ch)
	local A = st.acc
	local inv = flag("social.invite", false)
	local viaW, viaG, viaR = flag("social.invite.whisper", true), flag("social.invite.guild", true), flag("social.invite.raid", false)
	local maxg, cool = floor(num("social.invite.max", 40)), num("social.invite.cool", 30)
	local mark, where = flag("social.mark", false), chv("social.mark.where", "group")
	local filter, reset = chv("social.invite.filter", "all"), flag("social.invite.reset", true)
	-- discussion d'exemple
	bx(st, 0, 0, w, 64, T.c.bg, inv and A or T.c.border)
	chip(st, "invz", 4, 3, 100, 14, S("social", inv and "invon" or "invoff"), inv)
	chip(st, "filtz", 108, 3, 90, 14, sformat(S("social", "filter"), filter), false)
	chip(st, "resetz", 202, 3, w - 206, 14, S("social", "reset"), reset)
	tx(st, S("social", "lw"), 6, 22, 9, viaW and T.c.text or T.c.dim, "LEFT", w - 12)
	zn(st, "whz", 4, 21, w - 8, 12)
	tx(st, S("social", "lg"), 6, 34, 9, viaG and T.c.text or T.c.dim, "LEFT", w - 12)
	zn(st, "gdz", 4, 33, w - 8, 12)
	tx(st, inv and S("social", "ok") or S("social", "idle"), 6, 48, 9, inv and T.c.good or T.c.dim, "LEFT", w - 90)
	tx(st, cool .. "s", w - 80, 48, 9, T.c.dim, "RIGHT", 74)
	zn(st, "coolz", w - 82, 47, 78, 12)
	-- groupe : une case par place, jusqu'a la taille maximale
	local gy = 68
	local cell = 7
	local per = floor((w - 8) / (cell + 2))
	local n = mmin(maxg, 40)
	for i = 1, n do
		local col, row = md(i - 1, per), floor((i - 1) / per)
		local used = i <= 5
		rc(st, 2, used and A or T.c.border, 4 + col * (cell + 2), gy + row * (cell + 2), cell, cell, used and 0.9 or 0.6)
	end
	local gh = (floor((n - 1) / per) + 1) * (cell + 2)
	zn(st, "maxz", 4, gy, w - 8, gh)
	tx(st, sformat(S("social", "maxinfo"), n), 4, gy + gh + 1, 9, T.c.dim, "LEFT", w - 100)
	chip(st, "raidz", w - 90, gy + gh, 86, 14, S("social", "raid"), viaR)
	local my = gy + gh + 20
	-- marquage
	bx(st, 0, my, w, 24, T.c.bg, mark and A or T.c.border)
	rc(st, 2, mark and T.c.warn or T.c.dim, 8, my + 6, 12, 12, mark and 1 or 0.4)
	tx(st, S("social", "mob"), 26, my + 7, 9, mark and T.c.text or T.c.dim, "LEFT", 100)
	zn(st, "markz", 4, my, 130, 24)
	chip(st, "wherez", w - 94, my + 5, 90, 14, sformat(S("social", "where"), where), false)
	-- automatismes
	local ay = my + 30
	local colw = floor((w - 12) / 2)
	for i = 1, 6 do
		local x = 4 + md(i - 1, 2) * (colw + 4)
		local y = ay + floor((i - 1) / 2) * 15
		if y + 12 > ch + 8 then break end
		local key = "social.auto." .. SOA[i]
		local on
		if i == 1 then
			on = chv(key, "off") ~= "off"
		else
			on = flag(key, false)
		end
		ckb(st, "a" .. i, x, y, on, S("social", "a" .. i), colw - 16)
	end
end

register("social", {
	ids = { "invz", "filtz", "resetz", "whz", "gdz", "coolz", "maxz", "raidz", "markz", "wherez", "a1", "a2", "a3", "a4", "a5", "a6" },
	keys = { invz = "social.invite", filtz = "social.invite.filter", resetz = "social.invite.reset", whz = "social.invite.whisper",
		gdz = "social.invite.guild", coolz = "social.invite.cool", maxz = "social.invite.max", raidz = "social.invite.raid", markz = "social.mark",
		wherez = "social.mark.where", a1 = "social.auto.invite", a2 = "social.auto.decline", a3 = "social.auto.duel", a4 = "social.auto.guild",
		a5 = "social.auto.summon", a6 = "social.auto.rez" },
	draw = drawSocial,
})

-- ================================================================ tracker
local function drawTracker(st, w, ch)
	local A = st.acc
	local bar, width, hud = flag("tracker.bar", true), num("tracker.width", 240), flag("tracker.hud", false)
	local days, vmin = floor(num("tracker.days", 14)), num("tracker.valuemin", 1)
	local alert, amin, hlim = flag("tracker.alert", true), num("tracker.alertmin", 60), floor(num("tracker.hourlimit", 5))
	local craid = flag("tracker.countraids", false)
	-- mini-barre
	local bw = floor((w - 8) * width / 400)
	if bar then
		bx(st, 4, 2, bw, 18, T.c.bg, A)
		tx(st, S("tracker", "bar"), 8, 6, 9, T.c.text, "LEFT", bw - 8)
		rc(st, 3, A, 4 + bw - 3, 2, 3, 18)
		zn(st, "widthz", 4 + bw - 6, 2, 9, 18)
	else
		bx(st, 4, 2, bw, 18, T.c.bg, T.c.border, 0.4)
		tx(st, S("tracker", "nobar"), 4, 6, 9, T.c.dim, "CENTER", bw)
	end
	zn(st, "barz", 4, 2, bar and bw - 6 or bw, 18)
	-- barre de statut
	bx(st, 4, 24, w - 8, 14, T.c.inset, T.c.border)
	tx(st, "FPS 60", 8, 26, 8, T.c.dim, "LEFT", 50)
	if hud then
		rc(st, 2, A, 70, 26, 90, 10, 0.3)
		tx(st, S("tracker", "hud"), 70, 26, 8, T.c.text, "CENTER", 90)
	end
	zn(st, "hudz", 66, 24, 98, 14)
	-- verrous
	local ly = 44
	bx(st, 4, ly, w - 8, 54, T.c.bg, T.c.border)
	tx(st, S("tracker", "locks"), 8, ly + 3, 9, T.c.dim, "LEFT", 140)
	local lk = { { "Molten Core", "3j 4h", false }, { "Onyxia", "0j 0h 45m", true } }
	for i = 1, 2 do
		local y = ly + 16 + (i - 1) * 14
		local soon = lk[i][3] and alert and amin >= 45
		tx(st, lk[i][1], 8, y, 9, T.c.text, "LEFT", 100)
		tx(st, lk[i][2], 110, y, 9, soon and T.c.warn or T.c.dim, "LEFT", 90)
		if soon then
			rc(st, 3, T.c.warn, w - 24, y, 10, 10, 1)
			tx(st, "!", w - 24, y - 1, 10, T.c.bg, "CENTER", 10)
		end
	end
	zn(st, "lockz", 4, ly + 28, w - 8, 14)
	chip(st, "almz", w - 90, ly + 2, 84, 12, sformat(S("tracker", "alm"), amin), alert)
	-- entrees par heure
	local hy = ly + 60
	tx(st, S("tracker", "hour"), 4, hy, 9, T.c.dim, "LEFT", 130)
	for i = 1, mmin(hlim, 10) do rc(st, 2, i <= 3 and A or T.c.border, 134 + (i - 1) * 12, hy + 1, 10, 9, i <= 3 and 0.9 or 0.7) end
	zn(st, "hourz", 130, hy - 1, mmin(hlim, 10) * 12 + 4, 12)
	ckb(st, "raidz", w - 90, hy, craid, S("tracker", "raids"), 60)
	-- or sur les derniers jours
	local gy = hy + 16
	local gh = mmin(ch - gy - 20, 60)
	if gh < 20 then return end
	bx(st, 4, gy, w - 8, gh, T.c.bg, T.c.border)
	local bwid = (w - 16) / days
	for i = 1, days do
		local v = 0.25 + 0.7 * md(i * 37, 100) / 100
		local hh = floor((gh - 6) * v)
		rc(st, 2, A, 8 + (i - 1) * bwid, gy + gh - 3 - hh, mmax(bwid - 1, 1), hh, 0.8)
	end
	zn(st, "graphz", 4, gy, w - 8, gh)
	tx(st, sformat(S("tracker", "days"), days), 8, gy + gh + 2, 9, T.c.dim, "LEFT", 100)
	chip(st, "valz", w - 110, gy + gh + 2, 106, 14, sformat(S("tracker", "val"), vmin), false)
end

register("tracker", {
	ids = { "barz", "widthz", "hudz", "lockz", "almz", "hourz", "raidz", "graphz", "valz" },
	keys = { barz = "tracker.bar", widthz = "tracker.width", hudz = "tracker.hud", lockz = "tracker.alert", almz = "tracker.alertmin",
		hourz = "tracker.hourlimit", raidz = "tracker.countraids", graphz = "tracker.days", valz = "tracker.valuemin" },
	draw = drawTracker,
})

-- ================================================================ windows
local WIN = { "character", "spellbook", "talents", "quests", "social", "map", "merchant", "bank", "auction", "mail", "trade", "macro" }
local WINTOT = nil
local WINK = {}

local function drawWindows(st, w, ch)
	local A = st.acc
	local key = chv("windows.key", "none")
	if not WINTOT then
		WINTOT = 0
		for i = 1, getn(SUI.options) do
			local o = SUI.options[i]
			if o.type == "bool" and o.cat == "windows" and ssub(o.key, 1, 10) == "windows.w_" then WINTOT = WINTOT + 1 end
		end
	end
	local nOn = 0
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.cat == "windows" and o.type == "bool" and ssub(o.key, 1, 10) == "windows.w_" and C.Get(o.key) then nOn = nOn + 1 end
	end
	chip(st, "keyz", 4, 2, 150, 16, S("windows", "k" .. key), key ~= "none")
	tx(st, sformat(S("windows", "count"), nOn, WINTOT), w - 150, 5, 9, T.c.dim, "RIGHT", 146)
	chip(st, "resetz", w - 80, 22, 76, 14, S("windows", "reset"), flag("windows.resetall", false))
	local cols = 3
	local gw = floor((w - 8 - (cols - 1) * 4) / cols)
	local gh = mmin(46, floor((ch - 44) / 4) - 4)
	local n = 0
	for i = 1, 12 do
		local id = WIN[i]
		local okey = "windows.w_" .. id
		if SUI.Config and SUI.Menu and P.FindOption(okey) then
			n = n + 1
			local col, row = md(n - 1, cols), floor((n - 1) / cols)
			local x = 4 + col * (gw + 4)
			local y = 40 + row * (gh + 4)
			local on = flag(okey, true)
			bx(st, x, y, gw, gh, T.c.bg, on and A or T.c.border, on and 1 or 0.45)
			rc(st, 2, on and T.c.panel or T.c.inset, x + 1, y + 1, gw - 2, 11, 1)
			tx(st, S("windows", "n" .. id), x + 2, y + 2, 8, on and T.c.text or T.c.dim, "LEFT", gw - 4)
			if on then
				rc(st, 3, A, x + gw - 8, y + 3, 5, 5, 1)
			else
				rc(st, 3, T.c.dim, x + 4, y + 20, gw - 8, 1, 0.8)
			end
			zn(st, "w" .. n, x, y, gw, gh)
			WINK[n] = okey
		end
	end
end

do
	local ids = { "keyz", "resetz" }
	local keys = { keyz = "windows.key", resetz = "windows.resetall" }
	for i = 1, 12 do table.insert(ids, "w" .. i) end
	register("windows", {
		ids = ids,
		click = function(zone)
			if keys[zone] then return keys[zone] end
			local i = tonumber(ssub(zone, 2))
			if i then return WINK[i] end
			return nil
		end,
		label = function(zone)
			local i = tonumber(ssub(zone, 2))
			local k = i and WINK[i]
			if k then return "opt." .. k end
			return nil
		end,
		draw = drawWindows,
	})
end

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) l'empilement des textures d'une meme couche suit l'ordre de creation du pool ; (2) les pools de
-- textures / textes sont dimensionnes pour les cas courants : un depassement ne cree rien et supprime seulement l'element en trop ;
-- (3) rendu des anneaux du module cursor par petits points (pas de texture ronde) ; (4) fidelite au VRAI rendu des modules (fenetre des
-- jets, panneaux du courrier, hotel des ventes) : maquettes simplifiees a valider en jeu.
