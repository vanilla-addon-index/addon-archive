-- ShikiUI Preview_Layout : apercu de la MISE EN PAGE du volet d'apercu du menu. Un ecran miniature (au format de l'ecran reel) montre un
-- rectangle par cadre enregistre dans SUI.Layout (joueur, cible, incantation, buffs, barres d'action, raid, groupe, discussion, minicarte,
-- compteur de degats, menace...) a sa place REELLE (position et taille du cadre ; a defaut la position enregistree ou la position par
-- defaut), et les LIENS entre cadres (SUI.Layout.GetLink(enfant) -> parent, cote, dx, dy, quand cette API existe : appel garde) en traits.
-- Un clic sur un rectangle saute aux reglages du module (M.Open("cat", module)). C'est aussi l'apercu de repli : les pages sans apercu
-- propre montrent cette vue, avec le rectangle de leur module surligne.
-- Aucun cadre n'est cree dans update : 48 rectangles + 40 traits prepares dans build. Jamais de lecture ni d'ecriture sur les vrais cadres.
-- NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local P = SUI.Preview

local getn, tinsert = table.getn, table.insert
local floor = math.floor
local sfind, ssub = string.find, string.sub

local NRECT, NLINK = 64, 24
local PTS = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }

-- Categorie du menu qui regle un cadre de mise en page (par cle exacte, puis par prefixe avant le premier point).
local CATOF = { ["raid"] = "raid", ["hud"] = "perf", ["minimap"] = "minimap", ["loot"] = "loot", ["items"] = "items", ["mail"] = "mail",
	["auction"] = "auction", ["tracker"] = "tracker", ["tracker.win"] = "tracker", ["unit"] = "units", ["bars"] = "actionbars",
	["castbar"] = "castbar", ["auras"] = "auras", ["meter"] = "meter", ["threat"] = "threat", ["tanktools"] = "tanktools",
	["totems"] = "totems", ["chat"] = "chat", ["messages"] = "messages", ["group"] = "group", ["bags"] = "bags", ["nameplates"] = "nameplates" }

local function catOfKey(key)
	local c = CATOF[key]
	if c then return c end
	local _, _, pre = sfind(key, "^([^.]+)%.")
	c = pre and CATOF[pre]
	if c then return c end
	if pre and M.CatExists(pre) then return pre end
	if M.CatExists(key) then return key end
	return nil
end

local function labelOf(key)
	local Mv = SUI.Mover
	if Mv and type(Mv.Label) == "function" then
		local ok, s = pcall(Mv.Label, key)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return key
end

-- Rectangle d'un cadre en unites d'UIParent (gauche, bas, largeur, hauteur).
local function rectOf(key, it, uw, uh)
	local RectFn = SUI.Layout.Rect         -- API des liens (Layouts.lua) : rectangle calcule, lien compris ; appel garde
	if type(RectFn) == "function" then
		local ok, l, b, rw, rh = pcall(RectFn, key)
		if ok and type(l) == "number" and type(b) == "number" and type(rw) == "number" and type(rh) == "number" and rw > 1 and rh > 1 then
			return l, b, rw, rh
		end
	end
	local f = it.frame
	local w, h
	if f then
		w, h = f:GetWidth(), f:GetHeight()
		local l, b = f:GetLeft(), f:GetBottom()
		if l and b and w and h and w > 1 and h > 1 then
			local sc = 1
			if f.GetEffectiveScale and UIParent.GetEffectiveScale then
				local fe, pe = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
				if fe and pe and pe > 0 then sc = fe / pe end
			end
			return l * sc, b * sc, w * sc, h * sc
		end
	end
	if not w or w < 2 then w = 120 end
	if not h or h < 2 then h = 40 end
	local fs = (f and f.GetScale and f:GetScale()) or 1
	w, h = w * fs, h * fs
	local l, b = SUI.Config.GetPos(SUI.Layout.ReadKey(key))
	if l and b then return l, b, w, h end
	local a = PTS[it.point] or PTS.CENTER
	return a[1] * uw + (it.x or 0) - a[1] * w, a[2] * uh + (it.y or 0) - a[2] * h, w, h
end

local function sortedKeys()
	local keys = {}
	for k, _ in pairs(SUI.Layout.items) do tinsert(keys, k) end
	table.sort(keys)
	return keys
end

local function newLine(parent)
	local t = P.NewTex(parent, "OVERLAY")
	t:Hide()
	return t
end

local function seg(t, scr, x1, y1, x2, y2)
	-- trait horizontal ou vertical entre deux points (pixels de l'ecran miniature, y vers le bas)
	local x, y, w, h
	if y1 == y2 then
		x, y, w, h = (x1 < x2) and x1 or x2, y1, math.abs(x2 - x1), 2
	else
		x, y, w, h = x1, (y1 < y2) and y1 or y2, 2, math.abs(y2 - y1)
	end
	P.Box(t, scr, x, y - 1, w + 1, h)
end

local function build(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { rects = {}, lines = {}, map = {}, cats = {}, ent = {} }
	for i = 1, NRECT do st.ent[i] = { key = "", l = 0, b = 0, w = 0, h = 0, area = 0 } end
	root.st = st
	root.scr = CreateFrame("Frame", nil, root)
	root.scr:SetFrameLevel(P.Lv(1))
	T.Backdrop(root.scr, T.c.inset, T.c.border)
	st.hint = T.Text(root, 10, T.c.dim, "LEFT")
	st.hint:SetHeight(26)
	st.hint:SetJustifyV("TOP")
	for i = 1, NRECT do
		local z = P.Zone(root.scr, "r" .. i, 2)
		z.edge = P.NewTex(z, "BACKGROUND")
		z.fill = P.NewTex(z, "BORDER")
		z.lab = T.Text(z, 8, T.c.text, "CENTER")
		z:Hide()
		st.rects[i] = z
	end
	for i = 1, NLINK * 2 do st.lines[i] = newLine(root.scr) end
	return root
end

local function update(root, w, h, key, value)
	local st = root.st
	local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
	if not uw or uw < 1 or not uh or uh < 1 then return end
	local avw, avh = w, h - 30
	local s = avw / uw
	if avh / uh < s then s = avh / uh end
	local sw, sh = floor(uw * s), floor(uh * s)
	P.Place(root.scr, root, floor((w - sw) / 2), 0, sw, sh)
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -(sh + 4))
	st.hint:SetWidth(w)
	st.hint:SetText(L("mod.preview.layout.hint"))
	local keys = sortedKeys()
	local cnt = 0
	local getLink = SUI.Layout.LinkedParent       -- lien EFFECTIF (option active, parent present, sans cycle) ; a defaut GetLink
	if type(getLink) ~= "function" then getLink = SUI.Layout.GetLink end
	local ar, ag, ab = T.Accent()
	local focus = P.focus
	local ent = st.ent
	-- deux passages : les cadres AFFICHES d'abord (sinon l'ordre alphabetique des cles coupait joueur / cible), puis les cadres masques
	-- (grises) tant qu'il reste de la place ; les fenetres de messages en reserve (masquees) ne sont jamais dessinees : elles se superposaient.
	for pass = 1, 2 do
		for i = 1, getn(keys) do
			local k = keys[i]
			local it = SUI.Layout.items[k]
			if cnt < NRECT and it then
				local shown = it.frame and it.frame.IsShown and it.frame:IsShown() and true or false
				local pool = (not shown) and string.find(k, "^messages%.win")
				if ((pass == 1 and shown) or (pass == 2 and not shown and not pool)) then
					cnt = cnt + 1
					local e = ent[cnt]
					e.key = k
					e.l, e.b, e.w, e.h = rectOf(k, it, uw, uh)
					e.area = e.w * e.h
				end
			end
		end
	end
	-- les grands rectangles d'abord (dessous), les petits au-dessus : ils restent cliquables
	local sorted = st.sorted or {}
	st.sorted = sorted
	for i = 1, cnt do
		local e = ent[i]
		local j = i - 1
		while j >= 1 and sorted[j].area < e.area do
			sorted[j + 1] = sorted[j]
			j = j - 1
		end
		sorted[j + 1] = e
	end
	local n = 0
	local labx, laby, labw, nlab = st.labx or {}, st.laby or {}, st.labw or {}, 0
	st.labx, st.laby, st.labw = labx, laby, labw
	for i = 1, cnt do
		local e = sorted[i]
		local k = e.key
		local it = SUI.Layout.items[k]
		if it then
			n = n + 1
			local z = st.rects[n]
			local l, b, rw, rh = e.l, e.b, e.w, e.h
			local x, y = floor(l * s), floor((uh - b - rh) * s)
			local pw, ph = floor(rw * s), floor(rh * s)
			if pw < 3 then pw = 3 end
			if ph < 3 then ph = 3 end
			if x < 0 then x = 0 end
			if y < 0 then y = 0 end
			if x + pw > sw then x = sw - pw end
			if y + ph > sh then y = sh - ph end
			P.Place(z, root.scr, x, y, pw, ph)
			local cat = catOfKey(k)
			z.key, z.cat = k, cat
			st.map[z.pz] = k
			st.cats[z.pz] = cat
			local on = it.frame and it.frame.IsShown and it.frame:IsShown()
			if focus and cat == focus then
				z.edge:SetVertexColor(ar, ag, ab, 1)
			else
				P.Fill(z.edge, T.c.border, 1)
			end
			P.Box(z.edge, z, 0, 0, pw, ph)
			P.Fill(z.fill, T.c.panel, on and 1 or 0.45)
			P.Box(z.fill, z, 1, 1, pw - 2, ph - 2)
			z.cx, z.cy = x + pw / 2, y + ph / 2
			local lab = labelOf(k)
			local maxc = floor(pw / 5)
			if string.len(lab) > maxc then lab = ssub(lab, 1, maxc) end
			-- anti-collision : une etiquette qui chevaucherait une etiquette deja posee (les grands rectangles d'abord) est omise
			local lw = string.len(lab) * 5
			local show = pw >= 24 and ph >= 9
			if show then
				local cx, cy = x + pw / 2, y + ph / 2
				for q = 1, nlab do
					if math.abs(labx[q] - cx) < (labw[q] + lw) / 2 and math.abs(laby[q] - cy) < 9 then show = false end
				end
				if show then
					nlab = nlab + 1
					labx[nlab], laby[nlab], labw[nlab] = cx, cy, lw
				end
			end
			if show then
				P.Font(z.lab, 8)
				z.lab:SetText(lab)
				z.lab:ClearAllPoints()
				z.lab:SetPoint("CENTER", z, "CENTER", 0, 0)
				z.lab:SetWidth(pw - 2)
				z.lab:SetHeight(10)
				z.lab:Show()
			else
				z.lab:Hide()
			end
			z:Show()
		end
	end
	for i = n + 1, NRECT do st.rects[i]:Hide() end
	st.n = n
	-- liens (API facultative, appels gardes)
	local nl = 0
	for i = 1, NLINK * 2 do st.lines[i]:Hide() end
	if type(getLink) == "function" then
		for i = 1, n do
			local z = st.rects[i]
			local ok, parent, side, ldx, ldy, src = pcall(getLink, z.key)
			if ok and type(parent) == "string" and nl < NLINK then
				local pz
				for j = 1, n do
					if st.rects[j].key == parent then pz = st.rects[j] end
				end
				if pz then
					nl = nl + 1
					local c1 = st.lines[nl * 2 - 1]
					local c2 = st.lines[nl * 2]
					local col = (src == "default") and T.c.dim or T.c.warn      -- lien conseille : trait discret ; lien choisi : trait vif
					P.Fill(c1, col, 1)
					P.Fill(c2, col, 1)
					seg(c1, root.scr, z.cx, z.cy, pz.cx, z.cy)
					seg(c2, root.scr, pz.cx, z.cy, pz.cx, pz.cy)
				end
			end
		end
	end
	st.nlinks = nl
end

local function click(zone)
	local root = P.reg.layout and P.reg.layout.root
	if not root then return nil end
	-- le cadre mene a SA ligne de reglages (barre 3 -> reglages de la barre 3) quand le menu connait son groupe
	local fk = root.st.map[zone]
	if fk and M.OptionAnchorFor and M.OptionAnchorFor(fk) and M.OpenAt then return "at:" .. fk end
	local cat = root.st.cats[zone]
	if cat and M.CatExists(cat) then return "cat:" .. cat end
	return nil
end

-- Nom du cadre au survol : celui de la poignee de deplacement.
local function label(zone)
	local root = P.reg.layout and P.reg.layout.root
	local fk = root and root.st.map[zone]
	if not fk then return nil end
	return labelOf(fk)
end

P.Register("layout", { title = "mod.preview.layout.title", watch = { "pos", "layout", "mover.", "ui.scale" }, build = build, update = update,
	click = click, label = label })

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) GetLeft / GetBottom d'un cadre cache ou jamais affiche (repli sur la position enregistree) ;
-- (2) l'echelle effective des cadres (GetEffectiveScale) pour convertir en unites d'UIParent ; (3) l'API de liens
-- SUI.Layout.GetLink(cle) -> parent, cote, dx, dy (ecrite par un autre agent dans Layouts.lua / Mover.lua : non verifiee ici).
