-- ShikiUI Preview_More1 : apercus 2D supplementaires (voir Preview_Basic.lua pour le moteur P.Register).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
-- Modules couverts (positions paires de la liste alphabetique des modules sans apercu) : bulletin, chattabs, cooldowns,
-- datatext, finder, items, macros, marks, pallypower, skin, specs, vendor (bossmods a deja son apercu dans Mod_BossMods.lua). Meme principe que Preview_Basic.lua : tout est dessine avec des
-- textures / textes d'un POOL cree dans build (aucune creation dans update, donc sans danger en combat) ; les couleurs viennent des
-- jetons du style (T.c.*, T.Accent) ; un clic sur un element saute a son reglage ; un element desactive reste dessine en fantome (alpha
-- reduit) pour que sa zone reste cliquable. Les textes d'exemple sont des donnees fixes ; les mots traduits sont "mod.preview.m1.*".
-- NON VERIFIE EN JEU (rendu reel, ordre d'empilement des textures, tailles de police).
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config
local P = SUI.Preview

local getn = table.getn
local floor, ceil = math.floor, math.ceil
local sfind = string.find

local MAXT, MAXX = 170, 90          -- taille des pools (textures, textes) d'un apercu

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

local function pick(key, d)
	local v = C.Get(key)
	if v == nil then return d end
	return v
end

-- Texte traduit de l'apercu : K("bossmods", "pull") -> "mod.preview.m1.bossmods.pull".
local function K(mod, name)
	return L("mod.preview.m1." .. mod .. "." .. name)
end

-- Libelle d'un choix de reglage (langue de l'interface).
local function chLab(key, v)
	local o = P.FindOption(key)
	if o and o.choices and M.ChoiceLabel then return M.ChoiceLabel(o, v) end
	return tostring(v)
end

local ACC = { 0, 0, 0, 1 }
local function accent()
	ACC[1], ACC[2], ACC[3] = T.Accent()
	return ACC
end

local function classTok(class)
	local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if col then return { col.r, col.g, col.b, 1 } end
	return T.c.dim
end

-- ================================================================ toile : pool de textures / textes + zones, coordonnees virtuelles
local function cvNew(parent, zones)
	local root = CreateFrame("Frame", nil, parent)
	local cv = { root = root, t = {}, x = {}, z = {}, nt = 0, nx = 0, pt = 0, px = 0, f = 1, ox = 0, oy = 0, w = 0, h = 0, ch = 0 }
	for i = 1, MAXT do
		local t = P.NewTex(root, "ARTWORK")
		t:Hide()
		cv.t[i] = t
	end
	for i = 1, MAXX do
		local fs = T.Text(root, 10, T.c.text, "LEFT", true)
		fs:Hide()
		cv.x[i] = fs
	end
	cv.hint = T.Text(root, 10, T.c.dim, "LEFT", true)
	cv.hint:Hide()
	for i = 1, getn(zones) do cv.z[zones[i]] = P.Zone(root, zones[i]) end
	root.cv = cv
	return root
end

-- cw x ch = taille virtuelle du dessin ; il est mis a l'echelle pour tenir dans w x h (au plus x1.6) et centre en largeur.
local function cvBegin(cv, w, h, cw, ch)
	local f = w / cw
	if h > 0 and h / ch < f then f = h / ch end
	if f > 1.6 then f = 1.6 end
	if f < 0.4 then f = 0.4 end
	cv.f = f
	cv.ox = floor((w - cw * f) / 2)
	cv.oy = 0
	cv.w, cv.h, cv.ch = w, h, ch
	cv.nt, cv.nx = 0, 0
	for _, z in pairs(cv.z) do z:Hide() end
end

local function cvEnd(cv, hintKey)
	for i = cv.nt + 1, cv.pt do cv.t[i]:Hide() end
	for i = cv.nx + 1, cv.px do cv.x[i]:Hide() end
	cv.pt, cv.px = cv.nt, cv.nx
	local y = cv.oy + floor(cv.ch * cv.f) + 6
	local hs = cv.hint
	if hintKey and cv.h - y >= 26 then
		P.Font(hs, 10)
		hs:SetText(L(hintKey))
		hs:ClearAllPoints()
		hs:SetPoint("TOPLEFT", cv.root, "TOPLEFT", 4, -y)
		hs:SetWidth(cv.w - 8)
		hs:SetHeight(cv.h - y)
		hs:Show()
	else
		hs:Hide()
	end
end

local function rect(cv, x, y, w, h, tok, a)
	local n = cv.nt + 1
	if n > MAXT then return end
	cv.nt = n
	local f = cv.f
	local t = cv.t[n]
	P.Fill(t, tok, a)
	P.Box(t, cv.root, floor(cv.ox + x * f + 0.5), floor(cv.oy + y * f + 0.5), floor(w * f + 0.5), floor(h * f + 0.5))
end

-- Cadre : bordure (edge, ea) + fond (fill, fa) ; th = epaisseur de bordure (0 : sans bordure).
local function panel(cv, x, y, w, h, fill, fa, edge, ea, th)
	th = th or 1
	if th > 0 then
		rect(cv, x, y, w, h, edge, ea)
		rect(cv, x + th, y + th, w - 2 * th, h - 2 * th, fill, fa)
	else
		rect(cv, x, y, w, h, fill, fa)
	end
end

local function text(cv, x, y, w, size, str, tok, just, hh)
	local n = cv.nx + 1
	if n > MAXX then return end
	cv.nx = n
	local f = cv.f
	local fs = cv.x[n]
	P.Font(fs, size * f)
	fs:SetText(str)
	fs:SetJustifyH(just or "LEFT")
	local c = tok or T.c.text
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", cv.root, "TOPLEFT", floor(cv.ox + x * f), -floor(cv.oy + y * f))
	fs:SetWidth(floor(w * f))
	fs:SetHeight(floor((hh or (size + 3)) * f))
	fs:Show()
end

local function zone(cv, id, x, y, w, h)
	local z = cv.z[id]
	if not z then return end
	local f = cv.f
	P.PlaceZone(z, cv.root, floor(cv.ox + x * f), floor(cv.oy + y * f), floor(w * f), floor(h * f))
end

-- Pastille : etat actif = bordure d'accent et texte plein ; inactif = fantome.
local function chip(cv, x, y, w, h, str, on)
	local ar = accent()
	panel(cv, x, y, w, h, T.c.panel, on and 1 or 0.5, on and ar or T.c.border, on and 1 or 0.6)
	text(cv, x, y + floor((h - 9) / 2), w, 9, str, on and T.c.text or T.c.dim, "CENTER", 12)
end

-- Enregistre un apercu : spec = { zones = { ids (la derniere est au-dessus) }, keys = { zone -> reglage }, cw, ch (ou dims() -> cw, ch),
-- paint(cv), hint = cle de texte, click = function(zone) facultative (sinon keys) }.
local function register(id, spec)
	P.Register(id, { watch = { id .. "." },
		build = function(parent, w, h) return cvNew(parent, spec.zones) end,
		update = function(root, w, h, key, value)
			local cv = root.cv
			local cw, ch = spec.cw, spec.ch
			if spec.dims then cw, ch = spec.dims() end
			cvBegin(cv, w, h, cw, ch)
			spec.paint(cv)
			cvEnd(cv, spec.hint)
		end,
		click = function(zn)
			if spec.click then return spec.click(zn) end
			return spec.keys[zn]
		end })
end

-- ================================================================ DifficultBulletinBoard (bulletin)
local BUL = { { "Thorgrim", "LFM RFC tank healer" }, { "Elaria", "LFG WC dps" }, { "Kaelith", "LFM DM 2 dps" }, { "Mordan", "LFM BRD all" },
	{ "Lyra", "LFG STRAT healer" } }

local function bulPaint(cv)
	local skin = flag("bulletin.skin", true)
	local ar = accent()
	panel(cv, 20, 4, 260, 118, skin and T.c.panel or T.c.inset, 1, skin and T.c.border or T.c.dim, 1)
	rect(cv, 21, 5, 258, 16, skin and ar or T.c.border, skin and 0.55 or 0.9)
	text(cv, 28, 8, 200, 10, "DifficultBulletinBoard", T.c.text, "LEFT", 12)
	for i = 1, getn(BUL) do
		local yy = 26 + (i - 1) * 18
		rect(cv, 26, yy, 248, 15, skin and T.c.inset or T.c.panel, 0.8)
		rect(cv, 26, yy, 3, 15, (i - floor(i / 2) * 2 == 1) and T.c.good or T.c.warn, 0.9)
		text(cv, 34, yy + 3, 58, 9, BUL[i][1], T.c.text, "LEFT", 12)
		text(cv, 96, yy + 3, 176, 9, BUL[i][2], T.c.dim, "LEFT", 12)
	end
	chip(cv, 20, 128, 126, 14, K("bulletin", "pos"), flag("bulletin.rememberpos", false))
	chip(cv, 154, 128, 126, 14, K("bulletin", "skin"), skin)
	zone(cv, "win", 20, 4, 260, 118)
	zone(cv, "pin", 20, 128, 126, 14)
	zone(cv, "skin", 154, 128, 126, 14)
end

register("bulletin", { zones = { "win", "pin", "skin" }, keys = { win = "bulletin.skin", skin = "bulletin.skin", pin = "bulletin.rememberpos" },
	cw = 300, ch = 146, paint = bulPaint, hint = "mod.preview.m1.bulletin.hint" })

-- ================================================================ onglets de discussion (chattabs)
local function ctPaint(cv)
	local ar = accent()
	local auto, ded = flag("chattabs.autosetup", false), flag("chattabs.dedicated", true)
	local names = { K("chattabs", "general") }
	if auto then
		names[2], names[3], names[4] = K("chattabs", "guild"), K("chattabs", "world"), K("chattabs", "dungeon")
	elseif ded then
		names[2] = K("chattabs", "world")
	end
	local x = 4
	for i = 1, getn(names) do
		panel(cv, x, 2, 62, 15, T.c.panel, i == 1 and 1 or 0.6, T.c.border, 1)
		if i == 1 then rect(cv, x + 1, 15, 60, 2, ar, 1) end
		text(cv, x, 5, 62, 9, names[i], i == 1 and T.c.text or T.c.dim, "CENTER", 12)
		x = x + 65
	end
	local menuOn = flag("chattabs.menu", true)
	text(cv, x + 2, 4, 18, 11, "...", menuOn and T.c.text or T.c.dim, "CENTER", 14)
	zone(cv, "tab", 4, 2, x - 4, 15)
	zone(cv, "popup", x, 2, 22, 15)
	panel(cv, 4, 18, 292, 74, T.c.inset, 0.9, T.c.border, 1)
	text(cv, 10, 24, 280, 9, "[1. General] Thorgrim: hello", T.c.text, "LEFT", 12)
	if ded then
		text(cv, 10, 38, 280, 9, K("chattabs", "moved"), T.c.dim, "LEFT", 12)
	else
		text(cv, 10, 38, 280, 9, "[2. World] Elaria: LFM RFC", T.c.text, "LEFT", 12)
	end
	text(cv, 10, 52, 280, 9, "[Guild] Mordan: +1", T.c.good, "LEFT", 12)
	if menuOn then
		panel(cv, x - 40, 20, 100, 44, T.c.panel, 1, ar, 1)
		text(cv, x - 36, 24, 92, 9, K("chattabs", "rename"), T.c.text, "LEFT", 12)
		text(cv, x - 36, 36, 92, 9, K("chattabs", "close"), T.c.text, "LEFT", 12)
		text(cv, x - 36, 48, 92, 9, K("chattabs", "templates"), T.c.text, "LEFT", 12)
	end
	chip(cv, 4, 98, 92, 14, K("chattabs", "restore"), flag("chattabs.restore", true))
	chip(cv, 100, 98, 92, 14, K("chattabs", "autosave"), flag("chattabs.autosave", true))
	chip(cv, 196, 98, 100, 14, K("chattabs", "setup"), auto)
	zone(cv, "restore", 4, 98, 92, 14)
	zone(cv, "autosave", 100, 98, 92, 14)
	zone(cv, "setup", 196, 98, 100, 14)
end

register("chattabs", { zones = { "tab", "popup", "restore", "autosave", "setup" },
	keys = { tab = "chattabs.dedicated", popup = "chattabs.menu", restore = "chattabs.restore", autosave = "chattabs.autosave", setup = "chattabs.autosetup" },
	cw = 300, ch = 116, paint = ctPaint, hint = "mod.preview.m1.chattabs.hint" })

-- ================================================================ compteurs de recharge (cooldowns)
local function cdFmt(t)
	if t >= 60 then return floor(t / 60 + 0.5) .. "m" end
	if t < 2 then return tostring(floor(t * 10 + 0.5) / 10) end
	return tostring(floor(t + 0.5))
end

local function cdPaint(cv)
	local mn, yel, red = num("cooldowns.min", 3), num("cooldowns.yellow", 10), num("cooldowns.red", 3)
	local mid = yel
	if yel > red + 1 then mid = (yel + red) / 2 end
	local list = {
		{ mn * 0.6, "<" .. mn, "min" }, { yel * 1.6 + 1, ">" .. yel, "min2" }, { mid, tostring(yel), "yellow" }, { red * 0.6 + 0.2, tostring(red), "red" },
	}
	for i = 1, getn(list) do
		local t = list[i][1]
		local x = 12 + (i - 1) * 70
		panel(cv, x, 8, 48, 48, T.c.panel, 1, T.c.border, 1)
		rect(cv, x + 2, 10, 44, 44, T.c.border, 0.35)
		rect(cv, x + 2, 10, 44, 28, T.c.bg, 0.6)
		if i > 1 then          -- la 1re icone = une recharge plus courte que la duree minimale : pas de chiffre
			local tok = T.c.text
			if t <= red then tok = T.c.bad elseif t <= yel then tok = T.c.warn end
			text(cv, x, 24, 48, 16, cdFmt(t), tok, "CENTER", 20)
		end
		text(cv, x, 60, 48, 9, list[i][2], T.c.dim, "CENTER", 12)
		zone(cv, list[i][3], x, 8, 48, 62)
	end
end

register("cooldowns", { zones = { "min", "min2", "yellow", "red" },
	keys = { min = "cooldowns.min", min2 = "cooldowns.min", yellow = "cooldowns.yellow", red = "cooldowns.red" },
	cw = 300, ch = 76, paint = cdPaint, hint = "mod.preview.m1.cooldowns.hint" })

-- ================================================================ infos ecran (datatext)
local DT = { { "money", "12g 40s" }, { "durab", "85%" }, { "clock", "21:04" }, { "fps", "60" }, { "latency", "45ms" }, { "xp", "42%" } }
local DTZ = { "win" }
for i = 1, getn(DT) do DTZ[i + 1] = "t_" .. DT[i][1] end
local DTK = { win = "datatext.scale" }
for i = 1, getn(DT) do DTK["t_" .. DT[i][1]] = "datatext." .. DT[i][1] end

local function dtPaint(cv)
	local s = num("datatext.scale", 100) / 100
	local on = {}
	for i = 1, getn(DT) do
		if flag("datatext." .. DT[i][1], false) then on[getn(on) + 1] = i end
	end
	local n = getn(on)
	local bw, bh = floor(56 * s), floor(26 * s)
	local cols = n
	if cols > 3 then cols = 3 end
	if cols < 1 then cols = 1 end
	local rows = ceil(n / 3)
	if rows < 1 then rows = 1 end
	local ww, wh = cols * (bw + 3) + 5, rows * (bh + 3) + 5
	local x0 = floor((300 - ww) / 2)
	panel(cv, x0, 4, ww, wh, T.c.panel, 0.95, T.c.border, 1)
	if n == 0 then
		text(cv, 4, 4 + floor(wh / 2) - 5, 292, 10, K("datatext", "none"), T.c.dim, "CENTER", 13)
	end
	for k = 1, n do
		local d = DT[on[k]]
		local cx = x0 + 4 + ((k - 1) - floor((k - 1) / 3) * 3) * (bw + 3)
		local cy = 7 + floor((k - 1) / 3) * (bh + 3)
		rect(cv, cx, cy, bw, bh, T.c.inset, 0.8)
		text(cv, cx, cy + 2, bw, 8 * s, M.Short(L("opt.datatext." .. d[1]), 9), T.c.dim, "CENTER", 11 * s)
		local tok = T.c.text
		if d[1] == "durab" then tok = T.c.good end
		text(cv, cx, cy + 3 + 9 * s, bw, 11 * s, d[2], tok, "CENTER", 14 * s)
	end
	zone(cv, "win", x0, 4, ww, wh)
	local y = 4 + wh + 8
	for i = 1, getn(DT) do
		local x = 4 + (i - 1) * 49
		chip(cv, x, y, 47, 14, M.Short(L("opt.datatext." .. DT[i][1]), 7), flag("datatext." .. DT[i][1], false))
		zone(cv, "t_" .. DT[i][1], x, y, 47, 14)
	end
end

register("datatext", { zones = DTZ, keys = DTK, cw = 300, ch = 126, paint = dtPaint, hint = "mod.preview.m1.datatext.hint" })

-- ================================================================ chercheur de groupe (finder)
-- { type, instance, niveau, age (min), places, auteur }
local FD = {
	{ "LFM", "RFC", 15, 1, 3, "Thorgrim" }, { "LFG", "WC", 18, 2, 0, "Elaria" }, { "LFM", "DM", 20, 5, 2, "Kaelith" },
	{ "LFM", "SFK", 24, 9, 1, "Thorgrim" }, { "LFM", "BRD", 52, 12, 4, "Mordan" }, { "LFG", "STRAT", 58, 14, 0, "Lyra" },
	{ "LFM", "MC", 60, 3, 15, "Garrosh" }, { "LFM", "UBRS", 58, 6, 6, "Sylva" },
}
local FDZ = { "rows", "stripe", "kind", "age", "scale", "listen", "sort", "look", "src1", "src2", "src3", "group" }
local FDK = { rows = "finder.rows", stripe = "finder.stripe", kind = "finder.colors", age = "finder.fade", scale = "finder.scale",
	listen = "finder.listen", sort = "finder.sort", look = "finder.look", src1 = "finder.src.channel", src2 = "finder.src.yell",
	src3 = "finder.src.say", group = "finder.group" }

local function fdBefore(sort, a, b)
	if sort == "level" then
		if a[3] ~= b[3] then return a[3] < b[3] end
	elseif sort == "places" then
		if a[5] ~= b[5] then return a[5] > b[5] end
	end
	return a[4] < b[4]
end

local function fdPaint(cv)
	local ar = accent()
	local compact = (pick("finder.look", "cards") == "compact")
	local sort = pick("finder.sort", "new")
	local expire = num("finder.expire", 15)
	local colors = pick("finder.colors", "kind")
	local grp = flag("finder.group", true)
	-- liste : une carte par auteur (la plus recente) avec compteur, puis tri
	local list = {}
	for i = 1, getn(FD) do
		local ad = FD[i]
		local at = nil
		if grp then
			for j = 1, getn(list) do
				if list[j].ad[6] == ad[6] then at = j end
			end
		end
		if at then
			list[at].n = list[at].n + 1
			if ad[4] < list[at].ad[4] then list[at].ad = ad end
		else
			list[getn(list) + 1] = { ad = ad, n = 1 }
		end
	end
	for i = 2, getn(list) do
		local q = list[i]
		local j = i - 1
		while j >= 1 and fdBefore(sort, q.ad, list[j].ad) do
			list[j + 1] = list[j]
			j = j - 1
		end
		list[j + 1] = q
	end
	chip(cv, 4, 0, 90, 14, chLab("finder.listen", pick("finder.listen", "auto")), true)
	chip(cv, 98, 0, 96, 14, chLab("finder.sort", sort), true)
	chip(cv, 198, 0, 98, 14, chLab("finder.look", pick("finder.look", "cards")), true)
	chip(cv, 4, 18, 60, 14, K("finder", "src1"), flag("finder.src.channel", true))
	chip(cv, 68, 18, 60, 14, K("finder", "src2"), flag("finder.src.yell", true))
	chip(cv, 132, 18, 60, 14, K("finder", "src3"), flag("finder.src.say", false))
	chip(cv, 196, 18, 100, 14, K("finder", "group"), grp)
	zone(cv, "listen", 4, 0, 90, 14)
	zone(cv, "sort", 98, 0, 96, 14)
	zone(cv, "look", 198, 0, 98, 14)
	zone(cv, "src1", 4, 18, 60, 14)
	zone(cv, "src2", 68, 18, 60, 14)
	zone(cv, "src3", 132, 18, 60, 14)
	zone(cv, "group", 196, 18, 100, 14)
	local rows = num("finder.rows", 7)
	local vis = compact and rows * 2 or rows
	local cap = compact and 10 or 4
	if vis > cap then vis = cap end
	if vis > getn(list) then vis = getn(list) end
	local ch = compact and 14 or 32
	local y0 = 40
	local firstOld = nil
	for i = 1, vis do
		local q = list[i]
		local ad = q.ad
		local y = y0 + (i - 1) * (ch + 2)
		local ktok = (ad[1] == "LFM") and T.c.good or T.c.warn
		if colors == "accent" then ktok = ar elseif colors == "mono" then ktok = T.c.text end
		local old = flag("finder.fade", true) and ad[4] >= expire * 0.8
		local atok = old and T.c.warn or T.c.dim
		panel(cv, 4, y, 280, ch, T.c.panel, 0.95, T.c.border, 1)
		if flag("finder.stripe", true) then rect(cv, 5, y + 1, 3, ch - 2, ktok, 1) end
		local who = ad[6]
		if q.n > 1 then who = who .. " x" .. q.n end
		if compact then
			text(cv, 12, y + 2, 28, 9, ad[1], ktok, "LEFT", 12)
			text(cv, 42, y + 2, 38, 9, ad[2], T.c.text, "LEFT", 12)
			text(cv, 82, y + 2, 90, 9, who, T.c.dim, "LEFT", 12)
			text(cv, 176, y + 2, 60, 9, ad[5] .. " " .. K("finder", "places"), T.c.dim, "LEFT", 12)
			text(cv, 244, y + 2, 36, 9, ad[4] .. "m", atok, "RIGHT", 12)
		else
			text(cv, 12, y + 2, 30, 9, ad[1], ktok, "LEFT", 12)
			text(cv, 44, y + 2, 120, 9, ad[2] .. "  L" .. ad[3], T.c.text, "LEFT", 12)
			text(cv, 230, y + 2, 50, 9, ad[4] .. "m", atok, "RIGHT", 12)
			text(cv, 12, y + 12, 160, 9, who, T.c.text, "LEFT", 12)
			text(cv, 12, y + 22, 200, 9, ad[5] .. " " .. K("finder", "places"), T.c.dim, "LEFT", 12)
		end
		if i == 1 then
			zone(cv, "stripe", 5, y + 1, 4, ch - 2)
			zone(cv, "kind", 12, y + 1, 30, 11)
		end
		if old and not firstOld then firstOld = i end
	end
	local ai = firstOld or vis
	if ai >= 1 then zone(cv, "age", 230, y0 + (ai - 1) * (ch + 2), 54, 12) end
	if vis >= 1 then zone(cv, "rows", 4, y0, 280, vis * (ch + 2) - 2) end
	zone(cv, "scale", 288, 0, 10, y0 + vis * (ch + 2))
end

register("finder", { zones = FDZ, keys = FDK, cw = 300, ch = 192, paint = fdPaint, hint = "mod.preview.m1.finder.hint" })

-- ================================================================ jeux d'equipement et bijoux (items)
local ITZ = { "bar", "sets", "trink", "size", "alpha", "cd", "build", "menu", "grow", "char", "charbtn" }
local ITK = { bar = "items.bar", sets = "items.showsets", trink = "items.trinkets", size = "items.size", alpha = "items.alpha",
	cd = "items.cooldowns", build = "items.buildbtn", menu = "items.menumax", grow = "items.growup", char = "items.charbtn",
	charbtn = "items.charpos" }
local ITSETS = { "Tank", "DPS", "PvP" }

local function itPaint(cv)
	local ar = accent()
	local barOn = flag("items.bar", true)
	local a = num("items.alpha", 1)
	local px = floor(num("items.size", 30) * 0.8)
	local gap = 3
	local ghost = barOn and 1 or 0.3
	local setsOn, trOn, buildOn = flag("items.showsets", true), flag("items.trinkets", true), flag("items.buildbtn", true)
	local by = 104
	local nb = 3 + 2 + 1
	local totalw = nb * px + (nb + 1) * gap
	panel(cv, 2, by - 3, totalw, px + 6, T.c.bg, 0.8 * ghost, T.c.border, ghost, 1)
	local x = 2 + gap
	local sx = x
	for i = 1, 3 do
		local g = (setsOn and 1 or 0.3) * ghost * a
		panel(cv, x, by, px, px, T.c.panel, g, i == 1 and ar or T.c.border, g, 1)
		text(cv, x, by + floor((px - 9) / 2), px, 9, ITSETS[i], T.c.text, "CENTER", 12)
		x = x + px + gap
	end
	local tx = x
	local cdOn = flag("items.cooldowns", true)
	for i = 1, 2 do
		local g = (trOn and 1 or 0.3) * ghost * a
		panel(cv, x, by, px, px, T.c.panel, g, T.c.border, g, 1)
		rect(cv, x + 2, by + 2, px - 4, px - 4, i == 1 and T.c.warn or T.c.good, 0.5 * g)
		if i == 1 and cdOn then
			rect(cv, x + 2, by + 2, px - 4, floor((px - 4) * 0.6), T.c.bg, 0.65 * g)
			text(cv, x, by + floor((px - 10) / 2), px, 10, "45", T.c.text, "CENTER", 13)
		end
		x = x + px + gap
	end
	local bx = x
	local gb = (buildOn and 1 or 0.3) * ghost * a
	panel(cv, x, by, px, px, T.c.panel, gb, T.c.border, gb, 1)
	text(cv, x, by + floor((px - 9) / 2), px, 9, "B", T.c.text, "CENTER", 12)
	if not barOn then text(cv, 2, by + px + 8, totalw, 9, K("items", "hidden"), T.c.dim, "CENTER", 12) end
	-- menu des bijoux (vers le haut ou vers le bas)
	local nmenu = num("items.menumax", 6)
	if nmenu > 8 then nmenu = 8 end
	local up = flag("items.growup", false)
	local mh = nmenu * 11 + 4
	local my = up and (by - 5 - mh) or (by + px + 5)
	panel(cv, tx, my, 70, mh, T.c.panel, 0.95, ar, 1)
	for i = 1, nmenu do text(cv, tx + 4, my + 2 + (i - 1) * 11, 62, 9, K("items", "trinket") .. " " .. i, T.c.text, "LEFT", 11) end
	text(cv, tx + 74, up and (my + mh - 12) or my, 22, 12, up and "^" or "v", ar, "LEFT", 14)
	-- fenetre du personnage : bouton Builds (place et aspect)
	local cbOn = flag("items.charbtn", true)
	local cg = cbOn and 1 or 0.35
	local pos = pick("items.charpos", "top")
	local style = pick("items.charstyle", "label")
	local btxt = "Builds"
	if style == "current" then btxt = "Tank" elseif style == "compact" then btxt = "B" end
	local fx, fy, fw, fh = 204, 14, 92, 44
	local bbx, bby, bbw, bbh = 204, 2, 92, 11
	if pos == "bottom" then
		bby = 60
	elseif pos == "side" then
		fx, fw = 232, 64
		bbx, bby, bbw, bbh = 204, 14, 26, 44
	end
	panel(cv, fx, fy, fw, fh, T.c.panel, 0.9, T.c.border, 1)
	text(cv, fx, fy + 4, fw, 9, K("items", "char"), T.c.dim, "CENTER", 12)
	panel(cv, bbx, bby, bbw, bbh, T.c.panel, cg, ar, cg)
	text(cv, bbx, bby + floor((bbh - 9) / 2), bbw, 9, btxt, T.c.text, "CENTER", 12)
	-- zones (la derniere est au-dessus)
	zone(cv, "bar", 2, by - 3, totalw, px + 6)
	zone(cv, "alpha", 2 + totalw - 5, by - 3, 6, px + 6)
	zone(cv, "sets", sx, by, 3 * (px + gap) - gap, px)
	zone(cv, "trink", tx, by, 2 * (px + gap) - gap, px)
	zone(cv, "cd", tx, by, px, px)
	zone(cv, "build", bx, by, px, px)
	zone(cv, "size", 2, by + px + 3, totalw, 4)
	zone(cv, "menu", tx, my, 70, mh)
	zone(cv, "grow", tx + 74, up and (my + mh - 12) or my, 22, 14)
	zone(cv, "char", fx, fy, fw, fh)
	zone(cv, "charbtn", bbx, bby, bbw, bbh)
end

register("items", { zones = ITZ, keys = ITK, cw = 300, ch = 242, paint = itPaint, hint = "mod.preview.m1.items.hint" })

-- ================================================================ macros a conditions (macros)
local function mcPaint(cv)
	local ar = accent()
	local syn = flag("macros.syntax", true)
	local lenwarn = num("macros.lenwarn", 230)
	local n = 240
	panel(cv, 4, 2, 292, 112, T.c.panel, 0.95, T.c.border, 1)
	rect(cv, 5, 3, 290, 14, T.c.inset, 1)
	text(cv, 10, 6, 100, 9, "Macro", T.c.text, "LEFT", 12)
	local nt = (n >= lenwarn) and T.c.warn or T.c.dim
	text(cv, 150, 6, 52, 9, n .. "/255", nt, "RIGHT", 12)
	local mf = flag("macros.mfbutton", true)
	chip(cv, 232, 4, 60, 11, K("macros", "edit"), mf)
	-- code : #showtooltip / conditions (colorees si la coloration est active)
	text(cv, 10, 24, 120, 9, "#showtooltip Heal", syn and ar or T.c.text, "LEFT", 12)
	text(cv, 10, 38, 34, 9, "/cast", syn and T.c.good or T.c.text, "LEFT", 12)
	text(cv, 46, 38, 62, 9, "[mod:shift]", syn and T.c.warn or T.c.text, "LEFT", 12)
	text(cv, 112, 38, 120, 9, "Flash Heal; Heal", T.c.text, "LEFT", 12)
	text(cv, 10, 52, 34, 9, "/cast", syn and T.c.good or T.c.text, "LEFT", 12)
	text(cv, 46, 52, 90, 9, "[@mouseover,help]", syn and T.c.warn or T.c.text, "LEFT", 12)
	text(cv, 140, 52, 60, 9, "Hea", T.c.text, "LEFT", 12)
	local ac = flag("macros.autocomplete", true)
	local ga = ac and 1 or 0.3
	panel(cv, 138, 64, 90, 38, T.c.inset, ga, ar, ga)
	text(cv, 142, 67, 82, 9, "Heal", T.c.text, "LEFT", 11)
	text(cv, 142, 78, 82, 9, "Healing Touch", T.c.dim, "LEFT", 11)
	text(cv, 142, 89, 82, 9, "Healing Wave", T.c.dim, "LEFT", 11)
	local pv = flag("macros.preview", true)
	text(cv, 10, 100, 240, 9, K("macros", "prev"), pv and ar or T.c.dim, "LEFT", 12)
	-- chat : ligne #showtooltip masquee ou non, mode bavard
	panel(cv, 4, 118, 292, 26, T.c.inset, 0.9, T.c.border, 1)
	if flag("macros.hidehint", true) then
		text(cv, 10, 122, 280, 9, K("macros", "hidden"), T.c.dim, "LEFT", 12)
	else
		text(cv, 10, 122, 280, 9, "#showtooltip Heal", T.c.text, "LEFT", 12)
	end
	if flag("macros.verbose", false) then text(cv, 10, 133, 280, 9, K("macros", "say"), T.c.good, "LEFT", 12) end
	chip(cv, 4, 150, 140, 14, K("macros", "exec"), flag("macros.exec", true))
	chip(cv, 150, 150, 140, 14, K("macros", "verbose"), flag("macros.verbose", false))
	zone(cv, "syntax", 8, 22, 190, 42)
	zone(cv, "auto", 138, 64, 90, 38)
	zone(cv, "prev", 8, 98, 240, 13)
	zone(cv, "len", 150, 3, 54, 14)
	zone(cv, "btn", 232, 3, 60, 13)
	zone(cv, "chat", 4, 118, 292, 26)
	zone(cv, "exec", 4, 150, 140, 14)
	zone(cv, "verbose", 150, 150, 140, 14)
end

register("macros", { zones = { "syntax", "auto", "prev", "len", "btn", "chat", "exec", "verbose" },
	keys = { syntax = "macros.syntax", auto = "macros.autocomplete", prev = "macros.preview", len = "macros.lenwarn", btn = "macros.mfbutton",
		chat = "macros.hidehint", exec = "macros.exec", verbose = "macros.verbose" },
	cw = 300, ch = 168, paint = mcPaint, hint = "mod.preview.m1.macros.hint" })

-- ================================================================ marques de raid (marks)
local MKS = { { "*", "warn" }, { "o", "warn" }, { "<>", "acc" }, { "^", "good" }, { ")", "dim" }, { "#", "acc" }, { "x", "bad" }, { "S", "text" } }
local MKZ = { "bar", "i1", "i2", "i3", "i4", "i5", "i6", "i7", "i8", "vertical", "border" }
local MKK = { bar = "marks.vertical", vertical = "marks.vertical", border = "marks.border" }
for i = 1, 8 do MKK["i" .. i] = "marks.size" end

local function mkDims()
	local sz = floor(num("marks.size", 24) * 0.8)
	if flag("marks.vertical", false) then return 300, 8 + 8 * (sz + 2) + 24 end
	return 300, 8 + sz + 30
end

local function mkPaint(cv)
	local ar = accent()
	local sz = floor(num("marks.size", 24) * 0.8)
	local vert, bd = flag("marks.vertical", false), flag("marks.border", true)
	local bwid, bhei = 8 * (sz + 2) + 2, sz + 4
	local x0 = 8
	if vert then
		bwid, bhei = sz + 4, 8 * (sz + 2) + 2
		x0 = 130
	else
		x0 = floor((300 - bwid) / 2)
	end
	panel(cv, x0 - 2, 6, bwid, bhei, T.c.bg, 0.8, T.c.border, 0.8, 1)
	zone(cv, "bar", x0 - 2, 6, bwid, bhei)
	for i = 1, 8 do
		local ix = vert and (x0) or (x0 + (i - 1) * (sz + 2))
		local iy = vert and (8 + (i - 1) * (sz + 2)) or 8
		local d = MKS[i]
		local tok = T.c.dim
		if d[2] == "acc" then tok = ar elseif d[2] == "warn" then tok = T.c.warn elseif d[2] == "good" then tok = T.c.good
		elseif d[2] == "bad" then tok = T.c.bad elseif d[2] == "text" then tok = T.c.text end
		if bd then panel(cv, ix, iy, sz, sz, T.c.panel, 1, T.c.border, 1) else rect(cv, ix, iy, sz, sz, T.c.panel, 1) end
		rect(cv, ix + 3, iy + 3, sz - 6, sz - 6, tok, 0.35)
		text(cv, ix, iy + floor((sz - 10) / 2), sz, 10, d[1], tok, "CENTER", 13)
		zone(cv, "i" .. i, ix, iy, sz, sz)
	end
	local cy = vert and (8 + 8 * (sz + 2) + 6) or (8 + sz + 12)
	chip(cv, 70, cy, 70, 14, K("marks", "vertical"), vert)
	chip(cv, 160, cy, 70, 14, K("marks", "border"), bd)
	zone(cv, "vertical", 70, cy, 70, 14)
	zone(cv, "border", 160, cy, 70, 14)
end

register("marks", { zones = MKZ, keys = MKK, dims = mkDims, paint = mkPaint, hint = "mod.preview.m1.marks.hint" })

-- ================================================================ benedictions de raid (pallypower)
local PPC = { { "War", "WARRIOR", "Mi", "Ki" }, { "Pri", "PRIEST", "Wi", "Ki" }, { "Mag", "MAGE", "Wi", "Ki" }, { "Rog", "ROGUE", "Mi", "Ki" } }

local function ppPaint(cv)
	local ar = accent()
	local greater = flag("pallypower.greater", true)
	panel(cv, 40, 4, 220, 98, T.c.panel, 0.95, T.c.border, 1)
	text(cv, 44, 8, 100, 9, "Paladin", T.c.dim, "LEFT", 12)
	for i = 1, getn(PPC) do
		local y = 22 + (i - 1) * 19
		local c = PPC[i]
		rect(cv, 44, y, 212, 17, T.c.inset, 0.8)
		text(cv, 48, y + 4, 34, 9, c[1], classTok(c[2]), "LEFT", 12)
		for k = 1, 2 do
			local x = 90 + (k - 1) * 82
			panel(cv, x, y + 1, 76, 15, T.c.panel, 1, greater and ar or T.c.border, 1)
			text(cv, x + 3, y + 4, 30, 9, c[2 + k], T.c.text, "LEFT", 12)
			text(cv, x + 36, y + 4, 36, 9, greater and "15m" or "5m", T.c.dim, "RIGHT", 12)
		end
	end
	zone(cv, "grid", 44, 20, 212, 78)
	local jd = pick("pallypower.judge", "none")
	chip(cv, 40, 108, 108, 14, K("pallypower", "greater"), greater)
	chip(cv, 154, 108, 106, 14, K("pallypower", "judge") .. ": " .. chLab("pallypower.judge", jd), jd ~= "none")
	zone(cv, "greater", 40, 108, 108, 14)
	zone(cv, "judge", 154, 108, 106, 14)
end

register("pallypower", { zones = { "grid", "greater", "judge" },
	keys = { grid = "pallypower.greater", greater = "pallypower.greater", judge = "pallypower.judge" },
	cw = 300, ch = 126, paint = ppPaint, hint = "mod.preview.m1.pallypower.hint" })

-- ================================================================ habillage des fenetres (skin)
local SKF = { "menu", "options", "character", "spellbook", "talents", "questlog", "merchant", "trade", "mail", "bank", "loot", "worldmap" }
local SKC = { { "contrast", "skin.contrast" }, { "tint", "skin.tint" }, { "border", "skin.border" }, { "corners", "skin.corners" },
	{ "font", "skin.font" }, { "parchment", "skin.parchment" } }
local SKB = { { "yield", "skin.yield" }, { "talent", "skin.talentlight" }, { "art", "skin.art" } }
local SKZ = { "win", "frame", "bar", "corner", "lab", "txt", "parch", "dots", "artz" }
local SKK = { win = "skin.alpha", frame = "skin.border", bar = "skin.tint", corner = "skin.corners", lab = "skin.font", txt = "skin.fontscale",
	parch = "skin.parchment", dots = "skin.talentlight", artz = "skin.art" }
for i = 1, getn(SKC) do
	SKZ[getn(SKZ) + 1] = "c_" .. SKC[i][1]
	SKK["c_" .. SKC[i][1]] = SKC[i][2]
end
for i = 1, getn(SKB) do
	SKZ[getn(SKZ) + 1] = "c_" .. SKB[i][1]
	SKK["c_" .. SKB[i][1]] = SKB[i][2]
end
for i = 1, getn(SKF) do
	SKZ[getn(SKZ) + 1] = "f_" .. SKF[i]
	SKK["f_" .. SKF[i]] = "skin.f." .. SKF[i]
end

local function skPaint(cv)
	local ar = accent()
	local contrast, tint = pick("skin.contrast", "normal"), pick("skin.tint", "off")
	local border, corners = pick("skin.border", "style"), pick("skin.corners", "style")
	local fontm, fscale = pick("skin.font", "labels"), num("skin.fontscale", 1)
	local parch = pick("skin.parchment", "keep")
	local alpha = num("skin.alpha", 0.95)
	local th = 1
	if border == "none" then th = 0 elseif border == "thick" then th = 3 end
	local fill, edge, ea = T.c.panel, T.c.border, 1
	if contrast == "soft" then
		ea = 0.5
	elseif contrast == "high" then
		fill, edge = T.c.inset, T.c.text
	end
	if tint == "border" or tint == "both" then edge, ea = ar, 1 end
	panel(cv, 4, 4, 190, 130, fill, alpha, edge, ea, th)
	local tb = ((tint == "title" or tint == "both") and ar) or T.c.border
	rect(cv, 4 + th, 4 + th, 190 - 2 * th, 16, tb, (tb == ar) and 0.7 or 0.9)
	local ltok = (fontm == "off") and T.c.dim or T.c.text
	text(cv, 10, 8, 120, 10 * fscale, K("skin", "title"), ltok, "LEFT", 14 * fscale)
	local pa = (parch == "dark") and T.c.inset or T.c.warn
	rect(cv, 12, 28, 174, 66, pa, (parch == "dark") and 1 or 0.22)
	text(cv, 16, 34, 166, 9 * ((fontm == "all") and fscale or 1), K("skin", "body"), (fontm == "all") and T.c.text or T.c.dim, "LEFT", 14 * fscale)
	local tl = flag("skin.talentlight", true)
	for i = 1, 5 do
		panel(cv, 16 + (i - 1) * 20, 62, 16, 16, T.c.panel, 1, T.c.border, 1)
		rect(cv, 19 + (i - 1) * 20, 65, 10, 10, T.c.text, tl and 0.9 or 0.4)
	end
	if corners == "round" then
		rect(cv, 4, 4, 3, 3, T.c.bg, 1)
		rect(cv, 191, 4, 3, 3, T.c.bg, 1)
		rect(cv, 4, 131, 3, 3, T.c.bg, 1)
		rect(cv, 191, 131, 3, 3, T.c.bg, 1)
	end
	if not flag("skin.art", true) then
		rect(cv, 170, 5, 22, 14, T.c.warn, 0.55)
		rect(cv, 5, 120, 30, 12, T.c.warn, 0.55)
	end
	chip(cv, 12, 104, 174, 14, K("skin", "yield"), flag("skin.yield", true))
	zone(cv, "win", 4, 4, 190, 130)
	zone(cv, "frame", 4, 4, 190, 4)
	zone(cv, "bar", 20, 5, 150, 15)
	zone(cv, "corner", 4, 4, 8, 8)
	zone(cv, "lab", 10, 8, 80, 11)
	zone(cv, "txt", 16, 34, 166, 12)
	zone(cv, "parch", 12, 50, 174, 10)
	zone(cv, "dots", 16, 62, 96, 16)
	zone(cv, "artz", 170, 5, 22, 14)
	for i = 1, getn(SKC) do
		local c = SKC[i]
		chip(cv, 200, 4 + (i - 1) * 17, 96, 14, chLab(c[2], pick(c[2], "")), true)
		zone(cv, "c_" .. c[1], 200, 4 + (i - 1) * 17, 96, 14)
	end
	local by = 4 + getn(SKC) * 17
	for i = 1, getn(SKB) do
		local c = SKB[i]
		chip(cv, 200, by + (i - 1) * 17 - 0, 96, 14, K("skin", c[1]), flag(c[2], true))
		zone(cv, "c_" .. c[1], 200, by + (i - 1) * 17, 96, 14)
	end
	for i = 1, getn(SKF) do
		local x = 4 + ((i - 1) - floor((i - 1) / 4) * 4) * 74
		local y = 162 + floor((i - 1) / 4) * 16
		chip(cv, x, y, 70, 13, M.Short(L("opt.skin.f." .. SKF[i]), 10), flag("skin.f." .. SKF[i], true))
		zone(cv, "f_" .. SKF[i], x, y, 70, 13)
	end
end

register("skin", { zones = SKZ, keys = SKK, cw = 300, ch = 214, paint = skPaint, hint = "mod.preview.m1.skin.hint" })

-- ================================================================ specialisations (specs)
local SPC = { { "auto", "specs.auto", "auto" }, { "announce", "specs.announce", "announce" }, { "bars", "specs.bars", "bars" },
	{ "clear", "specs.bars.clear", "clear" }, { "btn", "specs.btn", "btn" } }
local SPZ = { "tree", "btnz", "say", "btnpos", "btnstyle", "delay", "minpoints" }
local SPK = { tree = "specs.auto", btnz = "specs.btnpos", say = "specs.announce", btnpos = "specs.btnpos", btnstyle = "specs.btnstyle",
	delay = "specs.delay", minpoints = "specs.minpoints" }
for i = 1, getn(SPC) do
	SPZ[getn(SPZ) + 1] = "c_" .. SPC[i][1]
	SPK["c_" .. SPC[i][1]] = SPC[i][2]
end

local function spPaint(cv)
	local ar = accent()
	local pts = { 31, 20, 0 }
	panel(cv, 4, 4, 196, 100, T.c.panel, 0.95, T.c.border, 1)
	for i = 1, 3 do
		local x = 8 + (i - 1) * 62
		rect(cv, x, 22, 58, 66, T.c.inset, 0.9)
		rect(cv, x, 22 + 66 - floor(pts[i] * 66 / 51), 58, floor(pts[i] * 66 / 51), (i == 1) and ar or T.c.border, 0.45)
		text(cv, x, 8, 58, 9, tostring(pts[i]), (i == 1) and T.c.text or T.c.dim, "CENTER", 12)
	end
	-- bouton Jeux ShikiUI sur la fenetre des talents
	local on = flag("specs.btn", true)
	local g = on and 1 or 0.35
	local pos, sty = pick("specs.btnpos", "bottom"), pick("specs.btnstyle", "full")
	local btxt = K("specs", "btnfull")
	if sty == "label" then btxt = K("specs", "btnlabel") elseif sty == "compact" then btxt = "J" end
	local bw, bx, by, bh = 100, 8, 90, 12
	if sty == "label" then bw = 50 elseif sty == "compact" then bw = 20 end
	if pos == "top" then
		bx, by = 100, 6
	elseif pos == "side" then
		bx, by, bw, bh = 204, 30, 20, 40
		btxt = "J"
	end
	panel(cv, bx, by, bw, bh, T.c.panel, g, ar, g)
	text(cv, bx, by + floor((bh - 9) / 2), bw, 9, btxt, T.c.text, "CENTER", 12)
	zone(cv, "tree", 4, 18, 196, 70)
	zone(cv, "btnz", bx, by, bw, bh)
	if flag("specs.announce", true) then
		text(cv, 4, 110, 196, 9, K("specs", "say"), T.c.good, "LEFT", 12)
	else
		text(cv, 4, 110, 196, 9, "-", T.c.dim, "LEFT", 12)
	end
	text(cv, 4, 122, 196, 9, "2 -> Tank", T.c.dim, "LEFT", 12)
	zone(cv, "say", 4, 108, 196, 12)
	local cx = 210
	if pos == "side" then cx = 226 end
	local cw = 296 - cx
	for i = 1, getn(SPC) do
		local c = SPC[i]
		chip(cv, cx, 4 + (i - 1) * 17, cw, 14, K("specs", c[3]), flag(c[2], false))
		zone(cv, "c_" .. c[1], cx, 4 + (i - 1) * 17, cw, 14)
	end
	local y = 4 + getn(SPC) * 17
	chip(cv, cx, y, cw, 14, chLab("specs.btnpos", pos), true)
	chip(cv, cx, y + 17, cw, 14, chLab("specs.btnstyle", sty), true)
	chip(cv, cx, y + 34, cw, 14, num("specs.delay", 3) .. "s", true)
	chip(cv, cx, y + 51, cw, 14, num("specs.minpoints", 5) .. " pts", true)
	zone(cv, "btnpos", cx, y, cw, 14)
	zone(cv, "btnstyle", cx, y + 17, cw, 14)
	zone(cv, "delay", cx, y + 34, cw, 14)
	zone(cv, "minpoints", cx, y + 51, cw, 14)
end

register("specs", { zones = SPZ, keys = SPK, cw = 300, ch = 150, paint = spPaint, hint = "mod.preview.m1.specs.hint" })

-- ================================================================ vendeur (vendor)
local VDC = { { "sell", "vendor.sell" }, { "repair", "vendor.repair" }, { "guild", "vendor.guild" }, { "announce", "vendor.announce" },
	{ "btns", "vendor.btn" } }
local VDZ = { "items", "sellbtn", "repbtn", "ask", "chat", "delay", "confirm" }
local VDK = { items = "vendor.sell", sellbtn = "vendor.sell", repbtn = "vendor.repair", ask = "vendor.confirm.repair", chat = "vendor.announce",
	delay = "vendor.delay", confirm = "vendor.confirm.repair" }
for i = 1, getn(VDC) do
	VDZ[getn(VDZ) + 1] = "c_" .. VDC[i][1]
	VDK["c_" .. VDC[i][1]] = VDC[i][2]
end

local function vdPaint(cv)
	local ar = accent()
	local sell, rep = flag("vendor.sell", true), flag("vendor.repair", true)
	local btn = flag("vendor.btn", true)
	panel(cv, 4, 4, 170, 110, T.c.panel, 0.95, T.c.border, 1)
	rect(cv, 5, 5, 168, 14, T.c.inset, 1)
	text(cv, 10, 8, 120, 9, K("vendor", "title"), T.c.text, "LEFT", 12)
	for i = 1, 15 do
		local cx = 12 + ((i - 1) - floor((i - 1) / 5) * 5) * 30
		local cy = 24 + floor((i - 1) / 5) * 24
		local junk = (i == 2 or i == 7 or i == 8 or i == 13)
		panel(cv, cx, cy, 22, 22, T.c.inset, 1, T.c.border, 1)
		if junk then
			rect(cv, cx + 3, cy + 3, 16, 16, T.c.dim, sell and 0.12 or 0.6)
		else
			rect(cv, cx + 3, cy + 3, 16, 16, (i - floor(i / 2) * 2 == 1) and ar or T.c.good, 0.5)
		end
	end
	local g = btn and 1 or 0.3
	panel(cv, 10, 98, 76, 13, T.c.panel, g, sell and ar or T.c.border, g)
	text(cv, 10, 100, 76, 9, K("vendor", "sellbtn"), T.c.text, "CENTER", 12)
	panel(cv, 92, 98, 76, 13, T.c.panel, g, rep and ar or T.c.border, g)
	text(cv, 92, 100, 76, 9, K("vendor", "repair"), T.c.text, "CENTER", 12)
	local cost, conf = 15, num("vendor.confirm.repair", 10)
	if rep and cost > conf then
		panel(cv, 30, 46, 114, 30, T.c.bg, 1, ar, 1)
		text(cv, 30, 52, 114, 9, K("vendor", "ask"), T.c.text, "CENTER", 12)
		text(cv, 30, 64, 114, 9, conf .. "g", T.c.dim, "CENTER", 12)
	end
	zone(cv, "items", 12, 24, 150, 70)
	zone(cv, "sellbtn", 10, 98, 76, 13)
	zone(cv, "repbtn", 92, 98, 76, 13)
	if rep and cost > conf then zone(cv, "ask", 30, 46, 114, 30) end
	-- resume dans le chat
	panel(cv, 4, 120, 292, 26, T.c.inset, 0.9, T.c.border, 1)
	local an = flag("vendor.announce", true)
	local gtok = an and T.c.text or T.c.dim
	text(cv, 10, 123, 280, 9, an and K("vendor", "sold") or "-", an and T.c.good or gtok, "LEFT", 12)
	local rtxt = K("vendor", "repaired")
	if flag("vendor.guild", true) then rtxt = rtxt .. " " .. K("vendor", "guildtag") end
	text(cv, 10, 134, 280, 9, an and rtxt or "-", an and T.c.warn or gtok, "LEFT", 12)
	zone(cv, "chat", 4, 120, 292, 26)
	-- reglages a droite
	local cx, cw = 180, 116
	for i = 1, getn(VDC) do
		local c = VDC[i]
		chip(cv, cx, 4 + (i - 1) * 17, cw, 14, K("vendor", c[1]), flag(c[2], true))
		zone(cv, "c_" .. c[1], cx, 4 + (i - 1) * 17, cw, 14)
	end
	local y = 4 + getn(VDC) * 17
	chip(cv, cx, y, cw, 14, num("vendor.delay", 0.2) .. "s", true)
	chip(cv, cx, y + 17, cw, 14, "> " .. conf .. "g", true)
	zone(cv, "delay", cx, y, cw, 14)
	zone(cv, "confirm", cx, y + 17, cw, 14)
end

register("vendor", { zones = VDZ, keys = VDK, cw = 300, ch = 150, paint = vdPaint, hint = "mod.preview.m1.vendor.hint" })

