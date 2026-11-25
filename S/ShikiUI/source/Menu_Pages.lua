-- ShikiUI Menu_Pages : les pages du menu (Accueil, Modules, Styles et mises en page, reglages d'un module, resultats de recherche) et les
-- elements en pool qu'elles utilisent (lignes de reglage, cartes, boutons, controles). Le moteur (fenetre, navigation, defilement, recherche) est
-- dans Menu.lua. Tout l'aspect vient des jetons du style (T.c.*, T.Backdrop, T.Text, T.Button, T.Accent) : aucune couleur ni texture en dur.
-- Un element est pris avec M.Get(genre) (nil en combat si le pool est trop petit : la page est alors tronquee, jamais de creation en combat).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu

local getn, tinsert = table.getn, table.insert
local floor = math.floor
local P = M.Pages
local NEW = M.New

local CW = 648           -- largeur utile de la zone defilante
local WIDE_W, WIDE_CTL = 648, 214      -- ligne a une colonne (aide visible) : largeur, largeur du controle
local COMPACT_W, COMPACT_CTL = 316, 138  -- ligne a deux colonnes (mode Essentiel)

-- ---------------------------------------------------------------- valeurs affichees
function M.FmtNum(v, o)
	if o.step and o.step < 1 then return string.format("%.2f", v) end
	return tostring(floor(v + 0.5))
end

function M.ValueText(o, v)
	if v == nil then v = SUI.Config.Get(o.key) end
	local t = o.type
	if t == "bool" then return L(v and "mod.menu.val.on" or "mod.menu.val.off") end
	if t == "number" then return M.FmtNum(v or 0, o) end
	if t == "choice" then return M.ChoiceLabel(o, v) end
	if v == nil or v == "" then return L("mod.menu.val.empty") end
	return tostring(v)
end

local function afterSet(o)
	if o.reload then SUI.Print(L("msg.reload")) end
end

local function wheel(f)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", M.OnWheel)
	return f
end

-- ---------------------------------------------------------------- elements simples : section, texte, bouton, note
function NEW.sec()
	local f = CreateFrame("Frame", nil, M.child)
	f.title = T.Text(f, 13, T.c.text, "LEFT")
	f.title:SetPoint("LEFT", f, "LEFT", 2, 3)
	f.title:SetWidth(480)
	f.title:SetHeight(16)
	f.count = T.Text(f, 10, T.c.dim, "RIGHT")
	f.count:SetPoint("RIGHT", f, "RIGHT", -2, 3)
	f.count:SetWidth(140)
	f.count:SetHeight(12)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetTexture(T.tex.white)
	f.line:SetHeight(1)
	f.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
	f.line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 2)
	-- bouton "Defaut" de la section (visible seulement si la section a des reglages modifies)
	f.rst = T.Button(f, "", 110, 18, function(b)
		local sec = b:GetParent()
		M.ConfirmClick(b, "secrst:" .. tostring(sec.rid), L("mod.menu.secreset"), function() M.ResetList(sec.rlist) end)
	end)
	f.rst:SetPoint("RIGHT", f, "RIGHT", -150, 3)
	f.rst:SetFrameLevel(M.lvl + 2)
	f.rst:SetScript("OnEnter", function() M.TipShow(this, L("mod.menu.secreset"), L("mod.menu.secreset.tip")) end)
	f.rst:SetScript("OnLeave", M.TipHide)
	f.rst:Hide()
	return f
end

-- Remet a leur valeur par defaut les reglages modifies de la liste (options) ; sauvegarde avant, retourne le nombre.
function M.ResetList(list)
	local n = 0
	for i = 1, getn(list or {}) do
		local o = list[i]
		if o.type ~= "header" and SUI.Config.IsModified(o.key) then
			if n == 0 and SUI.Backup then SUI.Backup.Create("reset") end
			SUI.Config.Reset(o.key)
			n = n + 1
		end
	end
	SUI.Print(L("msg.menu.modreset", n))
	M.Render()
	return n
end

function M.Section(title, count, list)
	M.EndRow(0)
	if M.y > 0 then M.y = M.y + 10 end
	local s = M.Get("sec")
	if not s then return nil end
	M.Flow(s, 1, CW, 26, 0, 6)
	local r, g, b = T.Accent()
	s.title:SetTextColor(r, g, b, 1)
	s.title:SetText(title)
	s.count:SetText(count or "")
	s.line:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	local nmod = 0
	for i = 1, getn(list or {}) do
		if list[i].type ~= "header" and SUI.Config.IsModified(list[i].key) then nmod = nmod + 1 end
	end
	s.rlist, s.rid = list, title
	if nmod > 0 then
		T.SetButtonText(s.rst, L("mod.menu.secreset.n", nmod))
		s.rst:Show()
	else
		s.rst:Hide()
	end
	M.EndRow(6)
	return s
end

function NEW.txt()
	local f = CreateFrame("Frame", nil, M.child)
	f.fs = T.Text(f, 11, T.c.dim, "LEFT")
	f.fs:SetPoint("TOPLEFT", f, "TOPLEFT", 4, 0)
	f.fs:SetWidth(CW - 8)
	f.fs:SetJustifyV("TOP")
	return f
end

-- Paragraphe (hauteur h) ; col : jeton de couleur (T.c.dim par defaut).
function M.Para(text, h, col)
	local t = M.Get("txt")
	if not t then return nil end
	M.Flow(t, 1, CW, h, 0, 6)
	t.fs:SetHeight(h)
	t.fs:SetText(text)
	col = col or T.c.dim
	t.fs:SetTextColor(col[1], col[2], col[3], 1)
	M.EndRow(6)
	return t
end

function NEW.btn()
	local b = T.Button(M.child, "", 100, 22, function(btn, mb)
		if btn.fn then btn.fn(btn, mb) end
	end)
	b:SetFrameLevel(M.lvl + 2)
	wheel(b)
	return b
end

-- Bouton dans une grille de cols colonnes (largeur w, hauteur h).
function M.GridBtn(label, cols, w, h, fn, selected)
	local b = M.Get("btn")
	if not b then return nil end
	M.Flow(b, cols, w, h, 12, 8)
	T.SetButtonText(b, label)
	b.fn = fn
	T.SetSelected(b, selected)
	return b
end

function NEW.note()
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	wheel(f)
	f.fs = T.Text(f, 11, T.c.text, "LEFT")
	f.fs:SetPoint("LEFT", f, "LEFT", 12, 0)
	f.fs:SetWidth(CW - 150)
	f.fs:SetHeight(28)
	f.btn = T.Button(f, "", 110, 22, function(b)
		if b.fn then b.fn() end
	end)
	f.btn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	return f
end

-- ---------------------------------------------------------------- lignes de reglage et controles
local function ctlBase(kind, w, h)
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 4)
	f:SetWidth(w)
	f:SetHeight(h)
	f.ck = kind
	wheel(f)
	return f
end

function M.CtlBool(ctl, on)
	local c = ctl.cell
	if not c or not c.opt then return end
	SUI.Config.Set(c.opt.key, on)
	afterSet(c.opt)
	M.SyncMod(c)
end

function NEW.c_check()
	local b
	b = T.Check(M.child, function(on) M.CtlBool(b, on) end)
	b:SetFrameLevel(M.lvl + 4)
	b:SetWidth(18)
	b:SetHeight(18)
	b.ck = "check"
	return b
end

function M.CtlNum(f, v)
	local c = f.cell
	if not c or not c.opt then return end
	local o = c.opt
	SUI.Config.Set(o.key, v)
	local nv = SUI.Config.Get(o.key)
	f.edit:SetText(M.FmtNum(nv, o))
	T.SetSlider(f.slider, o.min or 0, o.max or 100, o.step or 1, nv)
	afterSet(o)
	M.SyncMod(c)
end

function M.CtlNumText(f)
	local c = f.cell
	if not c or not c.opt then return end
	SUI.Config.Set(c.opt.key, f.edit:GetText() or "")
	M.RefreshCtl(c)
	afterSet(c.opt)
	M.SyncMod(c)
end

function NEW.c_slider()
	local f = ctlBase("slider", WIDE_CTL, 24)
	f.slider = T.Slider(f, 150, function(v) M.CtlNum(f, v) end)
	f.slider:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.edit = T.Edit(f, 48, 20)
	f.edit:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.edit:SetScript("OnEnterPressed", function()
		M.CtlNumText(f)
		this:ClearFocus()
	end)
	return f
end

function NEW.c_drop()
	local f = ctlBase("drop", WIDE_CTL, 24)
	f.btn = T.Button(f, "", WIDE_CTL, 22, function() M.OpenDrop(f) end)
	f.btn:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.arrow = T.Text(f.btn, 10, T.c.dim, "RIGHT")
	f.arrow:SetPoint("RIGHT", f.btn, "RIGHT", -6, 0)
	f.arrow:SetWidth(10)
	f.arrow:SetHeight(12)
	f.arrow:SetText("v")
	return f
end

function M.CtlSeg(f, i)
	local c = f.cell
	if not c or not c.opt then return end
	local v = c.opt.choices[i]
	if v ~= nil then
		SUI.Config.Set(c.opt.key, v)
		afterSet(c.opt)
		M.RefreshCtl(c)
		M.SyncMod(c)
	end
end

function NEW.c_seg()
	local f = ctlBase("seg", WIDE_CTL, 24)
	f.segs = {}
	for i = 1, 3 do
		local b = T.Button(f, "", 70, 22, function(btn) M.CtlSeg(f, btn.index) end)
		b.index = i
		f.segs[i] = b
	end
	return f
end

function NEW.c_color()
	local f = ctlBase("color", WIDE_CTL, 24)
	f.hex = T.Edit(f, 90, 20)
	f.hex:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	f.hex:SetMaxLetters(8)
	f.hex:SetScript("OnEnterPressed", function()
		local c = f.cell
		if c and c.opt then
			local txt = this:GetText() or ""
			if not SUI.Config.Set(c.opt.key, txt) then this:SetText(SUI.Config.Get(c.opt.key)) end
			M.RefreshCtl(c)
			M.SyncMod(c)
		end
		this:ClearFocus()
	end)
	f.swatchFrame = CreateFrame("Frame", nil, f)
	f.swatchFrame:SetWidth(20)
	f.swatchFrame:SetHeight(20)
	f.swatchFrame:SetPoint("RIGHT", f.hex, "LEFT", -6, 0)
	T.Backdrop(f.swatchFrame, T.c.inset, T.c.border)
	f.swatch = f.swatchFrame:CreateTexture(nil, "OVERLAY")
	f.swatch:SetTexture(T.tex.white)
	f.swatch:SetPoint("TOPLEFT", f.swatchFrame, "TOPLEFT", 2, -2)
	f.swatch:SetPoint("BOTTOMRIGHT", f.swatchFrame, "BOTTOMRIGHT", -2, 2)
	return f
end

function NEW.c_text()
	local e = T.Edit(M.child, WIDE_CTL, 22)
	e:SetFrameLevel(M.lvl + 4)
	e.ck = "text"
	e:SetScript("OnEnterPressed", function()
		local c = e.cell
		if c and c.opt then
			if not SUI.Config.Set(c.opt.key, this:GetText() or "") then this:SetText(tostring(SUI.Config.Get(c.opt.key) or "")) end
			M.SyncMod(c)
		end
		this:ClearFocus()
	end)
	return e
end

local function syncSwatch(ctl, o, v)
	local sr, sg, sb
	if SUI.Style and v ~= "" then sr, sg, sb = SUI.Style.ParseHex(v) end
	if not sr then
		local c = T.c[string.sub(o.key, 9)]
		if c then sr, sg, sb = c[1], c[2], c[3] else sr, sg, sb = T.c.dim[1], T.c.dim[2], T.c.dim[3] end
	end
	ctl.swatch:SetVertexColor(sr, sg, sb, 1)
end

-- Met a jour la VALEUR montree par le controle de la ligne c.
function M.RefreshCtl(c)
	local o, ctl = c.opt, c.ctl
	if not o or not ctl or ctl.cell ~= c then return end
	local v = SUI.Config.Get(o.key)
	local k = ctl.ck
	if k == "check" then
		T.SetCheck(ctl, v)
	elseif k == "slider" then
		T.SetSlider(ctl.slider, o.min or 0, o.max or 100, o.step or 1, v)
		ctl.edit:SetText(M.FmtNum(v, o))
	elseif k == "drop" then
		T.SetButtonText(ctl.btn, M.ChoiceLabel(o, v))
	elseif k == "seg" then
		for i = 1, ctl.n do T.SetSelected(ctl.segs[i], o.choices[i] == v) end
	elseif k == "color" then
		ctl.hex:SetText(v or "")
		syncSwatch(ctl, o, v or "")
	elseif k == "text" then
		ctl:SetText(tostring(v or ""))
	end
end

-- Pose le bon controle sur la ligne c (une fois par rendu).
function M.AttachCtl(c, o, ctlW, wide)
	local t = o.type
	local kind = "c_text"
	local n = 0
	if t == "bool" then
		kind = "c_check"
	elseif t == "number" then
		kind = "c_slider"
	elseif t == "color" then
		kind = "c_color"
	elseif t == "choice" and o.choices then
		n = getn(o.choices)
		kind = "c_drop"
		if n >= 1 and n <= 3 then
			local chars = 0
			for i = 1, n do chars = chars + string.len(M.ChoiceLabel(o, o.choices[i])) end
			if chars <= (wide and 30 or 19) then kind = "c_seg" end
		end
	end
	local ctl = M.Get(kind)
	c.ctl = nil
	if not ctl then return end
	ctl.cell = c
	c.ctl = ctl
	ctl:ClearAllPoints()
	ctl:SetPoint("RIGHT", c, "RIGHT", -6, 0)
	if kind == "c_slider" then
		ctl:SetWidth(ctlW)
		ctl.slider:SetWidth(ctlW - 56)
	elseif kind == "c_drop" then
		ctl:SetWidth(ctlW)
		ctl.btn:SetWidth(ctlW)
	elseif kind == "c_seg" then
		ctl:SetWidth(ctlW)
		ctl.n = n
		local w = floor(ctlW / n)
		for i = 1, 3 do
			local b = ctl.segs[i]
			if i <= n then
				b:SetWidth(w - 2)
				b:ClearAllPoints()
				b:SetPoint("LEFT", ctl, "LEFT", (i - 1) * w, 0)
				T.SetButtonText(b, M.ChoiceLabel(o, o.choices[i]))
				b:Show()
			else
				b:Hide()
			end
		end
	elseif kind == "c_color" then
		ctl:SetWidth(ctlW)
	elseif kind == "c_text" then
		ctl:SetWidth(ctlW)
	end
	ctl:Show()
end

function M.SyncMod(c)
	local o = c.opt
	if o and SUI.Config.IsModified(o.key) then c.mod:Show() else c.mod:Hide() end
end

local function cellEnter()
	local c = this
	local o = c.opt
	if not o then return end
	local def = SUI.Config.defaults[o.key]
	M.TipShow(c, L(o.label), M.Tx(o.tip), L("mod.menu.default", M.ValueText(o, def)) .. "    " .. L("mod.menu.key", o.key),
		o.reload and L("mod.menu.needsreload") or (c.fresh:IsShown() and L("mod.menu.new.tip") or nil))
end

-- Clic sur la ligne d'un interrupteur : bascule (grande zone cliquable).
local function cellUp()
	local c = this
	local o, ctl = c.opt, c.ctl
	if o and o.type == "bool" and ctl and ctl.cell == c and ctl.ck == "check" then
		T.SetCheck(ctl, not ctl.on)
		M.CtlBool(ctl, ctl.on)
	end
end

function NEW.cell()
	local c = CreateFrame("Frame", nil, M.child)
	c:SetFrameLevel(M.lvl + 1)
	c:EnableMouse(true)
	wheel(c)
	c:SetScript("OnEnter", cellEnter)
	c:SetScript("OnLeave", M.TipHide)
	c:SetScript("OnMouseUp", cellUp)
	c.hl = c:CreateTexture(nil, "BACKGROUND")
	c.hl:SetTexture(T.tex.white)
	c.hl:SetAllPoints(c)
	c.hl:Hide()
	c.line = c:CreateTexture(nil, "BORDER")
	c.line:SetTexture(T.tex.white)
	c.line:SetHeight(1)
	c.line:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.line:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	c.label = T.Text(c, 12, T.c.text, "LEFT")
	c.label:SetJustifyV("MIDDLE")
	c.help = T.Text(c, 10, T.c.dim, "LEFT")
	c.help:SetJustifyV("TOP")
	c.mod = CreateFrame("Button", nil, c)
	c.mod:SetWidth(16)
	c.mod:SetHeight(16)
	c.mod:SetPoint("LEFT", c, "LEFT", 4, 0)
	c.mod.dot = c.mod:CreateTexture(nil, "OVERLAY")
	c.mod.dot:SetTexture(T.tex.white)
	c.mod.dot:SetWidth(8)
	c.mod.dot:SetHeight(8)
	c.mod.dot:SetPoint("CENTER", c.mod, "CENTER", 0, 0)
	c.mod:SetScript("OnClick", function()
		local o = c.opt
		if o then
			SUI.Config.Reset(o.key)
			M.RefreshCtl(c)
			M.SyncMod(c)
		end
	end)
	c.mod:SetScript("OnEnter", function()
		M.TipShow(c.mod, L("mod.menu.modified"), L("mod.menu.modified.tip"))
	end)
	c.mod:SetScript("OnLeave", M.TipHide)
	c.mod:Hide()
	c.fresh = c:CreateTexture(nil, "OVERLAY")         -- pastille "nouveau" (apparu depuis la derniere version vue)
	c.fresh:SetTexture(T.tex.white)
	c.fresh:SetWidth(5)
	c.fresh:SetHeight(5)
	c.fresh:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -4)
	c.fresh:Hide()
	return c
end

-- Surbrillance de la ligne c (cle key) : cle exacte ou groupe (voir M.IsHl), opacite M.hlA (forte puis attenuee pour OpenAt).
function M.PaintHl(c, key)
	if M.IsHl(key) then
		local r, g, b = T.Accent()
		c.hl:SetVertexColor(r, g, b, M.hlA or 0.2)
		c.hl:Show()
	else
		c.hl:Hide()
	end
end

-- Remplit la ligne c pour le reglage o. wide : une colonne avec aide visible ; w, h : taille de la ligne.
function M.BindCell(c, o, wide, w, h)
	c.opt = o
	local ctlW = wide and WIDE_CTL or COMPACT_CTL
	local lw = w - ctlW - 38
	c.label:ClearAllPoints()
	c.help:ClearAllPoints()
	c.label:SetWidth(lw)
	if wide then
		c.label:SetPoint("TOPLEFT", c, "TOPLEFT", 26, -6)
		c.label:SetHeight(14)
		c.help:SetPoint("TOPLEFT", c, "TOPLEFT", 26, -22)
		c.help:SetWidth(lw)
		c.help:SetHeight(24)
		c.help:SetText(M.Short(M.Tx(o.tip), floor(lw / 5.4) * 2 - 6))
		c.help:Show()
	else
		c.label:SetPoint("LEFT", c, "LEFT", 26, 0)
		c.label:SetHeight(h - 4)
		c.help:Hide()
	end
	c.label:SetText(L(o.label))
	c.line:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 0.6)
	local ar, ag, ab = T.Accent()
	c.mod.dot:SetVertexColor(ar, ag, ab, 1)
	M.PaintHl(c, o.key)
	if M.IsNew(o.key) then
		c.fresh:SetVertexColor(ar, ag, ab, 1)
		c.fresh:Show()
	else
		c.fresh:Hide()
	end
	M.AttachCtl(c, o, ctlW, wide)
	M.RefreshCtl(c)
	M.SyncMod(c)
end

-- Un reglage a change : met a jour les lignes (et resultats de recherche) qui le montrent.
function M.RefreshKey(key)
	local p = M.pools.cell
	for i = 1, M.used.cell do
		local c = p[i]
		if c.opt and c.opt.key == key then
			M.RefreshCtl(c)
			M.SyncMod(c)
		end
	end
	p = M.pools.res
	for i = 1, M.used.res do
		if p[i].hit and p[i].hit.key == key then p[i].value:SetText(M.ValueText(p[i].hit)) end
	end
end

-- ---------------------------------------------------------------- cartes d'etat (accueil)
function NEW.stat()
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:EnableMouse(true)
	wheel(f)
	f.title = T.Text(f, 10, T.c.dim, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.title:SetWidth(120)
	f.title:SetHeight(12)
	f.value = T.Text(f, 14, T.c.text, "LEFT")
	f.value:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -23)
	f.value:SetWidth(134)
	f.value:SetHeight(18)
	f.sub = T.Text(f, 10, T.c.dim, "LEFT")
	f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -43)
	f.sub:SetWidth(134)
	f.sub:SetHeight(26)
	f.sub:SetJustifyV("TOP")
	f.dot = f:CreateTexture(nil, "OVERLAY")
	f.dot:SetTexture(T.tex.white)
	f.dot:SetWidth(8)
	f.dot:SetHeight(8)
	f.dot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -9, -9)
	f.b1 = T.Button(f, "", 64, 20, function(b, mb) if b.fn then b.fn(b, mb) end end)
	f.b1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.b2 = T.Button(f, "", 64, 20, function(b, mb) if b.fn then b.fn(b, mb) end end)
	f.b2:SetPoint("LEFT", f.b1, "RIGHT", 6, 0)
	return f
end

-- Grande carte d'action de l'accueil (Deplacer l'interface, Raccourcis) : toute la carte se clique, bordure accentuee quand le mode est actif.
local function cardBorder(f, hot)
	local c = T.c.border
	if hot or f.active then
		local r, g, b = T.Accent()
		f:SetBackdropBorderColor(r, g, b, 1)
	else
		f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
	end
end

function NEW.acard()
	local f = CreateFrame("Button", nil, M.child)
	f:SetFrameLevel(M.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	wheel(f)
	f.title = T.Text(f, 14, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
	f.title:SetWidth(290)
	f.title:SetHeight(18)
	f.desc = T.Text(f, 10, T.c.dim, "LEFT")
	f.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
	f.desc:SetWidth(290)
	f.desc:SetHeight(28)
	f.desc:SetJustifyV("TOP")
	f:SetScript("OnClick", function()
		if this.fn then this.fn() end
	end)
	f:SetScript("OnEnter", function() cardBorder(this, true) end)
	f:SetScript("OnLeave", function() cardBorder(this, false) end)
	return f
end

function M.ActionCard(title, desc, fn, active)
	local c = M.Get("acard")
	if not c then return nil end
	M.Flow(c, 2, 318, 68, 12, 12)
	c.fn = fn
	c.active = active and true or false
	c.title:SetText(title)
	c.desc:SetText(desc)
	if c.active then
		local r, g, b = T.Accent()
		c.title:SetTextColor(r, g, b, 1)
	else
		c.title:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
	end
	cardBorder(c, false)
	return c
end

local function stat(title, value, sub, dotCol, l1, f1, l2, f2)
	local s = M.Get("stat")
	if not s then return nil end
	M.Flow(s, 4, 153, 100, 12, 12)
	s.title:SetText(title)
	s.value:SetText(value)
	s.sub:SetText(sub or "")
	if dotCol then
		s.dot:SetVertexColor(dotCol[1], dotCol[2], dotCol[3], 1)
		s.dot:Show()
	else
		s.dot:Hide()
	end
	if l1 then
		T.SetButtonText(s.b1, l1)
		s.b1.fn = f1
		s.b1:Show()
	else
		s.b1:Hide()
	end
	if l2 then
		T.SetButtonText(s.b2, l2)
		s.b2.fn = f2
		s.b2:Show()
	else
		s.b2:Hide()
	end
	return s
end

function M.UpdatePerf()
	local s = M.perfCard
	if not s or not s:IsShown() then return end
	local fps = floor(GetFramerate() + 0.5)
	local _, _, lat = GetNetStats()
	local v = L("mod.menu.home.fps", fps)
	if v ~= s.pv then
		s.pv = v
		s.value:SetText(v)
	end
	local sub = L("mod.menu.home.mem", gcinfo() / 1024, floor((lat or 0) + 0.5))
	if sub ~= s.ps then
		s.ps = sub
		s.sub:SetText(sub)
	end
end

local function applyRole(btn)
	SUI.Config.ApplyRole(btn.role)
	SUI.Print(L("msg.role.applied", L("role." .. btn.role)))
end

local function goStyles() M.Open("styles") end
local function goLayouts()
	M.Open("styles")
	M.FocusKey("sec:layouts")
end
local function goWait()
	M.filter = "wait"
	M.Open("modules")
end

-- "Je veux changer..." : taches courantes (M.tasks) ; chacune ouvre l'apercu 2D du module ET la bonne ligne (M.OpenAt).
local function wantClick(b)
	if b.task then M.OpenAt(b.task, { preview = true }) end
end

function M.HomeWant()
	local list = {}
	for i = 1, getn(M.tasks) do
		local t = M.tasks[i]
		if t.cat and M.CatExists(t.cat) then tinsert(list, t) end
	end
	if getn(list) == 0 then return end
	M.Section(L("mod.menu.want.title"))
	M.Para(L("mod.menu.want.hint"), 24, T.c.dim)
	for i = 1, getn(list) do
		local b = M.GridBtn(L(list[i].label), 4, 153, 26, wantClick)
		if not b then break end
		b.task = list[i].key
	end
	M.EndRow(8)
end

-- Nouveautes depuis la derniere fois : resume, une touche par categorie concernee, et "Tout marquer comme vu".
local function newClearAll()
	local n = M.NewClear(nil)
	SUI.Print(L("msg.menu.new.cleared", n))
end

local function newGoCat(b)
	if b.cat == "modules" then M.Open("modules") elseif b.cat then M.Open("cat", b.cat) end
end

function M.HomeNew()
	local total = M.NewCount(nil)
	if total <= 0 then return end
	M.Section(L("mod.menu.new.title"))
	M.Para(L("mod.menu.new.summary", total), 18, T.c.text)
	local cats = {}
	for k, _ in pairs(M.newCat) do
		if k == "modules" or M.CatExists(k) then tinsert(cats, k) end
	end
	table.sort(cats)
	for i = 1, getn(cats) do
		if i > 7 then break end
		local k = cats[i]
		local b = M.GridBtn(L("mod.menu.new.catbtn", k == "modules" and L("mod.menu.nav.modules") or M.CatLabel(k), M.newCat[k]), 4, 153, 26,
			newGoCat)
		if not b then break end
		b.cat = k
	end
	M.GridBtn(L("mod.menu.new.clear"), 4, 153, 26, newClearAll)
	M.EndRow(8)
end

function P.home()
	local C = SUI.Config
	local S = SUI.Style
	M.SetHead(L("mod.menu.home.title"), L("mod.menu.home.desc"))
	M.HomeWant()
	M.HomeNew()
	M.Section(L("mod.menu.sec.state"))
	-- 1 mode
	stat(L("mod.menu.card.mode"), SUI.Mode.Name(C.mode), SUI.Mode.autoSet and L("mod.menu.home.auto") or "", nil,
		L("mod.menu.toggle"), function() M.ToggleMode() end)
	-- 2 role
	local role = C.GetRole()
	stat(L("mod.menu.card.role"), role and L("role." .. role) or L("mod.menu.none"), L("mod.menu.home.rolehint"))
	-- 3 style
	stat(L("mod.menu.card.style"), S.Label(C.Get("style.name")), M.Short(S.Desc(C.Get("style.name")), 44), nil,
		L("mod.menu.change"), goStyles)
	-- 4 mise en page
	local lay = SUI.Layout.Current()
	stat(L("mod.menu.card.layout"), lay and SUI.Layout.Label(lay) or L("mod.menu.none"), L("mod.menu.home.layouthint"), nil,
		L("mod.menu.change"), goLayouts)
	-- 5 profil
	stat(L("mod.menu.card.profile"), C.curName, L("mod.menu.home.profiles", getn(C.ListProfiles())), nil,
		"<", function() M.NextProfile(-1) end, ">", function() M.NextProfile(1) end)
	-- 6 extensions
	local api = SUI.Api
	local n = 0
	if api.superwow then n = n + 1 end
	if api.nampower then n = n + 1 end
	if api.unitxp then n = n + 1 end
	if api.classic then n = n + 1 end
	stat(L("mod.menu.card.ext"), L("mod.menu.home.ext", n), api.Summary() or L("menu.none"), n > 0 and T.c.good or T.c.dim)
	-- 7 performance (mise a jour chaque seconde tant que la page est visible)
	M.perfCard = stat(L("mod.menu.card.perf"), "", "", nil)
	if M.perfCard then
		M.perfCard.pv, M.perfCard.ps = nil, nil
		M.UpdatePerf()
	end
	-- 8 pfUI
	local Mg = SUI.Migrate
	local present = Mg and Mg.Present()
	local held = Mg and Mg.HeldCount() or 0
	local sub = L("mod.menu.home.pfui.none")
	if present then sub = held > 0 and L("mod.menu.home.pfui.wait", held) or L("mod.menu.home.pfui.done") end
	stat(L("mod.menu.card.pfui"), present and L("mod.menu.home.pfui.yes") or L("mod.menu.home.pfui.no"), sub,
		present and (held > 0 and T.c.warn or T.c.good) or T.c.dim, held > 0 and L("mod.menu.migrate") or nil, goWait)
	M.EndRow(12)
	-- deplacer l'interface et raccourcis clavier
	M.Section(L("mod.menu.sec.interface"))
	M.ActionCard(L("mod.mover.title"), L("mod.menu.card.move.desc"), function() SUI.Mover.Toggle() end, SUI.Mover.active)
	M.ActionCard(L("mod.bind.title"), L("mod.menu.card.bind.desc"), function() SUI.Bind.Toggle() end, SUI.Bind.active)
	M.EndRow(12)
	-- role
	M.Section(L("mod.menu.sec.role"))
	local order = C.roleOrder
	for i = 1, getn(order) do
		local b = M.GridBtn(L("role." .. order[i]), 4, 153, 26, applyRole, C.GetRole() == order[i])
		if not b then break end
		b.role = order[i]
		tinsert(M.roleButtons, b)
	end
	M.EndRow(8)
	-- raccourcis
	M.Section(L("mod.menu.sec.shortcuts"))
	M.GridBtn(L("mod.menu.nav.styles"), 4, 153, 26, goStyles)
	M.GridBtn(L("mod.menu.sc.layouts"), 4, 153, 26, goLayouts)
	M.GridBtn(L("mod.menu.nav.modules"), 4, 153, 26, function() M.filter = "all"; M.Open("modules") end)
	M.GridBtn(L("mod.menu.sc.wizard"), 4, 153, 26, function() M.ShowWizard(1) end)
	M.GridBtn(L("menu.import"), 4, 153, 26, function() M.ShowTransfer("import") end)
	M.GridBtn(L("menu.export"), 4, 153, 26, function() M.ShowTransfer("export") end)
	M.GridBtn(L("menu.reset"), 4, 153, 26, function(b)
		M.ConfirmClick(b, "profile", L("menu.reset"), function()
			SUI.Config.ResetProfile()
			SUI.Print(L("msg.reset.done"))
		end)
	end)
	M.EndRow(8)
	M.Para(L("mod.menu.home.hint"), 40)
end

-- ---------------------------------------------------------------- page Modules (grille de cartes)
function NEW.mcard()
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:EnableMouse(true)
	wheel(f)
	f:SetScript("OnEnter", function()
		local name = f.modName
		if name then M.TipShow(f, M.ModName(name), M.Tx("tip.modules." .. name)) end
	end)
	f:SetScript("OnLeave", M.TipHide)
	f.dot = f:CreateTexture(nil, "OVERLAY")
	f.dot:SetTexture(T.tex.white)
	f.dot:SetWidth(8)
	f.dot:SetHeight(8)
	f.dot:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -12)
	f.name = T.Text(f, 12, T.c.text, "LEFT")
	f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -9)
	f.name:SetWidth(140)
	f.name:SetHeight(14)
	f.sw = T.Check(f, function(on) M.ToggleModule(f, on) end)
	f.sw:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
	f.desc = T.Text(f, 10, T.c.dim, "LEFT")
	f.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -29)
	f.desc:SetWidth(188)
	f.desc:SetHeight(36)
	f.desc:SetJustifyV("TOP")
	f.state = T.Text(f, 10, T.c.dim, "LEFT")
	f.state:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -70)
	f.state:SetWidth(188)
	f.state:SetHeight(12)
	f.cfg = T.Button(f, "", 76, 20, function() M.Open("cat", f.modName) end)
	f.cfg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.mig = T.Button(f, "", 56, 20, function(b)
		local name = f.modName
		M.ConfirmClick(b, "mig:" .. name, L("mod.menu.migrate"), function()
			local ok, key, names = SUI.Migrate.Take(name)
			if ok then SUI.Print(L(key, names)) else SUI.Print(L(key, SUI.Migrate.Names())) end
		end)
	end)
	f.mig:SetPoint("LEFT", f.cfg, "RIGHT", 4, 0)
	f.raid = T.Check(f, function(on) M.RaidModule(f, on) end)
	f.raid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
	f.raidLabel = T.Text(f, 10, T.c.dim, "RIGHT")
	f.raidLabel:SetPoint("RIGHT", f.raid, "LEFT", -4, 0)
	f.raidLabel:SetWidth(34)
	f.raidLabel:SetHeight(12)
	f.raid:SetScript("OnEnter", function() M.TipShow(f.raid, L("mod.menu.raid"), L("mod.menu.raid.tip")) end)
	f.raid:SetScript("OnLeave", M.TipHide)
	return f
end

function M.ToggleModule(card, on)
	if card.modName then SUI.Config.Set("modules." .. card.modName, on) end
end

-- Interrupteur "Raid" : garde (ou coupe) le module quand le mode Raid est actif (ecart propre au mode Raid).
function M.RaidModule(card, on)
	if card.modName then SUI.Config.SetIn("raid", "modules." .. card.modName, on) end
end

function M.BindMCard(f, name)
	local C = SUI.Config
	local m = SUI.modules[name]
	f.key = "modules." .. name
	f.modName = name
	local st = M.State(name)
	local col = M.StateColor(st)
	f.dot:SetVertexColor(col[1], col[2], col[3], 1)
	f.name:SetText(M.ModName(name))
	f.desc:SetText(M.ModShort(name, 104))
	f.state:SetText(L("mod.menu.state." .. st) .. "  -  " .. L("mod.menu.cost", L("mod.menu.cost." .. (m.cost or "medium"))))
	f.state:SetTextColor(col[1], col[2], col[3], 1)
	T.SetCheck(f.sw, C.Get(f.key))
	T.SetCheck(f.raid, C.GetIn("raid", f.key))
	T.SetButtonText(f.cfg, L("mod.menu.configure"))
	T.SetButtonText(f.mig, L("mod.menu.migrate"))
	f.raidLabel:SetText(L("mod.menu.raid"))
	if M.CatCount(name) > 0 then f.cfg:Show() else f.cfg:Hide() end
	if st == "wait" and SUI.Migrate and SUI.Migrate.Take then f.mig:Show() else f.mig:Hide() end
	T.SetSelected(f, M.hl == f.key)
end

function P.modules()
	local show = M.filter
	local function fb(id, w)
		M.HeadBtn(L("mod.menu.filter." .. id), w, function() M.filter = id; M.Render() end, show == id)
	end
	fb("wait", 92)
	fb("off", 70)
	fb("on", 70)
	fb("all", 60)
	M.SetHead(L("mod.menu.nav.modules"), L("mod.menu.modules.desc"))
	-- regroupement par famille ; un module hors famille tombe dans "other"
	local placed = {}
	local groups = {}
	local fams = M.FamilyList()
	for i = 1, getn(fams) do
		local g = { id = fams[i].id, mods = {} }
		for j = 1, getn(fams[i].cats) do
			local c = fams[i].cats[j]
			if SUI.modules[c] then
				tinsert(g.mods, c)
				placed[c] = true
			end
		end
		tinsert(groups, g)
	end
	local other
	for i = 1, getn(groups) do
		if groups[i].id == "other" then other = groups[i] end
	end
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		if not placed[n] then
			if not other then
				other = { id = "other", mods = {} }
				tinsert(groups, other)
			end
			tinsert(other.mods, n)
		end
	end
	local total = 0
	for gi = 1, getn(groups) do
		local g = groups[gi]
		local keep = {}
		for j = 1, getn(g.mods) do
			local st = M.State(g.mods[j])
			if show == "all" or (show == "on" and st == "on") or (show == "off" and st == "off") or (show == "wait" and st == "wait") then
				tinsert(keep, g.mods[j])
			end
		end
		if getn(keep) > 0 then
			M.Section(L("mod.menu.fam." .. g.id), tostring(getn(keep)))
			for j = 1, getn(keep) do
				local card = M.Get("mcard")
				if not card then break end
				M.Flow(card, 3, 208, 124, 12, 12)
				M.BindMCard(card, keep[j])
				total = total + 1
			end
			M.EndRow(12)
		end
	end
	if total == 0 then M.Para(L("mod.menu.modules.empty"), 20) end
end

-- ---------------------------------------------------------------- page Styles et mises en page
local function accentRGB(tok)
	local a = tok.accent
	if type(a) == "table" then return a[1], a[2], a[3] end
	if a == "class" and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then return col.r, col.g, col.b end
	end
	local t = T.accents[a] or T.accents.blue
	return t[1], t[2], t[3]
end

local function tex(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.tex.white)
	return t
end

-- Apercu dessine avec les jetons : bordure, fond, barre de titre, barre de progression, bouton, texte.
local function newPreview(card, w, h)
	local pv = CreateFrame("Frame", nil, card)
	pv:SetWidth(w)
	pv:SetHeight(h)
	pv:SetPoint("LEFT", card, "LEFT", 8, 0)
	pv.edge = tex(pv, "BACKGROUND")
	pv.edge:SetAllPoints(pv)
	pv.bg = tex(pv, "BORDER")
	pv.bg:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
	pv.bg:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -1, 1)
	return pv
end

function NEW.scard()
	local b = CreateFrame("Button", nil, M.child)
	b:SetFrameLevel(M.lvl + 1)
	T.Backdrop(b, T.c.panel, T.c.border)
	b:RegisterForClicks("LeftButtonUp")
	wheel(b)
	b:SetScript("OnClick", function()
		local card = this
		if card.id and SUI.Style.styles[card.id] then SUI.Config.Set("style.name", card.id) end
	end)
	local pv = newPreview(b, 78, 62)
	b.pv = pv
	pv.title = tex(pv)
	pv.title:SetHeight(9)
	pv.title:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
	pv.title:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -1, -1)
	pv.sample = pv:CreateFontString(nil, "OVERLAY")
	pv.sample:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -14)
	pv.sample:SetFont(T.assets.font.arial, 10)
	pv.line = tex(pv)
	pv.line:SetHeight(2)
	pv.line:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -29)
	pv.line:SetWidth(40)
	pv.track = tex(pv)
	pv.track:SetHeight(6)
	pv.track:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", 6, 8)
	pv.track:SetWidth(40)
	pv.fill = tex(pv, "OVERLAY")
	pv.fill:SetHeight(6)
	pv.fill:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", 6, 8)
	pv.fill:SetWidth(26)
	pv.btnEdge = tex(pv)
	pv.btnEdge:SetWidth(22)
	pv.btnEdge:SetHeight(12)
	pv.btnEdge:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -5, 5)
	pv.btnBg = tex(pv, "OVERLAY")
	pv.btnBg:SetPoint("TOPLEFT", pv.btnEdge, "TOPLEFT", 1, -1)
	pv.btnBg:SetPoint("BOTTOMRIGHT", pv.btnEdge, "BOTTOMRIGHT", -1, 1)
	b.name = T.Text(b, 12, T.c.text, "LEFT")
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 94, -10)
	b.name:SetWidth(90)
	b.name:SetHeight(14)
	b.desc = T.Text(b, 9, T.c.dim, "LEFT")
	b.desc:SetPoint("TOPLEFT", b, "TOPLEFT", 94, -28)
	b.desc:SetWidth(106)
	b.desc:SetHeight(44)
	b.desc:SetJustifyV("TOP")
	b.del = T.Button(b, "x", 16, 16, function(btn)
		local card = btn:GetParent()
		if card.id then
			local ok, key = SUI.Style.Delete(card.id)
			SUI.Print(L(key, card.id))
			M.Render()
		end
	end)
	b.del:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
	b.del:Hide()
	return b
end

function M.BindStyleCard(b, id)
	local S = SUI.Style
	local rec = S.styles[id]
	local tok = S.Resolve(id)
	local c = tok.c
	local pv = b.pv
	b.id = id
	pv.edge:SetVertexColor(c.border[1], c.border[2], c.border[3], 1)
	pv.bg:SetVertexColor(c.bg[1], c.bg[2], c.bg[3], 1)
	pv.title:SetVertexColor(c.panel[1], c.panel[2], c.panel[3], 1)
	pv.line:SetVertexColor(c.dim[1], c.dim[2], c.dim[3], 1)
	pv.track:SetVertexColor(c.inset[1], c.inset[2], c.inset[3], 1)
	local ar, ag, ab = accentRGB(tok)
	pv.fill:SetVertexColor(ar, ag, ab, 1)
	pv.btnEdge:SetVertexColor(c.border[1], c.border[2], c.border[3], 1)
	pv.btnBg:SetVertexColor(c.panel[1], c.panel[2], c.panel[3], 1)
	pcall(pv.sample.SetFont, pv.sample, tok.font or T.assets.font.arial, 10 * tok.fontScale, tok.outline)
	pv.sample:SetText("Aa")
	pv.sample:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
	b.name:SetText(S.Label(id))
	b.desc:SetText(M.Short(S.Desc(id), 64))
	if rec.origin == "user" then b.del:Show() else b.del:Hide() end
	T.SetSelected(b, SUI.Config.Get("style.name") == id)
end

function NEW.lcard()
	local b = CreateFrame("Button", nil, M.child)
	b:SetFrameLevel(M.lvl + 1)
	T.Backdrop(b, T.c.panel, T.c.border)
	b:RegisterForClicks("LeftButtonUp")
	wheel(b)
	b:SetScript("OnClick", function()
		local card = this
		if card.id then
			local ok, key, n, bad = SUI.Layout.ApplyPreset(card.id)
			if ok then SUI.Print(L(key, SUI.Layout.Label(card.id), n, bad)) end
		end
	end)
	local pv = newPreview(b, 78, 50)
	b.pv = pv
	pv.rects = {}
	for i = 1, 8 do
		local r = tex(pv, "OVERLAY")
		r:SetWidth(14)
		r:SetHeight(6)
		r:Hide()
		pv.rects[i] = r
	end
	b.name = T.Text(b, 12, T.c.text, "LEFT")
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 94, -12)
	b.name:SetWidth(106)
	b.name:SetHeight(14)
	b.sub = T.Text(b, 10, T.c.dim, "LEFT")
	b.sub:SetPoint("TOPLEFT", b, "TOPLEFT", 94, -30)
	b.sub:SetWidth(106)
	b.sub:SetHeight(26)
	b.sub:SetJustifyV("TOP")
	return b
end

function M.BindLayoutCard(b, id)
	local def = SUI.layouts[id]
	local pv = b.pv
	b.id = id
	pv.edge:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	pv.bg:SetVertexColor(T.c.inset[1], T.c.inset[2], T.c.inset[3], 1)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local n = 0
	if type(def.pos) == "table" then
		for key, e in pairs(def.pos) do
			if n < 8 and type(e) == "table" and type(e[1]) == "number" and type(e[2]) == "number" then
				n = n + 1
				local x = (e[1] * sw + (e[3] or 0)) / sw * 78
				local y = (e[2] * sh + (e[4] or 0)) / sh * 50
				if x < 2 then x = 2 end
				if x > 62 then x = 62 end
				if y < 2 then y = 2 end
				if y > 42 then y = 42 end
				local r = pv.rects[n]
				r:ClearAllPoints()
				r:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", floor(x), floor(y))
				if key == "unit.player" then
					local ar, ag, ab = T.Accent()
					r:SetVertexColor(ar, ag, ab, 1)
				else
					r:SetVertexColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
				end
				r:Show()
			end
		end
	end
	for i = n + 1, 8 do pv.rects[i]:Hide() end
	b.name:SetText(SUI.Layout.Label(id))
	b.sub:SetText(n > 0 and L("mod.menu.layout.n", n) or L("mod.menu.layout.reset"))
	T.SetSelected(b, SUI.Layout.Current() == id)
end

function P.styles()
	local S = SUI.Style
	M.HeadBtn(L("mod.menu.export"), 84, function() M.ShowTransfer("export", S.Export()) end)
	M.HeadBtn(L("mod.menu.import"), 84, function() M.ShowTransfer("import", nil, "style") end)
	M.HeadBtn(L("mod.menu.manager"), 104, function() if SUI.StylePicker then SUI.StylePicker.Show() end end)
	M.HeadBtn(L("mod.menu.customize"), 116, function() M.Show("all"); M.Open("cat", "style") end)
	M.SetHead(L("mod.menu.nav.styles"), L("mod.menu.styles.desc"))
	M.Section(L("mod.menu.sec.styles"), tostring(getn(S.names)))
	for i = 1, getn(S.names) do
		local c = M.Get("scard")
		if not c then break end
		M.Flow(c, 3, 208, 84, 12, 12)
		M.BindStyleCard(c, S.names[i])
	end
	M.EndRow(12)
	M.secY = M.secY or {}
	M.secY.layouts = M.y
	M.Section(L("mod.menu.sec.layouts"), tostring(getn(SUI.layoutOrder)))
	for i = 1, getn(SUI.layoutOrder) do
		local c = M.Get("lcard")
		if not c then break end
		M.Flow(c, 3, 208, 70, 12, 12)
		M.BindLayoutCard(c, SUI.layoutOrder[i])
	end
	M.EndRow(12)
end

-- ---------------------------------------------------------------- page d'un module / d'une categorie
function M.ResetCat(cat)
	local n = 0
	local list = M.OptionsOf(cat)
	for i = 1, getn(list) do
		local o = list[i]
		if o.type ~= "header" and SUI.Config.IsModified(o.key) then
			SUI.Config.Reset(o.key)
			n = n + 1
		end
	end
	SUI.Print(L("msg.menu.modreset", n))
	M.Render()
end

function M.SecTitle(raw)
	if M.Has(raw) then return L(raw) end
	return raw
end

-- Regroupe les reglages en sections : champ o.section (facultatif), en-tetes (type header), sinon prefixe de la cle ("units.player.x" ->
-- "player"), sinon une seule section ; en mode Tout, une grande page sans section est coupee en Essentiel / Avance.
function M.Sections(opts)
	local secs, idx = {}, {}
	local hdr
	local explicit = false
	for i = 1, getn(opts) do
		local o = opts[i]
		if o.type == "header" then
			hdr = o
		elseif M.mode == "all" or o.simple then
			local id, title
			if o.section then
				id, title = "s:" .. o.section, M.SecTitle(o.section)
			elseif hdr then
				id, title = "h:" .. tostring(hdr.key or hdr.label), L(hdr.label)
			else
				local _, _, rest = string.find(o.key, "^[^.]+%.(.*)$")
				local _, _, pre = string.find(rest or "", "^([^.]+)%.")
				if pre then
					id = "p:" .. pre
					title = M.Has("mod.menu.sec." .. pre) and L("mod.menu.sec." .. pre) or M.Cap(pre)
				end
			end
			if id then explicit = true else id, title = "main", L("mod.menu.sec.main") end
			local s = idx[id]
			if not s then
				s = { id = id, title = title, list = {} }
				idx[id] = s
				tinsert(secs, s)
			end
			tinsert(s.list, o)
		end
	end
	if not explicit and M.mode == "all" and getn(secs) == 1 then
		local ess, adv = {}, {}
		local l = secs[1].list
		for i = 1, getn(l) do
			if l[i].simple then tinsert(ess, l[i]) else tinsert(adv, l[i]) end
		end
		if getn(ess) > 0 and getn(adv) > 0 then
			secs = { { id = "ess", title = L("mod.menu.sec.ess"), list = ess }, { id = "adv", title = L("mod.menu.sec.adv"), list = adv } }
		end
	end
	return secs
end

-- Familles de reglages "<mod>.<nom>.<reste>" (barres d'action, cadres d'unites) : retourne le prefixe, la liste des noms (au moins 4
-- reglages chacun) et la table nom -> { reste -> option }. nil si moins de deux noms comparables.
function M.CopyFamily(opts)
	local fam = {}
	for i = 1, getn(opts) do
		local o = opts[i]
		if o.type ~= "header" then
			local _, _, pre, nm, rest = string.find(o.key, "^([^.]+)%.([^.]+)%.(.+)$")
			if nm then
				fam[pre] = fam[pre] or { names = {}, map = {} }
				local f = fam[pre]
				if not f.map[nm] then
					f.map[nm] = { n = 0 }
					tinsert(f.names, nm)
				end
				f.map[nm][rest] = o
				f.map[nm].n = f.map[nm].n + 1
			end
		end
	end
	local best, bestN, bestPre = nil, 1, nil
	for pre, f in pairs(fam) do
		local ref
		for i = 1, getn(f.names) do
			local nm = f.names[i]
			if not ref or f.map[nm].n > f.map[ref].n then ref = nm end
		end
		local names = {}
		for i = 1, getn(f.names) do
			local nm = f.names[i]
			local common = 0
			for rest in pairs(f.map[nm]) do
				if rest ~= "n" and f.map[ref][rest] then common = common + 1 end
			end
			if common >= 4 then tinsert(names, nm) end
		end
		if getn(names) > bestN then best, bestN, bestPre = { names = names, map = f.map }, getn(names), pre end
	end
	if not best then return nil end
	return bestPre, best.names, best.map
end

-- Reglages comparables source -> destination : liste de { cle destination, valeur } dont la valeur differe (types identiques,
-- jamais la cle "enabled" : copier ne doit pas activer ou couper un cadre).
function M.CopyPlan(map, src, dst)
	local plan = {}
	local a, b = map[src], map[dst]
	if not a or not b or src == dst then return plan end
	for rest, o in pairs(a) do
		local d = b[rest]
		if rest ~= "n" and rest ~= "enabled" and type(o) == "table" and d and d.type == o.type and d.key ~= o.key then
			local v = SUI.Config.Get(o.key)
			if v ~= SUI.Config.Get(d.key) then tinsert(plan, { d.key, v }) end
		end
	end
	return plan
end

function M.CopyRun(plan)
	if SUI.Backup then SUI.Backup.Create("copy") end
	for i = 1, getn(plan) do SUI.Config.Set(plan[i][1], plan[i][2]) end
	SUI.Print(L("msg.menu.copy.done", getn(plan)))
	M.Render()
end

local function copyNext(names, cur, skip)
	local n = getn(names)
	for i = 1, n do
		if names[i] == cur then
			local j = i
			for _ = 1, n do
				j = j + 1
				if j > n then j = 1 end
				if names[j] ~= skip then return names[j] end
			end
		end
	end
	return names[1]
end

function M.CopySection(opts)
	local pre, names, map = M.CopyFamily(opts)
	if not pre then return end
	local st = M.copySt
	if not st or st.pre ~= pre then st = { pre = pre, src = names[1], dst = names[2] }; M.copySt = st end
	M.Section(L("mod.menu.sec.copy"), tostring(getn(names)))
	M.Para(L("mod.menu.copy.why"), 30)
	M.GridBtn(L("mod.menu.copy.src", M.Cap(st.src)), 3, 208, 26, function()
		st.src = copyNext(names, st.src, st.dst)
		M.Render()
	end)
	M.GridBtn(L("mod.menu.copy.dst", M.Cap(st.dst)), 3, 208, 26, function()
		st.dst = copyNext(names, st.dst, st.src)
		M.Render()
	end)
	local plan = M.CopyPlan(map, st.src, st.dst)
	local go = M.GridBtn(L("mod.menu.copy.go", getn(plan)), 3, 208, 26, nil)
	if go then
		go.fn = function(b)
			if getn(plan) == 0 then SUI.Print(L("msg.menu.copy.none")); return end
			M.ConfirmClick(b, "copy:" .. st.src .. ">" .. st.dst, L("mod.menu.copy.go", getn(plan)), function() M.CopyRun(M.CopyPlan(map, st.src, st.dst)) end)
		end
	end
	M.EndRow(8)
end

function P.cat()
	local C = SUI.Config
	local cat = M.cat
	local mod = SUI.modules[cat]
	local opts = M.OptionsOf(cat)
	local total, vis, modified = 0, 0, 0
	for i = 1, getn(opts) do
		local o = opts[i]
		if o.type ~= "header" then
			total = total + 1
			if o.simple then vis = vis + 1 end
			if C.IsModified(o.key) then modified = modified + 1 end
		end
	end
	M.HeadBtn(mod and L("mod.menu.modreset") or L("mod.menu.pagereset"), 150, function(b)
		M.ConfirmClick(b, "reset:" .. cat, mod and L("mod.menu.modreset") or L("mod.menu.pagereset"), function() M.ResetCat(cat) end)
	end)
	local nnew = M.NewCount(cat)
	if nnew > 0 then
		M.HeadBtn(L("mod.menu.new.clearcat", nnew), 130, function() M.NewClear(cat) end)
	end
	local acts = SUI.actions and SUI.actions[cat]
	if acts and mod and M.State(cat) == "on" then
		for i = 1, getn(acts) do
			if M.frame.head.nbtn < 4 then
				local fn = acts[i].fn
				M.HeadBtn(L(acts[i].label), acts[i].w, function() M.Hide() fn() end)
			end
		end
	end
	M.SetHead(M.CatLabel(cat), M.CatDesc(cat), mod and M.Tx("tip.modules." .. cat) or nil)
	local h = M.frame.head
	local counts = L("mod.menu.count", total, modified)
	if mod then
		local st = M.State(cat)
		local col = M.StateColor(st)
		M.SwitchName = cat
		T.SetCheck(h.sw, C.Get("modules." .. cat))
		h.sw:Show()
		h.status:SetText(L("mod.menu.state." .. st) .. "  -  " .. counts)
		h.status:SetTextColor(col[1], col[2], col[3], 1)
	else
		h.status:SetText(counts)
		h.status:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	end
	if C.mode ~= "normal" then M.Para(L("mod.menu.raidnote"), 18, T.c.warn) end
	local hidden = total - vis
	if M.mode == "essential" and hidden > 0 then
		local n = M.Get("note")
		if n then
			M.Flow(n, 1, CW, 38, 0, 10)
			n.fs:SetText(vis > 0 and L("mod.menu.hidden", hidden) or L("mod.menu.hidden.none", hidden))
			T.SetButtonText(n.btn, L("mod.menu.showall"))
			n.btn.fn = function() M.SetMode("all") end
			M.EndRow(10)
		end
	end
	local wide = (M.mode == "all")
	local cols = wide and 1 or 2
	local cw = wide and WIDE_W or COMPACT_W
	local ch = wide and 50 or 38
	local secs = M.Sections(opts)
	for si = 1, getn(secs) do
		local s = secs[si]
		M.Section(s.title, tostring(getn(s.list)), s.list)
		for i = 1, getn(s.list) do
			local c = M.Get("cell")
			if not c then break end
			M.Flow(c, cols, cw, ch, 16, 0)
			M.BindCell(c, s.list[i], wide, cw, ch)
		end
		M.EndRow(0)
	end
	if wide then M.CopySection(opts) end
end

-- ---------------------------------------------------------------- recherche
function NEW.res()
	local b = CreateFrame("Button", nil, M.child)
	b:SetFrameLevel(M.lvl + 1)
	T.Backdrop(b, T.c.panel, T.c.border)
	b:RegisterForClicks("LeftButtonUp")
	wheel(b)
	b:SetScript("OnClick", function() M.GoHit(this.hit) end)
	b.label = T.Text(b, 12, T.c.text, "LEFT")
	b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -6)
	b.label:SetWidth(380)
	b.label:SetHeight(14)
	b.path = T.Text(b, 10, T.c.dim, "LEFT")
	b.path:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -23)
	b.path:SetWidth(380)
	b.path:SetHeight(12)
	b.value = T.Text(b, 11, T.c.dim, "RIGHT")
	b.value:SetPoint("RIGHT", b, "RIGHT", -12, 0)
	b.value:SetWidth(200)
	b.value:SetHeight(14)
	return b
end

function P.search()
	local hits = M.Find(M.search)
	M.hits = hits
	local n = getn(hits)
	M.SetHead(L("mod.menu.search.title", M.search), L("mod.menu.search.count", n))
	if n == 0 then
		M.Para(L("menu.noresults"), 20)
		return
	end
	local shown = n
	if shown > M.MAXRES then shown = M.MAXRES end
	for i = 1, shown do
		local r = M.Get("res")
		if not r then break end
		local o = hits[i]
		M.Flow(r, 1, CW, 40, 0, 4)
		r.hit = o
		r.label:SetText(L(o.label))
		r.path:SetText(o.cat == "modules" and L("mod.menu.nav.modules") or M.CatLabel(o.cat))
		r.value:SetText(M.ValueText(o))
		T.SetSelected(r, i == M.resSel)
	end
	M.EndRow(4)
	if n > shown then M.Para(L("mod.menu.search.more", n - shown), 20) end
end


-- PAGE JOURNAL D'ERREURS : ShikiUIDB.global.errlog affiche en clair, les plus recentes d'abord.
function P.errors()
	local log = SUI.errlog or {}
	M.SetHead(L("mod.menu.nav.errors"), L("mod.menu.errors.desc"))
	M.Para(L("mod.menu.errors.count", getn(log)), 16)
	M.Para(L("mod.menu.errors.help"), 32)
	for i = getn(log), 1, -1 do
		local line = log[i]
		local _, _, tm, src, msg = string.find(line, "^(%d+)|([^|]+)|(.*)$")
		if tm and src and msg then
			M.Para("|cffff6060" .. src .. ":|r " .. msg, 36)
		else
			M.Para(line, 20)
		end
	end
	if getn(log) > 0 then
		M.GridBtn(L("mod.menu.errors.clear"), 3, 208, 26, function()
			for i = getn(SUI.errlog), 1, -1 do table.remove(SUI.errlog, i) end
			SUI.Config.db.global.errlog = SUI.errlog
			SUI.Print(L("errors.cleared"))
			M.Render()
		end)
	end
end
