-- ShikiUI Menu_Preview : moteur du VOLET D'APERCU 2D du menu (a droite des reglages, ou sous eux sur un ecran etroit).
-- Un module enregistre son apercu avec SUI.Preview.Register(idCategorie, def) :
--   def.build(parent, w, h)            -> cadre racine (cree UNE fois, hors combat) ; parent = zone de l'apercu, w x h = sa taille
--   def.update(racine, w, h, cle, val) -> redessine ; cle == nil : tout ; jamais de creation de cadre ici (appele aussi en combat)
--   def.click(zone)                    -> cle d'option (ou "cat:<categorie>") a atteindre quand on clique la zone nommee
--   def.watch  = { "prefixe.", ... }   -> prefixes de reglages qui redessinent (par defaut "<idCategorie>.") ; def.title = cle de traduction
-- Les zones cliquables se creent dans build avec SUI.Preview.Zone(parent, nomDeZone) ; le clic appelle def.click puis M.GoHit (page du
-- reglage, mode Tout si besoin, surbrillance, defilement : M.FocusKey). L'apercu ne touche JAMAIS aux vrais cadres du jeu : tout est dessine
-- avec des textures / cadres propres, aux couleurs du style (T.c.*, T.Accent) et aux donnees du jeu (couleurs de classe, de debuff).
-- Cadres du volet : niveaux calcules sur M.lvl (apres M.SyncLevel), donc au-dessus du fond de la fenetre et sous la liste deroulante ; ils
-- suivent M.SetRaised (mode deplacement) car ce sont des descendants de la fenetre. Rien n'est cree en combat (P.Ensure refuse).
-- NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config

local getn, tinsert = table.getn, table.insert
local floor = math.floor
local sfind, ssub = string.find, string.sub

local P = {}
SUI.Preview = P
M.Preview = P

P.reg = {}          -- idCategorie -> def
P.order = {}        -- ordre d'enregistrement
P.cur = nil         -- def affichee
P.curId = nil
P.focus = nil       -- categorie du menu quand l'apercu affiche est un repli (mise en page) : permet de surligner son module
P.pane = nil
P.lastKey = nil     -- derniere cle atteinte par un clic (tests, diagnostic)

-- Reglages qui redessinent TOUT apercu (style, accent, langue, echelle, mode, role, mise en page, positions, interrupteurs de modules).
local GLOBAL_EXACT = { ["mode"] = true, ["role"] = true, ["layout"] = true, ["pos"] = true, ["ui.accent"] = true, ["ui.locale"] = true,
	["ui.scale"] = true }
local GLOBAL_PREFIX = { "style.", "modules." }

-- ---------------------------------------------------------------- enregistrement
function P.Register(catId, def)
	if type(catId) ~= "string" or catId == "" or type(def) ~= "table" or type(def.build) ~= "function" then return false end
	local old = P.reg[catId]
	if old and old.root then old.root:Hide() end
	def.id = catId
	def.root = nil
	def.failed = nil
	if not old then tinsert(P.order, catId) end
	P.reg[catId] = def
	return true
end

-- ---------------------------------------------------------------- aides de dessin (jetons du style, jamais de couleur en dur)
function P.NewTex(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.tex.white)
	return t
end

-- Couleur d'un jeton { r, g, b, a } ; a : opacite imposee (facultative).
function P.Fill(t, col, a)
	t:SetVertexColor(col[1], col[2], col[3], a or col[4] or 1)
end

-- Place la texture t dans parent (x, y depuis le coin haut gauche, w x h) ; cachee si trop petite.
function P.Box(t, parent, x, y, w, h)
	if w < 0.5 or h < 0.5 then
		t:Hide()
		return
	end
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	t:SetWidth(w)
	t:SetHeight(h)
	t:Show()
end

-- Taille de police du style, a l'echelle voulue (le texte de l'apercu est reduit comme le dessin).
function P.Font(fs, size)
	if size < 6 then size = 6 end
	pcall(fs.SetFont, fs, T.font, size * (T.fontScale or 1), T.outline)
end

-- Place le cadre f dans parent (coin haut gauche) a la taille w x h.
function P.Place(f, parent, x, y, w, h)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	f:SetWidth(w)
	f:SetHeight(h)
end

-- ---------------------------------------------------------------- zones cliquables
function P.FindOption(key)
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.key == key and o.type ~= "header" then return o end
	end
	return nil
end

-- Saute a l'option (ou "cat:<categorie>") : page, mode Tout si l'option est avancee, surbrillance et defilement.
function P.Goto(key)
	if type(key) ~= "string" or key == "" then return false end
	P.lastKey = key
	local _, _, at = sfind(key, "^at:(.+)$")
	if at then
		-- cle de cadre du Mover : M.OpenAt va a la ligne / au groupe de reglages de ce cadre (defilement + surbrillance)
		if not M.OpenAt then return false end
		local ok = M.OpenAt(at)
		return ok and true or false
	end
	local _, _, cat = sfind(key, "^cat:(.+)$")
	if cat then
		if M.CatExists(cat) then
			M.Open("cat", cat)
			return true
		end
		return false
	end
	local o = P.FindOption(key)
	if not o then return false end
	M.GoHit(o)
	return true
end

local function zoneKey(z)
	local def = z.pdef
	if not def or type(def.click) ~= "function" then return nil end
	local ok, key = pcall(def.click, z.pz)
	if ok then return key end
	SUI.Report("preview click", key)
	return nil
end

-- Nom lisible d'un element de l'apercu : def.label(zone) (cle de traduction ou texte), sinon le libelle de son reglage, sinon son nom de zone.
function P.LabelOf(z)
	local def = z.pdef
	if def and type(def.label) == "function" then
		local ok, s = pcall(def.label, z.pz)
		if ok and type(s) == "string" and s ~= "" then
			if M.Has(s) then return L(s) end
			return s
		end
	end
	local key = zoneKey(z)
	local o = key and P.FindOption(key)
	if o then return L(o.label) end
	if key then
		local _, _, cat = sfind(key, "^cat:(.+)$")
		if cat then return M.CatLabel(cat) end
	end
	return tostring(z.pz)
end

-- ---------------------------------------------------------------- selection (cadre accent autour de l'element choisi)
P.sel = nil          -- { def = def, id = nom de zone }

local function selColor()
	local sf = P.selFrame
	if not sf then return end
	local r, g, b = T.Accent()
	for i = 1, 4 do sf.e[i]:SetVertexColor(r, g, b, 1) end
end

local function newSelFrame()
	local pv = P.pane
	local sf = CreateFrame("Frame", nil, pv)
	sf:SetFrameLevel(M.lvl + 30)
	sf:EnableMouse(false)
	sf.e = {}
	for i = 1, 4 do
		local t = sf:CreateTexture(nil, "OVERLAY")
		t:SetTexture(T.tex.white)
		sf.e[i] = t
	end
	sf.e[1]:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
	sf.e[1]:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
	sf.e[1]:SetHeight(2)
	sf.e[2]:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 0, 0)
	sf.e[2]:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
	sf.e[2]:SetHeight(2)
	sf.e[3]:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
	sf.e[3]:SetPoint("BOTTOMLEFT", sf, "BOTTOMLEFT", 0, 0)
	sf.e[3]:SetWidth(2)
	sf.e[4]:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
	sf.e[4]:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
	sf.e[4]:SetWidth(2)
	sf.gear = T.Button(sf, L("mod.preview.edit.btn"), 16, 12, function() P.OpenPanel(P.SelZone()) end)
	sf.gear:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -3)
	sf.gear:SetFrameLevel(M.lvl + 32)
	sf.gear:SetScript("OnEnter", function()
		local r, g, b = T.Accent()
		this:SetBackdropBorderColor(r, g, b, 1)
		M.TipShow(this, L("mod.preview.edit.tip"))
	end)
	sf.gear:SetScript("OnLeave", function()
		local c = T.c.border
		this:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
		M.TipHide()
	end)
	sf:Hide()
	P.selFrame = sf
	selColor()
	return sf
end

-- Zone (cadre) de l'element selectionne dans l'apercu affiche, ou nil.
function P.SelZone()
	local s = P.sel
	if not s or s.def ~= P.cur or not s.def.zmap then return nil end
	return s.def.zmap[s.id]
end

-- Replace le cadre de selection sur l'element choisi (apres chaque redessin : l'element a pu bouger, disparaitre ou changer de taille).
function P.SyncSel()
	local sf = P.selFrame
	if not sf then return end
	local z = P.SelZone()
	local def = P.cur
	if z and z:IsShown() and def and def.root and def.root:IsShown() then
		if sf.at ~= z then
			sf:ClearAllPoints()
			sf:SetPoint("TOPLEFT", z, "TOPLEFT", -1, 1)
			sf:SetPoint("BOTTOMRIGHT", z, "BOTTOMRIGHT", 1, -1)
			sf.at = z
		end
		sf:Show()
	else
		sf:Hide()
		sf.at = nil
		if P.panel and P.panel:IsShown() and not z then P.ClosePanel() end
	end
end

function P.Select(z)
	if not z or not z.pdef then return end
	if not P.selFrame and P.pane and not SUI.InCombat() then newSelFrame() end
	P.sel = { def = z.pdef, id = z.pz }
	P.SyncSel()
end

function P.ClearSel()
	P.sel = nil
	P.ClosePanel()
	P.SyncSel()
end

-- Selectionne par nom (tests, autres modules) : P.SelectId("units", "name:player").
function P.SelectId(catId, id)
	local def = P.reg[catId]
	local z = def and def.zmap and def.zmap[id]
	if not z then return false end
	P.Select(z)
	return true
end

-- ---------------------------------------------------------------- mini-panneau flottant : change sur place les reglages d'un element
local ROWH, POSH = 20, 54
local POS9 = {
	{ "topleft" }, { "top", "topcenter" }, { "topright" },
	{ "left" }, { "center" }, { "right" },
	{ "bottomleft" }, { "bottom", "bottomcenter" }, { "bottomright" },
}
local EDITABLE = { number = true, bool = true, choice = true }
local NROWS = 7

local function isPos9(o)
	if o.type ~= "choice" or not o.choices then return false end
	local n = 0
	for i = 1, getn(o.choices) do
		local v = o.choices[i]
		if v == "topleft" or v == "bottomright" or v == "center" or v == "topright" or v == "bottomleft" then n = n + 1 end
	end
	return n >= 4
end

local function hasChoice(o, v)
	for i = 1, getn(o.choices) do
		if o.choices[i] == v then return true end
	end
	return false
end

local function roundTo(v, step)
	local d = 1
	if step and step < 1 then d = 1000 end
	return floor(v * d + 0.5) / d
end

-- Un cran sur un reglage (nombre : +/- un pas ; choix : suivant / precedent en boucle ; case : bascule).
function P.StepOpt(o, dir)
	local v = C.Get(o.key)
	if o.type == "bool" then
		C.Set(o.key, not v)
	elseif o.type == "number" then
		if type(v) ~= "number" then v = o.default or 0 end
		local st = o.step or 1
		local nv = roundTo(v + dir * st, st)
		if o.min and nv < o.min then nv = o.min end
		if o.max and nv > o.max then nv = o.max end
		C.Set(o.key, nv)
	elseif o.type == "choice" and o.choices then
		local n = getn(o.choices)
		local at = 1
		for i = 1, n do
			if o.choices[i] == v then at = i end
		end
		at = at + dir
		if at < 1 then at = n elseif at > n then at = 1 end
		C.Set(o.key, o.choices[at])
	end
end

local function rowClick(b) P.StepOpt(b.row.opt, b.dir) end
local function cellClick(b) C.Set(b.row.opt.key, b.pick) end

local function newRow(pn, i)
	local r = {}
	r.lab = T.Text(pn, 10, T.c.text, "LEFT")
	r.lab:SetHeight(12)
	r.minus = T.Button(pn, "-", 16, 14, rowClick)
	r.plus = T.Button(pn, "+", 16, 14, rowClick)
	r.minus.row, r.plus.row, r.minus.dir, r.plus.dir = r, r, -1, 1
	r.val = T.Text(pn, 10, T.c.text, "CENTER")
	r.val:SetHeight(12)
	r.cell = {}
	for k = 1, 9 do
		local c = T.Button(pn, "", 14, 14, cellClick)
		c.row = r
		r.cell[k] = c
	end
	r.i = i
	return r
end

local function hideRow(r)
	r.lab:Hide()
	r.minus:Hide()
	r.plus:Hide()
	r.val:Hide()
	for k = 1, 9 do r.cell[k]:Hide() end
	r.opt = nil
end

local function newPanel()
	local pv = P.pane
	local pn = CreateFrame("Frame", nil, pv)
	pn:SetFrameLevel(M.lvl + 40)
	T.Backdrop(pn, T.c.panel, T.c.border)
	pn:EnableMouse(true)
	pn.title = T.Text(pn, 11, T.c.text, "LEFT")
	pn.title:SetPoint("TOPLEFT", pn, "TOPLEFT", 8, -6)
	pn.title:SetHeight(14)
	pn.close = T.Button(pn, "x", 16, 14, function() P.ClosePanel() end)
	pn.close:SetPoint("TOPRIGHT", pn, "TOPRIGHT", -4, -4)
	pn.all = T.Button(pn, L("mod.preview.edit.all"), 120, 16, function()
		local k = P.panelKey
		P.ClosePanel()
		if k then P.Goto(k) end
	end)
	pn.rows = {}
	for i = 1, NROWS do pn.rows[i] = newRow(pn, i) end
	pn:Hide()
	P.panel = pn
	return pn
end

-- Montre une rangee : etiquette a gauche, commande a droite. Retourne sa hauteur.
local function fillRow(pn, r, o, y, w)
	r.opt = o
	r.lab:ClearAllPoints()
	r.lab:SetPoint("TOPLEFT", pn, "TOPLEFT", 8, -(y + 3))
	r.lab:SetWidth(w * 0.5 - 10)
	r.lab:SetText(M.Short(L(o.label), 40))
	r.lab:Show()
	local cx = w - 8
	if isPos9(o) then
		local cur = C.Get(o.key)
		for k = 1, 9 do
			local c = r.cell[k]
			local pick = nil
			for j = 1, getn(POS9[k]) do
				if hasChoice(o, POS9[k][j]) then pick = POS9[k][j] end
			end
			c.pick = pick
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", pn, "TOPLEFT", cx - 3 * 16 + ((k - 1) - floor((k - 1) / 3) * 3) * 16, -(y + floor((k - 1) / 3) * 16))
			if pick then
				c:Show()
				T.SetSelected(c, pick == cur)
			else
				c:Hide()
			end
		end
		r.minus:Hide()
		r.plus:Hide()
		r.val:Hide()
		return POSH
	end
	for k = 1, 9 do r.cell[k]:Hide() end
	if o.type == "bool" then
		local on = C.Get(o.key) and true or false
		r.minus:Hide()
		r.val:Hide()
		r.plus:SetWidth(44)
		r.plus:ClearAllPoints()
		r.plus:SetPoint("TOPLEFT", pn, "TOPLEFT", cx - 44, -y)
		r.plus:Show()
		T.SetButtonText(r.plus, on and L("mod.preview.edit.on") or L("mod.preview.edit.off"))
		T.SetSelected(r.plus, on)
		return ROWH
	end
	r.plus:SetWidth(16)
	T.SetSelected(r.plus, false)
	T.SetButtonText(r.plus, "+")
	r.plus:ClearAllPoints()
	r.plus:SetPoint("TOPLEFT", pn, "TOPLEFT", cx - 16, -y)
	r.plus:Show()
	r.minus:ClearAllPoints()
	r.minus:SetPoint("TOPLEFT", pn, "TOPLEFT", cx - 16 - 74, -y)
	r.minus:Show()
	r.val:ClearAllPoints()
	r.val:SetPoint("TOPLEFT", pn, "TOPLEFT", cx - 16 - 56, -(y + 3))
	r.val:SetWidth(54)
	local v = C.Get(o.key)
	if o.type == "choice" then
		r.val:SetText(M.Short(M.ChoiceLabel(o, v), 9))
	else
		r.val:SetText(tostring(v))
	end
	r.val:Show()
	return ROWH
end

-- Contenu (re)ecrit depuis les reglages : appele a l'ouverture et a chaque changement de reglage.
function P.PanelRefresh()
	local pn = P.panel
	if not pn or not pn:IsShown() or not P.panelKeys then return end
	local w = pn:GetWidth()
	local y = 24
	for i = 1, NROWS do
		local r = pn.rows[i]
		local k = P.panelKeys[i]
		local o = k and P.FindOption(k)
		if o then
			y = y + fillRow(pn, r, o, y, w) + 2
		else
			hideRow(r)
		end
	end
	pn.all:ClearAllPoints()
	pn.all:SetPoint("TOPLEFT", pn, "TOPLEFT", 8, -(y + 2))
	pn:SetHeight(y + 24)
end

-- Reglages voisins d'un reglage (meme categorie, ordre proche et apres lui) : "coordonnees" mene aussi a leur position, leur precision...
-- Ceux qui placent (position, coin, cote) passent en premier. Utilise quand l'apercu ne declare pas son propre panneau.
local function isPlacer(k)
	return sfind(k, "pos", 1, true) or sfind(k, "anchor", 1, true) or sfind(k, "side", 1, true) or sfind(k, "place", 1, true)
end

function P.Neighbors(o, max)
	local list = {}
	for i = 1, getn(SUI.options) do
		local q = SUI.options[i]
		if q.cat == o.cat and q.key ~= o.key and EDITABLE[q.type] and q.order and o.order and q.order > o.order and q.order <= o.order + 9 then
			tinsert(list, q)
		end
	end
	for i = 2, getn(list) do
		local q = list[i]
		local j = i - 1
		while j >= 1 and list[j].order > q.order do
			list[j + 1] = list[j]
			j = j - 1
		end
		list[j + 1] = q
	end
	local out = {}
	for pass = 1, 2 do
		for i = 1, getn(list) do
			local q = list[i]
			if (pass == 1) == (isPlacer(q.key) and true or false) and getn(out) < max then tinsert(out, q.key) end
		end
	end
	return out
end

-- Reglages modifiables d'un element : def.panel(zone) -> { keys = { ... }, go = cle } ; sinon son reglage puis ses voisins.
function P.PanelKeys(z)
	local def = z.pdef
	local keys = {}
	local spec
	if def and type(def.panel) == "function" then
		local ok, s = pcall(def.panel, z.pz)
		if ok and type(s) == "table" then spec = s end
	end
	local src = spec and spec.keys
	if not src then
		local k = zoneKey(z)
		src = k and { k } or {}
		local o = k and P.FindOption(k)
		if o then
			local nb = P.Neighbors(o, 3)
			-- le reglage qui place passe devant : on y va d'abord pour deplacer l'element
			local first = {}
			for i = 1, getn(nb) do
				if isPlacer(nb[i]) then tinsert(first, nb[i]) end
			end
			src = {}
			for i = 1, getn(first) do tinsert(src, first[i]) end
			tinsert(src, k)
			for i = 1, getn(nb) do
				if not isPlacer(nb[i]) then tinsert(src, nb[i]) end
			end
		end
	end
	for i = 1, getn(src) do
		local o = P.FindOption(src[i])
		if o and EDITABLE[o.type] and getn(keys) < NROWS then tinsert(keys, src[i]) end
	end
	return keys, (spec and spec.go) or zoneKey(z)
end

function P.OpenPanel(z)
	if not z or not z.pdef or not P.pane then return false end
	local keys, gokey = P.PanelKeys(z)
	if getn(keys) == 0 then
		if gokey then P.Goto(gokey) end
		return false
	end
	if not P.panel then
		if SUI.InCombat() then
			if gokey then P.Goto(gokey) end
			return false
		end
		newPanel()
	end
	local pn = P.panel
	local pv = P.pane
	local w = 210
	if w > pv:GetWidth() - 12 then w = pv:GetWidth() - 12 end
	pn:SetWidth(w)
	pn.title:SetWidth(w - 34)
	pn.title:SetText(P.LabelOf(z))
	pn.all:SetWidth(w - 16)
	P.panelKeys, P.panelKey, P.panelDef = keys, gokey, z.pdef
	pn:ClearAllPoints()
	-- du cote oppose a l'element, pour ne pas le cacher
	if z.py and z.ph and z.py + z.ph / 2 < (pv:GetHeight() - 30) / 2 then
		pn:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -6, 6)
	else
		pn:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -6, -26)
	end
	pn:Show()
	P.PanelRefresh()
	return true
end

function P.ClosePanel()
	local pn = P.panel
	if pn and pn:IsShown() then pn:Hide() end
	P.panelKeys, P.panelKey, P.panelDef = nil, nil, nil
end

local function zoneClick()
	local z = this
	P.Select(z)
	if arg1 == "RightButton" then
		P.OpenPanel(z)
		return
	end
	P.ClosePanel()
	local key = zoneKey(z)
	if key then P.Goto(key) end
end

local function zoneEnter()
	local z = this
	local r, g, b = T.Accent()
	z.hl:SetVertexColor(r, g, b, 0.28)
	z.hl:Show()
	local key = zoneKey(z)
	local o = key and P.FindOption(key)
	local def = z.pdef
	local tip = ""
	if def and type(def.tip) == "function" then
		local ok, s = pcall(def.tip, z.pz)
		if ok and type(s) == "string" and s ~= "" then tip = M.Has(s) and L(s) or s end
	end
	if tip == "" and o then tip = M.Short(M.Tx(o.tip), 120) end
	M.TipShow(z, P.LabelOf(z), tip, L("mod.preview.zone"), L("mod.preview.zone2"))
end

local function zoneLeave()
	this.hl:Hide()
	M.TipHide()
end

-- Zone cliquable (a creer dans def.build, hors combat) : cadre transparent au-dessus de ses freres, surligne au survol.
-- Niveaux ABSOLUS : P.base = niveau du cadre racine de l apercu en cours de construction ; P.Lv(rel) = P.base + rel (deterministe, sans parcours).
P.base = 0
function P.Lv(rel) return P.base + (rel or 0) end

function P.Zone(parent, id, rel)
	local z = CreateFrame("Button", nil, parent)
	z:SetFrameLevel(P.Lv(rel or 3))
	z.pz = id
	z.pdef = P.building
	z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	z:EnableMouse(true)
	z.hl = z:CreateTexture(nil, "OVERLAY")
	z.hl:SetTexture(T.tex.white)
	z.hl:SetAllPoints(z)
	z.hl:Hide()
	if P.menuBuild and P.building then
		local zm = P.building.zmap
		if not zm then
			zm = {}
			P.building.zmap = zm
		end
		zm[id] = z
	end
	z:SetScript("OnClick", zoneClick)
	z:SetScript("OnEnter", zoneEnter)
	z:SetScript("OnLeave", zoneLeave)
	return z
end

-- Place une zone sur le rectangle (x, y, w, h) de parent ; taille minimale 6 px pour rester cliquable.
function P.PlaceZone(z, parent, x, y, w, h)
	if w < 6 then
		x = x - (6 - w) / 2
		w = 6
	end
	if h < 6 then
		y = y - (6 - h) / 2
		h = 6
	end
	P.Place(z, parent, x, y, w, h)
	z.py, z.ph = y, h
	z:Show()
end

-- ---------------------------------------------------------------- volet
function P.Dims()
	local G = M.G
	if M.pvMode == "below" then return G.W - G.CX - G.PAD, G.BH - 6 end
	return G.PW, G.NAVH
end

function P.BodySize()
	local w, h = P.Dims()
	return w - 12, h - 26 - 20
end

-- Recale le volet sur le niveau reel du contenu (voir M.SyncLevel : le client change le niveau du cadre defilant apres sa creation).
function P.SyncLevel()
	M.SyncLevel()
	-- la liste deroulante du menu doit rester AU-DESSUS du contenu du volet (niveaux dynamiques)
	if M.RaiseDrop then M.RaiseDrop() end
	local pv = P.pane
	if not pv or not M.lvl or not M.child then return end
	local want = M.lvl
	local cur = pv:GetFrameLevel()
	if cur ~= want then M.Restack(pv, M.child:GetFrameStrata(), want - cur, {}) end
end

function M.BuildPreview(f)
	if P.pane then return P.pane end
	M.SyncLevel()
	local pv = CreateFrame("Frame", nil, f)
	P.pane = pv
	pv:SetFrameStrata(f:GetFrameStrata())
	pv:SetFrameLevel(M.lvl)
	T.Backdrop(pv, T.c.panel, T.c.border)
	pv:EnableMouse(true)
	pv.title = T.Text(pv, 12, T.c.text, "LEFT")
	pv.title:SetPoint("TOPLEFT", pv, "TOPLEFT", 8, -7)
	pv.title:SetHeight(14)
	pv.bScreen = T.Button(pv, L("mod.preview.screen.toggle"), 64, 14, function()
		-- bascule : apercu de l'ecran <-> apercu de la categorie courante
		if P.curId == "layout" then
			P.Show(P.Pick())
		else
			P.Show("layout")
		end
	end)
	pv.bScreen:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -8, 6)
	pv.bScreen:Hide()   -- montre par P.Show quand un autre apercu est actif
	pv.status = T.Text(pv, 10, T.c.warn, "RIGHT")
	pv.status:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -8, -8)
	pv.status:SetHeight(12)
	pv.body = CreateFrame("Frame", nil, pv)
	pv.body:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -24)
	pv.body:SetFrameLevel(M.lvl + 1)
	pv.msg = T.Text(pv, 11, T.c.dim, "CENTER")
	pv.msg:SetPoint("CENTER", pv, "CENTER", 0, 0)
	pv.msg:SetWidth(220)
	pv.msg:SetHeight(60)
	pv.msg:Hide()
	pv.hint = T.Text(pv, 10, T.c.dim, "LEFT")
	pv.hint:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", 8, 6)
	pv.hint:SetHeight(12)
	pv:Hide()
	pv:SetScript("OnHide", function() P.ClosePanel() end)
	if not SUI.InCombat() then newSelFrame() end
	C.Watch("", P.OnKey)
	T.OnAccent(P.OnRestyle)
	M.PreviewLayout()
	if M.PreviewWanted() then P.EnsureAll() end
	return pv
end

-- Place le volet selon M.pvMode et redimensionne les apercus deja construits.
function M.PreviewLayout()
	local pv = P.pane
	local f = M.frame
	if not pv or not f then return end
	local G = M.G
	local w, h = P.Dims()
	pv:ClearAllPoints()
	if M.pvMode == "below" then
		pv:SetPoint("TOPLEFT", f, "TOPLEFT", G.CX, -(G.NAVTOP + G.NAVH + 2))
	else
		pv:SetPoint("TOPLEFT", f, "TOPLEFT", G.W + G.PX, -G.NAVTOP)
	end
	pv:SetWidth(w)
	pv:SetHeight(h)
	local bw, bh = P.BodySize()
	pv.body:SetWidth(bw)
	pv.body:SetHeight(bh)
	pv.title:SetWidth(w - 150)
	pv.status:SetWidth(150)
	pv.hint:SetWidth(w - 16)
	for i = 1, getn(P.order) do
		local d = P.reg[P.order[i]]
		if d.root then
			d.root:SetWidth(bw)
			d.root:SetHeight(bh)
		end
	end
	if M.pvMode == "off" then
		pv:Hide()
	elseif f:IsShown() then
		M.SyncPreview()
	end
end

-- Construit (hors combat) l'apercu d'une def. Retourne vrai si sa racine existe.
function P.Ensure(def)
	if not def then return false end
	if def.root then return true end
	if def.failed or SUI.InCombat() then return false end
	local pv = P.pane
	if not pv then return false end
	P.SyncLevel()
	local bw, bh = P.BodySize()
	P.building = def
	P.menuBuild = true
	def.zmap = nil
	P.base = pv.body:GetFrameLevel() + 1
	local ok, root = pcall(def.build, pv.body, bw, bh)
	P.building = nil
	P.menuBuild = false
	if not ok or type(root) ~= "table" then
		def.failed = true
		SUI.Report("preview " .. tostring(def.id), ok and "build sans cadre racine" or root)
		return false
	end
	P.Place(root, pv.body, 0, 0, bw, bh)
	root:SetFrameLevel(P.Lv(0))
	root:Hide()
	def.root = root
	return true
end

-- Instance INDEPENDANTE d'un apercu (hors du volet du menu) : pour l'assistant d'installation ou un autre panneau. Construite hors combat
-- seulement ; interactive = false rend les zones insensibles a la souris. Retourne { root, def, Update(cle) } ou nil.
function P.Instance(catId, parent, w, h, interactive)
	local def = P.reg[catId]
	if not def or not parent or SUI.InCombat() then return nil end
	P.building = def
	P.base = parent:GetFrameLevel() + 1
	local ok, root = pcall(def.build, parent, w, h)
	P.building = nil
	if not ok or type(root) ~= "table" then
		SUI.Report("preview " .. tostring(catId), ok and "build sans cadre racine" or root)
		return nil
	end
	P.Place(root, parent, 0, 0, w, h)
	root:SetFrameLevel(P.Lv(0))
	if not interactive then
		local function mute(fr)
			if fr.pz and fr.pdef then fr:EnableMouse(false) end
			local kids = { fr:GetChildren() }
			for i = 1, getn(kids) do
				if kids[i] ~= fr then mute(kids[i]) end
			end
		end
		mute(root)
	end
	local inst = { root = root, def = def, w = w, h = h }
	inst.Update = function(key, value)
		if type(def.update) ~= "function" then return end
		local ok2, err = pcall(def.update, root, w, h, key, value)
		if not ok2 then SUI.Report("preview " .. tostring(catId), err) end
	end
	inst.Update(nil, nil)
	return inst
end

function P.EnsureAll()
	for i = 1, getn(P.order) do P.Ensure(P.reg[P.order[i]]) end
end

-- ---------------------------------------------------------------- choix et mise a jour
function P.Fallback()
	if P.reg.layout then return "layout" end
	return P.order[1]
end

-- Apercu a montrer : celui de la categorie ouverte, sinon la mise en page (vue d'ensemble) ; pendant une recherche, le dernier affiche.
function P.Pick()
	if M.search ~= "" and P.curId then return P.curId end
	if M.page == "cat" and P.reg[M.cat] then return M.cat end
	return P.Fallback()
end

function P.UpdateStatus(def)
	local pv = P.pane
	if not pv or not def then return end
	local m = SUI.modules[def.id]
	if m and not m.enabled then
		pv.status:SetText(L("mod.preview.off"))
	else
		pv.status:SetText("")
	end
	-- titre et etat se partagent la ligne : le titre cede la place a l etat (sinon ils se chevauchent)
	local pw = pv:GetWidth() or 400
	pv.status:SetWidth(floor(pw * 0.5))     -- largeur libre le temps de mesurer le texte
	local sw = pv.status:GetStringWidth() or 0
	if sw > 0 then
		if sw > pw * 0.5 then sw = floor(pw * 0.5) end
		pv.status:SetWidth(sw + 2)
		pv.title:SetWidth(pw - sw - 28)
	else
		pv.status:SetWidth(10)
		pv.title:SetWidth(pw - 16)
	end
end

function P.Update(def, key, value)
	if not def or not def.root or type(def.update) ~= "function" then return end
	local bw, bh = P.BodySize()
	local ok, err = pcall(def.update, def.root, bw, bh, key, value)
	if not ok then SUI.Report("preview " .. tostring(def.id), err) end
	if def == P.cur then P.SyncSel() end
end

function P.Message(text)
	local pv = P.pane
	if text then
		pv.msg:SetText(text)
		pv.msg:Show()
	else
		pv.msg:Hide()
	end
end

function P.Show(id)
	local pv = P.pane
	local def = id and P.reg[id]
	if P.cur ~= def and P.panel and P.panel:IsShown() then P.ClosePanel() end
	P.cur, P.curId = def, id
	P.focus = (M.page == "cat" and id ~= M.cat) and M.cat or nil
	for i = 1, getn(P.order) do
		local d = P.reg[P.order[i]]
		if d ~= def and d.root and d.root:IsShown() then d.root:Hide() end
	end
	pv.hint:SetText(L("mod.preview.hint"))
	if not def then
		pv.title:SetText(L("mod.preview.title"))
		pv.status:SetText("")
		pv.bScreen:Hide()
		P.Message(L("mod.preview.none"))
		return
	end
	local name = def.title and M.Has(def.title) and L(def.title) or M.CatLabel(def.id)
	pv.title:SetText(L("mod.preview.for", name))
	if id ~= "layout" and P.reg.layout then
		pv.bScreen:Show()
		-- au dessus du contenu de l'apercu (cadre des unites, grilles) qui sinon le recouvre
		pv.bScreen:SetFrameLevel(pv:GetFrameLevel() + 60)
	else
		pv.bScreen:Hide()
	end
	P.UpdateStatus(def)
	if not P.Ensure(def) then
		P.Message(def.failed and L("mod.preview.error") or L("mod.preview.combat"))
		return
	end
	P.Message(nil)
	if not def.root:IsShown() then def.root:Show() end
	P.Update(def, nil, nil)
	P.SyncSel()
end

-- Appele par M.Render : montre l'apercu qui correspond a la page.
function M.SyncPreview()
	local pv = P.pane
	if not pv then return end
	P.SyncLevel()
	if M.pvMode == "off" then
		if pv:IsShown() then pv:Hide() end
		return
	end
	if not pv:IsShown() then pv:Show() end
	P.Show(P.Pick())
end

function P.IsGlobal(key)
	if GLOBAL_EXACT[key] then return true end
	for i = 1, getn(GLOBAL_PREFIX) do
		local p = GLOBAL_PREFIX[i]
		if ssub(key, 1, string.len(p)) == p then return true end
	end
	return false
end

function P.Matches(def, key)
	local w = def.watch
	if type(w) ~= "table" then
		local p = def.id .. "."
		return ssub(key, 1, string.len(p)) == p
	end
	for i = 1, getn(w) do
		if ssub(key, 1, string.len(w[i])) == w[i] then return true end
	end
	return false
end

-- Un reglage a change : redessine l'apercu affiche s'il est concerne (sans rien reconstruire).
function P.OnKey(key, value)
	if P.panel and P.panel:IsShown() then P.PanelRefresh() end
	local f = M.frame
	if not f or not f:IsShown() or M.pvMode == "off" or not P.pane or not P.pane:IsShown() then return end
	local def = P.cur
	if not def or not def.root then return end
	if key == nil or P.IsGlobal(key) or P.Matches(def, key) then
		if key == nil or ssub(key, 1, 8) == "modules." then P.UpdateStatus(def) end
		P.Update(def, key, value)
	end
end

function P.OnRestyle()
	selColor()
	local f = M.frame
	if f and f:IsShown() and M.pvMode ~= "off" and P.cur and P.cur.root then P.Update(P.cur, nil, nil) end
end

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) le niveau des cadres du volet (au-dessus du fond, sous la liste deroulante) apres le
-- relevement automatique de la fenetre "toplevel" ; (2) CreateFontString / SetFont avec une taille reduite (texte lisible a l'echelle
-- de l'apercu) ; (3) les textures "UI-RaidTargetingIcons" decoupees par SetTexCoord ; (4) la largeur de la fenetre elargie sur des
-- ecrans 4/3 (le plan M.PlanLayout bascule alors sous les reglages ou masque le volet).
