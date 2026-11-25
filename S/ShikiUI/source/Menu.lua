-- ShikiUI Menu (moteur) : fenetre 880x580, navigation par familles, recherche globale, defilement, listes deroulantes, transfert de profil,
-- assistant (Menu_Wizard.lua). Les PAGES (accueil, modules, styles, reglages d'un module, recherche) sont dans Menu_Pages.lua.
-- Principes : (1) AUCUNE couleur / texture en dur : tout vient de Theme.lua (T.c.*, T.Backdrop, T.Text, T.Button, T.Accent) ; le menu suit donc /sui style ;
-- (2) tout est en POOLS reutilises (M.pools) : une page prend ses elements avec M.Get(genre), le reste est cache ; rien n'est cree en combat ;
-- (3) rien ne tourne fenetre fermee (la seule minuterie, 1 s, n'existe que fenetre ouverte) ; (4) pages construites a la demande.
-- NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = {}
SUI.Menu = M

local getn, tinsert = table.getn, table.insert
local mmax = math.max
local floor = math.floor

-- geometrie (unites de la fenetre, avant mise a l'echelle)
M.G = { W = 880, H = 580, TITLE = 40, FOOT = 30, NAVW = 190, HEAD = 66, NAVTOP = 46, CX = 206, CW = 648, CTOP = 116, CH = 430, NAVH = 500,
	PW = 340, PX = 2, PAD = 8, BH = 232, PVMIN = 0.8 }   -- volet d'apercu : largeur, decalage, marge, hauteur sous les reglages, reduction maxi acceptee
M.pvMode = "off"         -- "side" (a droite) | "below" (sous les reglages) | "off" (masque ou ecran trop etroit), voir M.PlanLayout

M.mode = "essential"     -- "essential" | "all"  (anciennement simple / expert)
M.page = "home"          -- "home" | "modules" | "styles" | "cat"
M.cat = "general"        -- categorie affichee quand page == "cat"
M.search = ""
M.hl = nil               -- cle mise en surbrillance (resultat de recherche)
M.focus = nil            -- cle a amener dans la zone visible au prochain rendu
M.filter = "all"         -- filtre de la page Modules : all | on | off | wait
M.pools = {}
M.used = {}
M.New = {}               -- fabriques d'elements (Menu_Pages.lua)
M.Pages = {}             -- rendus de pages (Menu_Pages.lua)
M.navItems = {}
M.navList = {}
M.roleButtons = {}
M.hits = {}
M.resSel = 0
M.MAXRES = 30
M.KINDS = { "sec", "cell", "note", "mcard", "scard", "lcard", "stat", "btn", "res", "txt",
	"c_check", "c_slider", "c_drop", "c_seg", "c_color", "c_text", "arow", "aedit", "acard", "pedit" }
for i = 1, getn(M.KINDS) do
	M.pools[M.KINDS[i]] = {}
	M.used[M.KINDS[i]] = 0
end

-- familles de la navigation : un module ou une categorie inconnue tombe dans "other" (Autres)
M.FAMILIES = {
	{ id = "general", cats = { "general", "mode", "perf", "specs" } },
	{ id = "look", cats = { "style", "skin", "layout", "units", "nameplates", "tooltip", "powerauras", "cursor" } },
	{ id = "combat", cats = { "castbar", "auras", "threat", "tanktools", "meter", "totems", "clickheal", "alerts", "manaswap", "debuffs", "handguard", "cooldowns", "buffwatch", "ghosts", "bossmods", "groupfx", "esport" } },
	{ id = "group", cats = { "group", "raid", "markers", "marks", "pallypower", "grouppets", "finder" } },
	{ id = "interface", cats = { "actionbars", "chat", "chattabs", "messages", "windows", "minimap", "map", "datatext", "charstats" } },
	{ id = "tools", cats = { "social", "bulletin", "stats", "macros", "tracker" } },
	{ id = "loot", cats = { "loot", "items", "bags", "mail", "auction", "market", "vendor", "codex", "questtrack", "places" } },
}
M.openFam = {}           -- familles depliees dans la navigation (en memoire : la famille de la page courante s'ouvre seule)

-- ---------------------------------------------------------------- aides
function M.Has(key)
	if not key then return false end
	return SUI.locales[SUI.locale][key] ~= nil or SUI.locales.fr[key] ~= nil
end

-- Texte traduit si la cle existe, sinon chaine vide (ne signale pas de cle manquante).
function M.Tx(key)
	if M.Has(key) then return L(key) end
	return ""
end

function M.Cap(s)
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- Premiere phrase, au plus n caracteres (ASCII).
function M.Short(s, n)
	s = s or ""
	local i = string.find(s, ". ", 1, true)
	if i and i < n then s = string.sub(s, 1, i) end
	if string.len(s) > n then s = string.sub(s, 1, n - 3) .. "..." end
	return s
end

function M.NormMode(v)
	if v == "simple" or v == "essential" then return "essential" end
	if v == "expert" or v == "all" then return "all" end
	return nil
end

function M.CatLabel(cat)
	if M.Has("cat." .. cat) then return L("cat." .. cat) end
	return M.Cap(cat)
end

local function cmp(a, b)
	local oa, ob = a.order or 0, b.order or 0
	if oa ~= ob then return oa < ob end
	return a.idx < b.idx
end

-- Reglages d'une categorie (en-tetes compris), tries par ordre puis par declaration.
function M.OptionsOf(cat)
	local list = {}
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.cat == cat then tinsert(list, o) end
	end
	table.sort(list, cmp)
	return list
end

function M.CatCount(cat)
	local n = 0
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.cat == cat and o.type ~= "header" then n = n + 1 end
	end
	return n
end

function M.CatExists(cat)
	return type(cat) == "string" and cat ~= "modules" and M.CatCount(cat) > 0
end

-- Etat d'un module : "on" | "wait" (attend pfUI) | "off".
function M.State(name)
	local m = SUI.modules[name]
	if not m then return "off" end
	if m.enabled then return "on" end
	if SUI.Migrate and SUI.Migrate.Held(name) and SUI.Config.Get("modules." .. name) then return "wait" end
	return "off"
end

function M.StateColor(st)
	if st == "on" then return T.c.good end
	if st == "wait" then return T.c.warn end
	return T.c.dim
end

function M.ModName(name)
	local s = M.Tx("opt.modules." .. name)
	if s == "" then s = M.Cap(name) end
	return s
end

-- Description courte d'un module : def.short (cle de traduction, facultative) sinon premiere phrase de son infobulle.
function M.ModShort(name, n)
	local m = SUI.modules[name]
	if m and m.short and M.Has(m.short) then return M.Short(L(m.short), n or 110) end
	return M.Short(M.Tx("tip.modules." .. name), n or 110)
end

function M.CatDesc(cat)
	if SUI.modules[cat] then return M.ModShort(cat, 150) end
	return M.Tx("mod.menu.catdesc." .. cat)
end

-- Liste ordonnee { id, cats } des familles qui ont au moins une categorie disponible ; "other" ramasse le reste.
function M.FamilyList()
	local avail = {}
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.type ~= "header" and o.cat and o.cat ~= "modules" then avail[o.cat] = true end
	end
	local seen = {}
	local res = {}
	for i = 1, getn(M.FAMILIES) do
		local fam = M.FAMILIES[i]
		local cats = {}
		for j = 1, getn(fam.cats) do
			local c = fam.cats[j]
			if avail[c] and not seen[c] then
				seen[c] = true
				tinsert(cats, c)
			end
		end
		if getn(cats) > 0 then tinsert(res, { id = fam.id, cats = cats }) end
	end
	local rest = {}
	for c, _ in pairs(avail) do
		if not seen[c] then tinsert(rest, c) end
	end
	table.sort(rest, function(a, b)
		local oa, ob = SUI.categories[a] or 999, SUI.categories[b] or 999
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	if getn(rest) > 0 then tinsert(res, { id = "other", cats = rest }) end
	return res
end

-- ---------------------------------------------------------------- pools
function M.Get(kind)
	local p = M.pools[kind]
	local n = M.used[kind] + 1
	local it = p[n]
	if not it then
		if SUI.InCombat() then return nil end
		it = M.New[kind]()
		p[n] = it
	end
	M.used[kind] = n
	return it
end

function M.Begin()
	for k, _ in pairs(M.used) do M.used[k] = 0 end
	M.y, M.col, M.rowh = 0, 0, 0
	M.pending = nil
end

function M.EndRow(gy)
	if M.col > 0 then
		M.y = M.y + M.rowh + (gy or 0)
		M.col, M.rowh = 0, 0
	end
end

-- Place l'element it (hauteur h, largeur w) dans une grille de cols colonnes ; retourne x, y.
function M.Flow(it, cols, w, h, gx, gy)
	if M.col >= cols then M.EndRow(gy) end
	local x = M.col * (w + gx)
	it:ClearAllPoints()
	it:SetPoint("TOPLEFT", M.child, "TOPLEFT", x, -M.y)
	it:SetWidth(w)
	it:SetHeight(h)
	it:Show()
	it.y, it.h = M.y, h
	if h > M.rowh then M.rowh = h end
	M.col = M.col + 1
	return x, M.y
end

function M.End()
	M.EndRow(0)
	for k, p in pairs(M.pools) do
		for i = M.used[k] + 1, getn(p) do
			if p[i]:IsShown() then p[i]:Hide() end
		end
	end
	M.ScrollSet(M.cs, M.y + 10)
end

-- ---------------------------------------------------------------- defilement (barre large, molette, glissement du curseur)
function M.OnWheel()
	local s = this.sc or M.cs
	if s then M.ScrollTo(s, s.cur - arg1 * s.step) end
end

function M.ScrollTo(s, y)
	local max = s.child:GetHeight() - s.h
	if max < 0 then max = 0 end
	if y > max then y = max end
	if y < 0 then y = 0 end
	s.cur, s.max = y, max
	if y ~= s.set then
		s.set = y
		s.sf:SetVerticalScroll(y)
	end
	if max <= 0 then
		s.bar:Hide()
		return
	end
	s.bar:Show()
	local th = floor(s.h * s.h / (s.h + max))
	if th < 28 then th = 28 end
	local off = floor((s.h - th) * (y / max))
	-- Le glissement du pouce appelle ceci PAR IMAGE : ne refaire la geometrie du pouce que si elle change.
	if th ~= s.th or off ~= s.toff then
		s.th, s.toff = th, off
		s.thumb:SetHeight(th)
		s.thumb:ClearAllPoints()
		s.thumb:SetPoint("TOP", s.bar, "TOP", 0, -off)
	end
end

function M.ScrollSet(s, h)
	if h < 1 then h = 1 end
	s.child:SetHeight(h)
	M.ScrollTo(s, s.cur)
end

local function thumbDrag()
	local th = this
	local s = th.sc
	if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
		th:SetScript("OnUpdate", nil)
		return
	end
	local _, cy = GetCursorPosition()
	cy = cy / th:GetEffectiveScale()
	local track = s.h - th:GetHeight()
	if track > 0 then M.ScrollTo(s, s.dragCur + (s.dragY - cy) * s.max / track) end
end

local function thumbDown()
	local th = this
	local s = th.sc
	local _, cy = GetCursorPosition()
	s.dragY = cy / th:GetEffectiveScale()
	s.dragCur = s.cur
	th:SetScript("OnUpdate", thumbDrag)
end

local function thumbUp()
	this:SetScript("OnUpdate", nil)
end

local function thumbEnter()
	local r, g, b = T.Accent()
	this:SetBackdropColor(r, g, b, 1)
end

local function thumbLeave()
	local c = T.c.dim
	this:SetBackdropColor(c[1], c[2], c[3], c[4])
end

local function barDown()
	local b = this
	local s = b.sc
	local _, cy = GetCursorPosition()
	cy = cy / b:GetEffectiveScale()
	local th = s.thumb:GetHeight()
	local track = s.h - th
	if track <= 0 then return end
	local frac = ((b:GetTop() or 0) - cy - th / 2) / track
	M.ScrollTo(s, frac * s.max)
end

-- Zone defilante avec sa barre (largeur barw). Retourne s = { sf, child, bar, thumb, cur, max, h, step }.
function M.NewScroller(parent, w, h, barw, step)
	local s = { cur = 0, max = 0, h = h, step = step }
	local sf = CreateFrame("ScrollFrame", nil, parent)
	sf:SetWidth(w)
	sf:SetHeight(h)
	local child = CreateFrame("Frame", nil, sf)
	child:SetWidth(w)
	child:SetHeight(1)
	sf:SetScrollChild(child)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", M.OnWheel)
	sf.sc = s
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetWidth(barw)
	bar:SetHeight(h)
	T.Backdrop(bar, T.c.inset, T.c.border)
	bar:EnableMouse(true)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", M.OnWheel)
	bar:SetScript("OnMouseDown", barDown)
	bar.sc = s
	local th = CreateFrame("Button", nil, bar)
	th:SetWidth(barw - 2)
	th:SetHeight(28)
	T.Backdrop(th, T.c.dim, T.c.dim)
	th:EnableMouse(true)
	th:SetScript("OnMouseDown", thumbDown)
	th:SetScript("OnMouseUp", thumbUp)
	th:SetScript("OnEnter", thumbEnter)
	th:SetScript("OnLeave", thumbLeave)
	th.sc = s
	th:SetPoint("TOP", bar, "TOP", 0, 0)
	s.sf, s.child, s.bar, s.thumb = sf, child, bar, th
	return s
end

-- ---------------------------------------------------------------- infobulle
function M.TipShow(owner, title, l1, l2, l3)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, T.c.text[1], T.c.text[2], T.c.text[3])
	local d = T.c.dim
	if l1 and l1 ~= "" then GameTooltip:AddLine(l1, d[1], d[2], d[3], 1) end
	if l2 and l2 ~= "" then GameTooltip:AddLine(l2, d[1], d[2], d[3], 1) end
	if l3 and l3 ~= "" then GameTooltip:AddLine(l3, d[1], d[2], d[3], 1) end
	GameTooltip:Show()
end

function M.TipHide()
	if GameTooltip then GameTooltip:Hide() end
end

-- Bouton a confirmation en deux temps (3 s) : la 1re pression change le texte, la 2e execute fn.
function M.ConfirmClick(b, id, label, fn)
	if M.pending == id then
		M.pending = nil
		T.SetButtonText(b, label)
		fn()
		return
	end
	M.pending = id
	M.pendBtn, M.pendLabel, M.pendAt = b, label, GetTime()
	T.SetButtonText(b, L("menu.confirm"))
	SUI.After(3, M.ClearPending, "menu.confirm")
end

function M.ClearPending()
	if M.pending and GetTime() >= M.pendAt + 2.9 then
		T.SetButtonText(M.pendBtn, M.pendLabel)
		M.pending = nil
	end
end

-- ---------------------------------------------------------------- liste deroulante (fenetre commune, 10 lignes, molette)
local DROP_ROWS, DROP_W = 10, 210

-- Liste deroulante + capture : niveaux DYNAMIQUES. Le volet d apercu empile des enfants de plus en plus
-- profonds (apercus imbriques) ; les offsets fixes (+40/+50) finissaient SOUS le contenu. Recale a chaque ouverture
-- ET a chaque rendu (le contenu peut monter apres le drop).
function M.RaiseDrop()
	-- NIVEAUX FIXES ELEVES (O(1), jamais de scan) : le contenu du volet d apercu empile des offsets (+40 par
	-- niveau d apercu imbrique) ; +220 couvre toute imbrication realiste en restant au-dessus, catcher juste dessous.
	local f = M.frame
	if not f or not f.drop or not f.catcher or not M.lvl then return end
	f.drop:SetFrameLevel(M.lvl + 220)
	f.catcher:SetFrameLevel(M.lvl + 210)
	-- Les boutons de la liste sont des ENFANTS de f.drop : en 1.12 SetFrameLevel du parent ne recale pas les enfants, ils restaient
	-- a l'ancien niveau (sous le fond de la liste) et leur texte etait presque invisible.
	local i
	for i = 1, getn(f.drop.rows) do f.drop.rows[i]:SetFrameLevel(M.lvl + 222) end
end


function M.BuildDrop(f)
	local lvl = f:GetFrameLevel()
	local cat = CreateFrame("Button", nil, f)
	cat:SetAllPoints(f)
	cat:SetFrameLevel(lvl + 40)
	cat:EnableMouse(true)
	cat:SetScript("OnClick", function() M.CloseDrop() end)
	cat:Hide()
	f.catcher = cat
	local d = CreateFrame("Frame", nil, f)
	d:SetFrameLevel(lvl + 50)
	d:SetWidth(DROP_W + 8)
	T.Backdrop(d, T.c.bg, T.c.border)
	d:EnableMouse(true)
	d:EnableMouseWheel(true)
	d:SetScript("OnMouseWheel", function() M.DropScroll(-arg1) end)
	d:Hide()
	d.rows = {}
	for i = 1, DROP_ROWS do
		local b = T.Button(d, "", DROP_W, 20, function(btn) M.DropPick(btn.index) end)
		b.index = i
		b:SetPoint("TOPLEFT", d, "TOPLEFT", 4, -4 - (i - 1) * 21)
		d.rows[i] = b
	end
	d.range = T.Text(d, 9, T.c.dim, "CENTER")
	d.range:SetWidth(DROP_W)
	d.range:SetHeight(12)
	f.drop = d
end

function M.DropRender()
	local d, o = M.frame.drop, M.dropOpt
	local n = getn(o.choices)
	local cur = SUI.Config.Get(o.key)
	local rows = n
	if rows > DROP_ROWS then rows = DROP_ROWS end
	for i = 1, DROP_ROWS do
		local b = d.rows[i]
		local idx = M.dropOff + i
		if i <= rows and idx <= n then
			T.SetButtonText(b, M.ChoiceLabel(o, o.choices[idx]))
			T.SetSelected(b, o.choices[idx] == cur)
			b:Show()
		else
			b:Hide()
		end
	end
	local h = rows * 21 + 8
	if n > DROP_ROWS then
		d.range:ClearAllPoints()
		d.range:SetPoint("BOTTOM", d, "BOTTOM", 0, 3)
		d.range:SetText(L("mod.menu.drop.range", M.dropOff + 1, M.dropOff + rows, n))
		d.range:Show()
		h = h + 12
	else
		d.range:Hide()
	end
	d:SetHeight(h)
end

function M.DropScroll(dir)
	local o = M.dropOpt
	if not o or not M.frame.drop:IsShown() then return end
	local n = getn(o.choices)
	local off = M.dropOff + dir
	if off > n - DROP_ROWS then off = n - DROP_ROWS end
	if off < 0 then off = 0 end
	if off ~= M.dropOff then
		M.dropOff = off
		M.DropRender()
	end
end

-- Ouvre la liste du controle ctl (ctl.cell.opt = reglage de type choice).
function M.OpenDrop(ctl)
	local o = ctl.cell.opt
	local f = M.frame
	local n = getn(o.choices)
	local cur = SUI.Config.Get(o.key)
	local idx = 1
	for i = 1, n do
		if o.choices[i] == cur then idx = i end
	end
	M.dropOpt, M.dropCtl = o, ctl
	M.RaiseDrop()
	M.dropOff = idx - 1
	if M.dropOff > n - DROP_ROWS then M.dropOff = n - DROP_ROWS end
	if M.dropOff < 0 then M.dropOff = 0 end
	f.catcher:Show()
	M.DropRender()
	local d = f.drop
	d:ClearAllPoints()
	local screenY = (ctl.cell.y or 0) - (M.cs and M.cs.cur or 0)
	if screenY > M.G.CH / 2 then
		d:SetPoint("BOTTOMLEFT", ctl.btn, "TOPLEFT", 0, 2)
	else
		d:SetPoint("TOPLEFT", ctl.btn, "BOTTOMLEFT", 0, -2)
	end
	d:Show()
end

function M.CloseDrop()
	local f = M.frame
	if not f or not f.drop then return end
	f.drop:Hide()
	f.catcher:Hide()
	M.dropOpt, M.dropCtl = nil, nil
end

function M.DropPick(i)
	local o = M.dropOpt
	if not o then return end
	local v = o.choices[M.dropOff + i]
	M.CloseDrop()
	if v ~= nil then
		SUI.Config.Set(o.key, v)
		if o.reload then SUI.Print(L("msg.reload")) end
	end
end

-- Texte affiche pour la valeur d'un choix : o.choiceText(o, v) si le reglage le fournit (listes dynamiques : styles, polices...).
function M.ChoiceLabel(o, v)
	if o.choiceText then return o.choiceText(o, v) end
	return L("choice." .. o.key .. "." .. tostring(v))
end

-- ---------------------------------------------------------------- navigation (colonne de gauche)
function M.RebuildNav()
	local nav = {}
	tinsert(nav, { kind = "page", id = "home" })
	tinsert(nav, { kind = "page", id = "modules" })
	local fams = M.FamilyList()
	local hasTools = false
	for i = 1, getn(fams) do
		local fam = fams[i]
		tinsert(nav, { kind = "head", id = fam.id })
		if fam.id == "look" then tinsert(nav, { kind = "page", id = "styles" }) end
		if fam.id == "general" then tinsert(nav, { kind = "page", id = "profiles" }) end
		if fam.id == "tools" then
			tinsert(nav, { kind = "page", id = "addons" })
			tinsert(nav, { kind = "page", id = "errors" })
			hasTools = true
		end
		for j = 1, getn(fam.cats) do
			tinsert(nav, { kind = "cat", id = fam.cats[j] })
		end
	end
	if not hasTools then
		tinsert(nav, { kind = "head", id = "tools" })
		tinsert(nav, { kind = "page", id = "addons" })
	end
	local fam
	for i = 1, getn(nav) do
		if nav[i].kind == "head" then fam = nav[i].id end
		if i > 2 then nav[i].fam = fam end
	end
	M.navList = nav
end

-- Ouvre la famille qui contient la page / categorie donnee (la navigation ne montre que les familles depliees).
function M.OpenFamilyOf(kind, id)
	for i = 1, getn(M.navList) do
		local e = M.navList[i]
		if e.kind == kind and e.id == id and e.fam then
			M.openFam[e.fam] = true
			return
		end
	end
end

function M.NavLabel(e)
	if e.kind == "head" then return L("mod.menu.fam." .. e.id) end
	if e.kind == "page" then return L("mod.menu.nav." .. e.id) end
	return M.CatLabel(e.id)
end

local function navClick()
	local e = this.entry
	if not e then return end
	if e.kind == "head" then
		M.openFam[e.id] = not M.openFam[e.id]
		M.UpdateNav()
		return
	end
	M.Open(e.kind == "page" and e.id or "cat", e.id)
end

local function navEnter()
	local it = this
	if it.entry and it.entry.kind ~= "head" and it.entry.sel ~= true then it.hov:Show() end
end

local function navLeave()
	this.hov:Hide()
end

function M.NewNavItem()
	local it = CreateFrame("Button", nil, M.ns.child)
	it:SetWidth(M.G.NAVW - 12)
	it:SetHeight(22)
	it:EnableMouseWheel(true)
	it:SetScript("OnMouseWheel", M.OnWheel)
	it.sc = M.ns
	it:SetScript("OnClick", navClick)
	it:SetScript("OnEnter", navEnter)
	it:SetScript("OnLeave", navLeave)
	it.hov = it:CreateTexture(nil, "BACKGROUND")
	it.hov:SetTexture(T.tex.white)
	it.hov:SetAllPoints(it)
	it.hov:SetVertexColor(T.c.panel[1], T.c.panel[2], T.c.panel[3], 0.6)
	it.hov:Hide()
	it.selTex = it:CreateTexture(nil, "BACKGROUND")
	it.selTex:SetTexture(T.tex.white)
	it.selTex:SetAllPoints(it)
	it.selTex:Hide()
	it.bar = it:CreateTexture(nil, "ARTWORK")
	it.bar:SetTexture(T.tex.white)
	it.bar:SetWidth(3)
	it.bar:SetPoint("TOPLEFT", it, "TOPLEFT", 0, 0)
	it.bar:SetPoint("BOTTOMLEFT", it, "BOTTOMLEFT", 0, 0)
	it.bar:Hide()
	it.dot = it:CreateTexture(nil, "ARTWORK")
	it.dot:SetTexture(T.tex.white)
	it.dot:SetWidth(7)
	it.dot:SetHeight(7)
	it.dot:SetPoint("LEFT", it, "LEFT", 10, 0)
	it.dot:Hide()
	it.fresh = it:CreateTexture(nil, "OVERLAY")       -- pastille "nouveau" (reglages apparus depuis la derniere fois)
	it.fresh:SetTexture(T.tex.white)
	it.fresh:SetWidth(6)
	it.fresh:SetHeight(6)
	it.fresh:SetPoint("RIGHT", it, "RIGHT", -8, 0)
	it.fresh:Hide()
	it.arrow = T.Text(it, 11, T.c.dim, "RIGHT")      -- repli / depli d'une famille (+ / -)
	it.arrow:SetPoint("RIGHT", it, "RIGHT", -8, 0)
	it.arrow:Hide()
	it.label = T.Text(it, 12, T.c.text, "LEFT")
	it.label:SetPoint("LEFT", it, "LEFT", 24, 0)
	it.label:SetWidth(M.G.NAVW - 12 - 30)
	it.label:SetHeight(16)
	return it
end

-- Positionne et remplit les entrees de navigation (une fois par rendu : texte, couleur, pastille, selection).
function M.UpdateNav()
	local list = M.navList
	local y = 0
	local accR, accG, accB = T.Accent()
	local page = M.page
	if M.search ~= "" then page = "search" end
	local key = page .. ":" .. tostring(M.cat)
	if key ~= M.famKey then          -- la page a change : sa famille se deplie (un repli manuel reste respecte ensuite)
		M.famKey = key
		if page == "cat" then M.OpenFamilyOf("cat", M.cat) elseif page ~= "search" then M.OpenFamilyOf("page", page) end
	end
	for i = 1, getn(list) do
		local e = list[i]
		local it = M.navItems[i]
		if not it then
			if SUI.InCombat() then break end
			it = M.NewNavItem()
			M.navItems[i] = it
		end
		it.entry = e
		e.hid = (e.kind ~= "head" and e.fam ~= nil and not M.openFam[e.fam])
		local h = 22
		if e.hid then
			e.sel = false
			it:Hide()
			h = nil
		elseif e.kind == "head" then
			if i > 1 then y = y + 6 end
			h = 18
		end
		if h then
			it:ClearAllPoints()
			it:SetPoint("TOPLEFT", M.ns.child, "TOPLEFT", 0, -y)
			it:SetHeight(h)
			y = y + h
			it.label:SetText(M.NavLabel(e))
			local sel = (e.kind == "page" and page == e.id) or (e.kind == "cat" and page == "cat" and M.cat == e.id)
			e.sel = sel
			it.hov:Hide()
			if e.kind == "head" then
				it.label:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
				it.label:ClearAllPoints()
				it.label:SetPoint("LEFT", it, "LEFT", 8, 0)
				it.selTex:Hide()
				it.bar:Hide()
				it.dot:Hide()
				it.fresh:Hide()
				it.arrow:SetText(M.openFam[e.id] and "-" or "+")
				it.arrow:Show()
			else
				it.arrow:Hide()
				it.label:ClearAllPoints()
				it.label:SetPoint("LEFT", it, "LEFT", 24, 0)
				if sel then
					it.label:SetTextColor(accR, accG, accB, 1)
					it.selTex:SetVertexColor(T.c.panel[1], T.c.panel[2], T.c.panel[3], 1)
					it.selTex:Show()
					it.bar:SetVertexColor(accR, accG, accB, 1)
					it.bar:Show()
				else
					it.label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
					it.selTex:Hide()
					it.bar:Hide()
				end
				if e.kind == "cat" and SUI.modules[e.id] then
					local c = M.StateColor(M.State(e.id))
					it.dot:SetVertexColor(c[1], c[2], c[3], 1)
					it.dot:Show()
				else
					it.dot:Hide()
				end
				local nn = 0
				if e.kind == "cat" then nn = M.NewCount(e.id) elseif e.id == "modules" then nn = M.NewCount("modules") end
				if nn > 0 then
					it.fresh:SetVertexColor(accR, accG, accB, 1)
					it.fresh:Show()
				else
					it.fresh:Hide()
				end
			end
			it:Show()
		end
	end
	for i = getn(list) + 1, getn(M.navItems) do M.navItems[i]:Hide() end
	M.ScrollSet(M.ns, y + 6)
	M.navY = y
end

-- ---------------------------------------------------------------- etat memorise
function M.LoadState()
	local C = SUI.Config
	M.mode = M.NormMode(C.GetGlobal("menuMode")) or "essential"
	C.SetGlobal("menuMode", M.mode)
	local p = C.GetGlobal("menuPage")
	if type(p) == "string" then
		M.page = "home"
		if p == "modules" or p == "styles" or p == "addons" or p == "profiles" or p == "errors" then
			M.page = p
		else
			local _, _, c = string.find(p, "^cat:([a-z0-9]+)$")
			if c and M.CatExists(c) then
				M.page = "cat"
				M.cat = c
			end
		end
	end
end

function M.StorePage()
	local v = M.page
	if v == "cat" then v = "cat:" .. M.cat end
	SUI.Config.SetGlobal("menuPage", v)
end

-- Navigation : page = "home" | "modules" | "styles" | "cat" (cat = categorie ou module). Efface la recherche.
function M.Open(page, cat)
	if page == "cat" and not M.CatExists(cat) then page = "home" end
	if page ~= "home" and page ~= "modules" and page ~= "styles" and page ~= "addons" and page ~= "profiles" and page ~= "errors" and page ~= "cat" then page = "home" end
	M.page = page
	if page == "cat" then M.cat = cat end
	M.ClearHl()
	M.StorePage()
	if M.frame then
		M.search = ""
		M.resSel = 0
		M.silent = true
		M.frame.edit:SetText("")
		M.silent = false
		M.frame.editHint:SetText(L("mod.menu.search"))
		M.Render()
	end
end

function M.Route(arg)
	if not arg then return end
	local mm = M.NormMode(arg)
	if mm then
		M.mode = mm
		SUI.Config.SetGlobal("menuMode", mm)
	elseif arg == "home" or arg == "modules" or arg == "styles" or arg == "addons" or arg == "profiles" or arg == "errors" then
		M.page = arg
		M.StorePage()
	elseif M.CatExists(arg) then
		M.page = "cat"
		M.cat = arg
		M.StorePage()
	end
end

function M.SetMode(mode)
	mode = M.NormMode(mode)
	if not mode then return end
	M.mode = mode
	SUI.Config.SetGlobal("menuMode", mode)
	if M.frame then
		M.Translate()
		M.Render()
	end
end

-- ---------------------------------------------------------------- recherche globale
function M.Find(q)
	local hits = {}
	local seen = {}
	q = string.lower(q)
	for pass = 1, 4 do
		for i = 1, getn(SUI.options) do
			local o = SUI.options[i]
			if o.type ~= "header" and not seen[o.key] then
				local hit
				if pass == 1 then
					hit = string.find(string.lower(L(o.label)), q, 1, true)
				elseif pass == 2 then
					hit = string.find(string.lower(o.key), q, 1, true)
				elseif pass == 3 then
					hit = string.find(string.lower(M.Tx(o.tip)), q, 1, true)
				else
					hit = o.cat and string.find(string.lower(M.CatLabel(o.cat)), q, 1, true)
				end
				if hit then
					seen[o.key] = true
					tinsert(hits, o)
				end
			end
		end
	end
	return hits
end

-- Saute a la page du reglage o et le met en surbrillance.
function M.GoHit(o)
	if not o then return end
	if o.cat == "modules" then
		M.page = "modules"
		M.filter = "all"
	else
		if M.mode == "essential" and not o.simple then
			M.mode = "all"
			SUI.Config.SetGlobal("menuMode", "all")
			M.Translate()
		end
		M.page = "cat"
		M.cat = o.cat
	end
	M.StorePage()
	M.ClearHl()
	M.hl = o.key
	M.focus = o.key
	M.search = ""
	M.resSel = 0
	M.silent = true
	M.frame.edit:SetText("")
	M.silent = false
	M.frame.editHint:SetText(L("mod.menu.search"))
	M.Render()
end

local function onSearchChanged()
	local e = this
	if M.silent then return end
	M.search = e:GetText() or ""
	M.resSel = 0
	M.frame.editHint:SetText(M.search == "" and L("mod.menu.search") or "")
	M.Render()
end

-- Entree : ouvre le resultat selectionne (ou le premier).
local function onSearchEnter()
	local n = getn(M.hits)
	if M.search ~= "" and n > 0 then
		local i = M.resSel
		if i < 1 then i = 1 end
		M.GoHit(M.hits[i])
	end
	this:ClearFocus()
end

-- Tab : resultat suivant (NON VERIFIE EN JEU : OnTabPressed d'un EditBox 1.12).
local function onSearchTab()
	local n = getn(M.hits)
	if M.search == "" or n == 0 then return end
	if n > M.MAXRES then n = M.MAXRES end
	M.resSel = M.resSel + 1
	if M.resSel > n then M.resSel = 1 end
	M.Render()
end

local function onSearchEscape()
	local e = this
	if (e:GetText() or "") ~= "" then
		e:SetText("")
	else
		e:ClearFocus()
	end
end

-- ---------------------------------------------------------------- fenetre
-- Volet d'apercu voulu par l'utilisateur (reglage memorise, global) : vrai par defaut.
function M.PreviewWanted()
	return SUI.Config.GetGlobal("menuPreview") ~= false
end

-- Plan de la fenetre pour l'echelle sc : retourne mode, largeur, hauteur, echelle. L'apercu va a droite si la fenetre elargie tient sans
-- reduire l'echelle de plus de 20 % par rapport a la fenetre seule ; sinon sous les reglages (fenetre plus haute) ; sinon il est masque.
function M.PlanLayout(sc)
	local G = M.G
	local aw, ah = UIParent:GetWidth(), UIParent:GetHeight()
	local function fit(w, h)
		local s = math.min(sc, aw / (w + 16), ah / (h + 16))
		if s < 0.3 then s = 0.3 end
		return s
	end
	local base = fit(G.W, G.H)
	if M.PreviewWanted() then
		local sw = G.W + G.PX + G.PW + G.PAD
		local s1 = fit(sw, G.H)
		if s1 >= base * G.PVMIN then return "side", sw, G.H, s1 end
		local s2 = fit(G.W, G.H + G.BH)
		if s2 >= base * G.PVMIN then return "below", G.W, G.H + G.BH, s2 end
	end
	return "off", G.W, G.H, base
end

function M.ApplyScale()
	local f = M.frame
	local sc = SUI.Config.Get("ui.scale") or 1
	local mode, w, h, s = M.PlanLayout(sc)
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetScale(s)
	M.pvMode, M.frameW, M.frameH = mode, w, h
	M.scaleApplied = s
	if M.PreviewLayout then M.PreviewLayout() end
end

function M.TogglePreview()
	SUI.Config.SetGlobal("menuPreview", not M.PreviewWanted())
	if M.frame then
		if M.PreviewWanted() and M.Preview then M.Preview.EnsureAll() end      -- prepare les apercus hors combat
		M.ApplyScale()
		M.Translate()
		M.Render()
	end
end

local function lift(f, b)
	b:SetFrameLevel(f:GetFrameLevel() + 3)
	return b
end

function M.BuildTitle(f)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	bar:SetHeight(M.G.TITLE)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() f:StartMoving() end)
	bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	f.title = T.Text(f, 16, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
	f.ver = T.Text(f, 10, T.c.dim, "LEFT")
	f.ver:SetPoint("LEFT", f.title, "RIGHT", 6, -2)
	f.close = lift(f, T.Button(f, "x", 24, 22, function() f:Hide() end))
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -9)
	f.emBtn = lift(f, T.Button(f, "", 76, 22, function() SUI.Perf.SetEmergency(not SUI.emergency) end))
	f.emBtn:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
	f.modeBtn = lift(f, T.Button(f, "", 104, 22, function() M.ToggleMode() end))
	f.modeBtn:SetPoint("RIGHT", f.emBtn, "LEFT", -6, 0)
	f.segAll = lift(f, T.Button(f, "", 56, 22, function() M.SetMode("all") end))
	f.segAll:SetPoint("RIGHT", f.modeBtn, "LEFT", -10, 0)
	f.segEss = lift(f, T.Button(f, "", 78, 22, function() M.SetMode("essential") end))
	f.segEss:SetPoint("RIGHT", f.segAll, "LEFT", 2, 0)
	f.bindBtn = lift(f, T.Button(f, "", 84, 22, function() if SUI.Bind then SUI.Bind.Toggle() end end))
	f.bindBtn:SetPoint("RIGHT", f.segEss, "LEFT", -10, 0)
	f.moveBtn = lift(f, T.Button(f, "", 92, 22, function() if SUI.Mover then SUI.Mover.Toggle() end end))
	f.moveBtn:SetPoint("RIGHT", f.bindBtn, "LEFT", -6, 0)
	f.moveBtn:SetScript("OnEnter", function() M.TipShow(this, L("mod.mover.title"), L("mod.menu.tip.move")) end)
	f.moveBtn:SetScript("OnLeave", M.TipHide)
	f.bindBtn:SetScript("OnEnter", function() M.TipShow(this, L("mod.bind.title"), L("mod.menu.tip.bind")) end)
	f.bindBtn:SetScript("OnLeave", M.TipHide)
	f.edit = lift(f, T.Edit(f, 142, 22))
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 176, -9)
	f.edit:SetMaxLetters(40)
	f.edit:SetScript("OnTextChanged", onSearchChanged)
	f.edit:SetScript("OnEnterPressed", onSearchEnter)
	f.edit:SetScript("OnTabPressed", onSearchTab)
	f.edit:SetScript("OnEscapePressed", onSearchEscape)
	f.editHint = T.Text(f.edit, 11, T.c.dim, "LEFT")
	f.editHint:SetPoint("LEFT", f.edit, "LEFT", 6, 0)
end

-- En-tete de page (fixe, au-dessus de la zone defilante).
function M.BuildHead(f)
	local G = M.G
	local h = CreateFrame("Frame", nil, f)
	h:SetWidth(G.W - G.CX - 8)
	h:SetHeight(G.HEAD)
	h:SetPoint("TOPLEFT", f, "TOPLEFT", G.CX, -G.NAVTOP)
	T.Backdrop(h, T.c.panel, T.c.border)
	h:EnableMouse(true)
	h:SetScript("OnEnter", function()
		if this.tipTitle then M.TipShow(this, this.tipTitle, this.tipText) end
	end)
	h:SetScript("OnLeave", M.TipHide)
	h.title = T.Text(h, 16, T.c.text, "LEFT")
	h.title:SetPoint("TOPLEFT", h, "TOPLEFT", 14, -10)
	h.title:SetHeight(20)
	h.desc = T.Text(h, 10, T.c.dim, "LEFT")
	h.desc:SetPoint("TOPLEFT", h, "TOPLEFT", 14, -34)
	h.desc:SetHeight(26)
	h.desc:SetJustifyV("TOP")
	h.status = T.Text(h, 11, T.c.dim, "RIGHT")
	h.status:SetPoint("TOPRIGHT", h, "TOPRIGHT", -34, -42)
	h.status:SetWidth(220)
	h.status:SetHeight(14)
	h.sw = lift(f, T.Check(h, function(on)
		local name = M.SwitchName
		if name then SUI.Config.Set("modules." .. name, on) end
	end))
	h.sw:SetPoint("TOPRIGHT", h, "TOPRIGHT", -12, -40)
	h.btn = {}
	for i = 1, 4 do
		local b = T.Button(h, "", 110, 22, function(btn, mb)
			if btn.fn then btn.fn(btn, mb) end
		end)
		lift(f, b)
		b:Hide()
		h.btn[i] = b
	end
	h.nbtn, h.bx = 0, 0
	f.head = h
end

function M.HeadReset()
	local h = M.frame.head
	h.sw:Hide()
	M.SwitchName = nil
	h.status:SetText("")
	h.tipTitle = nil
	for i = 1, 4 do h.btn[i]:Hide() end
	h.nbtn, h.bx = 0, 0
end

function M.HeadBtn(label, w, fn, selected)
	local h = M.frame.head
	h.nbtn = h.nbtn + 1
	local b = h.btn[h.nbtn]
	b:SetWidth(w)
	T.SetButtonText(b, label)
	b.fn = fn
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", h, "TOPRIGHT", -10 - h.bx, -9)
	h.bx = h.bx + w + 6
	b:Show()
	T.SetSelected(b, selected)
	return b
end

function M.SetHead(title, desc, tipText)
	local h = M.frame.head
	h.title:SetWidth(M.G.W - M.G.CX - 8 - 28 - h.bx)
	h.title:SetText(title)
	h.desc:SetWidth(M.G.W - M.G.CX - 8 - 28 - 250)
	h.desc:SetText(desc or "")
	h.tipTitle = tipText and title or nil
	h.tipText = tipText
end

function M.BuildNav(f)
	local G = M.G
	M.ns = M.NewScroller(f, G.NAVW - 12, G.NAVH, 8, 44)
	M.ns.sf:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -G.NAVTOP)
	M.ns.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + G.NAVW - 8, -G.NAVTOP)
	M.RebuildNav()
	for i = 1, getn(M.navList) do M.navItems[i] = M.NewNavItem() end
end

function M.BuildContent(f)
	local G = M.G
	M.cs = M.NewScroller(f, G.CW, G.CH, G.SB or 12, 46)
	M.cs.sf:SetPoint("TOPLEFT", f, "TOPLEFT", G.CX, -G.CTOP)
	M.cs.bar:SetPoint("TOPLEFT", f, "TOPLEFT", G.CX + G.CW + 6, -G.CTOP)
	M.scroll = M.cs.sf
	M.child = M.cs.child
	M.lvl = M.child:GetFrameLevel()
end

function M.BuildFooter(f)
	f.profileBtn = T.Button(f, "", 170, 20, function(b, mb) M.NextProfile(mb == "RightButton" and -1 or 1) end)
	f.profileBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 6)
	f.info = T.Text(f, 10, T.c.dim, "LEFT")
	f.info:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 4)
	f.info:SetWidth(M.G.W - 330)
	f.info:SetHeight(24)
	f.pvBtn = T.Button(f, "", 100, 20, function() M.TogglePreview() end)
	f.pvBtn:SetPoint("RIGHT", f.profileBtn, "LEFT", -6, 0)
	f.pvBtn:SetScript("OnEnter", function() M.TipShow(this, L("mod.preview.btn"), L("mod.preview.btn.tip")) end)
	f.pvBtn:SetScript("OnLeave", M.TipHide)
end

function M.NextProfile(dir)
	local C = SUI.Config
	local list = C.ListProfiles()
	local n = getn(list)
	if n < 2 then return end
	local idx = 1
	for i = 1, n do
		if list[i] == C.curName then idx = i end
	end
	idx = idx + dir
	if idx < 1 then idx = n end
	if idx > n then idx = 1 end
	C.UseProfile(list[idx])
end

function M.Build()
	if M.frame then return M.frame end
	local G = M.G
	M.LoadState()
	local f = CreateFrame("Frame", "ShikiUI_Menu", UIParent)
	M.frame = f
	f:SetWidth(G.W)
	f:SetHeight(G.H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:SetScript("OnMouseWheel", M.OnWheel)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	f:SetScript("OnShow", M.OnShow)
	f:SetScript("OnHide", M.OnHide)
	M.BuildTitle(f)
	M.BuildHead(f)
	M.BuildNav(f)
	M.BuildContent(f)
	M.BuildFooter(f)
	M.BuildDrop(f)
	if M.BuildPreview then M.BuildPreview(f) end      -- volet d'apercu (Menu_Preview.lua)
	tinsert(UISpecialFrames, "ShikiUI_Menu")
	SUI.Config.Watch("", M.OnConfig)
	SUI.Perf.OnEmergency(M.OnEmergency)
	T.OnAccent(M.OnRestyle)
	M.Translate()
	return f
end

-- ---------------------------------------------------------------- pile (strate / niveau) pendant le mode deplacement
-- Le voile et les poignees du Mover sont en FULLSCREEN / FULLSCREEN_DIALOG : le menu (DIALOG) serait dessous, donc non cliquable. Tant que le
-- mode deplacement est actif, TOUT le menu (cadre, zone defilante, boutons, liste deroulante et son cadre de capture) passe en
-- FULLSCREEN_DIALOG avec +RAISE niveaux, au-dessus des poignees, du bandeau et des panneaux du Mover. Le mode n'est pas ferme.
M.STRATA, M.STRATA_RAISED, M.RAISE = "DIALOG", "FULLSCREEN_DIALOG", 100
M.raised = false

function M.Restack(fr, strata, delta, seen)
	if not fr or seen[fr] then return end
	seen[fr] = true
	fr:SetFrameStrata(strata)
	local lv = fr:GetFrameLevel() + delta
	if lv < 0 then lv = 0 end
	fr:SetFrameLevel(lv)
	if fr.GetChildren then
		local kids = { fr:GetChildren() }
		for i = 1, getn(kids) do
			if kids[i] ~= fr then M.Restack(kids[i], strata, delta, seen) end
		end
	end
end

function M.SetRaised(on)
	on = on and true or false
	local f = M.frame
	if not f or M.raised == on then return end
	local seen = {}
	local delta = on and M.RAISE or -M.RAISE
	local strata = on and M.STRATA_RAISED or M.STRATA
	M.Restack(f, strata, delta, seen)
	M.Restack(f.catcher, strata, delta, seen)
	M.Restack(f.drop, strata, delta, seen)
	if M.lvl then M.lvl = M.lvl + delta end
	M.raised = on
end

function M.OnShow()
	if M.tick then SUI.Cancel(M.tick) end
	M.tick = SUI.Every(1, M.Tick, "menutick", true)
end

function M.OnHide()
	if M.tick then SUI.Cancel(M.tick) end
	M.tick = nil
	M.CloseDrop()
	M.TipHide()
end

function M.OnEmergency()
	if M.frame and M.frame:IsShown() then
		T.SetSelected(M.frame.emBtn, SUI.emergency)
		M.UpdateFooter()
	end
end

function M.OnRestyle()
	if M.frame and M.frame:IsShown() then M.Render() end
end

function M.Tick()
	if M.page == "home" and M.search == "" and M.UpdatePerf then M.UpdatePerf() end
end

-- Textes statiques de la fenetre (langue, mode).
function M.Translate()
	local f = M.frame
	if not f then return end
	f.title:SetText(L("menu.title"))
	f.ver:SetText("v" .. tostring(SUI.VERSION))
	f.editHint:SetText((f.edit:GetText() or "") == "" and L("mod.menu.search") or "")
	T.SetButtonText(f.segEss, L("mod.menu.essential"))
	T.SetButtonText(f.segAll, L("mod.menu.all"))
	T.SetSelected(f.segEss, M.mode == "essential")
	T.SetSelected(f.segAll, M.mode == "all")
	T.SetButtonText(f.emBtn, L("menu.emergency"))
	T.SetSelected(f.emBtn, SUI.emergency)
	T.SetButtonText(f.pvBtn, L("mod.preview.btn"))
	T.SetSelected(f.pvBtn, M.PreviewWanted() and M.pvMode ~= "off")
	M.UpdateActionButtons()
	M.UpdateMode()
	M.UpdateFooter()
end

-- Boutons Deplacer / Raccourcis de la barre de titre : accentues tant que leur mode est actif.
function M.UpdateActionButtons()
	local f = M.frame
	if not f or not f.moveBtn then return end
	T.SetButtonText(f.moveBtn, L("mod.menu.btn.move"))
	T.SetButtonText(f.bindBtn, L("mod.menu.btn.bind"))
	T.SetSelected(f.moveBtn, SUI.Mover and SUI.Mover.active and true or false)
	T.SetSelected(f.bindBtn, SUI.Bind and SUI.Bind.active and true or false)
end

-- Appele par Mover / Bind a l entree et a la sortie de leur mode.
function M.OnMoveMode(on)
	M.SetRaised(on and SUI.Mover and SUI.Mover.active)
	M.UpdateActionButtons()
	if M.frame and M.frame:IsShown() and M.page == "home" then M.Render() end
end

-- Bouton Normal / Raid de la barre de titre.
function M.UpdateMode()
	local f = M.frame
	if not f or not f.modeBtn then return end
	T.SetButtonText(f.modeBtn, L("mod.mode.button", SUI.Mode.Name(SUI.Config.mode)))
	T.SetSelected(f.modeBtn, SUI.Config.mode ~= "normal")
end

function M.ToggleMode()
	local target = SUI.Mode.Other()
	local ok, key = SUI.Mode.Toggle()
	if key == "msg.mode.queued" then SUI.Print(L(key, SUI.Mode.Name(target))) end
	M.UpdateMode()
end

function M.UpdateFooter()
	local f = M.frame
	T.SetButtonText(f.profileBtn, L("menu.profile", SUI.Config.curName))
	local ints = SUI.Api.Integrations()
	local ext = SUI.Api.Summary()
	local held = SUI.Migrate and SUI.Migrate.HeldCount() or 0
	local line2 = L("menu.integ", getn(ints) > 0 and table.concat(ints, ", ") or L("menu.none"))
	if held > 0 then line2 = L("menu.migrate", held) end
	f.info:SetText(L("menu.ext", ext or L("menu.none")) .. "\n" .. line2)
end

-- Rendu complet de la page courante (ou des resultats de recherche).
-- Le client change le niveau du cadre de contenu apres sa creation (SetScrollChild, cadre "toplevel" releve a l'affichage) : M.lvl, lu a la
-- construction, ne correspond plus. Les controles (M.lvl + 4) se retrouvaient SOUS le cadre de contenu (qui capte la souris) et ne recevaient
-- plus aucun clic. On recale M.lvl sur le niveau reel et on decale d'autant les cadres deja crees.
function M.SyncLevel()
	local ch = M.child
	if not ch or not M.lvl then return end
	local cur = ch:GetFrameLevel()
	local delta = cur - M.lvl
	if delta == 0 then return end
	local seen = { [ch] = true }
	local strata = ch:GetFrameStrata()
	local kids = { ch:GetChildren() }
	for i = 1, getn(kids) do
		local k = kids[i]
		M.Restack(k, strata, delta, seen)
	end
	M.lvl = cur
end

function M.Render()
	local f = M.frame
	if not f then return end
	M.SyncLevel()
	M.CloseDrop()
	local key = M.page .. ":" .. M.cat .. ":" .. (M.search ~= "" and "s" or "p") .. ":" .. M.mode
	if key ~= M.lastKey then
		M.lastKey = key
		M.cs.cur = 0
	end
	M.Begin()
	M.HeadReset()
	M.roleButtons = {}
	M.perfCard = nil
	local kind = M.page
	if M.search ~= "" then kind = "search" end
	M.Pages[kind]()
	M.End()
	M.UpdateNav()
	if M.SyncPreview then M.SyncPreview() end
	if M.focus then
		M.FocusKey(M.focus)
		M.focus = nil
	end
end

-- Amene la ligne / la carte de la cle dans la zone visible.
function M.FocusKey(key)
	if string.sub(key, 1, 4) == "sec:" then
		local y = M.secY and M.secY[string.sub(key, 5)]
		if y then M.ScrollTo(M.cs, y) end
		return
	end
	local p = M.pools.cell
	for i = 1, M.used.cell do
		if p[i].opt and p[i].opt.key == key then
			M.ScrollTo(M.cs, p[i].y - 50)
			return
		end
	end
	p = M.pools.mcard
	for i = 1, M.used.mcard do
		if p[i].key == key then
			M.ScrollTo(M.cs, p[i].y - 50)
			return
		end
	end
end

function M.Show(arg)
	if not M.frame and SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return
	end
	M.Build()
	M.Route(arg)
	M.ApplyScale()
	M.RebuildNav()
	M.Translate()
	M.SetRaised(SUI.Mover and SUI.Mover.active)
	M.frame:Show()
	M.Render()
	if type(arg) == "string" and string.find(arg, ".", 1, true) then M.OpenAt(arg) end     -- /sui menu actionbars.bar3
end

function M.Hide()
	if M.frame then M.frame:Hide() end
end

function M.Toggle()
	if M.frame and M.frame:IsShown() then M.Hide() else M.Show() end
end

-- ---------------------------------------------------------------- SAUT A UN REGLAGE (API publique)
-- SUI.Menu.OpenAt(cle, opts) : ouvre le menu (meme ferme), va a la page, FAIT DEFILER jusqu'a la ligne puis la met en surbrillance
--   quelques secondes (2,5 s forte, 2,5 s attenuee). "cle" accepte :
--     - une cle de reglage        "actionbars.bar3.scale"      -> cette ligne ;
--     - un PREFIXE de reglages    "actionbars.bar3." ou "actionbars.bar3" -> tout le groupe est surligne, defilement sur le premier ;
--       (suffixe "*" = simple debut de nom : "group.enem*") ;
--     - une cle de cadre du Mover "bars.bar3", "unit.player", "raid" -> convertie par SUI.Menu.OptionAnchorFor ;
--     - une categorie ("actionbars"), "cat:<categorie>", ou une page ("home", "modules", "styles", "profiles", "addons").
--   opts (facultatif) : { noHighlight = true } pas de surbrillance ; { preview = true } rallume le volet d'apercu 2D s'il avait ete coupe.
--   Retour : atteint (true si un reglage OU une categorie a ete atteint ; false = cle inconnue, le menu s'est ouvert sans erreur sur
--   l'accueil), cle du reglage cible (ou nil). Si le reglage n'existe qu'en mode Tout, le menu y passe et le dit dans le chat.
--   Les sections ne sont jamais repliees dans ce menu : rien a deplier. Cle inconnue : on remonte "a.b.c" -> "a.b" -> "a" puis la
--   categorie proche. Appelable depuis n'importe quel module : if SUI.Menu and SUI.Menu.OpenAt then SUI.Menu.OpenAt("meter.") end
-- SUI.Menu.OptionAnchorFor(cleDeCadre) : prefixe de reglages d'un cadre deplacable (cle du Mover / du Layout), nil si inconnu.
-- SUI.Menu.RegisterAnchor(cleDeCadre, prefixe) : un module declare (ou corrige) la correspondance de SES cadres. Les cles a chiffre final
--   ("meter.win3", "powerauras.z2") retombent sur la cle sans chiffre ("meter.win"). Sans entree : premier segment = categorie ("loot." ...).
-- SUI.Menu.RegisterTask(id, cleTexte, cleReglage, categorie) : ajoute une tache a la liste "Je veux changer..." de l'accueil.
-- Nouveautes : SUI.Menu.IsNew(cle), NewCount(cat), NewClear(cat | nil = tout) ; le "connu" est memorise (global menuKnown).
M.anchors = {}
M.ANCHOR_ALIAS = { bars = "actionbars", unit = "units", pp = "pallypower", hud = "perf", lootwin = "loot", lootroll = "loot",
	pins = "group", party = "group" }
local UF = "unit."      -- (concatenation : le controle des traductions prendrait ces cles de cadre pour des textes)
M.ANCHORS_DEF = {
	"bars.main", "actionbars.main.", "bars.bar2", "actionbars.bar2.", "bars.bar3", "actionbars.bar3.", "bars.bar4", "actionbars.bar4.",
	"bars.bar5", "actionbars.bar5.", "bars.stance", "actionbars.stance.", "bars.pet", "actionbars.pet.", "bars.micro", "actionbars.micro.",
	"bars.xp", "actionbars.xpbar", "bars.rep", "actionbars.xpbar",
	"unit.player", "units.player.", "unit.target", "units.target.", "unit.targettarget", "units.tot.", UF .. "targettargettarget", "units.tott.",
	"unit.pet", "units.pet.", UF .. "pettarget", "units.pettarget.", UF .. "focus", "units.focus.",
	"group", "group.", "group.enemies", "group.enem*", "raid", "raid.", "hud", "perf.hud", "minimap", "minimap.",
	"castbar.player", "castbar.player", "castbar.target", "castbar.target", "castbar.focus", "castbar.focus",
	"auras.pb", "auras.buffs", "auras.pd", "auras.debuffs", "auras.pw", "auras.weapon", "auras.tb", "auras.targetbuffs",
	"auras.td", "auras.targetdebuffs",
	"meter.win", "meter.", "threat.win", "threat.", "tanktools.bar", "tanktools.", "totems.bar", "totems.", "tracker", "tracker.",
	"tracker.win", "tracker.", "marks.bar", "marks.", "buffwatch.win", "buffwatch.", "datatext.win", "datatext.",
	"bossmods.win", "bossmods.", "bossmods.msg", "bossmods.", "esport.win", "esport.", "pp.win", "pallypower.",
	"powerauras.z", "powerauras.", "powerauras.banner", "powerauras.", "messages.win", "messages.win*", "messages.badge", "messages.badge",
	"messages.hist", "messages.hist*", "messages.toasts", "messages.toast*", "loot", "loot.", "lootwin", "loot.lootframe", "lootroll",
	"loot.rollframe", "items", "items.", "mail", "mail.", "auction", "auction.", "bags.window", "bags.", "bags.bank", "bags.bankwin",
	"finder.win", "finder.", "cursor.char", "cursor.char*", "chat.copy", "chat.",
}
function M.RegisterAnchor(moverKey, optionPrefix)
	if type(moverKey) ~= "string" or moverKey == "" or type(optionPrefix) ~= "string" or optionPrefix == "" then return false end
	M.anchors[moverKey] = optionPrefix
	return true
end
for i = 1, getn(M.ANCHORS_DEF), 2 do M.RegisterAnchor(M.ANCHORS_DEF[i], M.ANCHORS_DEF[i + 1]) end

function M.OptionAnchorFor(frameKey)
	if type(frameKey) ~= "string" or frameKey == "" then return nil end
	local a = M.anchors[frameKey]
	if a then return a, false end
	local base = string.gsub(frameKey, "[0-9]+$", "")
	if base ~= frameKey and base ~= "" then
		a = M.anchors[base]
		if a then return a, false end
	end
	local _, _, seg = string.find(frameKey, "^([^.]+)")
	if seg then
		seg = M.ANCHOR_ALIAS[seg] or seg
		if M.CatExists(seg) then return seg .. ".", true end
	end
	return nil
end

-- La cle de reglage "key" appartient-elle au groupe "pre" ? ("a.b." debut de nom ; "a.b*" debut de nom ; "a.b" = a.b ou a.b.*)
function M.KeyMatches(key, pre)
	local n = string.len(pre)
	local last = string.sub(pre, n, n)
	if last == "." then return string.sub(key, 1, n) == pre end
	if last == "*" then return string.sub(key, 1, n - 1) == string.sub(pre, 1, n - 1) end
	return key == pre or string.sub(key, 1, n + 1) == pre .. "."
end

function M.OptionsFor(pre)
	local res = {}
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.type ~= "header" and M.KeyMatches(o.key, pre) then tinsert(res, o) end
	end
	return res
end

-- Retourne la liste des reglages, le prefixe retenu et la categorie de repli (cle inconnue : categorie proche ou nil).
function M.ResolveAt(key)
	local list = M.OptionsFor(key)
	if getn(list) > 0 then return list, key, nil end
	local a, generic = M.OptionAnchorFor(key)
	if a and not generic then
		list = M.OptionsFor(a)
		if getn(list) > 0 then return list, a, nil end
	end
	local cur = key
	while true do
		local _, _, up = string.find(cur, "^(.*)%.[^.]*$")
		if not up or not string.find(up, ".", 1, true) then break end
		cur = up
		list = M.OptionsFor(cur)
		if getn(list) > 0 then return list, cur, nil end
	end
	local _, _, seg = string.find(a or key, "^([^.*]+)")
	if seg then
		seg = M.ANCHOR_ALIAS[seg] or seg
		if M.CatExists(seg) then return list, nil, seg end
	end
	return list, nil, nil
end

-- Surbrillance : cle exacte (M.hl) ou groupe (M.hlPre) ; M.hlA = opacite ; M.hlTimed = surbrillance de OpenAt (s'eteint seule).
function M.IsHl(key)
	if M.hl == key then return true end
	return M.hlPre ~= nil and M.KeyMatches(key, M.hlPre)
end

function M.RefreshHl()
	local p = M.pools.cell
	for i = 1, M.used.cell do
		if p[i].opt then M.PaintHl(p[i], p[i].opt.key) end
	end
end

local function hlEnd()
	M.hlTask = nil
	if not M.hlTimed then return end
	M.hl, M.hlPre, M.hlTimed, M.hlA = nil, nil, nil, nil
	if M.frame and M.frame:IsShown() then M.RefreshHl() end
end

local function hlSoft()
	M.hlTask = nil
	if not M.hlTimed then return end
	M.hlA = 0.12
	if M.frame and M.frame:IsShown() then M.RefreshHl() end
	M.hlTask = SUI.After(2.5, hlEnd, "uxhl")
end

function M.ClearHl()
	SUI.Cancel(M.hlTask)
	M.hlTask, M.hl, M.hlPre, M.hlTimed, M.hlA = nil, nil, nil, nil, nil
end

local PAGES = { home = true, modules = true, styles = true, profiles = true, addons = true, errors = true }

function M.OpenAt(key, opts)
	opts = opts or {}
	if type(key) ~= "string" or key == "" then
		M.Show()
		return false, nil
	end
	if not M.frame and SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return false, nil
	end
	M.Show()
	if not M.frame then return false, nil end
	if opts.preview and not M.PreviewWanted() then M.TogglePreview() end
	local _, _, c0 = string.find(key, "^cat:(.+)$")
	c0 = c0 or key
	if PAGES[c0] then
		M.ClearHl()
		M.Open(c0)
		return true, nil
	end
	if M.CatExists(c0) then
		M.ClearHl()
		M.Open("cat", c0)
		return true, nil
	end
	local list, pre, cat = M.ResolveAt(key)
	if getn(list) == 0 then
		M.ClearHl()
		if cat then
			M.Open("cat", cat)
			return true, nil
		end
		M.Open("home")
		return false, nil
	end
	local target
	if M.mode == "all" then
		target = list[1]
	else
		for i = 1, getn(list) do
			if list[i].simple then
				target = list[i]
				break
			end
		end
	end
	local adv = false
	if not target then
		target = list[1]
		adv = target.cat ~= "modules"
	end
	if target.cat == "modules" then
		M.page = "modules"
		M.filter = "all"
	else
		if adv then
			M.mode = "all"
			SUI.Config.SetGlobal("menuMode", "all")
			M.Translate()
			SUI.Print(L("msg.menu.openat.adv"))
		end
		M.page = "cat"
		M.cat = target.cat
	end
	M.StorePage()
	SUI.Cancel(M.hlTask)
	M.hlTask = nil
	if opts.noHighlight then
		M.hl, M.hlPre, M.hlTimed, M.hlA = nil, nil, nil, nil
	else
		M.hl = target.key
		M.hlPre = getn(list) > 1 and pre or nil
		M.hlTimed, M.hlA = true, 0.3
		M.hlTask = SUI.After(2.5, hlSoft, "uxhl")
	end
	M.focus = target.key
	M.search = ""
	M.resSel = 0
	M.silent = true
	M.frame.edit:SetText("")
	M.silent = false
	M.frame.editHint:SetText(L("mod.menu.search"))
	M.Render()
	return true, target.key
end

-- ---------------------------------------------------------------- taches courantes ("Je veux changer...", page d'accueil)
M.tasks = {}
function M.RegisterTask(id, labelKey, optionKey, cat)
	if type(id) ~= "string" or type(labelKey) ~= "string" or type(optionKey) ~= "string" then return false end
	if not cat then
		local _, _, seg = string.find(optionKey, "^([^.*]+)")
		cat = seg and (M.ANCHOR_ALIAS[seg] or seg) or nil
	end
	for i = 1, getn(M.tasks) do
		if M.tasks[i].id == id then
			M.tasks[i].label, M.tasks[i].key, M.tasks[i].cat = labelKey, optionKey, cat
			return true
		end
	end
	tinsert(M.tasks, { id = id, label = labelKey, key = optionKey, cat = cat })
	return true
end
M.RegisterTask("bar", "mod.menu.want.bar", "actionbars.main.")
M.RegisterTask("player", "mod.menu.want.player", "units.player.")
M.RegisterTask("target", "mod.menu.want.target", "units.target.")
M.RegisterTask("group", "mod.menu.want.group", "group.")
M.RegisterTask("raid", "mod.menu.want.raid", "raid.")
M.RegisterTask("minimap", "mod.menu.want.minimap", "minimap.")
M.RegisterTask("chat", "mod.menu.want.chat", "chat.")
M.RegisterTask("auras", "mod.menu.want.auras", "auras.")
M.RegisterTask("castbar", "mod.menu.want.castbar", "castbar.player")
M.RegisterTask("bags", "mod.menu.want.bags", "bags.")
M.RegisterTask("meter", "mod.menu.want.meter", "meter.")
M.RegisterTask("plates", "mod.menu.want.plates", "nameplates.")

-- ---------------------------------------------------------------- nouveautes (reglages apparus depuis la derniere fois)
-- "Connu" = ensemble des cles de reglage deja presentees (global menuKnown). Premier lancement avec cette fonction : tout l'existant est
-- connu (rien n'est signale). Ensuite toute cle absente du connu est "nouvelle" jusqu'a NewClear.
function M.NewSnapshot(cat)
	local C = SUI.Config
	local known = C.GetGlobal("menuKnown")
	if type(known) ~= "table" then known = {} end
	local n = 0
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.type ~= "header" and (cat == nil or o.cat == cat) then
			if not known[o.key] then n = n + 1 end
			known[o.key] = true
		end
	end
	C.SetGlobal("menuKnown", known)
	M.newKeys, M.newCat, M.newTotal = nil, nil, nil
	return n
end

function M.NewScan()
	if M.newKeys then return end
	local known = SUI.Config.GetGlobal("menuKnown")
	if type(known) ~= "table" then M.NewSnapshot(nil) end
	known = SUI.Config.GetGlobal("menuKnown")
	M.newKeys, M.newCat, M.newTotal = {}, {}, 0
	if type(known) ~= "table" then return end
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.type ~= "header" and not known[o.key] then
			M.newKeys[o.key] = true
			local c = o.cat or "?"
			M.newCat[c] = (M.newCat[c] or 0) + 1
			M.newTotal = M.newTotal + 1
		end
	end
end

function M.IsNew(key)
	M.NewScan()
	return M.newKeys[key] and true or false
end

function M.NewCount(cat)
	M.NewScan()
	if cat == nil then return M.newTotal end
	return M.newCat[cat] or 0
end

-- Marque comme vu : une categorie, ou tout (cat == nil). Retourne le nombre de reglages concernes.
function M.NewClear(cat)
	local n = M.NewSnapshot(cat)
	if M.frame and M.frame:IsShown() then M.Render() end
	return n
end

-- ---------------------------------------------------------------- reactions aux changements de reglages
function M.OnConfig(key, value)
	local f = M.frame
	if not f or not f:IsShown() then return end
	if key == nil or key == "ui.locale" or key == "mode" or key == "role" or key == "layout" then
		if key == "ui.locale" or key == nil then
			M.RebuildNav()
			M.Translate()
		end
		if key == "mode" then M.UpdateMode() end
		M.Render()
		return
	end
	if key == "ui.scale" and not M.scalePending then
		M.scalePending = true
		SUI.After(0.6, M.ScaleLater, "menuscale")
	end
	if string.sub(key, 1, 6) == "style." and (M.page == "styles" or M.page == "home") then
		M.Render()
		return
	end
	if string.sub(key, 1, 8) == "modules." then
		M.UpdateNav()
		M.UpdateFooter()
		if M.page == "modules" or M.page == "cat" or M.search ~= "" then M.Render() end
		return
	end
	if M.RefreshKey then M.RefreshKey(key) end
	M.UpdateFooter()
end

function M.ScaleLater()
	M.scalePending = false
	if M.frame and M.frame:IsShown() then M.ApplyScale() end
	-- l'assistant est affine de la meme facon (il ne reagit pas tout seul a ui.scale)
	if M.WizFit then M.WizFit() end
end

-- ---------------------------------------------------------------- export / import de profil
function M.BuildTransfer()
	if M.tf then return M.tf end
	local f = CreateFrame("Frame", "ShikiUI_Transfer", UIParent)
	M.tf = f
	f:SetWidth(460)
	f:SetHeight(120)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	f.edit = T.Edit(f, 436, 24)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
	f.edit:SetMaxLetters(0)
	f.ok = T.Button(f, "", 100, 22, function()
		if f.mode == "import" then M.DoImport(f.edit:GetText(), f.kind) end
		f:Hide()
	end)
	f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
	f.cancel = T.Button(f, "", 100, 22, function() f:Hide() end)
	f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
	f.msg = T.Text(f, 10, T.c.dim, "LEFT")
	f.msg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
	tinsert(UISpecialFrames, "ShikiUI_Transfer")
	return f
end

-- text : chaine a exporter si ce n'est pas le profil ; kind = "style" : l'import cree un style (et non un profil).
function M.ShowTransfer(mode, text, kind)
	if not M.tf and SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return
	end
	local f = M.BuildTransfer()
	f.mode = mode
	f.kind = kind
	f.title:SetText(mode == "export" and L("transfer.export") or L("transfer.import"))
	T.SetButtonText(f.ok, mode == "export" and L("transfer.close") or L("transfer.do"))
	T.SetButtonText(f.cancel, L("transfer.cancel"))
	f.msg:SetText(mode == "export" and L("msg.export.hint") or "")
	f:Show()
	if mode == "export" then
		f.edit:SetText(text or SUI.Config.Export())
		f.edit:SetFocus()
		f.edit:HighlightText()
	else
		f.edit:SetText("")
		f.edit:SetFocus()
	end
end

function M.DoImport(str, kind)
	if kind == "style" then
		local ok, id, acc, ign = SUI.Style.Import(str)
		if ok then
			SUI.Print(L("msg.style.imported", id, acc, ign, id))
		else
			SUI.Print(L("msg.import.bad", (string.sub(tostring(id), 1, 4) == "msg.") and L(id) or tostring(id)))
		end
		return ok
	end
	local ok, a, b, c = SUI.Config.Import(str)
	if ok then
		SUI.Print(L("msg.import.ok", a, b, c))
	else
		SUI.Print(L("msg.import.bad", tostring(a)))
	end
	return ok
end

-- (l'assistant de premiere installation est dans Menu_Wizard.lua ; les profils et sauvegardes dans Menu_Profiles.lua)

-- /sui menu [accueil | modules | styles | <module ou categorie>] : ouvre le menu sur une page.
SUI.RegisterCommand("menu", function(rest)
	local _, _, w = string.find(rest or "", "^%s*(%S+)")
	if w then w = string.lower(w) end
	if w == "accueil" then w = "home" end
	M.Show(w)
end, "mod.menu.help")

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) la molette atteint-elle le ScrollFrame quand le curseur est sur un bouton / une ligne (les
-- elements activent donc EnableMouseWheel eux aussi) ; (2) le rognage des clics hors zone visible d'un ScrollFrame ; (3) GetCursorPosition /
-- IsMouseButtonDown pour le glissement de la barre ; (4) OnTabPressed d'un EditBox ; (5) la coupure d'un FontString trop long par SetHeight
-- (les textes sont donc aussi raccourcis par M.Short) ; (6) le niveau (SetFrameLevel) des controles poses au-dessus des lignes.
