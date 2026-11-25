-- ShikiUI Theme : moteur de styles (jetons -> rendu) + fabriques de widgets 1.12 + gestion des positions (Layout).
-- Un STYLE est un ensemble de jetons (palette, police, texture de barre, fond, bordure, boutons, opacite) enregistre par SUI.RegisterStyle
-- (Style.lua) ; les modules ne codent JAMAIS une couleur ou une texture : ils lisent T.c.<nom> et passent par les fabriques
-- (T.Backdrop, T.Text, T.Button, T.Bar, T.Panel...). Chaque widget cree est memorise : changer de style (T.Apply + T.Restyle) repeint tout a chaud.
-- Les couleurs de T.c sont des tables MODIFIEES SUR PLACE : une reference gardee par un module reste donc valable apres un changement de style.
-- Aucune methode absente de WoW 1.12 (pas de SetSize / SetShown).
--
-- Chemins de textures / polices : UNIQUEMENT ceux releves dans des addons installes (aux-addon, BigWigs, HandGuard, Puppeteer, pfUI...) :
--   Interface\Buttons\WHITE8X8 ; Interface\TargetingFrame\UI-StatusBar ; Interface\Tooltips\UI-Tooltip-Background / -Border ;
--   Interface\DialogFrame\UI-DialogBox-Background / -Border (edgeSize 20 vu dans aux-addon) ; Interface\Buttons\UI-Panel-Button-Up / -Down /
--   -Highlight ; Fonts\ARIALN.TTF ; Fonts\FRIZQT__.TTF.
-- NON VERIFIE en jeu par ce projet : le rendu de ces textures dans nos cadres, les coordonnees de texture (SetTexCoord) des boutons Blizzard,
-- la valeur de retour de FontString:SetFont (supposee false si le fichier manque), la sonde GetTexture() d'un fichier absent.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local T = {}
SUI.Theme = T

local getn, tinsert = table.getn, table.insert

-- ---------------------------------------------------------------- ressources autorisees (noms -> chemins)
T.tex = { white = "Interface\\Buttons\\WHITE8X8" }
T.FONTS = { arial = "Fonts\\ARIALN.TTF", frizqt = "Fonts\\FRIZQT__.TTF" }
T.BARS = { flat = "Interface\\Buttons\\WHITE8X8", blizzard = "Interface\\TargetingFrame\\UI-StatusBar" }
T.PANELS = { flat = "Interface\\Buttons\\WHITE8X8", tooltip = "Interface\\Tooltips\\UI-Tooltip-Background",
	dialog = "Interface\\DialogFrame\\UI-DialogBox-Background" }
-- bordures : fichier, epaisseur (edgeSize), retrait (insets)
T.EDGES = {
	none = { file = nil, size = 0, ins = 0 },
	thin = { file = "Interface\\Buttons\\WHITE8X8", size = 1, ins = 1 },
	thick = { file = "Interface\\Buttons\\WHITE8X8", size = 2, ins = 2 },
	rounded = { file = "Interface\\Tooltips\\UI-Tooltip-Border", size = 16, ins = 4 },
	dialog = { file = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 20, ins = 5 },
}
T.OUTLINES = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE" }
T.BUTTONS = {
	flat = false,
	blizzard = { up = "Interface\\Buttons\\UI-Panel-Button-Up", down = "Interface\\Buttons\\UI-Panel-Button-Down",
		hi = "Interface\\Buttons\\UI-Panel-Button-Highlight", coords = { 0, 0.625, 0, 0.6875 } },
}
-- familles de ressources : un style (ou un fichier utilisateur, voir Style.lua : SUI.RegisterAsset) ne designe une ressource que par son NOM
T.assets = { font = T.FONTS, bar = T.BARS, panel = T.PANELS, edge = T.EDGES, outline = T.OUTLINES, button = T.BUTTONS }

-- ---------------------------------------------------------------- palette vivante (tables modifiees sur place)
T.c = {
	bg     = { 0.065, 0.070, 0.080, 0.95 },
	panel  = { 0.095, 0.100, 0.115, 0.95 },
	inset  = { 0.045, 0.048, 0.056, 1 },
	border = { 0.200, 0.210, 0.240, 1 },
	text   = { 0.900, 0.910, 0.930, 1 },
	dim    = { 0.580, 0.600, 0.650, 1 },
	good   = { 0.360, 0.800, 0.470, 1 },
	warn   = { 0.950, 0.760, 0.260, 1 },
	bad    = { 0.910, 0.330, 0.330, 1 },
}
T.colorNames = { "bg", "panel", "inset", "border", "text", "dim", "good", "warn", "bad" }
T.accents = {
	blue   = { 0.30, 0.77, 0.91 },
	green  = { 0.40, 0.80, 0.50 },
	orange = { 0.96, 0.62, 0.25 },
}
T.accentUsers = {}
T.font = T.FONTS.arial
T.fontScale = 1
T.outline = ""
T.barTex = T.BARS.flat
T.panelTex = T.PANELS.flat
T.edge = T.EDGES.thin
T.button = false
T.alpha = 1                -- multiplie l'opacite des fonds (bg, panel, inset)
T.styleAccent = "blue"     -- accent propre au style : "blue" | "green" | "orange" | "class" | { r, g, b }
T.items = {}               -- widgets crees (pour repeindre a chaud)
T.restyles = 0

function T.Accent()
	local mode = SUI.Config.Get("ui.accent")
	if mode == "style" then mode = T.styleAccent end
	if type(mode) == "table" then return mode[1], mode[2], mode[3] end
	if mode == "class" and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then return col.r, col.g, col.b end
	end
	local a = T.accents[mode] or T.accents.blue
	return a[1], a[2], a[3]
end

-- fn() est rappelee quand la couleur d'accent change.
function T.OnAccent(fn)
	tinsert(T.accentUsers, fn)
end

function T.RefreshAccent()
	for i = 1, getn(T.accentUsers) do
		local ok, err = pcall(T.accentUsers[i])
		if not ok then SUI.Report("accent", err) end
	end
end

-- ---------------------------------------------------------------- peinture des widgets (a la creation ET au changement de style)
local function paintBackdrop(f, bg, border)
	local e = T.edge
	local ins = e.ins
	if e.file then
		f:SetBackdrop({ bgFile = T.panelTex, edgeFile = e.file, tile = true, tileSize = 16, edgeSize = e.size,
			insets = { left = ins, right = ins, top = ins, bottom = ins } })
	else
		f:SetBackdrop({ bgFile = T.panelTex, tile = true, tileSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
	end
	f:SetBackdropColor(bg[1], bg[2], bg[3], (bg[4] or 1) * T.alpha)
	if e.file then f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

local function paintText(fs, size, wantOutline)
	local px = math.floor(size * T.fontScale + 0.5)
	if px < 6 then px = 6 end
	local flags = T.outline
	if wantOutline and flags == "" then flags = "OUTLINE" end
	local ok, r = pcall(fs.SetFont, fs, T.font, px, flags)
	if not ok or r == false then pcall(fs.SetFont, fs, T.FONTS.arial, px, flags) end
end

local function paintBar(b)
	b:SetStatusBarTexture(T.barTex)
	if b.bg then
		b.bg:SetTexture(T.tex.white)
		b.bg:SetVertexColor(T.c.inset[1], T.c.inset[2], T.c.inset[3], 1)
	end
end

local function paintButton(b)
	local bt = T.button
	if bt then
		local co = bt.coords
		b:SetNormalTexture(bt.up)
		b:SetPushedTexture(bt.down)
		b:SetHighlightTexture(bt.hi)
		local n = b:GetNormalTexture()
		if n then n:SetTexCoord(co[1], co[2], co[3], co[4]) end
		local p = b:GetPushedTexture()
		if p then p:SetTexCoord(co[1], co[2], co[3], co[4]) end
		local h = b:GetHighlightTexture()
		if h then
			h:SetTexCoord(co[1], co[2], co[3], co[4])
			h:SetBlendMode("ADD")
		end
	else
		b:SetNormalTexture(nil)
		b:SetPushedTexture(nil)
		b:SetHighlightTexture(nil)
	end
end

local function paint(it)
	local o = it.o
	if it.k == "bd" then
		paintBackdrop(o, it.bg, it.border)
	elseif it.k == "tx" then
		paintText(o, it.size, it.outline)
		local c = it.color
		o:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	elseif it.k == "bar" then
		paintBar(o)
	elseif it.k == "btn" then
		paintButton(o)
	elseif it.k == "ed" then
		local px = math.floor(11 * T.fontScale + 0.5)
		pcall(o.SetFont, o, T.font, px < 6 and 6 or px)
	end
end

local function track(o, k, extra)
	local it = extra or {}
	it.o = o
	it.k = k
	tinsert(T.items, it)
	return it
end

-- Repeint tous les widgets crees (apres T.Apply). A appeler hors combat (Style.lua passe par SUI.WhenSafe).
function T.Restyle()
	T.restyles = T.restyles + 1
	for i = 1, getn(T.items) do
		local ok, err = pcall(paint, T.items[i])
		if not ok then SUI.Report("restyle", err) end
	end
	if SUI.Layout then SUI.Layout.UpdateLock() end
	T.RefreshAccent()
end

-- ---------------------------------------------------------------- widgets
function T.Backdrop(f, bg, border)
	bg = bg or T.c.panel
	border = border or T.c.border
	if f.suiBd then
		f.suiBd.bg, f.suiBd.border = bg, border
	else
		f.suiBd = track(f, "bd", { bg = bg, border = border })
	end
	paintBackdrop(f, bg, border)
end

function T.Text(parent, size, color, justify, outline)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local c = color or T.c.text
	local it = track(fs, "tx", { size = size or 11, color = c, outline = outline and true or false })
	paintText(fs, it.size, it.outline)
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function btnClick()
	local b = this
	if b.onclick and not b.disabled then b.onclick(b, arg1) end
end

local function btnEnter()
	local b = this
	if b.disabled then return end
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
end

local function btnLeave()
	local b = this
	if b.selected then
		local r, g, bl = T.Accent()
		b:SetBackdropBorderColor(r, g, bl, 1)
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

function T.Button(parent, label, w, h, onclick)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(h)
	T.Backdrop(b, T.c.panel, T.c.border)
	track(b, "btn")
	paintButton(b)
	b.label = T.Text(b, 11, T.c.text, "CENTER")
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetText(label or "")
	b.onclick = onclick
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", btnClick)
	b:SetScript("OnEnter", btnEnter)
	b:SetScript("OnLeave", btnLeave)
	return b
end

function T.SetButtonText(b, text)
	b.label:SetText(text or "")
end

function T.SetSelected(b, on)
	b.selected = on and true or false
	local r, g, bl = T.Accent()
	if on then
		b:SetBackdropBorderColor(r, g, bl, 1)
		if b.label then b.label:SetTextColor(r, g, bl, 1) end
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
		if b.label then b.label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1) end
	end
end

function T.Check(parent, onchange)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(16)
	b:SetHeight(16)
	T.Backdrop(b, T.c.inset, T.c.border)
	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetTexture(T.tex.white)
	b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
	b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
	local r, g, bl = T.Accent()
	b.mark:SetVertexColor(r, g, bl, 1)
	b.mark:Hide()
	b.on = false
	b.onchange = onchange
	b:SetScript("OnClick", function()
		local c = this
		T.SetCheck(c, not c.on)
		if c.onchange then c.onchange(c.on) end
	end)
	if not b.suiAccent then
		b.suiAccent = true
		tinsert(T.accentUsers, function()
			local r2, g2, b2 = T.Accent()
			b.mark:SetVertexColor(r2, g2, b2, 1)
		end)
	end
	return b
end

function T.SetCheck(b, on)
	b.on = on and true or false
	if b.on then b.mark:Show() else b.mark:Hide() end
end

local function sliderChanged()
	local s = this
	if s.silent then return end
	if s.onchange then s.onchange(s:GetValue()) end
end

function T.Slider(parent, w, onchange)
	local s = CreateFrame("Slider", nil, parent)
	s:SetWidth(w)
	s:SetHeight(10)
	s:SetOrientation("HORIZONTAL")
	T.Backdrop(s, T.c.inset, T.c.border)
	s:SetThumbTexture(T.tex.white)
	local th = s:GetThumbTexture()
	th:SetWidth(8)
	th:SetHeight(14)
	local r, g, b = T.Accent()
	th:SetVertexColor(r, g, b, 1)
	s.onchange = onchange
	s:SetScript("OnValueChanged", sliderChanged)
	if not s.suiAccent then
		s.suiAccent = true
		tinsert(T.accentUsers, function()
			local r2, g2, b2 = T.Accent()
			th:SetVertexColor(r2, g2, b2, 1)
		end)
	end
	return s
end

function T.SetSlider(s, min, max, step, value)
	s.silent = true
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	s:SetValue(value)
	s.silent = false
end

function T.Edit(parent, w, h)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetWidth(w)
	e:SetHeight(h)
	e:SetAutoFocus(false)
	track(e, "ed")
	pcall(e.SetFont, e, T.font, 11)
	e:SetTextInsets(4, 4, 2, 2)
	T.Backdrop(e, T.c.inset, T.c.border)
	e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	return e
end

function T.Bar(parent)
	local b = CreateFrame("StatusBar", nil, parent)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	track(b, "bar")
	paintBar(b)
	b:SetMinMaxValues(0, 1)
	b:SetValue(1)
	return b
end

-- Cadre de fond standard (couleur 'panel', bordure et opacite du style courant) : tout panneau de module passe par la.
function T.Panel(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(w)
	f:SetHeight(h)
	T.Backdrop(f, T.c.panel, T.c.border)
	return f
end

-- ---------------------------------------------------------------- application d'un jeu de jetons RESOLUS (voir Style.lua)
-- tok = { c = { bg = {r,g,b,a}, ... }, accent, font, fontScale, outline, bar, panel, edge, button, alpha } : chemins deja valides.
function T.Apply(tok)
	for i = 1, getn(T.colorNames) do
		local n = T.colorNames[i]
		local src, dst = tok.c[n], T.c[n]
		if src then
			dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4]
		end
	end
	T.styleAccent = tok.accent or "blue"
	T.font = tok.font or T.FONTS.arial
	T.fontScale = tok.fontScale or 1
	T.outline = tok.outline or ""
	T.barTex = tok.bar or T.BARS.flat
	T.panelTex = tok.panel or T.PANELS.flat
	T.edge = tok.edge or T.EDGES.thin
	T.button = tok.button or false
	T.alpha = tok.alpha or 1
end

-- ---------------------------------------------------------------- aspect par module : texture / police / forme (options <prefix>.*)
-- Options communes (descripteurs a ajouter a la liste 'options' d'un module) : SUI.Look.Options("meter", { bar = true, font = true, shape = true })
--   -> <prefix>.bartex (texture de barre), <prefix>.font (police), <prefix>.fontsize (taille, 0 = celle du module), <prefix>.shape
--      (style | plain | gradient | segmented | thin). Valeur par defaut "style" = l'aspect du style actif. Les listes sont CELLES du systeme de
--      style (style.bartex / style.font, donc aussi les ressources ajoutees par SUI.RegisterAsset).
-- Lecture : T.AssetFor("bar" | "font", prefix) -> chemin ; T.BarTexture(prefix) ; T.Font(prefix) -> chemin, taille (nil = celle du module).
-- Application : SUI.Look.ApplyBar(bar, prefix, { height = h, thin = px, segments = n }) pose texture, hauteur (forme "thin"), degrade et
--   segments d'une barre ; SUI.Look.ApplyText(fontstring, prefix, tailleDuModule, contour) pose police et taille. Rappelees seules quand
--   un reglage ou le style change. Si la largeur ou la hauteur de la barre change, rappeler ApplyBar. Aucune creation en combat
--   (differee a la sortie de combat). SUI.Look.Forget(objet) detache un objet. Aucune couleur en dur : jetons T.c.*.
local Look = {}
SUI.Look = Look
Look.SHAPES = { "style", "plain", "gradient", "segmented", "thin" }
Look.bars = {}
Look.texts = {}
Look.applied = 0

local function cget(key)
	if not SUI.Config.cur then return nil end
	return SUI.Config.Get(key)
end

local ASSET_SUFFIX = { bar = ".bartex", font = ".font" }

function T.AssetFor(kind, prefix)
	local suffix = ASSET_SUFFIX[kind]
	if not suffix then return nil end
	local base = (kind == "bar") and T.barTex or T.font
	local name = cget(prefix .. suffix)
	if type(name) ~= "string" or name == "" or name == "style" then return base end
	local path = T.assets[kind][name]
	local S = SUI.Style
	if not path or (S and S.missing and S.missing[kind .. ":" .. name]) then return base end
	return path
end

function T.BarTexture(prefix)
	return T.AssetFor("bar", prefix)
end

function T.Font(prefix)
	local size = cget(prefix .. ".fontsize")
	if type(size) ~= "number" or size <= 0 then size = nil end
	return T.AssetFor("font", prefix), size
end

local function barChoices()
	local m = SUI.Config.meta["style.bartex"]
	if m and m.choices then return m.choices end
	local l = { "style" }
	for k, _ in pairs(T.BARS) do tinsert(l, k) end
	return l
end

local function fontChoices()
	local m = SUI.Config.meta["style.font"]
	if m and m.choices then return m.choices end
	local l = { "style" }
	for k, _ in pairs(T.FONTS) do tinsert(l, k) end
	return l
end

local function assetText(base)
	return function(o, v)
		if v == "style" then return SUI.L("choice.visibility.style") end
		local key = "choice." .. base .. "." .. v
		if SUI.locales.fr[key] ~= nil then return SUI.L(key) end
		return tostring(v)
	end
end

local function shapeText(o, v)
	if v == "style" then return SUI.L("choice.visibility.style") end
	return SUI.L("choice.visibility.shape." .. v)
end

-- flags : { bar, font, shape (booleens), cat, order, simple }
function Look.Options(prefix, flags)
	flags = flags or {}
	local cat = flags.cat
	if not cat then
		local _, _, c = string.find(prefix, "^([^.]+)")
		cat = c or prefix
	end
	local order = flags.order or 820
	local simple = flags.simple and true or nil
	local out = {}
	if flags.bar then
		tinsert(out, { key = prefix .. ".bartex", type = "choice", cat = cat, label = "opt.visibility.bartex", tip = "tip.visibility.bartex",
			choices = barChoices(), default = "style", order = order, simple = simple, choiceText = assetText("style.bartex") })
	end
	if flags.shape then
		tinsert(out, { key = prefix .. ".shape", type = "choice", cat = cat, label = "opt.visibility.shape", tip = "tip.visibility.shape",
			choices = Look.SHAPES, default = "style", order = order + 1, simple = simple, choiceText = shapeText })
	end
	if flags.font then
		tinsert(out, { key = prefix .. ".font", type = "choice", cat = cat, label = "opt.visibility.font", tip = "tip.visibility.font",
			choices = fontChoices(), default = "style", order = order + 2, simple = simple, choiceText = assetText("style.font") })
		tinsert(out, { key = prefix .. ".fontsize", type = "number", cat = cat, label = "opt.visibility.fontsize", tip = "tip.visibility.fontsize",
			min = 0, max = 24, step = 1, default = 0, order = order + 3, simple = simple })
	end
	return out
end

-- Les reglages (ou le style) ont change : on repeint tout ce qui est suivi. Branche une seule fois, au premier objet suivi.
local function relook()
	for i = 1, getn(Look.bars) do
		local b = Look.bars[i]
		Look.ApplyBar(b, b.suiLookPrefix, b.suiLookOpts)
	end
	for i = 1, getn(Look.texts) do
		local fs = Look.texts[i]
		Look.ApplyText(fs, fs.suiLookPrefix, fs.suiLookSize, fs.suiLookOutline)
	end
end

local function lookKey(key)
	if key == nil then
		relook()
	elseif not string.find(key, "^style%.") and (string.find(key, "%.bartex$") or string.find(key, "%.shape$") or string.find(key, "%.font$") or string.find(key, "%.fontsize$")) then
		relook()
	end
end

local function track(list, o)
	if not o.suiLookTracked then
		o.suiLookTracked = true
		tinsert(list, o)
	end
	if not Look.hooked then
		Look.hooked = true
		SUI.Config.Watch("", lookKey)
		T.OnAccent(relook)       -- appele par T.Restyle apres le repeint des widgets : la police / texture du module repasse par-dessus
	end
end

function Look.Forget(o)
	if not o then return end
	o.suiLookTracked = nil
	for i = getn(Look.bars), 1, -1 do
		if Look.bars[i] == o then table.remove(Look.bars, i) end
	end
	for i = getn(Look.texts), 1, -1 do
		if Look.texts[i] == o then table.remove(Look.texts, i) end
	end
end

-- Pose texture / hauteur / degrade / segments d'une barre selon <prefix>.bartex et <prefix>.shape.
function Look.ApplyBar(bar, prefix, o)
	if not bar or type(prefix) ~= "string" then return end
	o = o or bar.suiLookOpts or {}
	bar.suiLookPrefix, bar.suiLookOpts = prefix, o
	track(Look.bars, bar)
	Look.applied = Look.applied + 1
	bar:SetStatusBarTexture(T.BarTexture(prefix))
	local shape = cget(prefix .. ".shape")
	if type(shape) ~= "string" then shape = "style" end
	-- hauteur : naturelle (celle du module), ou fine
	if o.height then bar.suiBaseH = o.height end
	if not bar.suiBaseH then bar.suiBaseH = bar:GetHeight() end
	local baseH = bar.suiBaseH
	if baseH and baseH > 0 then
		if shape == "thin" then
			bar:SetHeight(o.thin or math.max(2, math.floor(baseH * 0.4 + 0.5)))
			bar.suiThin = true
		elseif bar.suiThin then
			bar:SetHeight(baseH)
			bar.suiThin = nil
		end
	end
	-- degrade et segments : des textures a creer UNE fois (jamais en combat)
	local wantGrad = (shape == "gradient")
	local wantSeg = (shape == "segmented")
	local n = math.floor(tonumber(o.segments) or 10)
	if n < 2 then n = 2 end
	if n > 40 then n = 40 end
	local segs = bar.suiSegs
	local need = (wantGrad and not bar.suiGrad) or (wantSeg and (not segs or getn(segs) < n - 1))
	local fight = need and SUI.InCombat()
	if fight and not bar.suiLookPending then
		bar.suiLookPending = true
		SUI.WhenSafe(function()
			bar.suiLookPending = nil
			if bar.suiLookTracked then Look.ApplyBar(bar, bar.suiLookPrefix, bar.suiLookOpts) end
		end)
	end
	if wantGrad and (bar.suiGrad or not fight) then
		if not bar.suiGrad then
			bar.suiGrad = bar:CreateTexture(nil, "OVERLAY")
			bar.suiGrad:SetAllPoints(bar)
			bar.suiGrad:SetTexture(T.tex.white)
		end
		local c = T.c.inset
		bar.suiGrad:SetGradientAlpha("VERTICAL", c[1], c[2], c[3], 0.55, c[1], c[2], c[3], 0)
		bar.suiGrad:Show()
	elseif bar.suiGrad then
		bar.suiGrad:Hide()
	end
	if wantSeg then
		if not segs then
			segs = {}
			bar.suiSegs = segs
		end
		local w = bar:GetWidth()
		local c = T.c.bg
		for i = 1, n - 1 do
			local t = segs[i]
			if not t and not fight then
				t = bar:CreateTexture(nil, "OVERLAY")
				t:SetTexture(T.tex.white)
				t:SetWidth(1)
				segs[i] = t
			end
			if t then
				if w and w > 0 then
					local x = math.floor(w * i / n)
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
					t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
					t:SetVertexColor(c[1], c[2], c[3], 1)
					t:Show()
				else
					t:Hide()
				end
			end
		end
		for i = n, getn(segs) do segs[i]:Hide() end
	elseif segs then
		for i = 1, getn(segs) do segs[i]:Hide() end
	end
end

-- Pose police et taille d'un texte selon <prefix>.font / <prefix>.fontsize. size : taille prevue par le module (suit l'echelle du style).
function Look.ApplyText(fs, prefix, size, wantOutline)
	if not fs or type(prefix) ~= "string" then return end
	fs.suiLookPrefix, fs.suiLookSize, fs.suiLookOutline = prefix, size, wantOutline
	track(Look.texts, fs)
	local path, px = T.Font(prefix)
	if not px then
		px = math.floor((size or 11) * T.fontScale + 0.5)
		if px < 6 then px = 6 end
	end
	local flags = T.outline
	if wantOutline and flags == "" then flags = "OUTLINE" end
	local ok, r = pcall(fs.SetFont, fs, path, px, flags)
	if not ok or r == false then pcall(fs.SetFont, fs, T.FONTS.arial, px, flags) end
end

-- ---------------------------------------------------------------- bouton engrenage : ouvre la page de reglages du module
-- T.GearButton(parent, categorieMenu, opts) -> bouton (nil si appele en combat : cree a la sortie de combat, opts.onCreate(btn) le recoit)
--   categorieMenu : cle de categorie du menu = nom du module ("meter") ; clic gauche -> SUI.Menu.Show(categorie).
--   opts : size (16), point / relPoint / x / y (ancre : TOPRIGHT, -4, -4), title (infobulle), onRight(btn) (clic droit), onCreate(btn), tipAnchor.
--   Glyphe texte "o" ; une texture d'engrenage fournie par le style (T.tex.gear, absente par defaut) la remplacerait.
--   Le client change le niveau du contenu d'un cadre apres sa construction : le bouton est recale a chaque affichage du parent
--   (T.GearLevel). Pour une fenetre Blizzard, passer le cadre Blizzard comme parent.
local function maxLevel(f, depth)
	local top = f:GetFrameLevel()
	if depth > 0 then
		local kids = { f:GetChildren() }
		for i = 1, getn(kids) do
			local l = maxLevel(kids[i], depth - 1)
			if l > top then top = l end
		end
	end
	return top
end

function T.GearLevel(btn)
	local p = btn and btn.suiGearParent
	if not p then return end
	local top = p:GetFrameLevel()
	local kids = { p:GetChildren() }
	for i = 1, getn(kids) do
		if kids[i] ~= btn then
			local l = maxLevel(kids[i], 2)
			if l > top then top = l end
		end
	end
	btn:SetFrameStrata(p:GetFrameStrata())
	btn:SetFrameLevel(top + 2)
end

local function gearShown()
	local p = this
	local list = p.suiGears
	if p.suiGearOldShow then pcall(p.suiGearOldShow)   -- (2026-11-20) un script absent ne doit pas tuer le chainage
end
	if not list then return end
	for i = 1, getn(list) do T.GearLevel(list[i]) end
	SUI.After(0.3, function()
		for i = 1, getn(list) do T.GearLevel(list[i]) end
	end, "gearlevel")
end

local function gearClick(b, button)
	if button == "RightButton" and b.gearRight then
		b.gearRight(b)
	elseif SUI.Menu and SUI.Menu.Show then
		SUI.Menu.Show(b.gearCat)
	end
end

local function gearEnter()
	local b = this
	btnEnter()
	if not GameTooltip then return end
	GameTooltip:SetOwner(b, b.gearTipAnchor or "ANCHOR_BOTTOMLEFT")
	local c, d = T.c.text, T.c.dim
	GameTooltip:AddLine(b.gearTitle or SUI.L("mod.visibility.gear"), c[1], c[2], c[3])
	GameTooltip:AddLine(SUI.L("mod.visibility.gear.hint", b.gearCat), d[1], d[2], d[3])
	GameTooltip:Show()
end

local function gearLeave()
	btnLeave()
	if GameTooltip then GameTooltip:Hide() end
end

local function buildGear(parent, cat, opts)
	local size = opts.size or 16
	local b = T.Button(parent, "o", size, size, gearClick)
	b.gearCat, b.gearTitle, b.gearRight, b.gearTipAnchor = cat, opts.title, opts.onRight, opts.tipAnchor
	b.suiGearParent = parent
	b:SetScript("OnEnter", gearEnter)
	b:SetScript("OnLeave", gearLeave)
	local gt = T.tex.gear
	if gt then
		b.label:Hide()
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetTexture(gt)
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
		b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
		b.icon:SetVertexColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	end
	b:SetPoint(opts.point or "TOPRIGHT", parent, opts.relPoint or opts.point or "TOPRIGHT", opts.x or -4, opts.y or -4)
	if not parent.suiGears then
		parent.suiGears = {}
		parent.suiGearOldShow = parent:GetScript("OnShow")
		parent:SetScript("OnShow", gearShown)
	end
	tinsert(parent.suiGears, b)
	T.GearLevel(b)
	if opts.onCreate then opts.onCreate(b) end
	return b
end

function T.GearButton(parent, cat, opts)
	if not parent or type(cat) ~= "string" then return nil end
	opts = opts or {}
	if SUI.InCombat() then
		SUI.WhenSafe(function() buildGear(parent, cat, opts) end)
		return nil
	end
	return buildGear(parent, cat, opts)
end

-- ---------------------------------------------------------------- positions (Layout)
-- Les positions sont enregistrees dans l'unite d'UIParent (gauche / bas), independamment de l'echelle des cadres.
local Layout = {}
SUI.Layout = Layout
Layout.items = {}

-- Cle de position LUE pour un cadre : en mode Raid, la position propre au mode ("cle|raid") si elle existe, sinon la position Normal.
function Layout.ReadKey(key)
	local m = SUI.Config.mode
	if m and m ~= "normal" then
		local k = key .. "|" .. m
		if SUI.Config.GetPos(k) then return k end
	end
	return key
end

-- Cle de position ECRITE : propre au mode courant (Normal : la cle seule).
function Layout.WriteKey(key)
	local m = SUI.Config.mode
	if m and m ~= "normal" then return key .. "|" .. m end
	return key
end

-- Le deplacement a la souris est assure par le service Mover (poignees nommees, voir Mover.lua) : un cadre enregistre ne se deplace
-- plus tout seul quand ui.locked est faux (plus de fond ni de poignee anonyme).
function Layout.Register(frame, key, point, x, y)
	Layout.items[key] = { frame = frame, point = point or "CENTER", x = x or 0, y = y or 0 }
	frame.layoutKey = key
	frame:SetMovable(true)
	Layout.Apply(key)
	if SUI.Mover then SUI.Mover.Adopt(key, frame) end
end

-- Position enregistree = coin BAS-GAUCHE en unites UIParent. Quand l'echelle change, un cadre large
-- (anchore a droite, ex. auras TOPRIGHT) change de taille a l'ecran : garder le meme bas-gauche le DECALE
-- visuellement de toute sa largeur. On compense : le point d'ANCRE du cadre (it.point) reste fixe a l'ecran.
function Layout.Apply(key, keepAnchor)
	local it = Layout.items[key]
	if not it then return end
	local f = it.frame
	local l, b, s = SUI.Config.GetPos(Layout.ReadKey(key))
	local oldsc = f:GetScale() or 1
	local sc = SUI.Config.Get("ui.scale") * (s or 1)
	if type(it.mul) == "function" then      -- echelle propre au module (ex. micro-menu), combinee a celle du Mover
		local m = it.mul()
		if type(m) == "number" and m > 0 then sc = sc * m end
	end
	f:SetScale(sc)
	f:ClearAllPoints()
	if l then
		if keepAnchor and it.point and math.abs(oldsc - sc) > 0.001 then
			-- le coin bas-gauche enregistre ne bouge pas a l'ecran : recale par l'ecart d'ancrage entre les deux echelles
			local fw = (f:GetWidth() or 0)
			local fh = (f:GetHeight() or 0)
			local ax, ay = 0.5, 0.5
			local p = it.point
			if p and string.find(p, "LEFT") then ax = 0 elseif p and string.find(p, "RIGHT") then ax = 1 end
			if p and string.find(p, "TOP") then ay = 1 elseif p and string.find(p, "BOTTOM") then ay = 0 end
			-- la position enregistree l/b correspond au bas-gauche A L'ANCIENNE ECHELLE du cadre de taille fixe fw/fh :
			-- son ancre etait a (l + fw*oldsc*ax, b + fh*oldsc*ay) en unites UIParent ; on la preserve
			local nl = l + fw * (oldsc - sc) * ax
			local nb = b + fh * (oldsc - sc) * ay
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", nl / sc, nb / sc)
		else
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / sc, b / sc)
		end
	else
		f:SetPoint(it.point, UIParent, it.point, it.x, it.y)
	end
end

function Layout.ApplyAll()
	for key, _ in pairs(Layout.items) do Layout.Apply(key, true) end
end

-- Remet la bordure normale des cadres enregistres (les poignees de deplacement sont dessinees par le Mover, jamais sur les cadres).
function Layout.UpdateLock()
	local c = T.c.border
	for _, it in pairs(Layout.items) do
		local f = it.frame
		if f.SetBackdropBorderColor and f.suiBd then f:SetBackdropBorderColor(c[1], c[2], c[3], c[4]) end
	end
end

local applyPending = false
local function applySoon()
	if applyPending then return end
	applyPending = true
	-- coalesce : les rafales de Notify("pos") (reset, plusieurs detachements) ne font qu'UN ApplyAll
	SUI.WhenSafe(function()
		applyPending = false
		Layout.ApplyAll()
	end)
end
local function onThemeKey(key, value)
	if key == nil then
		-- reset de profil : Layouts.lua (charge apres Theme) fait InvalidateLinks + ApplyAll dans le BON ordre,
		-- ici on ne repeint que le theme (l'ancien double ApplyAll travaillait avec un index de liens perime)
		Layout.UpdateLock()
		T.RefreshAccent()
	elseif key == "ui.scale" then
		Layout.ApplyAll()
	elseif key == "pos" then
		applySoon()
	elseif key == "ui.locked" then
		Layout.UpdateLock()
	elseif key == "ui.accent" then
		T.RefreshAccent()
		Layout.UpdateLock()
	end
end
SUI.Config.Watch("", onThemeKey)
