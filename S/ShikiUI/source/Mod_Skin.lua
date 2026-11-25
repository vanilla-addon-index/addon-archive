-- ShikiUI Skin : habille les fenetres Blizzard (menu Echap, options, personnage, sorts, quetes, marchand, popups, listes deroulantes...)
-- avec le style ShikiUI, dans l'esprit des "skins" de pfUI (module "skin", conception originale ; les noms de cadres viennent de pfUI
-- et de FrameXML 1.12, relus, jamais copies ni executes).
-- PRINCIPE. Le decor Blizzard n'est JAMAIS detruit : les textures d'art d'un cadre sont rendues transparentes (SetAlpha 0, sinon Hide) et un
-- cadre de fond enfant, plus BAS que le cadre, porte le fond / la bordure du style. Un cadre qui a un vrai Backdrop XML (dialogues, listes,
-- infobulles) est repeint sur place ; couper le module (ou la case du groupe) restaure l'etat (approximatif pour ces derniers : /reload).
-- Jamais masque : icones (textures dont le nom contient Icon), modeles 3D (cadres enfants), cases d'objets / sorts (seule la bordure
-- "Quickslot" est masquee), tuiles de la carte du monde (on n'habille que ses controles), carte des vols.
-- ARCHITECTURE. Un registre de GROUPES (SUI.Skin.AddGroup) ; un groupe = des "specs" (donnees : nom de cadre, type de fond, listes de boutons /
-- onglets / cases / curseurs / listes / champs / barres de defilement...). Chargement paresseux : un Blizzard_* charge a la demande est pris a
-- ADDON_LOADED ; un cadre deja la est habille tout de suite ; chaque cadre re-verifie ses enfants a chaque OnShow (chaine, jamais de HookScript).
-- Aucun OnUpdate : tout passe par SUI.WhenSafe (jamais de creation de cadre en combat) et SUI.After.
-- COEXISTENCE. Un groupe dont pfUI fait tourner la skin equivalente (pfUI.skin[nom], non coupee par pfUI_config.disabled["skin_"..nom])
-- est laisse a pfUI (reglage skin.yield). Cadres du jeu ou de modules ShikiUI deja traites : GameTooltip si le module tooltip tourne.
-- REGLAGES. Case du module, case par groupe (skin.f.<id>), opacite du fond, bordure (style / aucune / fine / epaisse), coins (style / carres /
-- arrondis), contraste (discret / normal / fort), teinte d'accent (aucune / bordure / titre / les deux), police (inchangee / etiquettes /
-- tout) et taille, decor Blizzard masque ou non, parchemin (garde / sombre). Aucune couleur en dur : T.c.*, T.Accent ; repeinture a chaud
-- au changement de style, d'accent et de reglage.
-- NON VERIFIE EN JEU : tout. Notamment les noms de cadres supposes (AddonList, entrees des raccourcis, cadres Turtle), les marges des fonds
-- (valeurs relevees dans pfUI), SetAlpha sur une Texture 1.12, GetFont / GetTexture sur les regions, le niveau de cadre d'un fond enfant,
-- le rendu des boutons habilles (etats desactive / survol), les couleurs de texte des parchemins en mode sombre.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind = string.find
local floor = math.floor

local M = {}
SUI.Skin = M

M.on = false
M.recs = {}          -- tout ce qu'on a modifie (pour restaurer / repeindre)
M.groups = {}        -- id -> definition
M.order = {}         -- ids dans l'ordre d'enregistrement
M.gon = {}           -- id -> case du groupe
M.gstate = {}        -- id -> "on" | "off" | "pfui"
M.waiting = {}       -- addon charge a la demande -> true
M.later = false
M.nframes = 0
M.pend = false
M.wrapped = {}
M.mul = 1
M.ar, M.ag, M.ab = 1, 1, 1
M.cfg = { alpha = 0.95, contrast = "normal", tint = "off", border = "style", corners = "style", font = "labels", fontscale = 1,
	art = true, parchment = "keep", yield = true, talentlight = true }

local ZERO = { 0, 0, 0, 0 }
local PROTECTED = { "Icon", "Model", "Check", "Cooldown" }
local EXCLUDE = { "Scroll", "PageButton", "Arrow", "Rotate", "Expand", "Collapse", "CloseButton", "Tab" }
local WIN = { panel = true, inset = true, tooltip = true }

-- ---------------------------------------------------------------- utilitaires
local function frameOf(name)
	if type(name) ~= "string" then return nil end
	local f = getglobal(name)
	if type(f) == "table" and f.GetObjectType then return f end
	return nil
end

local function kindOf(o)
	local ok, k = pcall(o.GetObjectType, o)
	if ok then return k end
	return nil
end

local function packRegions(f) return { f:GetRegions() } end
local function packChildren(f) return { f:GetChildren() } end

local function listOf(f, which)
	if not f then return {} end
	local ok, t = pcall(which, f)
	if ok and type(t) == "table" then return t end
	return {}
end

local function nameHas(name, list)
	if type(name) ~= "string" then return false end
	for i = 1, getn(list) do
		if sfind(name, list[i], 1, true) then return true end
	end
	return false
end

local function addRec(r)
	tinsert(M.recs, r)
	return r
end

local function seq(prefix, n, suffix)
	local t = {}
	for i = 1, n do tinsert(t, prefix .. i .. (suffix or "")) end
	return t
end

local function cat(a, b)
	local t = {}
	for i = 1, getn(a) do tinsert(t, a[i]) end
	for i = 1, getn(b) do tinsert(t, b[i]) end
	return t
end

local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger0",
	"Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }
local function slotNames(prefix)
	local t = {}
	for i = 1, getn(SLOTS) do tinsert(t, prefix .. SLOTS[i] .. "Slot") end
	return t
end

-- ---------------------------------------------------------------- jetons effectifs (apres un changement de style ou de reglage)
function M.ReadConfig()
	local cfg = M.cfg
	cfg.alpha = C.Get("skin.alpha")
	cfg.contrast = C.Get("skin.contrast")
	cfg.tint = C.Get("skin.tint")
	cfg.border = C.Get("skin.border")
	cfg.corners = C.Get("skin.corners")
	cfg.font = C.Get("skin.font")
	cfg.fontscale = C.Get("skin.fontscale")
	cfg.art = C.Get("skin.art") and true or false
	cfg.parchment = C.Get("skin.parchment")
	cfg.yield = C.Get("skin.yield") and true or false
	cfg.talentlight = C.Get("skin.talentlight") and true or false
	for i = 1, getn(M.order) do
		local id = M.order[i]
		local v = C.Get("skin.f." .. id)
		if v == nil then v = true end        -- groupe ajoute apres coup (sans case) : actif
		M.gon[id] = v and true or false
	end
end

function M.Resolve()
	local cfg = M.cfg
	local e = T.edge
	if cfg.border == "none" then e = T.EDGES.none
	elseif cfg.border == "thin" then e = T.EDGES.thin
	elseif cfg.border == "thick" then e = T.EDGES.thick end
	if e and e.file then
		if cfg.corners == "round" then
			e = T.EDGES.rounded
		elseif cfg.corners == "square" and (e == T.EDGES.rounded or e == T.EDGES.dialog) then
			e = T.EDGES.thin
		end
		if cfg.contrast == "high" and e == T.EDGES.thin then e = T.EDGES.thick
		elseif cfg.contrast == "soft" and e == T.EDGES.thick then e = T.EDGES.thin end
	end
	M.edge = e or T.EDGES.none
	M.cedge = (M.edge.file and T.EDGES.thin) or T.EDGES.none
	if cfg.contrast == "soft" then M.mul = 0.75 else M.mul = 1 end
	M.ar, M.ag, M.ab = T.Accent()
end

-- ---------------------------------------------------------------- etat d'un groupe, coexistence avec pfUI
local function disabledIn(key)
	local cfg = getglobal("pfUI_config")
	if type(cfg) ~= "table" or type(cfg.disabled) ~= "table" then return false end
	local v = cfg.disabled[key]
	return v == "1" or v == 1 or v == true
end

function M.PfuiSkinRuns(name)
	local p = getglobal("pfUI")
	if type(p) ~= "table" or type(p.skin) ~= "table" then return false end
	if p.skin[name] == nil then return false end
	return not disabledIn("skin_" .. name)
end

function M.PfuiModuleRuns(name)
	local mg = SUI.Migrate
	if mg and mg.Present and mg.Present() and mg.Running then return mg.Running(name) and true or false end
	local p = getglobal("pfUI")
	if type(p) ~= "table" or type(p.module) ~= "table" or p.module[name] == nil then return false end
	return not disabledIn(name)
end

function M.Owned(g)
	if not M.cfg.yield then return false end
	if g.pfui then
		for i = 1, getn(g.pfui) do
			if M.PfuiSkinRuns(g.pfui[i]) then return true end
		end
	end
	if g.pfmod and M.PfuiModuleRuns(g.pfmod) then return true end
	return false
end

function M.GroupState(g)
	if not M.on or not M.gon[g.id] then return "off" end
	if M.Owned(g) then return "pfui" end
	return "on"
end

local function recOn(r)
	if not M.on or M.gstate[r.g] ~= "on" then return false end
	if r.art and not M.cfg.art then return false end
	if r.paper and M.cfg.parchment ~= "dark" then return false end
	return true
end

-- ---------------------------------------------------------------- peinture d'un fond
local function bgOf(role)
	local c = T.c
	if role == "panel" or role == "tooltip" then return c.bg end
	if role == "button" or role == "tab" then return c.panel end
	return c.inset
end

local function paintBd(r)
	local f = r.f
	local role = r.role
	local win = WIN[role]
	local e = win and M.edge or M.cedge
	local bg = bgOf(role)
	local a = (bg[4] or 1) * T.alpha
	if win then
		a = a * M.cfg.alpha * M.mul
		if M.cfg.contrast == "high" and a < 0.97 then a = 0.97 end
	end
	if a > 1 then a = 1 end
	-- r.flat : panneau de section frere des controles (meme niveau de cadre, dessine apres leurs fonds) : bordure seule, sinon son
	-- remplissage opaque recouvrirait les fonds / cases des controles poses dessus.
	local fill = (not r.flat) and T.panelTex or nil
	local sig = (e.file or "-") .. e.size .. "/" .. tostring(fill)
	if r.sig ~= sig then
		r.sig = sig
		local ins = e.ins
		local spec = { bgFile = fill, edgeFile = e.file, tile = true, tileSize = 16, edgeSize = e.size,
			insets = { left = ins, right = ins, top = ins, bottom = ins } }
		f:SetBackdrop(spec)
	end
	f:SetBackdropColor(bg[1], bg[2], bg[3], a)
	if e.file then
		local c = T.c.border
		local rr, gg, bb, ba = c[1], c[2], c[3], c[4] or 1
		local tint = M.cfg.tint
		local hot = r.hover or r.sel
		if hot or M.cfg.contrast == "high" or (win and (tint == "border" or tint == "both")) then
			rr, gg, bb, ba = M.ar, M.ag, M.ab, 1
			if r.hover and r.close then
				local bad = T.c.bad
				rr, gg, bb = bad[1], bad[2], bad[3]
			end
		elseif M.cfg.contrast == "soft" then
			ba = ba * 0.6
		end
		f:SetBackdropBorderColor(rr, gg, bb, ba)
	end
	r.painted = true
end

local function restoreSelf(r)
	if not r.painted then return end
	local f = r.f
	r.painted = false
	r.sig = nil
	local spec
	if r.look == "tooltip" then
		spec = { bgFile = T.PANELS.tooltip, edgeFile = T.EDGES.rounded.file, tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 } }
	else
		spec = { bgFile = T.PANELS.dialog, edgeFile = T.EDGES.dialog.file, tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 } }
	end
	f:SetBackdrop(spec)
	local nb = getglobal("TOOLTIP_DEFAULT_BACKGROUND_COLOR")
	local nc = getglobal("TOOLTIP_DEFAULT_COLOR")
	if r.look == "tooltip" and type(nb) == "table" and type(nc) == "table" then
		f:SetBackdropColor(nb.r, nb.g, nb.b, 1)
		f:SetBackdropBorderColor(nc.r, nc.g, nc.b, 1)
	else
		f:SetBackdropColor(1, 1, 1, 1) -- style:ok restauration du blanc neutre du jeu
		f:SetBackdropBorderColor(1, 1, 1, 1) -- style:ok restauration du blanc neutre du jeu
	end
end

local function fontApply(r, on)
	local want = M.cfg.font
	local act = on and (want == "all" or (want == "labels" and r.lvl == 1))
	if act then
		local px = floor(r.size * T.fontScale * M.cfg.fontscale + 0.5)
		if px < 6 then px = 6 end
		local flags = T.outline
		if flags == "" then flags = r.flags end
		local ok, res = pcall(r.o.SetFont, r.o, T.font, px, flags)
		if not ok or res == false then pcall(r.o.SetFont, r.o, T.FONTS.arial, px, flags) end
		r.act = true
	elseif r.act then
		r.act = false
		pcall(r.o.SetFont, r.o, r.file, r.size, r.flags)
	end
end

local function defaultText()
	local nc = getglobal("NORMAL_FONT_COLOR")
	if type(nc) == "table" then return nc.r, nc.g, nc.b end
	return T.c.text[1], T.c.text[2], T.c.text[3]
end

function M.ApplyRec(r)
	local on = recOn(r)
	local k = r.k
	if k == "bd" then
		if on then
			r.f:Show()
			paintBd(r)
		else
			r.f:Hide()
		end
	elseif k == "self" then
		if on then paintBd(r) else restoreSelf(r) end
	elseif k == "hide" then
		if r.dead then return end
		local ok = pcall(function()
			if on then
				if r.mode ~= "a" or not pcall(r.o.SetAlpha, r.o, 0) then r.o:Hide() end
			else
				if r.mode == "a" then if not pcall(r.o.SetAlpha, r.o, r.a) then r.o:Show() end elseif r.shown then r.o:Show() end
			end
		end)
		if not ok then r.dead = true end
		if not ok and type(r.o) == "table" and r.o.GetName and r.o:GetName() then
			SUI.LogError("skin hide", "groupe " .. tostring(r.g) .. " objet " .. tostring(r.o) .. " type " .. type(r.o) .. " nom " .. tostring(type(r.o) == "table" and r.o.GetName and r.o:GetName()))
		end
	elseif k == "font" then
		fontApply(r, on)
	elseif k == "thumb" then
		local th = r.o
		if on then
			th:SetTexture(T.tex.white)
			th:SetVertexColor(M.ar, M.ag, M.ab, 1)
			if r.nw then th:SetWidth(r.nw) end
			if r.nh then th:SetHeight(r.nh) end
			r.act = true
		elseif r.act then
			r.act = false
			if r.tex then th:SetTexture(r.tex) end
			th:SetVertexColor(1, 1, 1, 1) -- style:ok restauration du blanc neutre du jeu
			th:SetWidth(r.w)
			th:SetHeight(r.h)
		end
	elseif k == "glyph" then
		if on then
			r.o:Show()
			r.o:SetText("x")
		else
			r.o:Hide()
		end
	elseif k == "color" then
		if on and (M.cfg.tint == "title" or M.cfg.tint == "both") then
			r.o:SetTextColor(M.ar, M.ag, M.ab, 1)
			r.act = true
		elseif r.act then
			r.act = false
			local cr, cg, cb = defaultText()
			r.o:SetTextColor(cr, cg, cb, 1)
		end
	elseif k == "ptext" then
		if on then
			local c = T.c.text
			r.o:SetTextColor(c[1], c[2], c[3], 1)
			r.act = true
		elseif r.act then
			r.act = false
			local cr, cg, cb = defaultText()
			r.o:SetTextColor(cr, cg, cb, 1)
		end
	end
end

function M.Sync()
	M.Resolve()
	for i = 1, getn(M.recs) do
		local r = M.recs[i]
		if r.k == "bd" and r.tab and r.p then r.sel = (not r.p:IsEnabled()) and true or false end
		local ok, err = pcall(M.ApplyRec, r)
		if not ok then SUI.Report("skin sync", err) end
	end
end

-- ---------------------------------------------------------------- briques : masquer, fond, police
function M.AddHide(o, id, art, paper)
	if not o or o.suiHid or not o.Hide then return end
	if type(o) ~= "table" or not o.GetObjectType or not pcall(o.GetObjectType, o) then return end   -- pas un vrai cadre/region : ignore sans bruit
	if not o.IsShown or not pcall(o.IsShown, o) then return end   -- region invalide dans le client (infobulles) : on ne la touche pas
	o.suiHid = true
	local r = { k = "hide", o = o, g = id, art = art, paper = paper }
	if o.SetAlpha then
		r.mode = "a"
		r.a = (o.GetAlpha and o:GetAlpha()) or 1
	else
		r.mode = "h"
		r.shown = o:IsShown() and true or false
	end
	M.ApplyRec(addRec(r))
end

function M.Strip(f, keep, id, art, paper)
	local regs = listOf(f, packRegions)
	for i = 1, getn(regs) do
		local o = regs[i]
		if type(o) == "table" and kindOf(o) == "Texture" then
			local n = o.GetName and o:GetName()
			if not nameHas(n, PROTECTED) and not (keep and nameHas(n, keep)) then M.AddHide(o, id, art, paper) end
		end
	end
end

function M.HideStates(b, id, withHighlight)
	local getters = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
	if withHighlight then tinsert(getters, "GetHighlightTexture") end
	for i = 1, getn(getters) do
		local fn = b[getters[i]]
		if fn then
			local ok, tex = pcall(fn, b)
			if ok and type(tex) == "table" then M.AddHide(tex, id, false, false) end
		end
	end
end

-- Fond enfant, plus bas que le cadre (le decor Blizzard reste dessous / dessus selon son propre niveau).
function M.Backdrop(f, role, id, ins, art, paper)
	if f.suiBd then return f.suiBd end
	local bd = CreateFrame("Frame", nil, f)
	local lv = f:GetFrameLevel()
	if lv > 0 then
		lv = lv - 1
	else
		-- niveau 0 : le fond (enfant, meme niveau) se dessinait PAR-DESSUS les textures du bouton (icones de talents noires). On monte le bouton d'un cran.
		pcall(f.SetFrameLevel, f, 1)
	end
	bd:SetFrameLevel(lv)
	ins = ins or ZERO
	bd:SetPoint("TOPLEFT", f, "TOPLEFT", ins[1], -ins[2])
	bd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -ins[3], ins[4])
	local r = addRec({ k = "bd", f = bd, p = f, role = role, g = id, art = art, paper = paper })
	f.suiBd = r
	M.ApplyRec(r)
	return r
end

function M.SelfBox(f, sp, id, role, look)
	if f.suiSelf then return end
	local r = addRec({ k = "self", f = f, role = role or "panel", look = look or "dialog", g = id, art = true, paper = sp.paper,
		flat = sp.flat and role == "inset" or nil })
	f.suiSelf = r
	M.ApplyRec(r)
end

function M.Font(fs, id, lvl)
	if not fs or fs.suiFont or not fs.GetFont then return end
	local ok, file, size, flags = pcall(fs.GetFont, fs)
	if not ok or type(file) ~= "string" or type(size) ~= "number" or size <= 0 then return end
	fs.suiFont = true
	M.ApplyRec(addRec({ k = "font", o = fs, file = file, size = size, flags = flags or "", g = id, lvl = lvl }))
end

function M.Color(fs, id, kind, paper)
	if not fs or fs.suiColor then return end
	fs.suiColor = true
	M.ApplyRec(addRec({ k = kind, o = fs, g = id, paper = paper, art = paper }))
end

function M.Thumb(th, id, w, h)
	if not th or th.suiThumb then return end
	th.suiThumb = true
	local p = th.GetTexture and th:GetTexture()
	if type(p) ~= "string" then p = nil end
	M.ApplyRec(addRec({ k = "thumb", o = th, g = id, tex = p, w = th:GetWidth(), h = th:GetHeight(), nw = w, nh = h }))
end

function M.Walk(f, depth, id)
	local regs = listOf(f, packRegions)
	for i = 1, getn(regs) do
		if type(regs[i]) == "table" and kindOf(regs[i]) == "FontString" then M.Font(regs[i], id, 2) end
	end
	if depth > 1 then
		local kids = listOf(f, packChildren)
		for i = 1, getn(kids) do
			if type(kids[i]) == "table" then M.Walk(kids[i], depth - 1, id) end
		end
	end
end

-- ---------------------------------------------------------------- survol : chaine les scripts existants
local function hover(b, on)
	local r = b.suiBd
	if r and M.on and recOn(r) then
		r.hover = on
		paintBd(r)
	end
end

local function onEnter()
	local b = this
	local o = b.suiOldEnter
	if o then o() end
	pcall(hover, b, true)
end

local function onLeave()
	local b = this
	local o = b.suiOldLeave
	if o then o() end
	pcall(hover, b, false)
end

function M.HookHover(b)
	if b.suiHov or not b.GetScript then return end
	b.suiHov = true
	b.suiOldEnter = b:GetScript("OnEnter")
	b.suiOldLeave = b:GetScript("OnLeave")
	b:SetScript("OnEnter", onEnter)
	b:SetScript("OnLeave", onLeave)
end

-- ---------------------------------------------------------------- controles
function M.Button(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	M.Strip(b, nil, id, false, false)
	M.HideStates(b, id, true)
	M.Backdrop(b, "button", id)
	M.HookHover(b)
	if b.GetFontString then M.Font(b:GetFontString(), id, 1) end
end

function M.Tab(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	M.Strip(b, nil, id, false, false)
	M.HideStates(b, id, true)
	local r = M.Backdrop(b, "tab", id)
	r.tab = true
	r.sel = (not b:IsEnabled()) and true or false
	M.ApplyRec(r)
	M.HookHover(b)
	if b.GetFontString then M.Font(b:GetFontString(), id, 1) end
end

-- Onglets du bas : Blizzard les chevauche (decalage -15) et les redimensionne a sa guise -> largeur = texte + marge, hauteur fixe, 3 px d'ecart.
function M.FitTabs(list)
	if not list then return end
	local prev = nil
	for i = 1, getn(list) do
		local b = list[i]
		if b and b.IsShown and b:IsShown() then
			local w = 56
			local fs = b.GetFontString and b:GetFontString()
			if fs and fs.GetStringWidth then
				local tw = fs:GetStringWidth()
				if type(tw) == "number" and tw + 24 > w then w = tw + 24 end
			end
			b:SetWidth(w)
			b:SetHeight(24)
			if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) end
			prev = b
		end
	end
end

function M.Slot(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	local n = b.GetNormalTexture and b:GetNormalTexture()
	local p = n and n.GetTexture and n:GetTexture()
	if type(p) == "string" and sfind(p, "Quickslot", 1, true) then M.AddHide(n, id, false, false) end
	M.Backdrop(b, "slot", id)
	M.HookHover(b)
end

function M.Icon(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	M.Backdrop(b, "slot", id)
	M.HookHover(b)
end

function M.Check(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	-- Case a cocher large (ligne entiere des fenetres Options de Blizzard : libelle a l'interieur du bouton) : un fond sur toute la
	-- largeur masquait les libelles. On laisse alors le dessin d'origine.
	local bw = b.GetWidth and b:GetWidth()
	if type(bw) == "number" and bw > 40 then return end
	local g1 = b.GetNormalTexture and b:GetNormalTexture()
	local g2 = b.GetPushedTexture and b:GetPushedTexture()
	if type(g1) == "table" then M.AddHide(g1, id, false, false) end
	if type(g2) == "table" then M.AddHide(g2, id, false, false) end
	M.Backdrop(b, "check", id, { 4, 4, 4, 4 })
end

function M.Close(b, id)
	if b.suiSkin then return end
	b.suiSkin = true
	M.HideStates(b, id, false)
	local ins = 9
	local w = b:GetWidth()
	if type(w) == "number" and w > 0 and w < 24 then ins = 3 end
	local r = M.Backdrop(b, "button", id, { ins, ins, ins, ins })
	r.close = true
	M.HookHover(b)
	local g = T.Text(b, 12, T.c.text, "CENTER")
	g:SetPoint("CENTER", b, "CENTER", 0, 0)
	M.ApplyRec(addRec({ k = "glyph", o = g, g = id }))
end

function M.Slider(s, id)
	if s.suiSkin then return end
	s.suiSkin = true
	local th = s.GetThumbTexture and s:GetThumbTexture()
	if type(th) ~= "table" then return end
	local vertical = s.GetOrientation and s:GetOrientation() == "VERTICAL"
	if vertical then M.Thumb(th, id, 16, 10) else M.Thumb(th, id, 10, 16) end
end

function M.Scroll(s, id)
	if s.suiSkin then return end
	s.suiSkin = true
	M.Backdrop(s, "track", id)
	local th = s.GetThumbTexture and s:GetThumbTexture()
	if type(th) == "table" then M.Thumb(th, id, 10, nil) end
end

function M.Drop(f, id)
	if f.suiSkin then return end
	f.suiSkin = true
	M.Strip(f, nil, id, false, false)
	M.Backdrop(f, "edit", id, { 15, 1, 15, 6 })
end

function M.Edit(e, id)
	if e.suiSkin then return end
	e.suiSkin = true
	M.Strip(e, nil, id, false, false)
	M.Backdrop(e, "edit", id)
end

function M.IsPlain(b)
	local n = b.GetName and b:GetName()
	if type(n) ~= "string" or b.suiSkin then return false end
	if nameHas(n, EXCLUDE) then return false end
	if getglobal(n .. "IconTexture") or getglobal(n .. "Icon") then return false end
	local t = b.GetText and b:GetText()
	return type(t) == "string" and t ~= ""
end

function M.Auto(f, depth, id)
	local kids = listOf(f, packChildren)
	for i = 1, getn(kids) do
		local c = kids[i]
		if type(c) == "table" then
			local k = kindOf(c)
			if k == "Button" then
				if M.IsPlain(c) then pcall(M.Button, c, id) end
			elseif k == "Frame" and depth > 1 then
				M.Auto(c, depth - 1, id)
			end
		end
	end
end

-- ---------------------------------------------------------------- une spec = un cadre et ses controles
local function each(list, fn, id, sp)
	if not list then return end
	for i = 1, getn(list) do
		local o = frameOf(list[i])
		if o then
			local ok, err = pcall(fn, o, id, sp)
			if not ok then SUI.Report("skin " .. tostring(list[i]), err) end
		end
	end
end

local function subBox(o, id, sp)
	M.Backdrop(o, "inset", id, ZERO, true, sp.paper)
	M.Strip(o, sp.keep, id, true, sp.paper)
end

local function subSelf(o, id, sp)
	M.SelfBox(o, sp, id, "inset", sp.slook or "tooltip")
end

local function stripOnly(o, id, sp)
	M.Strip(o, sp.keep, id, true, sp.paper)
end

local function paperText(o, id, sp)
	M.Color(o, id, "ptext", true)
end

local function skipSpec(sp)
	if sp.skipmod then
		local m = SUI.modules[sp.skipmod]
		if m and m.enabled then return true end
	end
	return false
end

local function onShow()
	local f = this
	if f.suiInShow then return end   -- anti-boucle avec Mod_Windows (voir Mod_Windows.onShow)
	f.suiInShow = true
	local o = f.suiOldShow
	if o then pcall(o) end
	f.suiInShow = nil
	local sp = f.suiSpec
	if sp and M.on then
		if f.suiSelf then pcall(paintBd, f.suiSelf) end
		sp.again = true
		M.Later()
	end
end

function M.SkinSpec(g, sp, f)
	local id = g.id
	if not f.suiSpec then
		f.suiSpec = sp
		if f.GetScript then
			f.suiOldShow = f:GetScript("OnShow")
			f:SetScript("OnShow", onShow)
		end
		M.nframes = M.nframes + 1
	end
	if sp.box == "child" then
		M.Backdrop(f, sp.role or "panel", id, sp.inset, true, sp.paper)
	elseif sp.box == "self" then
		M.SelfBox(f, sp, id, sp.role, sp.look)
	end
	if sp.box and sp.strip ~= false then M.Strip(f, sp.keep, id, true, sp.paper) end
	each(sp.subs, subBox, id, sp)
	each(sp.selfs, subSelf, id, sp)
	each(sp.strips, stripOnly, id, sp)
	each(sp.texts, paperText, id, sp)
	each(sp.tabs, M.Tab, id, sp)
	if sp.tabs then
		local grp = {}
		for i = 1, getn(sp.tabs) do
			local tb = frameOf(sp.tabs[i])
			if tb then
				tb.suiGroup = grp
				tinsert(grp, tb)
			end
		end
		pcall(M.FitTabs, grp)
	end
	each(sp.buttons, M.Button, id, sp)
	each(sp.checks, M.Check, id, sp)
	each(sp.sliders, M.Slider, id, sp)
	each(sp.drops, M.Drop, id, sp)
	each(sp.edits, M.Edit, id, sp)
	each(sp.scrolls, M.Scroll, id, sp)
	each(sp.slots, M.Slot, id, sp)
	each(sp.icons, M.Icon, id, sp)
	each(sp.close, M.Close, id, sp)
	if sp.auto then M.Auto(f, sp.auto, id) end
	if sp.f == "TalentFrame" then
		M.WrapTalents()
		pcall(M.TalentLight)
	end
	if sp.title then
		local fs
		if type(sp.title) == "string" then
			fs = frameOf(sp.title)
		else
			local regs = listOf(f, packRegions)
			for i = 1, getn(regs) do
				if not fs and type(regs[i]) == "table" and kindOf(regs[i]) == "FontString" then fs = regs[i] end
			end
		end
		if fs then
			M.Font(fs, id, 1)
			M.Color(fs, id, "color")
		end
	end
	if M.cfg.font == "all" and not f.suiWalked then
		f.suiWalked = true
		M.Walk(f, 3, id)
	end
end

function M.SkinGroup(g)
	for i = 1, getn(g.specs) do
		local sp = g.specs[i]
		if not skipSpec(sp) and (not sp.done or sp.again) then
			local f = frameOf(sp.f)
			if f then
				sp.again = false
				local ok, err = pcall(M.SkinSpec, g, sp, f)
				if not ok then SUI.Report("skin " .. tostring(sp.f), err) end
				sp.done = true
			end
		end
	end
end

function M.Pass()
	for i = 1, getn(M.order) do
		local g = M.groups[M.order[i]]
		if M.gstate[g.id] == "on" then M.SkinGroup(g) end
	end
end

-- Un tour complet : lit les reglages, calcule l'etat des groupes, habille ce qui manque, repeint.
-- Anti-reentrance : un Run declenche des Show/Hide de cadres habilles, leurs OnShow rappellent M.Later,
-- qui re-programmerait Run pendant qu'il tourne (stack overflow vu en jeu lors de la fermeture de l'assistant).
M.running = false
function M.Run()
	if M.running then M.later = false ; SUI.After(0.2, M.Flush, "skin.flush") ; return end
	M.running = true
	M.later = false
	local okRun, errRun = pcall(M.RunInner)
	M.running = false
	if not okRun then SUI.Report("skin run", errRun) end
end

function M.RunInner()
	M.ReadConfig()
	M.Resolve()
	for i = 1, getn(M.order) do
		local g = M.groups[M.order[i]]
		M.gstate[g.id] = M.GroupState(g)
	end
	if M.cfg.font == "all" then
		for i = 1, getn(M.order) do
			local g = M.groups[M.order[i]]
			for k = 1, getn(g.specs) do g.specs[k].again = g.specs[k].done and true or g.specs[k].again end
		end
	end
	M.Pass()
	M.Sync()
end

function M.Later()
	if M.later then return end
	M.later = true
	SUI.WhenSafe(M.Run)
end

function M.Flush()
	M.pend = false
	SUI.WhenSafe(M.Run)
end

function M.Dirty()
	if M.pend then return end
	M.pend = true
	SUI.After(0.1, M.Flush, "skin.flush")
end

-- ---------------------------------------------------------------- registre extensible
-- def : { pfui = { noms de skins pfUI }, pfmod = "module pfUI", specs = { spec... } }
-- spec : { f = "Cadre", addon = "Blizzard_X", box = "child" | "self", role, look = "dialog" | "tooltip", inset = { g, h, d, b }, strip = false,
--   paper = true (parchemin : decor traite seulement en mode sombre), title = true | "NomTexte", close/buttons/tabs/checks/sliders/drops/
--   edits/scrolls/slots/icons/subs/selfs/strips/texts = { noms }, auto = profondeur (boutons enfants), keep = { motifs de noms a garder },
--   skipmod = "module ShikiUI qui s'en charge" }
function M.AddGroup(id, def)
	if type(id) ~= "string" or M.groups[id] then return false end
	def.id = id
	def.specs = def.specs or {}
	M.groups[id] = def
	tinsert(M.order, id)
	for i = 1, getn(def.specs) do
		if def.specs[i].addon then M.waiting[def.specs[i].addon] = true end
	end
	return true
end

function M.AddSpec(id, sp)
	local g = M.groups[id]
	if not g then return false end
	tinsert(g.specs, sp)
	if sp.addon then M.waiting[sp.addon] = true end
	M.Later()
	return true
end

-- ---------------------------------------------------------------- crochets (inertes si le module est coupe)
function M.OnAddon(ev, name)
	if M.on and M.waiting[name] then M.Later() end
end

function M.OnWorld()
	if M.on then M.Later() end
end

local function tabHook(tab)
	local r = tab and tab.suiBd
	if r and r.tab and M.on and recOn(r) then
		r.sel = (not tab:IsEnabled()) and true or false
		paintBd(r)
	end
	if tab and tab.suiGroup and M.on then pcall(M.FitTabs, tab.suiGroup) end
end

function M.Wrap(name)
	local orig = getglobal(name)
	if type(orig) ~= "function" or M.wrapped[name] then return end
	M.wrapped[name] = true
	setglobal(name, function(a, b)
		-- l'original (code Blizzard/FrameXML) peut lever une erreur (ex. Cooldown.lua a l'ouverture de
		-- banque) : elle ne doit jamais remonter dans notre dispatcher ni dans le journal
		local ok, r1, r2 = pcall(orig, a, b)
		if M.on then pcall(tabHook, a) end
		if not ok then return nil end
		return r1, r2
	end)
end

-- Apparence : changement de style / d'accent (T.Restyle -> T.RefreshAccent) : repeindre tout.
function M.OnLook()
	if M.on and M.ready then M.Sync() end
end
T.OnAccent(M.OnLook)

-- Talents lisibles : Blizzard assombrit les icones des talents sans point (gris) et le fond sombre du style les rend presque invisibles.
-- Apres chaque TalentFrame_Update : icone des talents appris a pleine lumiere, celle des autres a 85 % (jamais plus sombre).
function M.TalentLight()
	if not M.on or not C.Get("skin.talentlight") then return end
	local tf = getglobal("TalentFrame")
	if not tf or not tf.IsShown or not tf:IsShown() or type(GetTalentInfo) ~= "function" then return end
	local tab = tf.selectedTab or 1
	local n = (GetNumTalents and GetNumTalents(tab)) or 0
	for i = 1, n do
		local _, _, _, _, rank = GetTalentInfo(tab, i)
		local ic = getglobal("TalentFrameTalent" .. i .. "IconTexture")
		if ic and ic.SetVertexColor then
			local w = T.c.text
			local k = (rank or 0) > 0 and 1 or 0.95
			ic:SetVertexColor(w[1] * k, w[2] * k, w[3] * k)
			if ic.SetAlpha then ic:SetAlpha(1) end
		end
	end
end

function M.WrapTalents()
	local orig = getglobal("TalentFrame_Update")
	if type(orig) ~= "function" or M.wrapped.talents then return end
	M.wrapped.talents = true
	setglobal("TalentFrame_Update", function(a, b)
		local r1, r2 = orig(a, b)
		pcall(M.TalentLight)
		return r1, r2
	end)
end

function M.OnKey(key, value)
	if M.on then M.Dirty() end
	if key == "skin.talentlight" then
		local up = getglobal("TalentFrame_Update")
		local tf = getglobal("TalentFrame")
		if type(up) == "function" and tf and tf.IsShown and tf:IsShown() then pcall(up) end
	end
end

function M.Enable()
	M.on = true
	M.ready = true
	SUI.On("ADDON_LOADED", M.OnAddon)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnWorld)
	if not M.watching then
		M.watching = true
		C.Watch("skin.", M.OnKey)
	end
	M.Wrap("PanelTemplates_SelectTab")
	M.Wrap("PanelTemplates_DeselectTab")
	M.later = true
	SUI.WhenSafe(M.Run)
end

function M.Disable()
	M.on = false
	SUI.Off("ADDON_LOADED", M.OnAddon)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnWorld)
	M.later = true
	SUI.WhenSafe(M.Run)
end

-- ---------------------------------------------------------------- etat et commande
function M.Info(id)
	local g = M.groups[id]
	if not g then return nil end
	local done = 0
	for i = 1, getn(g.specs) do
		if g.specs[i].done then done = done + 1 end
	end
	local st = M.gstate[id] or "off"
	if st == "on" and done == 0 then st = "wait" end
	return st, done, getn(g.specs)
end

function M.Status()
	local n = 0
	for i = 1, getn(M.order) do
		local st = M.Info(M.order[i])
		if st == "on" then n = n + 1 end
	end
	return n, M.nframes
end

function M.Command(rest)
	if rest == "refresh" then
		for i = 1, getn(M.order) do
			local g = M.groups[M.order[i]]
			for k = 1, getn(g.specs) do g.specs[k].again = true end
		end
		M.Run()
	end
	local n, frames = M.Status()
	SUI.Print(L("msg.skin.head", n, frames))
	for i = 1, getn(M.order) do
		local id = M.order[i]
		local st, done, total = M.Info(id)
		SUI.Print(L("msg.skin.line", L("opt.skin.f." .. id), L("msg.skin.state." .. st), done, total))
	end
end

-- ---------------------------------------------------------------- les groupes de cadres
local PANEL = { 10, 10, 31, 72 }

M.AddGroup("menu", { pfui = { "Game Menu" }, specs = {
	{ f = "GameMenuFrame", box = "self", look = "dialog", title = true, auto = 1, buttons = { "ShikiUI_GameMenuButton" } },
} })

M.AddGroup("options", { pfui = { "Options - Video", "Options - Sound", "Options - Interface", "Options - New" }, specs = {
	{ f = "OptionsFrame", box = "self", look = "dialog", title = true, auto = 2, flat = true, checks = seq("OptionsFrameCheckButton", 24),
		sliders = seq("OptionsFrameSlider", 12), drops = { "OptionsFrameResolutionDropDown", "OptionsFrameRefreshDropDown",
			"OptionsFrameMultiSampleDropDown" },
		selfs = { "OptionsFrameDisplay", "OptionsFrameWorldAppearance", "OptionsFrameBrightness", "OptionsFramePixelShaders",
			"OptionsFrameMiscellaneous" }, subs = { "OptionsFrameCategoryList", "OptionsFrameContent" },
		scrolls = { "OptionsFrameCategoryListScrollFrameScrollBar", "OptionsFrameContentScrollFrameScrollBar" } },
	{ f = "SoundOptionsFrame", box = "self", look = "dialog", title = true, auto = 2, checks = seq("SoundOptionsFrameCheckButton", 16),
		sliders = seq("SoundOptionsFrameSlider", 10) },
	{ f = "UIOptionsFrame", box = "self", look = "dialog", title = true, auto = 2, checks = seq("UIOptionsFrameCheckButton", 30),
		sliders = seq("UIOptionsFrameSlider", 12), drops = { "UIOptionsFrameCameraDropDown", "UIOptionsFrameClickCameraDropDown",
			"UIOptionsFrameCombatTextDropDown", "UIOptionsFrameTargetofTargetDropDown" },
		tabs = { "UIOptionsFrameTab1", "UIOptionsFrameTab2" } },
	{ f = "InterfaceOptionsFrame", box = "self", look = "dialog", title = true, auto = 2, tabs = { "InterfaceOptionsFrameTab1",
		"InterfaceOptionsFrameTab2" } },
} })

M.AddGroup("addons", { specs = {
	{ f = "AddonList", box = "self", look = "dialog", title = true, auto = 2, checks = seq("AddonListEntry", 30, "Enabled"),
		scrolls = { "AddonListScrollFrameScrollBar" }, drops = { "AddonCharacterDropDown", "AddonListCharacterDropDown" } },
} })

M.AddGroup("keybind", { pfui = { "KeyBindings" }, specs = {
	{ f = "KeyBindingFrame", addon = "Blizzard_BindingUI", box = "self", look = "dialog", title = true, auto = 2,
		checks = { "KeyBindingFrameCharacterButton" }, scrolls = { "KeyBindingFrameScrollFrameScrollBar" },
		buttons = cat(seq("KeyBindingFrameBinding", 30, "Key1Button"), seq("KeyBindingFrameBinding", 30, "Key2Button")) },
} })

M.AddGroup("macro", { pfui = { "Macro" }, specs = {
	{ f = "MacroFrame", addon = "Blizzard_MacroUI", box = "child", inset = { 10, 10, 32, 52 }, title = true,
		close = { "MacroFrameCloseButton" }, tabs = { "MacroFrameTab1", "MacroFrameTab2" },
		buttons = { "MacroEditButton", "MacroDeleteButton", "MacroNewButton", "MacroExitButton", "MacroSaveButton", "MacroCancelButton" },
		scrolls = { "MacroFrameScrollFrameScrollBar" }, slots = cat(seq("MacroButton", 18), { "MacroFrameSelectedMacroButton" }) },
	{ f = "MacroPopupFrame", addon = "Blizzard_MacroUI", box = "self", look = "dialog", buttons = { "MacroPopupOkayButton",
		"MacroPopupCancelButton" }, edits = { "MacroPopupEditBox" }, scrolls = { "MacroPopupScrollFrameScrollBar" },
		slots = seq("MacroPopupButton", 20) },
} })

M.AddGroup("character", { pfui = { "Character" }, specs = {
	{ f = "CharacterFrame", box = "child", inset = { 10, 10, 30, 72 }, title = "CharacterNameText", close = { "CharacterFrameCloseButton" },
		tabs = seq("CharacterFrameTab", 5), strips = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame" },
		slots = slotNames("Character"), scrolls = { "ReputationListScrollFrameScrollBar", "SkillListScrollFrameScrollBar",
			"SkillDetailScrollFrameScrollBar" }, drops = { "PlayerStatFrameLeftDropDown", "PlayerStatFrameRightDropDown" } },
	{ f = "ReputationDetailFrame", box = "self", look = "dialog", close = { "ReputationDetailCloseButton" },
		checks = { "ReputationDetailInactiveCheckBox", "ReputationDetailAtWarCheckBox", "ReputationDetailMainScreenCheckBox" } },
} })

M.AddGroup("spellbook", { pfui = { "Spellbook" }, specs = {
	{ f = "SpellBookFrame", box = "child", inset = { 12, 12, 30, 72 }, title = "SpellBookTitleText", close = { "SpellBookCloseButton" },
		tabs = seq("SpellBookFrameTabButton", 3), slots = seq("SpellButton", 12), icons = seq("SpellBookSkillLineTab", 8) },
} })

M.AddGroup("talents", { pfui = { "Talents" }, specs = {
	{ f = "TalentFrame", addon = "Blizzard_TalentUI", box = "child", inset = { 10, 10, 32, 72 }, title = "TalentFrameTitleText",
		close = { "TalentFrameCloseButton" }, tabs = seq("TalentFrameTab", 3), buttons = { "TalentFrameCancelButton" },
		scrolls = { "TalentFrameScrollFrameScrollBar" }, strips = { "TalentFrameScrollFrame" } },
} })

M.AddGroup("questlog", { pfui = { "Quest Log" }, specs = {
	{ f = "QuestLogFrame", paper = true, box = "child", inset = PANEL, title = "QuestLogTitleText", close = { "QuestLogFrameCloseButton" },
		buttons = { "QuestLogFrameAbandonButton", "QuestFramePushQuestButton", "QuestFrameExitButton", "QuestLogFrameCancelButton" },
		scrolls = { "QuestLogListScrollFrameScrollBar", "QuestLogDetailScrollFrameScrollBar" },
		strips = { "QuestLogDetailScrollFrame", "QuestLogListScrollFrame", "EmptyQuestLogFrame" },
		texts = { "QuestLogQuestTitle", "QuestLogObjectivesText", "QuestLogQuestDescription", "QuestLogDescriptionTitle",
			"QuestLogRewardTitleText", "QuestLogItemChooseText", "QuestLogItemReceiveText", "QuestLogRequiredMoneyText" } },
} })

M.AddGroup("npc", { pfui = { "Gossip and Quest" }, specs = {
	{ f = "GossipFrame", paper = true, box = "child", inset = { 12, 18, 28, 66 }, close = { "GossipFrameCloseButton" },
		buttons = { "GossipFrameGreetingGoodbyeButton" }, scrolls = { "GossipGreetingScrollFrameScrollBar" },
		texts = { "GossipGreetingText", "GossipFrameNpcNameText" } },
	{ f = "QuestFrame", paper = true, box = "child", inset = { 12, 18, 28, 66 }, close = { "QuestFrameCloseButton" },
		buttons = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton", "QuestFrameGoodbyeButton",
			"QuestFrameCompleteQuestButton", "QuestFrameCancelButton", "QuestFrameGreetingGoodbyeButton" },
		scrolls = { "QuestDetailScrollFrameScrollBar", "QuestProgressScrollFrameScrollBar", "QuestRewardScrollFrameScrollBar",
			"QuestGreetingScrollFrameScrollBar" },
		texts = { "QuestTitleText", "QuestDescription", "QuestObjectiveText", "QuestDetailObjectiveTitleText", "QuestRewardTitleText",
			"QuestRewardText", "QuestProgressTitleText", "QuestProgressText", "QuestProgressRequiredItemsText",
			"QuestRewardItemChooseText", "QuestRewardItemReceiveText", "QuestRewardRewardTitleText" } },
} })

M.AddGroup("merchant", { pfui = { "Merchant" }, specs = {
	{ f = "MerchantFrame", box = "child", inset = { 10, 10, 32, 58 }, title = "MerchantNameText", close = { "MerchantFrameCloseButton" },
		tabs = { "MerchantFrameTab1", "MerchantFrameTab2" }, slots = cat(seq("MerchantItem", 12, "ItemButton"),
			{ "MerchantBuyBackItemItemButton" }), strips = cat(seq("MerchantItem", 12), { "MerchantBuyBackItem" }),
		icons = { "MerchantRepairItemButton", "MerchantRepairAllButton", "MerchantGuildBankRepairButton" } },
} })

M.AddGroup("trade", { pfui = { "Trade" }, specs = {
	{ f = "TradeFrame", box = "child", inset = PANEL, close = { "TradeFrameCloseButton" },
		buttons = { "TradeFrameTradeButton", "TradeFrameCancelButton" },
		slots = cat(seq("TradePlayerItem", 7, "ItemButton"), seq("TradeRecipientItem", 7, "ItemButton")),
		strips = cat(seq("TradePlayerItem", 7), seq("TradeRecipientItem", 7)) },
} })

M.AddGroup("trainer", { pfui = { "Trainer" }, specs = {
	{ f = "ClassTrainerFrame", addon = "Blizzard_TrainerUI", box = "child", inset = PANEL, close = { "ClassTrainerFrameCloseButton" },
		buttons = { "ClassTrainerTrainButton", "ClassTrainerCancelButton" }, drops = { "ClassTrainerFrameFilterDropDown" },
		scrolls = { "ClassTrainerListScrollFrameScrollBar", "ClassTrainerDetailScrollFrameScrollBar" },
		strips = { "ClassTrainerListScrollFrame", "ClassTrainerDetailScrollFrame", "ClassTrainerExpandButtonFrame" } },
} })

M.AddGroup("professions", { pfui = { "Profession" }, specs = {
	{ f = "TradeSkillFrame", addon = "Blizzard_TradeSkillUI", box = "child", inset = PANEL, close = { "TradeSkillFrameCloseButton" },
		buttons = { "TradeSkillCreateButton", "TradeSkillCancelButton", "TradeSkillCreateAllButton" },
		checks = { "TradeSkillFrameAvailableFilterCheckButton" }, edits = { "TradeSkillInputBox" },
		drops = { "TradeSkillSubClassDropDown", "TradeSkillInvSlotDropDown" },
		scrolls = { "TradeSkillListScrollFrameScrollBar", "TradeSkillDetailScrollFrameScrollBar" },
		strips = { "TradeSkillListScrollFrame", "TradeSkillDetailScrollFrame", "TradeSkillExpandButtonFrame" } },
	{ f = "CraftFrame", addon = "Blizzard_CraftUI", box = "child", inset = PANEL, close = { "CraftFrameCloseButton" },
		buttons = { "CraftCreateButton", "CraftCancelButton" }, checks = { "CraftFrameAvailableFilterCheckButton" },
		drops = { "CraftFrameFilterDropDown" }, scrolls = { "CraftListScrollFrameScrollBar", "CraftDetailScrollFrameScrollBar" },
		strips = { "CraftListScrollFrame", "CraftDetailScrollFrame", "CraftExpandButtonFrame" } },
} })

M.AddGroup("social", { pfui = { "Friends" }, specs = {
	{ f = "FriendsFrame", box = "child", inset = { 8, 10, 32, 74 }, title = "FriendsFrameTitleText", close = { "FriendsFrameCloseButton" },
		tabs = seq("FriendsFrameTab", 5), strips = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "GuildFrame", "ChannelFrame",
			"RaidFrame" }, auto = 3, edits = { "WhoFrameEditBox" }, drops = { "WhoFrameDropDown" },
		scrolls = { "FriendsFrameFriendsScrollFrameScrollBar", "WhoListScrollFrameScrollBar", "GuildListScrollFrameScrollBar",
			"ChannelListScrollFrameScrollBar", "ChannelRosterScrollFrameScrollBar" } },
	{ f = "AddFriendFrame", box = "self", look = "dialog", auto = 1, edits = { "AddFriendNameEditBox" } },
	{ f = "GuildMemberDetailFrame", box = "self", look = "dialog", auto = 1, close = { "GuildMemberDetailCloseButton" } },
	{ f = "GuildInfoFrame", box = "self", look = "dialog", auto = 1 },
	{ f = "GuildControlPopupFrame", box = "self", look = "dialog", auto = 1, edits = { "GuildControlPopupFrameEditBox" } },
	{ f = "RaidInfoFrame", box = "self", look = "dialog", auto = 1 },
	{ f = "ChannelFrameDaughterFrame", box = "self", look = "dialog", auto = 1 },
} })

M.AddGroup("inspect", { pfui = { "Inspect" }, specs = {
	{ f = "InspectFrame", addon = "Blizzard_InspectUI", box = "child", inset = { 10, 10, 30, 72 }, close = { "InspectFrameCloseButton" },
		tabs = seq("InspectFrameTab", 3), slots = slotNames("Inspect"), strips = { "InspectPaperDollFrame", "InspectHonorFrame" } },
} })

M.AddGroup("dressup", { pfui = { "Dress Up Frame" }, specs = {
	{ f = "DressUpFrame", box = "child", inset = PANEL, close = { "DressUpFrameCloseButton" },
		buttons = { "DressUpFrameCancelButton", "DressUpFrameResetButton" } },
} })

M.AddGroup("stable", { pfui = { "Pet Stable Master" }, specs = {
	{ f = "PetStableFrame", box = "child", inset = PANEL, close = { "PetStableFrameCloseButton" },
		buttons = { "PetStablePurchaseButton" }, slots = cat({ "PetStableCurrentPet" }, seq("PetStableStabledPet", 2)) },
} })

-- Carte des vols : la carte est l'art du cadre, on ne touche qu'au bouton de fermeture.
M.AddGroup("taxi", { pfui = { "Flightmaster" }, specs = {
	{ f = "TaxiFrame", close = { "TaxiCloseButton" } },
} })

M.AddGroup("auction", { pfui = { "Auctionhouse" }, specs = {
	{ f = "AuctionFrame", addon = "Blizzard_AuctionUI", box = "child", inset = ZERO, close = { "AuctionFrameCloseButton" },
		tabs = seq("AuctionFrameTab", 3), buttons = { "BrowseSearchButton", "BrowseBidButton", "BrowseBuyoutButton",
			"BrowseCloseButton", "BidBidButton", "BidBuyoutButton", "BidCloseButton", "AuctionsCreateAuctionButton",
			"AuctionsCancelAuctionButton", "AuctionsCloseButton" }, edits = { "BrowseName", "BrowseMinLevel", "BrowseMaxLevel" },
		drops = { "BrowseDropDown", "PriceDropDown", "DurationDropDown" }, checks = { "IsUsableCheckButton", "ShowOnPlayerCheckButton" },
		scrolls = { "BrowseScrollFrameScrollBar", "BrowseFilterScrollFrameScrollBar", "BidScrollFrameScrollBar",
			"AuctionsScrollFrameScrollBar" }, strips = { "BrowseScrollFrame", "BidScrollFrame", "AuctionsScrollFrame",
			"BrowseFilterScrollFrame" } },
} })

M.AddGroup("mail", { pfui = { "Mailbox" }, specs = {
	{ f = "MailFrame", box = "child", inset = { 12, 12, 30, 72 }, close = { "InboxCloseButton" }, tabs = { "MailFrameTab1", "MailFrameTab2" },
		buttons = { "SendMailMailButton", "SendMailCancelButton" }, edits = { "SendMailNameEditBox", "SendMailSubjectEditBox" },
		slots = cat(seq("MailItem", 7, "Button"), { "SendMailPackageButton" }), strips = { "InboxFrame", "SendMailFrame" },
		scrolls = { "SendMailScrollFrameScrollBar" } },
	{ f = "OpenMailFrame", paper = true, box = "child", inset = { 10, 10, 32, 72 }, close = { "OpenMailCloseButton" },
		buttons = { "OpenMailReplyButton", "OpenMailDeleteButton", "OpenMailCancelButton" },
		scrolls = { "OpenMailScrollFrameScrollBar" } },
} })

M.AddGroup("bank", { specs = {
	{ f = "BankFrame", box = "child", inset = PANEL, close = { "BankCloseButton" }, buttons = { "BankFramePurchaseButton" },
		slots = cat(seq("BankFrameItem", 24), seq("BankFrameBag", 6)) },
} })

M.AddGroup("loot", { pfmod = "loot", specs = {
	{ f = "LootFrame", box = "child", inset = PANEL, close = { "LootCloseButton" }, slots = seq("LootButton", 4) },
} })

M.AddGroup("pvp", { pfui = { "Battlefield", "Battlefield Score" }, specs = {
	{ f = "BattlefieldFrame", box = "child", inset = { 10, 10, 32, 72 }, close = { "BattlefieldFrameCloseButton" },
		buttons = { "BattlefieldFrameJoinButton", "BattlefieldFrameCancelButton", "BattlefieldFrameGroupJoinButton" },
		scrolls = { "BattlefieldListScrollFrameScrollBar" } },
	{ f = "WorldStateScoreFrame", box = "child", inset = { 10, 14, 112, 68 }, close = { "WorldStateScoreFrameCloseButton" },
		buttons = { "WorldStateScoreFrameLeaveButton" }, tabs = seq("WorldStateScoreFrameTab", 3),
		scrolls = { "WorldStateScoreScrollFrameScrollBar" } },
} })

M.AddGroup("lfg", { pfui = { "Turtle LFT", "Looking for group" }, specs = {
	{ f = "LFTFrame", box = "child", inset = { 14, 10, 30, 70 }, auto = 2, tabs = seq("LFTFrameTab", 2),
		drops = { "LFTFrameDropDown", "LFTNewGroupFramePresetDropDown" }, scrolls = { "LFTFrameScrollFrameScrollBar" } },
	{ f = "LFTNewGroupFrame", box = "child", inset = ZERO, auto = 2 },
	{ f = "LFTGroupReadyFrame", box = "child", inset = ZERO, auto = 2 },
	{ f = "LFTRoleCheckFrame", box = "child", inset = ZERO, auto = 2 },
} })

-- Carte du monde : seulement les controles (jamais les tuiles).
M.AddGroup("worldmap", { pfmod = "map", specs = {
	{ f = "WorldMapFrame", close = { "WorldMapFrameCloseButton" }, buttons = { "WorldMapZoomOutButton" },
		drops = { "WorldMapContinentDropDown", "WorldMapZoneDropDown", "WorldMapZoneMinimapDropDown" } },
} })

M.AddGroup("books", { pfui = { "Books" }, specs = {
	{ f = "ItemTextFrame", paper = true, box = "child", inset = { 12, 12, 30, 72 }, close = { "ItemTextCloseButton" },
		scrolls = { "ItemTextScrollFrameScrollBar" } },
} })

local popupSpecs = {}
for i = 1, 4 do
	tinsert(popupSpecs, { f = "StaticPopup" .. i, box = "self", look = "dialog", close = { "StaticPopup" .. i .. "CloseButton" },
		buttons = { "StaticPopup" .. i .. "Button1", "StaticPopup" .. i .. "Button2", "StaticPopup" .. i .. "Button3" },
		edits = { "StaticPopup" .. i .. "EditBox", "StaticPopup" .. i .. "WideEditBox" } })
end
tinsert(popupSpecs, { f = "StackSplitFrame", box = "child", inset = ZERO, buttons = { "StackSplitOkayButton", "StackSplitCancelButton" } })
tinsert(popupSpecs, { f = "CoinPickupFrame", box = "child", inset = ZERO, buttons = { "CoinPickupOkayButton", "CoinPickupCancelButton" } })
tinsert(popupSpecs, { f = "ColorPickerFrame", box = "self", look = "dialog", buttons = { "ColorPickerOkayButton", "ColorPickerCancelButton" },
	sliders = { "OpacitySliderFrame" } })
tinsert(popupSpecs, { f = "OpacityFrame", box = "self", look = "tooltip", sliders = { "OpacityFrameSlider" } })
tinsert(popupSpecs, { f = "TutorialFrame", box = "self", look = "dialog", buttons = { "TutorialFrameOkayButton" },
	checks = { "TutorialFrameCheckButton" } })
tinsert(popupSpecs, { f = "ReadyCheckFrame", box = "self", look = "dialog", buttons = { "ReadyCheckFrameYesButton", "ReadyCheckFrameNoButton" } })
M.AddGroup("popups", { pfui = { "Popup Dialogs", "Stack Split", "Coin Pickup", "Color Picker", "Opacity", "Tutorial", "Readycheck" },
	specs = popupSpecs })

M.AddGroup("chatmenu", { specs = {
	{ f = "ChatMenu", box = "self", look = "tooltip" },
	{ f = "EmoteMenu", box = "self", look = "tooltip" },
	{ f = "LanguageMenu", box = "self", look = "tooltip" },
	{ f = "VoiceMacroMenu", box = "self", look = "tooltip" },
} })

local dropSpecs = {}
for i = 1, 3 do
	tinsert(dropSpecs, { f = "DropDownList" .. i, slook = "tooltip", selfs = { "DropDownList" .. i .. "Backdrop",
		"DropDownList" .. i .. "MenuBackdrop" } })
end
M.AddGroup("dropdowns", { pfmod = "skin", specs = dropSpecs })

M.AddGroup("tooltips", { pfui = { "Tooltips" }, specs = {
	{ f = "ItemRefTooltip", box = "self", look = "tooltip", close = { "ItemRefCloseButton" } },
	{ f = "ShoppingTooltip1", box = "self", look = "tooltip" },
	{ f = "ShoppingTooltip2", box = "self", look = "tooltip" },
	{ f = "WorldMapTooltip", box = "self", look = "tooltip" },
	{ f = "GameTooltip", box = "self", look = "tooltip", skipmod = "tooltip" },
} })

M.AddGroup("misc", { pfui = { "Help", "Petition", "Guild Registrar", "Guild Tabard", "GM Survey" }, specs = {
	{ f = "HelpFrame", box = "child", inset = { 4, 4, 44, 12 }, auto = 2, close = { "HelpFrameCloseButton" },
		scrolls = { "HelpFrameOpenTicketScrollFrameScrollBar" } },
	{ f = "PetitionFrame", paper = true, box = "child", inset = { 12, 16, 28, 66 }, close = { "PetitionFrameCloseButton" },
		buttons = { "PetitionFrameSignButton", "PetitionFrameRequestButton", "PetitionFrameRenameButton", "PetitionFrameCancelButton" } },
	{ f = "GuildRegistrarFrame", paper = true, box = "child", inset = { 12, 16, 28, 66 }, close = { "GuildRegistrarFrameCloseButton" },
		buttons = { "GuildRegistrarFramePurchaseButton", "GuildRegistrarFrameCancelButton" } },
	{ f = "TabardFrame", box = "child", inset = PANEL, buttons = { "TabardFrameAcceptButton", "TabardFrameCancelButton" } },
	{ f = "GMSurveyFrame", addon = "Blizzard_GMSurveyUI", box = "self", look = "dialog", auto = 2 },
} })

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("skin", 50)

local SIMPLE = { menu = true, options = true, character = true, popups = true, dropdowns = true, tooltips = true }

local function opt(key, typ, order, def, extra)
	local o = { key = "skin." .. key, type = typ, cat = "skin", label = "opt.skin." .. key, tip = "tip.skin." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function buildOptions()
	local list = {
		{ key = "skin.hdr.look", type = "header", cat = "skin", label = "mod.skin.hdr.look", order = 5 },
		opt("contrast", "choice", 10, "normal", { choices = { "soft", "normal", "high" }, simple = true }),
		opt("alpha", "number", 20, 0.95, { min = 0.3, max = 1, step = 0.05, simple = true }),
		opt("tint", "choice", 30, "off", { choices = { "off", "border", "title", "both" }, simple = true }),
		opt("border", "choice", 40, "style", { choices = { "style", "none", "thin", "thick" } }),
		opt("corners", "choice", 50, "style", { choices = { "style", "square", "round" } }),
		opt("font", "choice", 60, "labels", { choices = { "off", "labels", "all" } }),
		opt("fontscale", "number", 70, 1, { min = 0.8, max = 1.4, step = 0.05 }),
		{ key = "skin.hdr.rules", type = "header", cat = "skin", label = "mod.skin.hdr.rules", order = 100 },
		opt("art", "bool", 110, true, { simple = true }),
		opt("parchment", "choice", 120, "keep", { choices = { "keep", "dark" } }),
		opt("yield", "bool", 130, true, { simple = true }),
		opt("talentlight", "bool", 140, true, { simple = true }),
		{ key = "skin.hdr.frames", type = "header", cat = "skin", label = "mod.skin.hdr.frames", order = 200 },
	}
	for i = 1, getn(M.order) do
		local id = M.order[i]
		tinsert(list, opt("f." .. id, "bool", 200 + i, true, { simple = SIMPLE[id] and true or nil }))
	end
	return list
end

SUI.RegisterModule("skin", {
	default = false,         -- mise au point : rien n'a ete verifie en jeu ; l'utilisateur l'active
	cost = "light",          -- une passe a l'activation, a chaque ouverture d'un cadre habille et a chaque changement de reglage
	options = buildOptions(),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("skin", M.Command, "help.skin")
