-- ShikiUI Mover : service de DEPLACEMENT des cadres (mode "Deplacer l'interface").
--   SUI.Mover.Register(id, frame, { label, point, x, y, scale, group, preview, ghost, always })  declare un cadre deplacable ;
--   SUI.Layout.Register(...) (Theme.lua) appelle SUI.Mover.Adopt : TOUT cadre enregistre dans le Layout est donc deplacable, avec un nom.
--   Enter() / Exit(garder) / Toggle() ; Reset(id|"all") ; SetShowAll(on) ; Preview(id, on).
-- Pendant le mode : un voile, une POIGNEE NOMMEE sur chaque cadre (jamais de carre anonyme : un cadre vide garde une poignee minimale avec
-- son nom), glisser pour deplacer (aimantation aux bords / centres / milieux des autres cadres et de l'ecran, guides visibles, Alt = sans
-- aimant, grille facultative), fleches = 1 px (Maj = 10), molette = echelle, clic = panneau de position precise (X, Y, echelle, aligner
-- sur..., symetrique, centrer), clic droit = reinitialiser, bandeau (Verrouiller et quitter, Grille, Montrer tout, Tout reinitialiser,
-- Annuler, Joueur / Cible symetriques), Echap = quitter. "Montrer tout" dessine de FAUX cadres d'exemple (groupe / raid 5-10-25-40,
-- cibles, boss, plaques) pour placer sans etre en instance.
-- Positions : profil.pos[id] (mode Normal) ou profil.pos[id.."|raid"] (mode Raid) = { l, b, s } en unites d'UIParent (+ facteur d'echelle s).
-- LIENS (voir Layouts.lua) : deplacer un parent entraine ses enfants (ils gardent leur decalage) ; glisser un cadre vers le cote d'un autre fait
-- briller ce cote et PROPOSE le lien au relachement ; un symbole o-o entre deux poignees liees detache d'un clic ; clic droit = "Accroche a : ...".
-- ui.locked reste synchronise : Enter() = faux, Exit() = vrai. Rien ne tourne hors du mode (OnUpdate seulement pendant un glissement).
-- NON VERIFIE EN JEU : GetCursorPosition / GetEffectiveScale, EnableKeyboard (les touches sont-elles consommees ?), SetFrameStrata des
-- poignees, GetLeft/GetBottom d'un cadre cache, OnMouseUp hors de la poignee, UISpecialFrames avec un clavier capte.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config
local Layout = SUI.Layout

local getn, tinsert = table.getn, table.insert
local floor, abs = math.floor, math.abs

-- Garde d'ordre : SUI.Layout (Theme.lua) est requis par Adopt/Register.
if not SUI.Layout then error("ShikiUI: Theme.lua doit etre charge avant Mover.lua (verifie l'ordre du .toc)", 0) end

local M = {}
SUI.Mover = M

M.items = {}            -- id -> { id, frame, label, group, scaleOk, preview, ghost, always, handle }
M.order = {}
M.active = false
M.showAll = false
M.MINW, M.MINH = 86, 34
M.SNAP = 6
M.STEP, M.STEPBIG = 1, 10
M.ALWAYS = { ["unit.player"] = true, ["unit.target"] = true, ["unit.targettarget"] = true }
M.PARTNER = { ["unit.player"] = "unit.target", ["unit.target"] = "unit.player" }
M.RAIDSIZES = { 5, 10, 25, 40 }
M.raidIdx = 3
M.FRAC = { 1, 0.8, 0.55, 0.9, 0.35, 0.7 }       -- vie factice des cellules d'exemple
M.alignMode = "y"
M.alignOff = 0
M.multi = {}            -- selection multiple (id -> true) pour egaliser les ecarts
M.ROWS = 6
M.GHOSTW, M.GHOSTH = 160, 60     -- taille maximale d'un faux cadre d'exemple
M.GHOSTA = 0.35                  -- opacite des faux cadres d'exemple

SUI.RegisterOption({ key = "mover.snap", type = "bool", cat = "layout", label = "opt.mover.snap", tip = "tip.mover.snap", default = true, order = 20 })
SUI.RegisterOption({ key = "mover.gaps", type = "bool", cat = "layout", label = "opt.mover.gaps", tip = "tip.mover.gaps", default = true, order = 25 })
SUI.RegisterOption({ key = "mover.grid", type = "bool", cat = "layout", label = "opt.mover.grid", tip = "tip.mover.grid", default = false, order = 30 })
SUI.RegisterOption({ key = "mover.gridsize", type = "number", cat = "layout", label = "opt.mover.gridsize", tip = "tip.mover.gridsize",
	min = 20, max = 100, step = 10, default = 40, order = 40 })

-- ---------------------------------------------------------------- enregistrement et noms
local function has(key)
	return SUI.locales[SUI.locale][key] ~= nil or SUI.locales.fr[key] ~= nil
end

local function cap(s)
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- Nom lisible d'un cadre (jamais vide) : libelle donne a Register, sinon texte "mod.mover.n.<id>", sinon "<famille> <numero>", sinon l'identifiant.
function M.Label(id)
	local rec = M.items[id]
	if rec and rec.label and rec.label ~= "" then
		if has(rec.label) then return L(rec.label) end
		return rec.label
	end
	local key = "mod.mover.n." .. tostring(id)
	if has(key) then return L(key) end
	local _, _, base, num = string.find(tostring(id), "^(.-)(%d+)$")
	if base and base ~= "" and has("mod.mover.n." .. base) then return L("mod.mover.n." .. base) .. " " .. num end
	local _, _, pre = string.find(tostring(id), "^([^.]+)%.")
	if pre and has("mod.mover.n." .. pre) then return L("mod.mover.n." .. pre) .. " (" .. string.sub(id, string.len(pre) + 2) .. ")" end
	if id == nil or id == "" then return "?" end
	return cap(tostring(id))
end

local function newRec(id)
	local rec = { id = id, scaleOk = true }
	M.items[id] = rec
	tinsert(M.order, id)
	return rec
end

-- Appele par Layout.Register : le cadre est deja positionne par le Layout.
function M.Adopt(id, frame)
	local rec = M.items[id] or newRec(id)
	rec.frame = frame
	if M.active and not SUI.InCombat() then M.Sync() end
end

function M.Register(id, frame, opts)
	if type(id) ~= "string" or id == "" or string.len(id) > 32 or type(frame) ~= "table" or frame == UIParent then return false end
	opts = opts or {}
	local it = Layout.items[id]
	if not it or it.frame ~= frame then Layout.Register(frame, id, opts.point, opts.x, opts.y) end
	local rec = M.items[id] or newRec(id)
	rec.frame = frame
	if opts.label then rec.label = opts.label end
	if opts.group then rec.group = opts.group end
	if opts.scale ~= nil then rec.scaleOk = opts.scale and true or false end
	if opts.preview then rec.preview = opts.preview end
	if opts.ghost then rec.ghost = opts.ghost end
	if opts.sync then rec.sync = opts.sync end
	if opts.apply then rec.apply = opts.apply end
	if opts.always ~= nil then rec.always = opts.always and true or false end
	if M.active and not SUI.InCombat() then M.Sync() end
	return true
end

-- Hook d'apercu d'un module : fn(on) montre / cache ses faux cadres.
function M.Preview(id, on)
	local rec = M.items[id]
	if not rec or not rec.preview then return false end
	local ok, err = pcall(rec.preview, on and true or false)
	if not ok then SUI.Report("mover preview " .. id, err) end
	return ok
end

-- ---------------------------------------------------------------- geometrie (unites d'UIParent)
function M.Cursor()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	if not s or s <= 0 then s = 1 end
	return x / s, y / s
end

-- Coin bas-gauche du cadre (unites d'UIParent). Cadre cache ou jamais place (GetLeft nul) : position enregistree, sinon position par defaut
-- deduite de son ancrage ; c'est ce qui garde une poignee deplacable pour les cadres caches ou vides.
function M.Visible(f)
	if f.IsVisible then return f:IsVisible() and true or false end
	return f:IsShown() and true or false
end

function M.FrameLB(rec)
	local f = rec.frame
	local sc = f:GetScale() or 1
	local l, b = f:GetLeft(), f:GetBottom()
	if l and b then return l * sc, b * sc, sc end
	local sl, sb = C.GetPos(Layout.ReadKey(rec.id))
	if sl then return sl * sc, sb * sc, sc end   -- meme convention que la branche ci-dessus (coordonees a l'echelle du cadre)
	local it = Layout.items[rec.id]
	if not it then return nil end
	local ax, ay = M.AnchorFrac(it.point)
	local fw, fh = (f:GetWidth() or 0) * sc, (f:GetHeight() or 0) * sc
	return UIParent:GetWidth() * ax + (it.x or 0) * sc - fw * ax, UIParent:GetHeight() * ay + (it.y or 0) * sc - fh * ay, sc
end

-- Description des faux cadres d'un identifiant : { cols, rows, cw, ch } (cellules de groupe) ou nil (un seul cadre).
function M.GridSpec(prefix, n, defw, defh)
	local cw, ch = defw, defh
	if C.defaults[prefix .. "width"] ~= nil then cw = C.Get(prefix .. "width") end
	if C.defaults[prefix .. "height"] ~= nil then ch = C.Get(prefix .. "height") end
	local cols = 1
	if n > 5 then cols = floor((n + 4) / 5) end
	local rows = n
	if rows > 5 then rows = 5 end
	return { n = n, cols = cols, rows = rows, cw = cw, ch = ch }
end

function M.GhostSpec(rec)
	local id = rec.id
	if rec.ghost then return rec.ghost end
	if id == "group" then return M.GridSpec("group.", 5, 100, 30) end
	if id == "group.enemies" then return M.GridSpec("group.enemy", 4, 100, 30) end
	if id == "raid" then return M.GridSpec("raid.", M.RAIDSIZES[M.raidIdx], 80, 28) end
	if string.find(id, "^boss") then return { n = 4, cols = 1, rows = 4, cw = 170, ch = 30 } end
	return nil
end

-- Taille de la poignee (unites UIParent), puis taille reelle du cadre.
function M.RectSize(rec)
	local f = rec.frame
	local sc = f:GetScale() or 1
	local fw, fh = (f:GetWidth() or 0) * sc, (f:GetHeight() or 0) * sc
	local w, h = fw, fh
	local gs = M.GhostSpec(rec)
	if gs then
		w = gs.cols * (gs.cw + 2) * sc
		h = gs.rows * (gs.ch + 2) * sc
	elseif not M.Visible(f) then      -- faux cadre d'exemple d'un cadre cache : taille compacte fixe (jamais la taille reelle d'une fenetre de chat)
		if w > M.GHOSTW then w = M.GHOSTW end
		if h > M.GHOSTH then h = M.GHOSTH end
	end
	if w < M.MINW then w = M.MINW end
	if h < M.MINH then h = M.MINH end
	return w, h, fw, fh
end

-- Rectangle de la poignee : gauche, bas, droite, haut, largeur, hauteur, hauteur reelle du cadre.
function M.Rect(rec)
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return nil end
	local w, h, fw, fh = M.RectSize(rec)
	local top = b0 + fh
	return l0, top - h, l0 + w, top, w, h, fh
end

function M.AnchorFrac(p)
	local ax, ay = 0.5, 0.5
	p = p or "CENTER"
	if string.find(p, "LEFT") then ax = 0 elseif string.find(p, "RIGHT") then ax = 1 end
	if string.find(p, "TOP") then ay = 1 elseif string.find(p, "BOTTOM") then ay = 0 end
	return ax, ay
end

-- Decalage (px, py) du point d'ancrage du cadre par rapport au meme point de l'ecran.
function M.Offsets(rec)
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return 0, 0 end
	local _, _, fw, fh = M.RectSize(rec)
	local it = Layout.items[rec.id]
	local ax, ay = M.AnchorFrac(it and it.point)
	return floor(l0 + fw * ax - UIParent:GetWidth() * ax + 0.5), floor(b0 + fh * ay - UIParent:GetHeight() * ay + 0.5)
end

function M.FromOffsets(rec, px, py)
	local _, _, fw, fh = M.RectSize(rec)
	local it = Layout.items[rec.id]
	local ax, ay = M.AnchorFrac(it and it.point)
	return px + UIParent:GetWidth() * ax - fw * ax, py + UIParent:GetHeight() * ay - fh * ay
end

function M.ScaleOf(rec)
	local _, _, s = C.GetPos(Layout.ReadKey(rec.id))
	return s or 1
end

-- Deplacement en direct (sans sauvegarde), puis enregistrement.
function M.Move(rec, nl, nb)
	local f = rec.frame
	local sc = f:GetScale() or 1
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", nl / sc, nb / sc)
end

-- Deplacement rapide, SANS entrer dans le mode deplacement : cliquer-glisser sur le cadre (ou sur ses boutons) le deplace, la position est
-- enregistree comme celle du mode deplacement (annulable, liens et echelle respectes). Utilise par les cadres que l'on bouge souvent
-- (suivi des quetes...). Refuse en combat. enabled : fonction optionnelle (faux = pas de glisser).
function M.QuickDrag(frame, id, enabled, extra)
	if not frame or not id then return end
	local function start()
		if SUI.InCombat() or (enabled and not enabled()) then return end
		frame:StartMoving()
		frame.quickMoving = true
	end
	local function stop()
		if not frame.quickMoving then return end
		frame.quickMoving = false
		frame:StopMovingOrSizing()
		local rec = M.items[id]
		if not rec then return end
		local l, b = M.FrameLB(rec)
		if l and b then M.Commit(rec, l, b) end
	end
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", start)
	frame:SetScript("OnDragStop", stop)
	frame.quickDragStart, frame.quickDragStop = start, stop
	for i = 1, extra and getn(extra) or 0 do
		local b = extra[i]
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", start)
		b:SetScript("OnDragStop", stop)
	end
end

-- Previent le module que sa poignee vient d'etre posee (il deplace alors l'element reel qu'elle represente).
local function notifyApply(rec)
	if rec.apply then
		local ok, err = pcall(rec.apply)
		if not ok then SUI.Report("mover apply " .. tostring(rec.id), err) end
	end
end

function M.Commit(rec, nl, nb, s)
	if s == nil then s = M.ScaleOf(rec) end
	M.PushUndo(rec.id)
	Layout.ClearPreview(rec.id)
	local p, side, ldx, ldy = Layout.LinkedParent(rec.id)
	local cl, cb
	if p then cl, cb = Layout.Rect(rec.id) end         -- place actuelle, AVANT le changement d'echelle
	C.SetPos(Layout.WriteKey(rec.id), nl, nb, s)       -- place libre gardee a jour (repli si le parent disparait)
	if p then      -- cadre accroche : deplacer = changer le decalage (le lien est enregistre, meme s'il etait conseille)
		local dx, dy = ldx, ldy
		if cl and (abs(nl - cl) > 0.5 or abs(nb - cb) > 0.5) then dx, dy = Layout.LinkOffsets(rec.id, p, side, nl, nb) end
		Layout.WriteLink(rec.id, p, side, dx, dy)
	end
	Layout.Apply(rec.id)
	notifyApply(rec)
	M.Refresh(rec)
	M.RefreshKids(rec)
	M.UpdateLinks()
end

-- Les cadres accroches ont bouge avec leur parent : leurs poignees et leurs modules suivent.
function M.RefreshKids(rec)
	local kids = Layout.Descendants(rec.id)
	for i = 1, getn(kids) do
		local r = M.items[kids[i]]
		if r then
			notifyApply(r)
			if r.handle then M.Refresh(r) end
		end
	end
end

function M.PlaceCenter(rec, cx, cy)
	local w, h, _, fh = M.RectSize(rec)
	M.Commit(rec, cx - w / 2, cy + h / 2 - fh)
end

function M.Nudge(dx, dy)
	local rec = M.sel or M.hover
	if not rec or not rec.handle or not rec.handle:IsShown() then return false end
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return false end
	local step = M.STEP
	if IsShiftKeyDown() then step = M.STEPBIG end
	M.Commit(rec, l0 + dx * step, b0 + dy * step)
	return true
end

-- ---------------------------------------------------------------- remise a zero, annulation
local function copyPos(src)
	local out = {}
	for k, e in pairs(src) do
		if type(e) == "table" then out[k] = { l = e.l, b = e.b, s = e.s } end
	end
	return out
end

function M.Reset(id)
	if M.active then M.undoId = nil; M.PushUndo(nil) end
	if id == nil or id == "all" then
		C.ResetPositions()
		C.cur.layout = nil
		Layout.ApplyAll()
		M.Sync()
		return true
	end
	if not M.items[id] then return false end
	Layout.ClearLink(id)            -- le lien conseille revient
	C.ClearPosAll(id)
	Layout.Apply(id)
	C.Notify("pos", nil)
	M.Sync()
	return true
end

-- Annulation pas a pas (Ctrl+Z) : un instantane des positions est pris AVANT chaque geste (une rafale de fleches ou un glisser = un geste).
M.UNDOMAX = 20
M.undo = {}
M.undoAt, M.undoId = 0, nil
function M.PushUndo(id)
	local now = GetTime()
	if id and id == M.undoId and now - M.undoAt < 0.8 then
		M.undoAt = now
		return
	end
	M.undoId, M.undoAt = id, now
	local u = M.undo
	if getn(u) >= M.UNDOMAX then table.remove(u, 1) end
	tinsert(u, { pos = copyPos(C.cur.pos), layout = C.cur.layout })
end

function M.Undo()
	local u = M.undo
	local n = getn(u)
	if n == 0 then return false end
	local e = u[n]
	table.remove(u, n)
	M.undoId = nil
	C.cur.pos = e.pos
	C.cur.layout = e.layout
	Layout.ApplyAll()
	C.Notify("pos", nil)
	M.Sync()
	return true
end

function M.Restore()
	if not M.snap then return end
	C.cur.pos = copyPos(M.snap.pos)
	C.cur.layout = M.snap.layout
	Layout.ApplyAll()
	C.Notify("pos", nil)
end

-- ---------------------------------------------------------------- poignees
-- Niveau de la poignee : decroissant avec la surface (les petites poignees au-dessus des grandes, toujours atteignables) ; une poignee mise en
-- avant depuis la liste passe au-dessus de tout (sous les panneaux).
function M.HandleLevel(rec)
	local base = M.veil:GetFrameLevel()
	if M.raised == rec then return base + 27 end
	local w, h = M.RectSize(rec)
	local frac = (w * h) / (UIParent:GetWidth() * UIParent:GetHeight())
	if frac > 1 then frac = 1 end
	if frac < 0 then frac = 0 end
	return base + 5 + floor(19 * (1 - math.sqrt(frac)) + 0.5)
end

function M.ApplyLevel(rec)
	if rec.handle and M.veil then rec.handle:SetFrameLevel(M.HandleLevel(rec)) end
end

-- Clignotement (quelques battements) de la poignee d'un cadre choisi dans la liste, pour la retrouver meme recouverte.
function M.Flash(rec)
	SUI.Cancel(M.flashTask)
	M.flash = { rec = rec, n = 0, on = true }
	M.PaintHandle(rec)
	M.flashTask = SUI.After(0.25, M.FlashStep, "mover.flash")
end

function M.FlashStep()
	local f = M.flash
	M.flashTask = nil
	if not f or not M.active then return end
	f.n = f.n + 1
	f.on = not f.on
	if f.n >= 7 then M.flash = nil end
	M.PaintHandle(f.rec)
	if M.flash then M.flashTask = SUI.After(0.25, M.FlashStep, "mover.flash") end
end

function M.PaintHandle(rec)
	local h = rec.handle
	if not h then return end
	local c = T.c.panel
	local fl = M.flash and M.flash.rec == rec and M.flash.on
	local a = 0.55
	if fl then a = 0.95 elseif M.sel == rec then a = 0.8 elseif not M.Visible(rec.frame) then a = 0.3 end
	h:SetBackdropColor(c[1], c[2], c[3], a)
	if M.sel == rec or M.hover == rec or fl or (M.multi and M.multi[rec.id]) then
		local r, g, b = T.Accent()
		h:SetBackdropBorderColor(r, g, b, 1)
	else
		local bc = T.c.border
		h:SetBackdropBorderColor(bc[1], bc[2], bc[3], 1)
	end
	if h.grip then
		local ar, ag, ab = T.Accent()
		h.grip.tex:SetVertexColor(ar, ag, ab, (M.sel == rec or M.hover == rec) and 0.95 or 0.55)
	end
end

function M.Repaint()
	if not M.active then return end
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec.handle and rec.handle:IsShown() then
			M.PaintHandle(rec)
			M.DrawGhost(rec)
		end
	end
end

local function cellsFor(h, n)
	for i = 1, n do
		if not h.cells[i] then
			if SUI.InCombat() then return false end
			local c = {}
			c.bg = h:CreateTexture(nil, "BORDER")
			c.bg:SetTexture(T.tex.white)
			c.bar = h:CreateTexture(nil, "ARTWORK")
			c.bar:SetTexture(T.tex.white)
			h.cells[i] = c
		end
	end
	return true
end

-- Dessine n cellules factices (colonnes de rows cellules) de taille cw x ch dans la frame h.
function M.DrawCells(h, n, rows, cw, ch, alpha)
	alpha = alpha or 0.9
	if n > 0 and not cellsFor(h, n) then n = getn(h.cells) end
	local ar, ag, ab = T.Accent()
	for i = 1, getn(h.cells) do
		local c = h.cells[i]
		if i <= n then
			local col = floor((i - 1) / rows)
			local row = (i - 1) - col * rows
			local x, y = col * (cw + 2), row * (ch + 2)
			c.bg:ClearAllPoints()
			c.bg:SetPoint("TOPLEFT", h, "TOPLEFT", x, -y)
			c.bg:SetWidth(cw)
			c.bg:SetHeight(ch)
			c.bg:SetVertexColor(T.c.inset[1], T.c.inset[2], T.c.inset[3], alpha)
			c.bg:Show()
			c.bar:ClearAllPoints()
			c.bar:SetPoint("TOPLEFT", h, "TOPLEFT", x + 1, -y - 1)
			c.bar:SetWidth(floor((cw - 2) * M.FRAC[SUI.Mod(i - 1, 6) + 1]))
			c.bar:SetHeight(ch - 2)
			c.bar:SetVertexColor(ar, ag, ab, alpha * 0.6)
			c.bar:Show()
		else
			c.bg:Hide()
			c.bar:Hide()
		end
	end
end

function M.IsGhost(rec)
	local f = rec.frame
	if not M.Visible(f) then return true end
	return M.showAll and M.GhostSpec(rec) ~= nil
end

function M.DrawGhost(rec)
	local h = rec.handle
	if not h then return end
	if not M.IsGhost(rec) then
		M.DrawCells(h, 0, 1, 1, 1)
		return
	end
	local gs = M.GhostSpec(rec)
	if gs then
		local sc = rec.frame:GetScale() or 1
		M.DrawCells(h, gs.n, gs.rows, gs.cw * sc, gs.ch * sc, M.GHOSTA + 0.15)
	else
		local w, hh = M.RectSize(rec)
		M.DrawCells(h, 1, 1, w - 4, hh - 4, M.GHOSTA)
	end
end

function M.CoordText(rec)
	local px, py = M.Offsets(rec)
	if px ~= px or py ~= py then px, py = 0, 0 end       -- NaN (cadre sans geometrie lisible)
	return L("mod.mover.coord", floor(px + 0.5), floor(py + 0.5))
end

-- Taille, ancrage, nom, apercu et coordonnees de la poignee d'un cadre.
function M.Refresh(rec)
	local h = rec.handle
	if not h then return end
	local f = rec.frame
	local w, hh = M.RectSize(rec)
	h:SetWidth(w)
	h:SetHeight(hh)
	if h.grip then
		if rec.scaleOk then h.grip:Show() else h.grip:Hide() end
	end
	M.ApplyLevel(rec)
	h:ClearAllPoints()
	if f:GetLeft() then
		h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	else
		local l, b = M.FrameLB(rec)
		local _, _, _, fh = M.RectSize(rec)
		if l then h:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, b + fh) else h:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	end
	local name = M.Label(rec.id)
	if M.IsGhost(rec) then name = name .. " (" .. L("mod.mover.tag") .. ")" end
	local s = M.ScaleOf(rec)
	if abs(s - 1) > 0.001 then name = name .. "  x" .. string.format("%.2f", s) end
	h.label:SetWidth(w - 6)
	-- petite poignee : le nom prend toute la hauteur, les coordonnees passent dessous (sinon elles se chevauchent)
	local small = hh < 44
	if small ~= h.smallMode then
		h.smallMode = small
		h.label:ClearAllPoints()
		h.coord:ClearAllPoints()
		if small then
			h.label:SetPoint("CENTER", h, "CENTER", 0, 0)
			h.coord:SetPoint("TOP", h, "BOTTOM", 0, -1)
		else
			h.label:SetPoint("TOP", h, "TOP", 0, -4)
			h.coord:SetPoint("BOTTOM", h, "BOTTOM", 0, 3)
		end
	end
	h.label:SetHeight(small and (hh > 18 and hh - 4 or 14) or 24)
	h.label:SetText(name)
	h.coord:SetText(M.CoordText(rec))
	M.DrawGhost(rec)
	M.PaintHandle(rec)
end

local function hEnter()
	local rec = this.rec
	M.hover = rec
	M.PaintHandle(rec)
end

local function hLeave()
	local rec = this.rec
	if M.hover == rec then M.hover = nil end
	M.PaintHandle(rec)
end

-- Change l'echelle d'un cadre de delta (bornee 0,5 - 2), ou la fixe a 'fixed' si fixed ~= nil.
function M.StepScale(rec, delta, fixed)
	if not rec.scaleOk then return false end
	local s = fixed or (M.ScaleOf(rec) + delta)
	if s < 0.5 then s = 0.5 end
	if s > 2 then s = 2 end
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return false end
	M.Commit(rec, l0, b0, SUI.Round(s, 2))
	if M.panel and M.panel:IsShown() and M.sel == rec then M.FillPanel(rec) end
	return true
end

-- ---------------------------------------------------------------- coin bas-droit : redimensionner
-- Glisser le coin change l'ECHELLE du cadre (les proportions sont donc toujours gardees) ; le coin haut-gauche reste en place.
-- Maj = pas de 0,05. La taille (px et echelle) s'affiche en direct sur la poignee ; l'enregistrement a lieu au relachement (un seul pas d'annulation).
M.GRIP = 14

function M.ClampScale(s, coarse)
	if coarse then s = floor(s / 0.05 + 0.5) * 0.05 end
	if s < 0.5 then s = 0.5 end
	if s > 2 then s = 2 end
	return SUI.Round(s, 2)
end

function M.GripApply(g)
	local rec = g.rec
	rec.frame:SetScale(g.s)
	g.nb = g.top - g.fh0 * g.s / g.s0
	M.Move(rec, g.l, g.nb)
	M.Refresh(rec)
	local k = g.s / g.s0
	rec.handle.coord:SetText(L("mod.mover.size.live", floor(g.fw0 * k + 0.5), floor(g.fh0 * k + 0.5), g.s))
end

function M.GripTick()
	local g = M.rz
	local grip = this
	if not g or g.grip ~= grip then
		grip:SetScript("OnUpdate", nil)
		return
	end
	if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
		M.GripEnd(grip)
		return
	end
	local cx, cy = M.Cursor()
	local ratio = ((cx - g.l) / g.w + (g.top - cy) / g.hh) / 2
	local s = M.ClampScale(g.s0 * ratio, IsShiftKeyDown())
	if s ~= g.s then
		g.s = s
		M.GripApply(g)
	end
end

function M.GripDown()
	if arg1 ~= "LeftButton" or SUI.InCombat() or not M.active then return end
	local grip = this
	local rec = grip:GetParent().rec
	if not rec or not rec.scaleOk then return end
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return end
	local w, hh, fw, fh = M.RectSize(rec)
	local s0 = M.ScaleOf(rec)
	M.ClosePropose()
	M.CloseCtx()
	M.Select(rec, true)
	M.rz = { grip = grip, rec = rec, l = l0, w = w, hh = hh, fw0 = fw, fh0 = fh, top = b0 + fh, s0 = s0, s = s0, nb = b0 }
	grip:SetScript("OnUpdate", M.GripTick)
end

function M.GripEnd(grip)
	local g = M.rz
	grip:SetScript("OnUpdate", nil)
	if not g or g.grip ~= grip then return end
	M.rz = nil
	local rec = g.rec
	if g.s ~= g.s0 then
		M.Commit(rec, g.l, g.nb, g.s)
	else
		M.Refresh(rec)
	end
	if M.panel and M.panel:IsShown() and M.sel == rec then M.FillPanel(rec) end
end

local function hWheel()
	local rec = this.rec
	M.StepScale(rec, arg1 * 0.05)
end

local function hDown()
	local h = this
	local rec = h.rec
	if arg1 ~= "LeftButton" then return end
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return end
	local w, hh, fw, fh = M.RectSize(rec)
	local cx, cy = M.Cursor()
	local d = { h = h, rec = rec, cx = cx, cy = cy, l = l0, b = b0, w = w, hh = hh, fh = fh, moved = false }
	d.xs, d.ys = M.Targets(rec)
	d.rects = M.OtherRects(rec)
	d.hg = M.GapPairs(d.rects, 1, 3, 2, 4)      -- ecarts deja presents entre deux autres cadres (horizontal)
	d.vg = M.GapPairs(d.rects, 2, 4, 1, 3)      -- idem vertical
	M.ClosePropose()
	M.drag = d
	h:SetScript("OnUpdate", M.DragTick)
end

-- Page de reglages (categorie du menu) qui correspond a l'identifiant d'un cadre : "bars.main" -> actionbars, "unit.player" -> units...
local SETCAT = { bars = "actionbars", unit = "units", hud = "perf", party = "group", pins = "group" }
function M.SettingsCat(id)
	local _, _, pre = string.find(tostring(id), "^([^.%d]+)")
	if not pre then return nil end
	local cat = SETCAT[pre] or pre
	local mn = SUI.Menu
	if mn and mn.CatExists and mn.CatExists(cat) then return cat end
	return nil
end

local function hUp()
	local h = this
	local rec = h.rec
	if arg1 == "MiddleButton" then       -- clic molette : remet ce cadre a sa place d'origine
		M.Reset(rec.id)
		if M.panel and M.panel:IsShown() and M.sel == rec then M.FillPanel(rec) end
		SUI.Print(L("msg.mover.reset.one", M.Label(rec.id)))
		return
	end
	if arg1 == "RightButton" then        -- clic droit : menu d'actions de ce cadre (le mode deplacement reste actif)
		M.OpenCtx(rec)
		return
	end
	if arg1 ~= "LeftButton" then return end
	M.DragEnd(h)
end

-- ---------------------------------------------------------------- menu contextuel d'une poignee (clic droit)
-- Au-dessus de tout (strate TOOLTIP, niveaux explicites) : poignees, bandeau, panneaux et menu ShikiUI restent dessous. Un cadre plein ecran
-- capte les clics hors du menu (il se ferme) ; le mode deplacement n'est JAMAIS quitte par un clic droit.
M.CTXSTRATA = "TOOLTIP"
M.CTXACTS = { "pos", "link", "unlink", "reset", "minus", "plus", "norm", "opts", "lock" }
M.CTXW, M.CTXROW = 200, 24

local function ctxPick(b)
	local rec = M.ctxRec
	local act = b.act
	if not rec or not M.active or not act then
		M.CloseCtx()
		return
	end
	if act == "minus" then
		M.StepScale(rec, -0.05)
		M.FillCtx(rec)
		return
	elseif act == "plus" then
		M.StepScale(rec, 0.05)
		M.FillCtx(rec)
		return
	end
	M.CloseCtx()
	if act == "norm" then
		M.StepScale(rec, 0, 1)
	elseif act == "pos" then
		M.Select(rec)
	elseif act == "link" then
		M.OpenLinkMenu(rec)
	elseif act == "unlink" then
		M.UnlinkRec(rec)
	elseif act == "reset" then
		M.Reset(rec.id)
		if M.panel and M.panel:IsShown() and M.sel == rec then M.FillPanel(rec) end
		SUI.Print(L("msg.mover.reset.one", M.Label(rec.id)))
	elseif act == "opts" then
		M.OpenSettings(rec)
	elseif act == "lock" then
		M.Exit(true)
	end
end

-- Vrai si le menu sait ouvrir des reglages pour ce cadre (ligne precise via OpenAt, ou page de categorie).
function M.HasSettings(rec)
	local mn = SUI.Menu
	if mn and mn.OptionAnchorFor and mn.OpenAt and mn.OptionAnchorFor(rec.id) then return true end
	return M.SettingsCat(rec.id) ~= nil
end

-- Ouvre le menu ShikiUI sur la page du module SANS quitter le mode deplacement (le menu passe au-dessus des poignees : Menu.SetRaised).
function M.OpenSettings(rec)
	local mn = SUI.Menu
	if mn and mn.OpenAt and mn.OptionAnchorFor and mn.OptionAnchorFor(rec.id) then
		local found = mn.OpenAt(rec.id)         -- directement a la ligne / au groupe de reglages du cadre (ex. bars.bar3 -> barre d'action 3)
		if found then return true end
	end
	local cat = M.SettingsCat(rec.id)
	if not cat or not mn or not mn.Open or not mn.Show then
		SUI.Print(L("msg.mover.nosettings", M.Label(rec.id)))
		return false
	end
	mn.Show()
	mn.Open("cat", cat)
	return true
end

function M.BuildCtx()
	if M.ctx then return M.ctx end
	local n = getn(M.CTXACTS)
	local cv = CreateFrame("Button", "ShikiUI_MoverCtxCatcher", UIParent)
	cv:SetAllPoints(UIParent)
	cv:SetFrameStrata(M.CTXSTRATA)
	cv:SetFrameLevel(1)
	cv:EnableMouse(true)
	cv:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cv:SetScript("OnClick", function() M.CloseCtx() end)
	cv:Hide()
	M.ctxCatcher = cv
	local p = CreateFrame("Frame", "ShikiUI_MoverCtx", UIParent)
	M.ctx = p
	p:SetFrameStrata(M.CTXSTRATA)
	p:SetFrameLevel(10)
	p:SetWidth(M.CTXW)
	p:SetHeight(34 + n * M.CTXROW + 6)
	p:EnableMouse(true)
	T.Backdrop(p, T.c.bg, T.c.border)
	p:Hide()
	p.title = T.Text(p, 12, T.c.text, "LEFT", true)
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
	p.title:SetWidth(M.CTXW - 20)
	p.title:SetHeight(16)
	p.rows = {}
	for i = 1, n do
		local b = T.Button(p, "", M.CTXW - 16, 22, ctxPick)
		b:SetFrameStrata(M.CTXSTRATA)
		b:SetFrameLevel(12)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -30 - (i - 1) * M.CTXROW)
		b.act = M.CTXACTS[i]
		p.rows[i] = b
	end
	return p
end

function M.CtxText(act, rec)
	if act == "minus" or act == "plus" then
		return L("mod.mover.ctx." .. act, string.format("%.2f", M.ScaleOf(rec)))
	end
	if act == "link" or act == "unlink" then
		local p = Layout.GetLink(rec.id)
		return L("mod.mover.ctx." .. act, p and M.Label(p) or L("mod.mover.lk.none"))
	end
	return L("mod.mover.ctx." .. act)
end

function M.FillCtx(rec)
	local p = M.ctx
	if not p then return end
	p.title:SetText(M.Label(rec.id))
	for i = 1, getn(p.rows) do
		local b = p.rows[i]
		local act = b.act
		local ok = true
		if act == "minus" or act == "plus" or act == "norm" then ok = rec.scaleOk and true or false end
		if act == "opts" then ok = M.HasSettings(rec) end
		if act == "link" then ok = Layout.LinksEnabled() and Layout.items[rec.id] ~= nil end
		if act == "unlink" then ok = Layout.GetLink(rec.id) ~= nil end
		b.disabled = not ok
		b:SetAlpha(ok and 1 or 0.4)
		T.SetButtonText(b, M.CtxText(act, rec))
	end
end

function M.OpenCtx(rec)
	if not M.active or not rec or SUI.InCombat() then return false end
	local p = M.BuildCtx()
	M.ctxRec = rec
	M.FillCtx(rec)
	local cx, cy = M.Cursor()
	local w, h = p:GetWidth(), p:GetHeight()
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	if cx + w > sw - 4 then cx = sw - w - 4 end
	if cx < 4 then cx = 4 end
	if cy - h < 4 then cy = h + 4 end
	if cy > sh - 4 then cy = sh - 4 end
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx, cy)
	M.ctxCatcher:Show()
	p:Show()
	return true
end

function M.CloseCtx()
	M.ctxRec, M.lkRec = nil, nil
	if M.ctx then M.ctx:Hide() end
	if M.lkMenu then M.lkMenu:Hide() end
	if M.ctxCatcher then M.ctxCatcher:Hide() end
end

function M.NewHandle(rec)
	local h = CreateFrame("Button", nil, M.veil)
	h:SetFrameStrata("FULLSCREEN_DIALOG")
	h:SetFrameLevel(M.veil:GetFrameLevel() + 5)
	h:EnableMouse(true)
	h:EnableMouseWheel(true)
	T.Backdrop(h, T.c.panel, T.c.border)
	h.rec = rec
	h.cells = {}
	h.label = T.Text(h, 11, T.c.text, "CENTER", true)
	h.label:SetPoint("TOP", h, "TOP", 0, -4)
	h.label:SetHeight(24)
	h.coord = T.Text(h, 9, T.c.dim, "CENTER", true)
	h.coord:SetPoint("BOTTOM", h, "BOTTOM", 0, 3)
	h.coord:SetWidth(120)
	h.coord:SetHeight(12)
	local g = CreateFrame("Button", nil, h)       -- coin bas-droit : glisser pour redimensionner (voir M.GripDown)
	g:SetWidth(M.GRIP)
	g:SetHeight(M.GRIP)
	g:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
	g:EnableMouse(true)
	g.tex = g:CreateTexture(nil, "OVERLAY")
	g.tex:SetTexture(T.tex.white)
	g.tex:SetAllPoints(g)
	g:SetScript("OnMouseDown", M.GripDown)
	h.grip = g
	h:SetScript("OnEnter", hEnter)
	h:SetScript("OnLeave", hLeave)
	h:SetScript("OnMouseWheel", hWheel)
	h:SetScript("OnMouseDown", hDown)
	h:SetScript("OnMouseUp", hUp)
	return h
end

-- Met les poignees d'accord avec l'etat : un cadre visible (ou toujours montre, ou "Montrer tout") a une poignee nommee.
function M.Sync()
	if not M.active then return end
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		local f = rec.frame
		if rec.sync and f then       -- hook du module : met le cadre a jour (taille, visibilite) avant le dessin de la poignee
			local sok, serr = pcall(rec.sync)
			if not sok then SUI.Report("mover sync " .. tostring(rec.id), serr) end
		end
		local want = f and (M.ALWAYS[rec.id] or rec.always or rec.forced or M.showAll or f:IsShown()) and true or false
		if want then
			if not rec.handle and not SUI.InCombat() then rec.handle = M.NewHandle(rec) end
			if rec.handle then
				M.Refresh(rec)
				rec.handle:Show()
			end
		elseif rec.handle then
			rec.handle:Hide()
		end
	end
	M.SyncDemo()
	M.RefreshBanner()
	M.UpdateLinks()
	if M.list and M.list:IsShown() then M.FillList() end
end

-- Un cadre est hors de l'ecran (ou sans position lisible) : sa poignee serait inatteignable.
function M.OffScreen(rec)
	if not rec.frame then return true end
	local l, b, r, t = M.Rect(rec)
	if not l then return true end
	return r < 24 or t < 24 or l > UIParent:GetWidth() - 24 or b > UIParent:GetHeight() - 24
end

-- Depuis la liste : force la poignee du cadre (meme cache ou vide), le ramene au centre s'il est hors ecran, puis le selectionne.
function M.Focus(rec)
	if not M.active or not rec or not rec.frame or SUI.InCombat() then return false end
	rec.forced = true
	M.Sync()
	if M.OffScreen(rec) then M.PlaceCenter(rec, UIParent:GetWidth() / 2, UIParent:GetHeight() / 2) end
	M.Select(rec)
	M.raised = rec            -- apres Select (qui retire l'ancienne mise en avant)
	M.ApplyLevel(rec)
	M.Flash(rec)
	return true
end

-- ---------------------------------------------------------------- aimantation, guides, grille
function M.Targets(skip)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local xs, ys = { 0, sw / 2, sw }, { 0, sh / 2, sh }
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec ~= skip and rec.handle and rec.handle:IsShown() and not (skip and Layout.IsDescendant(rec.id, skip.id)) then
			local l, b, r, t = M.Rect(rec)
			if l then
				tinsert(xs, l)
				tinsert(xs, (l + r) / 2)
				tinsert(xs, r)
				tinsert(ys, b)
				tinsert(ys, (b + t) / 2)
				tinsert(ys, t)
			end
		end
	end
	return xs, ys
end

function M.SnapAxis(a, b, c, list)
	local best, delta, at = M.SNAP + 0.001, nil, nil
	for i = 1, getn(list) do
		local t = list[i]
		local d = t - a
		if abs(d) < best then best, delta, at = abs(d), d, t end
		d = t - b
		if abs(d) < best then best, delta, at = abs(d), d, t end
		d = t - c
		if abs(d) < best then best, delta, at = abs(d), d, t end
	end
	return delta, at
end

function M.ShowGuides(ax, ay)
	local v, h = M.guideV, M.guideH
	if not v then return end
	-- Appele PAR IMAGE pendant le glissement : ne refaire la pose que si l'accroche a change.
	-- (M.gAx / M.gAy sont remis a nil a la fin du glissement, voir DragEnd.)
	if M.gAx == ax and M.gAy == ay and (ax or ay) then return end
	M.gAx, M.gAy = ax, ay
	if ax then
		v:ClearAllPoints()
		v:SetPoint("BOTTOMLEFT", M.veil, "BOTTOMLEFT", ax, 0)
		v:SetHeight(UIParent:GetHeight())
		v:Show()
	else
		v:Hide()
	end
	if ay then
		h:ClearAllPoints()
		h:SetPoint("BOTTOMLEFT", M.veil, "BOTTOMLEFT", 0, ay)
		h:SetWidth(UIParent:GetWidth())
		h:Show()
	else
		h:Hide()
	end
end

-- ---------------------------------------------------------------- ecarts egaux et distance au voisin
-- Rectangles { gauche, bas, droite, haut } (indices 1..4) des autres cadres visibles (meme filtre que Targets).
function M.OtherRects(skip)
	local out = {}
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec ~= skip and rec.handle and rec.handle:IsShown() and not (skip and Layout.IsDescendant(rec.id, skip.id)) then
			local l, b, r, t = M.Rect(rec)
			if l then tinsert(out, { l, b, r, t }) end
		end
	end
	return out
end

-- Ecarts deja presents entre deux rectangles qui se font face sur l'axe (mlo, mhi), avec recouvrement sur l'autre axe (clo, chi).
-- Une entree par valeur d'ecart (arrondie) : { v, m1, m2, c } (c = milieu du recouvrement).
function M.GapPairs(rects, mlo, mhi, clo, chi)
	local out, seen = {}, {}
	local n = getn(rects)
	for i = 1, n do
		local a = rects[i]
		for j = 1, n do
			local b = rects[j]
			if i ~= j then
				local v = b[mlo] - a[mhi]
				local k = floor(v + 0.5)
				if v >= 1 and not seen[k] then
					local c1, c2 = a[clo], a[chi]
					if b[clo] > c1 then c1 = b[clo] end
					if b[chi] < c2 then c2 = b[chi] end
					if c2 - c1 > 0 then
						seen[k] = true
						tinsert(out, { v = v, m1 = a[mhi], m2 = b[mlo], c = (c1 + c2) / 2 })
					end
				end
			end
		end
	end
	return out
end

-- Voisins immediats de p sur l'axe (mlo, mhi) : celui d'avant (le plus proche, recouvrement croise > 0) et celui d'apres.
function M.Neighbors(p, rects, mlo, mhi, clo, chi)
	local before, after
	for i = 1, getn(rects) do
		local r = rects[i]
		local c1, c2 = p[clo], p[chi]
		if r[clo] > c1 then c1 = r[clo] end
		if r[chi] < c2 then c2 = r[chi] end
		if c2 - c1 > 0 then
			if r[mhi] <= p[mlo] + 0.001 and (not before or r[mhi] > before[mhi]) then before = r end
			if r[mlo] >= p[mhi] - 0.001 and (not after or r[mlo] < after[mlo]) then after = r end
		end
	end
	return before, after
end

local function crossMid(p, r, clo, chi)
	local c1, c2 = p[clo], p[chi]
	if r[clo] > c1 then c1 = r[clo] end
	if r[chi] < c2 then c2 = r[chi] end
	return (c1 + c2) / 2
end

-- Aimantation d'ecart egal sur un axe. p = rectangle deplace. Renvoie le decalage a appliquer sur l'axe (ou nil) et les segments
-- a dessiner { horiz, m1, m2, c, v } : l'ecart du cadre deplace et l'ecart de reference (ou les deux ecarts egaux de part et d'autre).
function M.GapAxisSnap(p, rects, gaps, mlo, mhi, clo, chi, horiz)
	local before, after = M.Neighbors(p, rects, mlo, mhi, clo, chi)
	local size = p[mhi] - p[mlo]
	local best, bd, bg, bkind = M.SNAP + 0.001, nil, nil, nil
	for i = 1, getn(gaps) do
		local g = gaps[i]
		if before then
			local d = before[mhi] + g.v - p[mlo]
			if abs(d) < best then best, bd, bg, bkind = abs(d), d, g, "b" end
		end
		if after then
			local d = after[mlo] - g.v - size - p[mlo]
			if abs(d) < best then best, bd, bg, bkind = abs(d), d, g, "a" end
		end
	end
	if before and after then
		local free = after[mlo] - before[mhi] - size
		if free >= 2 then
			local d = before[mhi] + free / 2 - p[mlo]
			if abs(d) < best then best, bd, bg, bkind = abs(d), d, nil, "both" end
		end
	end
	if not bd then return nil, nil end
	local lo = p[mlo] + bd
	local hi = lo + size
	local segs = {}
	if bkind == "b" or bkind == "both" then
		tinsert(segs, { horiz = horiz, m1 = before[mhi], m2 = lo, c = crossMid(p, before, clo, chi), v = lo - before[mhi] })
	end
	if bkind == "a" or bkind == "both" then
		tinsert(segs, { horiz = horiz, m1 = hi, m2 = after[mlo], c = crossMid(p, after, clo, chi), v = after[mlo] - hi })
	end
	if bg then tinsert(segs, { horiz = horiz, m1 = bg.m1, m2 = bg.m2, c = bg.c, v = bg.v }) end
	return bd, segs
end

-- Distance jusqu'au voisin le plus proche (quatre directions) : un segment { horiz, m1, m2, c, v } ou nil.
function M.NearGap(p, rects)
	local best
	local axes = { { 1, 3, 2, 4, true }, { 2, 4, 1, 3, false } }
	for k = 1, 2 do
		local ax = axes[k]
		local before, after = M.Neighbors(p, rects, ax[1], ax[2], ax[3], ax[4])
		if before then
			local v = p[ax[1]] - before[ax[2]]
			if not best or v < best.v then best = { horiz = ax[5], m1 = before[ax[2]], m2 = p[ax[1]], c = crossMid(p, before, ax[3], ax[4]), v = v } end
		end
		if after then
			local v = after[ax[1]] - p[ax[2]]
			if not best or v < best.v then best = { horiz = ax[5], m1 = p[ax[2]], m2 = after[ax[1]], c = crossMid(p, after, ax[3], ax[4]), v = v } end
		end
	end
	return best
end

M.GAPSEGS = 8
-- Dessine (ou masque, segs = nil) les segments d'ecart : trait accent + valeur en pixels. Appele par image : ne repose rien si inchange.
function M.ShowGaps(segs)
	local v = M.veil
	if not v then return end
	local sig = ""
	if segs then
		for i = 1, getn(segs) do
			local s = segs[i]
			sig = sig .. (s.horiz and "h" or "v") .. floor(s.m1 + 0.5) .. "," .. floor(s.m2 + 0.5) .. "," .. floor(s.c + 0.5) .. ";"
		end
	end
	if M.gSig == sig and M.gaps then return end
	M.gSig = sig
	if not M.gaps then M.gaps = {} end
	local pool = M.gaps
	local ar, ag, ab = T.Accent()
	for i = 1, M.GAPSEGS do
		local g = pool[i]
		local s = segs and segs[i]
		if not g and s then
			g = { tex = v:CreateTexture(nil, "OVERLAY"), fs = T.Text(v, 10, T.c.text, "CENTER", true) }
			g.tex:SetTexture(T.tex.white)
			pool[i] = g
		end
		if g then
			if s then
				g.tex:SetVertexColor(ar, ag, ab, 1)
				g.tex:ClearAllPoints()
				g.fs:ClearAllPoints()
				if s.horiz then
					g.tex:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", s.m1, s.c)
					g.tex:SetWidth(s.m2 - s.m1)
					g.tex:SetHeight(1)
					g.fs:SetPoint("BOTTOM", v, "BOTTOMLEFT", (s.m1 + s.m2) / 2, s.c + 3)
				else
					g.tex:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", s.c, s.m1)
					g.tex:SetWidth(1)
					g.tex:SetHeight(s.m2 - s.m1)
					g.fs:SetPoint("LEFT", v, "BOTTOMLEFT", s.c + 4, (s.m1 + s.m2) / 2)
				end
				g.fs:SetText(string.format("%d", floor(s.v + 0.5)))
				g.tex:Show()
				g.fs:Show()
			else
				g.tex:Hide()
				g.fs:Hide()
			end
		end
	end
end

-- Position finale (nl, nb) d'un glissement en cours apres aimantation (Alt = aucune), et lignes-guides.
function M.SnapPos(d, nl, nb)
	local alt = IsAltKeyDown() and true or false
	local ax, ay, gx, gy
	local gsegs
	local useGaps = d.rects and C.Get("mover.gaps")
	if not alt then
		if C.Get("mover.snap") then
			local dx, atx = M.SnapAxis(nl, nl + d.w / 2, nl + d.w, d.xs)
			if dx then nl, ax = nl + dx, atx end
			local top = nb + d.fh
			local bot = top - d.hh
			local dy, aty = M.SnapAxis(bot, (bot + top) / 2, top, d.ys)
			if dy then nb, ay = nb + dy, aty end
			if useGaps then      -- ecarts egaux : seulement sur un axe sans accroche de bord
				if not ax then
					local ddx, sx = M.GapAxisSnap({ nl, bot, nl + d.w, top }, d.rects, d.hg, 1, 3, 2, 4, true)
					if ddx then nl, gx, gsegs = nl + ddx, true, sx end
				end
				if not ay then
					local ddy, sy = M.GapAxisSnap({ nl, bot, nl + d.w, top }, d.rects, d.vg, 2, 4, 1, 3, false)
					if ddy then
						nb, gy = nb + ddy, true
						if not gsegs then gsegs = {} end
						for i = 1, getn(sy) do tinsert(gsegs, sy[i]) end
					end
				end
			end
		end
		if C.Get("mover.grid") then
			local g = C.Get("mover.gridsize")
			if not ax and not gx then nl = floor(nl / g + 0.5) * g end
			if not ay and not gy then
				local top = nb + d.fh
				local bot = top - d.hh
				nb = nb + (floor(bot / g + 0.5) * g - bot)
			end
		end
	end
	M.ShowGuides(ax, ay)
	if useGaps then      -- sans ecart egal : distance jusqu'au voisin le plus proche (meme avec Alt)
		if not gsegs then
			local top = nb + d.fh
			local near = M.NearGap({ nl, top - d.hh, nl + d.w, top }, d.rects)
			if near then gsegs = { near } end
		end
		M.ShowGaps(gsegs)
	else
		M.ShowGaps(nil)
	end
	return nl, nb
end

function M.DragTick()
	local h = this
	local d = M.drag
	if not d or d.h ~= h then
		h:SetScript("OnUpdate", nil)
		return
	end
	if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
		M.DragEnd(h)
		return
	end
	local cx, cy = M.Cursor()
	if not d.moved then
		if abs(cx - d.cx) + abs(cy - d.cy) < 3 then return end
		d.moved = true
		M.Select(d.rec, true)
	end
	local nl, nb = M.SnapPos(d, d.l + (cx - d.cx), d.b + (cy - d.cy))
	d.nl, d.nb = nl, nb
	M.Move(d.rec, nl, nb)
	Layout.PreviewMove(d.rec.id, nl, nb)        -- les cadres accroches suivent en direct
	-- Scan des liens et marques (O(nombre de cadres), deux rectangles par lien) : toutes les 0,05 s,
	-- le suivi des cadres accroches reste lui PAR IMAGE. Le texte de coordonnees n'est reecrit qu'au changement.
	local now = GetTime()
	if not d.scanAt or now - d.scanAt >= 0.05 then
		d.scanAt = now
		d.ltgt, d.lside = M.LinkScan(d, nl, nb)
		M.ShowGlow(d.ltgt, d.lside)
		M.UpdateLinks()
		local ct = M.CoordText(d.rec)
		if ct ~= d.coordTxt then
			d.coordTxt = ct
			h.coord:SetText(ct)
		end
	end
end

-- Poignees visibles sous le point (x, y), de la plus petite a la plus grande.
function M.Under(x, y)
	local out = {}
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec.handle and rec.handle:IsShown() then
			local l, b, r, t = M.Rect(rec)
			if l and x >= l and x <= r and y >= b and y <= t then tinsert(out, { rec = rec, area = (r - l) * (t - b), n = i }) end
		end
	end
	table.sort(out, function(a, c)
		if a.area ~= c.area then return a.area < c.area end
		return a.n < c.n
	end)
	local recs = {}
	for i = 1, getn(out) do recs[i] = out[i].rec end
	return recs
end

-- Passe a la poignee suivante sous la souris (Tab, ou clic repete sur la poignee deja choisie).
function M.CycleUnder()
	if not M.active then return nil end
	local x, y = M.Cursor()
	local list = M.Under(x, y)
	local n = getn(list)
	if n == 0 then return nil end
	local idx = 0
	for i = 1, n do
		if list[i] == M.sel then idx = i end
	end
	local nxt = list[SUI.Mod(idx, n) + 1]
	M.Select(nxt)
	return nxt
end

function M.DragEnd(h)
	local d = M.drag
	h:SetScript("OnUpdate", nil)
	if not d or d.h ~= h then return end
	M.drag = nil
	M.ShowGuides(nil, nil)
	M.ShowGaps(nil)
	M.ShowGlow(nil)
	if d.moved and d.nl then
		M.Commit(d.rec, d.nl, d.nb)
		M.AfterDrop(d.rec, d.ltgt, d.lside)
		if M.panel and M.panel:IsShown() and M.sel == d.rec then M.FillPanel(d.rec) end
	else
		Layout.ClearPreview(d.rec.id)
		local cx, cy = M.Cursor()
		if M.sel == d.rec and getn(M.Under(cx, cy)) > 1 then
			M.CycleUnder()
		else
			M.Select(d.rec)
		end
	end
end

function M.GridShow()
	local on = C.Get("mover.grid") and M.active
	local lines = M.gridLines
	if not on then
		if lines then
			for i = 1, getn(lines) do lines[i]:Hide() end
		end
		return
	end
	local g = C.Get("mover.gridsize")
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local nv, nh = floor(sw / g), floor(sh / g)
	lines = lines or {}
	M.gridLines = lines
	local need = nv + nh + 2
	for i = getn(lines) + 1, need do
		local t = M.veil:CreateTexture(nil, "BORDER")
		t:SetTexture(T.tex.white)
		lines[i] = t
	end
	local ar, ag, ab = T.Accent()
	local n = 0
	for i = 0, nv do
		n = n + 1
		local t = lines[n]
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", M.veil, "BOTTOMLEFT", i * g, 0)
		t:SetWidth(1)
		t:SetHeight(sh)
		t:SetVertexColor(ar, ag, ab, (i * g * 2 == floor(sw / 2) * 2) and 0.3 or 0.08)
		t:Show()
	end
	for i = 0, nh do
		n = n + 1
		local t = lines[n]
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", M.veil, "BOTTOMLEFT", 0, i * g)
		t:SetHeight(1)
		t:SetWidth(sw)
		t:SetVertexColor(ar, ag, ab, 0.08)
		t:Show()
	end
	for i = n + 1, getn(lines) do lines[i]:Hide() end
end

-- ---------------------------------------------------------------- liens : cote qui brille, symboles, proposition, menu "Accroche a"
M.ATTACH = 12                    -- distance (unites d'UIParent) sous laquelle le cote d'un autre cadre "attire" le cadre glisse
M.SIDEKEYS = { "auto", "TOP", "BOTTOM", "LEFT", "RIGHT" }
M.LKROWS = 8
M.LKW = 244
M.lkSide = "auto"
M.lkOff = 0

-- Pendant un glissement (la poignee du cadre glisse est en nl, nb) : l'autre cadre dont un cote est tout pres, et ce cote. Jamais un cadre qui
-- depend du cadre glisse (cycle).
function M.LinkScan(d, nl, nb)
	if not Layout.LinksEnabled() then return nil end
	local id = d.rec.id
	if not Layout.items[id] then return nil end
	local l0, r0 = nl, nl + d.w
	local t0 = nb + d.fh
	local b0 = t0 - d.hh
	local best, brec, bside = M.ATTACH + 0.001, nil, nil
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec ~= d.rec and rec.handle and rec.handle:IsShown() and Layout.items[rec.id] and not Layout.IsDescendant(rec.id, id) then
			local ol, ob, orr, ot, ow, oh = M.Rect(rec)
			if ol then
				local g
				local ovx = math.min(r0, orr) - math.max(l0, ol)
				local ovy = math.min(t0, ot) - math.max(b0, ob)
				if ovx >= math.min(d.w, ow) * 0.25 then
					g = abs(t0 - ob)
					if g < best then best, brec, bside = g, rec, "BOTTOM" end
					g = abs(b0 - ot)
					if g < best then best, brec, bside = g, rec, "TOP" end
				end
				if ovy >= math.min(d.hh, oh) * 0.25 then
					g = abs(r0 - ol)
					if g < best then best, brec, bside = g, rec, "LEFT" end
					g = abs(l0 - orr)
					if g < best then best, brec, bside = g, rec, "RIGHT" end
				end
			end
		end
	end
	return brec, bside
end

-- Fait briller un cote (TOP / BOTTOM / LEFT / RIGHT) de la poignee de 'rec' ; rec nil : eteint.
function M.ShowGlow(rec, side)
	local g = M.glow
	if not rec or not side then
		if g then g:Hide() end
		return
	end
	if not g then
		if SUI.InCombat() or not M.veil then return end
		g = CreateFrame("Frame", nil, M.veil)
		g:SetFrameStrata("FULLSCREEN_DIALOG")
		g:SetFrameLevel(M.veil:GetFrameLevel() + 29)
		g.tex = g:CreateTexture(nil, "OVERLAY")
		g.tex:SetTexture(T.tex.white)
		g.tex:SetAllPoints(g)
		g:Hide()
		M.glow = g
	end
	local l, b, r, t = M.Rect(rec)
	if not l then
		g:Hide()
		return
	end
	local th = 5
	g:ClearAllPoints()
	if side == "TOP" then
		g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, t - 1)
		g:SetWidth(r - l)
		g:SetHeight(th)
	elseif side == "BOTTOM" then
		g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b - th + 1)
		g:SetWidth(r - l)
		g:SetHeight(th)
	elseif side == "LEFT" then
		g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - th + 1, b)
		g:SetWidth(th)
		g:SetHeight(t - b)
	else
		g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r - 1, b)
		g:SetWidth(th)
		g:SetHeight(t - b)
	end
	local ar, ag, ab = T.Accent()
	g.tex:SetVertexColor(ar, ag, ab, 0.95)
	g.side, g.rec = side, rec
	g:Show()
end

function M.MarkClick(b)
	if b.rec then M.UnlinkRec(b.rec) end
end

function M.Mark(n)
	local m = M.linkMarks
	if not m then
		m = {}
		M.linkMarks = m
	end
	if m[n] then return m[n] end
	if SUI.InCombat() or not M.veil then return nil end
	local b = T.Button(M.veil, L("mod.mover.lk.mark"), 28, 16, M.MarkClick)
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetFrameLevel(M.veil:GetFrameLevel() + 28)
	b:Hide()
	m[n] = b
	return b
end

-- Un symbole "o-o" entre la poignee d'un enfant et celle de son parent (clic = detacher).
function M.UpdateLinks()
	local marks = M.linkMarks
	local used = 0
	if M.active and M.veil and Layout.LinksEnabled() then
		for i = 1, getn(M.order) do
			local rec = M.items[M.order[i]]
			if rec.handle and rec.handle:IsShown() then
				local pid, side = Layout.LinkedParent(rec.id)
				local prec = pid and M.items[pid]
				if prec and prec.handle and prec.handle:IsShown() then
					local cl, cb, cr, ct = M.Rect(rec)
					local pl, pb, pr, pt = M.Rect(prec)
					local mk = (cl and pl) and M.Mark(used + 1) or nil
					if mk then
						used = used + 1
						local x, y
						if side == "TOP" then
							x, y = ((pl + pr) / 2 + (cl + cr) / 2) / 2, (pt + cb) / 2
						elseif side == "BOTTOM" then
							x, y = ((pl + pr) / 2 + (cl + cr) / 2) / 2, (pb + ct) / 2
						elseif side == "LEFT" then
							x, y = (pl + cr) / 2, ((pb + pt) / 2 + (cb + ct) / 2) / 2
						else
							x, y = (pr + cl) / 2, ((pb + pt) / 2 + (cb + ct) / 2) / 2
						end
						mk.rec = rec
						mk:ClearAllPoints()
						mk:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
						mk:Show()
					end
				end
			end
		end
	end
	if marks then
		for i = used + 1, getn(marks) do marks[i]:Hide() end
	end
	return used
end

-- Detache un cadre (il reste ou il est).
function M.UnlinkRec(rec)
	local p = Layout.GetLink(rec.id)
	local ok = Layout.Unlink(rec.id)
	if ok then SUI.Print(L("msg.mover.link.off", M.Label(rec.id), p and M.Label(p) or "?")) end
	return ok
end

local function farFrom(id, pid)
	local cl, cb, cw, ch = Layout.Rect(id)
	local pl, pb, pw, ph = Layout.Rect(pid)
	if not cl or not pl then return false end
	local dx = math.max(pl - (cl + cw), cl - (pl + pw), 0)
	local dy = math.max(pb - (cb + ch), cb - (pb + ph), 0)
	return dx * dx + dy * dy > Layout.LINKFAR * Layout.LINKFAR
end

-- Apres un glissement : un cadre pose contre le cote d'un autre PROPOSE le lien ; un enfant tire trop loin de son parent est detache.
function M.AfterDrop(rec, tgt, tside)
	if not Layout.LinksEnabled() or SUI.InCombat() then return end
	local id = rec.id
	local p, side = Layout.GetLink(id)
	if tgt then
		if p == tgt.id and side == tside then return end
		local cl, cb = Layout.Rect(id)
		local dx, dy = Layout.LinkOffsets(id, tgt.id, tside, cl, cb, true)
		M.Propose(rec, tgt, tside, dx, dy)
	elseif p and farFrom(id, p) then
		if Layout.Unlink(id) then SUI.Print(L("msg.mover.link.far", M.Label(id), M.Label(p))) end
	end
end

function M.ClosePropose()
	SUI.Cancel(M.propTask)
	M.propTask, M.propData = nil, nil
	if M.prop then M.prop:Hide() end
end

-- Adaptation de taille : un module declare que la taille de son cadre peut epouser celui du parent auquel
-- on l'accroche (ex : la castbar prend la largeur du cadre joueur/cible). La barre de proposition montre
-- alors un 3e bouton "Accrocher + taille".
M.SizeFit = {}            -- [key enfant] = fonction(parentKey) -> true si la taille a ete adaptee
function M.RegisterSizeFit(key, fn)
	M.SizeFit[key] = fn
end

function M.ProposeFit()
	local d = M.propData
	M.ClosePropose()
	if not d then return end
	local ok, why = Layout.SetLink(d.child, d.parent, d.side, d.dx, d.dy)
	M.ReportLink(d, ok, why)
	if ok and M.SizeFit[d.child] then
		local fok = pcall(M.SizeFit[d.child], d.parent)
		if fok then SUI.Print(L("mod.mover.fit.ok", M.Label(d.child), M.Label(d.parent))) end
	end
end

function M.ProposeYes()
	local d = M.propData
	M.ClosePropose()
	if not d then return end
	local ok, why = Layout.SetLink(d.child, d.parent, d.side, d.dx, d.dy)
	M.ReportLink(d, ok, why)
end

function M.ReportLink(d, ok, why)
	if ok then
		if d then SUI.Print(L("msg.mover.link.ok", M.Label(d.child), M.Label(d.parent), L("mod.mover.side." .. d.side))) end
	elseif why == "cycle" and d then
		SUI.Print(L("msg.mover.link.cycle", M.Label(d.child), M.Label(d.parent)))
	else
		SUI.Print(L("msg.mover.link.fail"))
	end
end

-- Barre de proposition ("Accrocher X a Y ?") : Accrocher / Non merci, disparait seule.
function M.Propose(rec, tgt, side, dx, dy)
	local p = M.prop
	if not p then
		if SUI.InCombat() or not M.veil then return false end
		p = CreateFrame("Frame", "ShikiUI_MoverPropose", UIParent)
		M.prop = p
		p:SetWidth(470)
		p:SetHeight(58)
		p:SetFrameStrata("FULLSCREEN_DIALOG")
		p:SetFrameLevel(M.veil:GetFrameLevel() + 45)
		p:SetPoint("TOP", UIParent, "TOP", 0, -112)
		p:EnableMouse(true)
		T.Backdrop(p, T.c.bg, T.c.border)
		p.text = T.Text(p, 12, T.c.text, "CENTER", true)
		p.text:SetPoint("TOP", p, "TOP", 0, -9)
		p.text:SetWidth(450)
		p.text:SetHeight(16)
		p.yes = T.Button(p, L("mod.mover.prop.yes"), 130, 22, M.ProposeYes)
		p.yes:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 26, 8)
		p.fit = T.Button(p, L("mod.mover.prop.fit"), 150, 22, M.ProposeFit)
		p.fit:SetPoint("BOTTOM", p, "BOTTOM", 0, 8)
		p.no = T.Button(p, L("mod.mover.prop.no"), 130, 22, M.ClosePropose)
		p.no:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -26, 8)
		p:Hide()
	end
	M.propData = { child = rec.id, parent = tgt.id, side = side, dx = dx, dy = dy }
	p.fit:Show()
	if not M.SizeFit[rec.id] then p.fit:Hide() end
	p.text:SetText(L("mod.mover.prop.text", M.Label(rec.id), M.Label(tgt.id), L("mod.mover.side." .. side)))
	p:Show()
	SUI.Cancel(M.propTask)
	M.propTask = SUI.After(10, M.ClosePropose, "mover.propose")
	return true
end

-- ---------------------------------------------------------------- menu "Accroche a : ..." (clic droit)
function M.LinkCandidates(rec)
	local out = {}
	for i = 1, getn(M.order) do
		local o = M.items[M.order[i]]
		if o ~= rec and o.frame and Layout.items[o.id] and not Layout.IsDescendant(o.id, rec.id) then
			tinsert(out, { rec = o, label = M.Label(o.id) })
		end
	end
	table.sort(out, function(a, b) return string.lower(a.label) < string.lower(b.label) end)
	return out
end

function M.LkSide(b)
	M.lkSide = b.side
	if M.lkRec then M.FillLinkMenu(M.lkRec) end
end

function M.LkPage(b)
	if not M.lkRec then return end
	local n = getn(M.LinkCandidates(M.lkRec))
	local off = M.lkOff + b.dir * M.LKROWS
	if off < 0 or off >= n then return end
	M.lkOff = off
	M.FillLinkMenu(M.lkRec)
end

function M.LkPick(b)
	local rec, tgt = M.lkRec, b.cand
	if not rec or not tgt then return end
	local side = M.lkSide
	if side == "auto" then
		local cl, cb = Layout.Rect(rec.id)
		side = Layout.NearestSide(rec.id, tgt.id, cl, cb)
	end
	M.CloseCtx()
	local ok, why = Layout.SetLink(rec.id, tgt.id, side)
	M.ReportLink({ child = rec.id, parent = tgt.id, side = side }, ok, why)
end

function M.BuildLinkMenu()
	if M.lkMenu then return M.lkMenu end
	M.BuildCtx()
	local p = CreateFrame("Frame", "ShikiUI_MoverLinkMenu", UIParent)
	M.lkMenu = p
	p:SetFrameStrata(M.CTXSTRATA)
	p:SetFrameLevel(10)
	p:SetWidth(M.LKW)
	p:SetHeight(58 + M.LKROWS * 22 + 34)
	p:EnableMouse(true)
	T.Backdrop(p, T.c.bg, T.c.border)
	p:Hide()
	p.title = T.Text(p, 12, T.c.text, "LEFT", true)
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
	p.title:SetWidth(M.LKW - 20)
	p.title:SetHeight(16)
	p.sides = {}
	for i = 1, getn(M.SIDEKEYS) do
		local b = T.Button(p, "", 44, 20, M.LkSide)
		b:SetFrameStrata(M.CTXSTRATA)
		b:SetFrameLevel(12)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 6 + (i - 1) * 47, -30)
		b.side = M.SIDEKEYS[i]
		p.sides[i] = b
	end
	p.rows = {}
	for i = 1, M.LKROWS do
		local b = T.Button(p, "", M.LKW - 12, 20, M.LkPick)
		b:SetFrameStrata(M.CTXSTRATA)
		b:SetFrameLevel(12)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -56 - (i - 1) * 22)
		p.rows[i] = b
	end
	p.prev = T.Button(p, "<", 30, 20, M.LkPage)
	p.prev:SetFrameStrata(M.CTXSTRATA)
	p.prev:SetFrameLevel(12)
	p.prev:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 6, 6)
	p.prev.dir = -1
	p.next = T.Button(p, ">", 30, 20, M.LkPage)
	p.next:SetFrameStrata(M.CTXSTRATA)
	p.next:SetFrameLevel(12)
	p.next:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -6, 6)
	p.next.dir = 1
	p.page = T.Text(p, 10, T.c.dim, "CENTER")
	p.page:SetPoint("BOTTOM", p, "BOTTOM", 0, 10)
	p.page:SetWidth(120)
	p.page:SetHeight(12)
	return p
end

function M.FillLinkMenu(rec)
	local p = M.lkMenu
	if not p then return end
	local cur = Layout.GetLink(rec.id)
	p.title:SetText(L("mod.mover.lk.title", M.Label(rec.id)))
	for i = 1, getn(p.sides) do
		local b = p.sides[i]
		T.SetButtonText(b, L("mod.mover.side." .. b.side))
		T.SetSelected(b, M.lkSide == b.side)
	end
	local list = M.LinkCandidates(rec)
	local n = getn(list)
	if M.lkOff >= n then M.lkOff = 0 end
	for i = 1, M.LKROWS do
		local b = p.rows[i]
		local c = list[M.lkOff + i]
		if c then
			b.cand = c.rec
			T.SetButtonText(b, c.label)
			T.SetSelected(b, cur == c.rec.id)
			b:Show()
		else
			b.cand = nil
			b:Hide()
		end
	end
	local pages = floor((n + M.LKROWS - 1) / M.LKROWS)
	if pages < 1 then pages = 1 end
	p.page:SetText(L("mod.mover.p.page", floor(M.lkOff / M.LKROWS) + 1, pages))
end

function M.OpenLinkMenu(rec)
	if not M.active or not rec or SUI.InCombat() then return false end
	if not Layout.LinksEnabled() then
		SUI.Print(L("msg.mover.link.disabled"))
		return false
	end
	local p = M.BuildLinkMenu()
	M.lkRec = rec
	M.lkOff = 0
	M.FillLinkMenu(rec)
	local cx, cy = M.Cursor()
	local w, h = p:GetWidth(), p:GetHeight()
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	if cx + w > sw - 4 then cx = sw - w - 4 end
	if cx < 4 then cx = 4 end
	if cy - h < 4 then cy = h + 4 end
	if cy > sh - 4 then cy = sh - 4 end
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx, cy)
	M.ctxCatcher:Show()
	p:Show()
	return true
end

-- ---------------------------------------------------------------- alignement et symetrie
function M.AlignTo(rec, other, mode)
	local l, b, r, t, w = M.Rect(rec)
	local ol, ob, orr, ot, ow = M.Rect(other)
	if not l or not ol then return false end
	if mode == "y" then
		M.PlaceCenter(rec, (l + r) / 2, (ob + ot) / 2)
	elseif mode == "x" then
		local l0, b0 = M.FrameLB(rec)
		M.Commit(rec, ol, b0)
	elseif mode == "w" then
		if not rec.scaleOk then return false end
		local s = M.ScaleOf(rec) * ow / w
		if s < 0.5 then s = 0.5 end
		if s > 2 then s = 2 end
		local l0, b0 = M.FrameLB(rec)
		M.Commit(rec, l0, b0, SUI.Round(s, 2))
	else
		return false
	end
	return true
end

-- Place rec a l'oppose de other par rapport au centre de l'ecran, a la meme hauteur.
function M.MirrorOf(rec, other)
	local ol, ob, orr, ot = M.Rect(other)
	if not ol then return false end
	M.PlaceCenter(rec, UIParent:GetWidth() - (ol + orr) / 2, (ob + ot) / 2)
	return true
end

function M.CenterH(rec)
	local w, _, _, fh = M.RectSize(rec)
	local l0, b0 = M.FrameLB(rec)
	if not l0 then return false end
	M.Commit(rec, UIParent:GetWidth() / 2 - w / 2, b0)
	return true
end

-- Joueur et Cible : meme hauteur, a distance egale du centre de l'ecran (joueur a gauche, cible a droite).
function M.MirrorUnits()
	local a, b = M.items["unit.player"], M.items["unit.target"]
	if not (a and b and a.frame and b.frame) then
		SUI.Print(L("msg.mover.sym.missing"))
		return false
	end
	local al, ab, ar, at, aw = M.Rect(a)
	local bl, bb, br, bt, bw = M.Rect(b)
	if not al or not bl then
		SUI.Print(L("msg.mover.sym.missing"))
		return false
	end
	local pivot = UIParent:GetWidth() / 2
	local dist = abs((al + ar) / 2 - pivot)
	local mind = (aw + bw) / 4 + 10
	if dist < mind then dist = mind end
	local cy = (ab + at) / 2
	M.PlaceCenter(a, pivot - dist, cy)
	M.PlaceCenter(b, pivot + dist, cy)
	SUI.Print(L("msg.mover.sym.ok"))
	return true
end

-- ---------------------------------------------------------------- selection multiple et ecarts egaux
function M.MultiCount()
	local n = 0
	for id in pairs(M.multi) do
		local rec = M.items[id]
		if rec and rec.handle and rec.handle:IsShown() then n = n + 1 end
	end
	return n
end

function M.ToggleMulti(rec)
	if not rec then return false end
	if M.multi[rec.id] then M.multi[rec.id] = nil else M.multi[rec.id] = true end
	M.PaintHandle(rec)
	return M.multi[rec.id] and true or false
end

function M.ClearMulti()
	local old = M.multi
	M.multi = {}
	for id in pairs(old) do
		local rec = M.items[id]
		if rec and rec.handle then M.PaintHandle(rec) end
	end
end

-- Repartit les cadres de la selection multiple pour que les ecarts entre voisins soient egaux sur l'axe x (horiz) ou y.
-- Le premier et le dernier restent en place. Renvoie ok, ecart (px) ; ok = false si moins de 3 cadres.
function M.EqualizeGaps(horiz)
	local list = {}
	for id in pairs(M.multi) do
		local rec = M.items[id]
		if rec and rec.handle and rec.handle:IsShown() then
			local l, b, r, t, w, h, fh = M.Rect(rec)
			if l then
				local lo, hi = l, r
				if not horiz then lo, hi = b, t end
				tinsert(list, { rec = rec, lo = lo, hi = hi, size = hi - lo, h = h, fh = fh })
			end
		end
	end
	local n = getn(list)
	if n < 3 then return false, 0 end
	table.sort(list, function(a, c) return a.lo < c.lo end)
	local sum = 0
	for i = 1, n do sum = sum + list[i].size end
	local gap = (list[n].hi - list[1].lo - sum) / (n - 1)
	if gap < 0 then gap = 0 end
	M.PushUndo("multi")            -- un seul pas d'annulation pour tout le groupe
	local pos = list[1].lo
	for i = 2, n - 1 do
		pos = pos + list[i - 1].size + gap
		local e = list[i]
		local l0, b0 = M.FrameLB(e.rec)
		M.undoId, M.undoAt = "multi", GetTime()
		if horiz then
			M.Commit(e.rec, pos, b0)
		else
			M.Commit(e.rec, l0, pos + e.h - e.fh)
		end
	end
	M.undoId = nil
	return true, gap
end

local function multiClick()
	local rec = M.sel
	if not rec then return end
	M.ToggleMulti(rec)
	M.FillPanel(rec)
end

local function multiClear()
	M.ClearMulti()
	if M.sel then M.FillPanel(M.sel) end
end

local function equalClick(horiz)
	if M.MultiCount() < 3 then
		SUI.Print(L("msg.mover.eq.need"))
		return
	end
	local ok, gap = M.EqualizeGaps(horiz)
	if ok then SUI.Print(L("msg.mover.eq.ok", floor(gap + 0.5))) end
	if M.sel then M.FillPanel(M.sel) end
end

-- ---------------------------------------------------------------- panneau de position precise
local function numOf(edit)
	return tonumber(edit:GetText() or "")
end

function M.FillPanel(rec)
	local p = M.panel
	if not p then return end
	p.title:SetText(M.Label(rec.id))
	if p.collapsed then return end
	local px, py = M.Offsets(rec)
	p.edX:SetText(tostring(px))
	p.edY:SetText(tostring(py))
	p.edS:SetText(string.format("%.2f", M.ScaleOf(rec)))
	if rec.scaleOk then
		p.edS:Show()
		p.lbS:Show()
	else
		p.edS:Hide()
		p.lbS:Hide()
	end
	local _, _, fw, fh = M.RectSize(rec)
	p.size:SetText(L("mod.mover.p.size", floor(fw + 0.5), floor(fh + 0.5), M.ScaleOf(rec)))
	p.bAll.disabled = not M.HasSettings(rec)
	p.bAll:SetAlpha(p.bAll.disabled and 0.4 or 1)
	T.SetButtonText(p.bMulti, L(M.multi[rec.id] and "mod.mover.p.multi.off" or "mod.mover.p.multi.on", M.MultiCount()))
	T.SetSelected(p.bMulti, M.multi[rec.id] and true or false)
	-- liste des autres cadres
	local list = {}
	for i = 1, getn(M.order) do
		local o = M.items[M.order[i]]
		if o ~= rec and o.handle and o.handle:IsShown() then tinsert(list, o) end
	end
	M.alignList = list
	local n = getn(list)
	if M.alignOff >= n then M.alignOff = 0 end
	for i = 1, M.ROWS do
		local b = p.rows[i]
		local o = list[M.alignOff + i]
		if o then
			b.rec = o
			T.SetButtonText(b, M.Label(o.id))
			T.SetSelected(b, M.alignSel == o)
			b:Show()
		else
			b:Hide()
		end
	end
	local pages = floor((n + M.ROWS - 1) / M.ROWS)
	if pages < 1 then pages = 1 end
	p.page:SetText(L("mod.mover.p.page", floor(M.alignOff / M.ROWS) + 1, pages))
	T.SetSelected(p.mY, M.alignMode == "y")
	T.SetSelected(p.mX, M.alignMode == "x")
	T.SetSelected(p.mW, M.alignMode == "w")
end

local function panelApplyXY()
	local rec = M.sel
	local p = M.panel
	if not rec or not p then return end
	local px, py = numOf(p.edX), numOf(p.edY)
	if px and py then
		local nl, nb = M.FromOffsets(rec, px, py)
		M.Commit(rec, nl, nb)
	end
	M.FillPanel(rec)
end

local function panelApplyScale()
	local rec = M.sel
	local p = M.panel
	if not rec or not p or not rec.scaleOk then return end
	local s = numOf(p.edS)
	if s then
		if s < 0.5 then s = 0.5 end
		if s > 2 then s = 2 end
		local l0, b0 = M.FrameLB(rec)
		if l0 then M.Commit(rec, l0, b0, SUI.Round(s, 2)) end
	end
	M.FillPanel(rec)
end

local function rowClick(b)
	local rec = M.sel
	if not rec or not b.rec then return end
	M.alignSel = b.rec
	if M.AlignTo(rec, b.rec, M.alignMode) then SUI.Print(L("msg.mover.align.ok", M.Label(rec.id), M.Label(b.rec.id))) end
	M.FillPanel(rec)
end

local function setMode(m)
	M.alignMode = m
	if M.sel then M.FillPanel(M.sel) end
end

local function pageMove(dir)
	local n = getn(M.alignList or {})
	local off = M.alignOff + dir * M.ROWS
	if off < 0 or off >= n then return end
	M.alignOff = off
	if M.sel then M.FillPanel(M.sel) end
end

local function mirrorClick()
	local rec = M.sel
	if not rec then return end
	local other = M.alignSel
	if not other or other == rec then other = M.items[M.PARTNER[rec.id] or ""] end
	if not other or not other.handle or not other.handle:IsShown() then
		SUI.Print(L("msg.mover.sym.pick"))
		return
	end
	M.MirrorOf(rec, other)
	SUI.Print(L("msg.mover.align.ok", M.Label(rec.id), M.Label(other.id)))
	M.FillPanel(rec)
end

function M.BuildPanel()
	if M.panel then return M.panel end
	local p = CreateFrame("Frame", "ShikiUI_MoverPanel", M.veil)
	M.panel = p
	p:SetWidth(300)
	p:SetHeight(446)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:SetFrameLevel(M.veil:GetFrameLevel() + 30)
	p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -130)
	p:EnableMouse(true)
	-- le panneau se deplace : glisser le titre ou un espace vide (pour voir ce qu'il y a derriere)
	p:SetMovable(true)
	p:SetClampedToScreen(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", function() this:StartMoving() end)
	p:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	T.Backdrop(p, T.c.bg, T.c.border)
	p.title = T.Text(p, 13, T.c.text, "LEFT")
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
	p.title:SetWidth(220)
	p.title:SetHeight(16)
	p.body = {}
	local function lab(text, x, y, w)
		local fs = T.Text(p, 11, T.c.dim, "LEFT")
		tinsert(p.body, fs)
		fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
		fs:SetWidth(w)
		fs:SetHeight(14)
		fs:SetText(text)
		return fs
	end
	lab(L("mod.mover.p.x"), 12, -43, 14)
	p.edX = T.Edit(p, 62, 20)
	p.edX:SetPoint("TOPLEFT", p, "TOPLEFT", 28, -38)
	p.edX:SetScript("OnEnterPressed", function() panelApplyXY() this:ClearFocus() end)
	lab(L("mod.mover.p.y"), 100, -43, 14)
	p.edY = T.Edit(p, 62, 20)
	p.edY:SetPoint("TOPLEFT", p, "TOPLEFT", 116, -38)
	p.edY:SetScript("OnEnterPressed", function() panelApplyXY() this:ClearFocus() end)
	p.lbS = lab(L("mod.mover.p.scale"), 186, -43, 40)
	p.edS = T.Edit(p, 50, 20)
	p.edS:SetPoint("TOPLEFT", p, "TOPLEFT", 238, -38)
	p.edS:SetScript("OnEnterPressed", function() panelApplyScale() this:ClearFocus() end)
	p.bCenter = T.Button(p, L("mod.mover.p.center"), 136, 22, function() if M.sel then M.CenterH(M.sel) M.FillPanel(M.sel) end end)
	p.bCenter:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -68)
	p.bMirror = T.Button(p, L("mod.mover.p.mirror"), 136, 22, mirrorClick)
	p.bMirror:SetPoint("TOPLEFT", p, "TOPLEFT", 152, -68)
	p.bReset = T.Button(p, L("mod.mover.p.reset"), 136, 22, function()
		if M.sel then
			M.Reset(M.sel.id)
			M.FillPanel(M.sel)
		end
	end)
	p.bReset:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -96)
	p.bClose = T.Button(p, L("mod.mover.p.close"), 136, 22, function() M.ClosePanel() end)
	p.bClose:SetPoint("TOPLEFT", p, "TOPLEFT", 152, -96)
	lab(L("mod.mover.p.align"), 12, -128, 270)
	p.mY = T.Button(p, L("mod.mover.p.mode.y"), 88, 20, function() setMode("y") end)
	p.mY:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -146)
	p.mX = T.Button(p, L("mod.mover.p.mode.x"), 88, 20, function() setMode("x") end)
	p.mX:SetPoint("TOPLEFT", p, "TOPLEFT", 106, -146)
	p.mW = T.Button(p, L("mod.mover.p.mode.w"), 88, 20, function() setMode("w") end)
	p.mW:SetPoint("TOPLEFT", p, "TOPLEFT", 200, -146)
	p.rows = {}
	for i = 1, M.ROWS do
		local b = T.Button(p, "", 276, 20, function(btn) rowClick(btn) end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -172 - (i - 1) * 22)
		p.rows[i] = b
	end
	p.prev = T.Button(p, "<", 30, 20, function() pageMove(-1) end)
	p.prev:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -312)
	p.next = T.Button(p, ">", 30, 20, function() pageMove(1) end)
	p.next:SetPoint("TOPLEFT", p, "TOPLEFT", 258, -312)
	p.page = T.Text(p, 10, T.c.dim, "CENTER")
	p.page:SetPoint("TOPLEFT", p, "TOPLEFT", 50, -316)
	p.page:SetWidth(200)
	p.page:SetHeight(12)
	p.size = T.Text(p, 10, T.c.dim, "LEFT")
	p.size:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -340)
	p.size:SetWidth(276)
	p.size:SetHeight(12)
	p.bAll = T.Button(p, L("mod.mover.p.allopts"), 276, 22, function() if M.sel then M.OpenSettings(M.sel) end end)
	p.bAll:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -358)
	p.bMulti = T.Button(p, L("mod.mover.p.multi.on", 0), 136, 22, multiClick)
	p.bMulti:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -386)
	p.bMultiClr = T.Button(p, L("mod.mover.p.multi.clear"), 136, 22, multiClear)
	p.bMultiClr:SetPoint("TOPLEFT", p, "TOPLEFT", 152, -386)
	p.bEqH = T.Button(p, L("mod.mover.p.eq.h"), 136, 22, function() equalClick(true) end)
	p.bEqH:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -412)
	p.bEqV = T.Button(p, L("mod.mover.p.eq.v"), 136, 22, function() equalClick(false) end)
	p.bEqV:SetPoint("TOPLEFT", p, "TOPLEFT", 152, -412)
	local bodyW = { p.edX, p.edY, p.edS, p.bCenter, p.bMirror, p.bReset, p.bClose, p.mY, p.mX, p.mW, p.prev, p.next, p.page, p.size, p.bAll,
		p.bMulti, p.bMultiClr, p.bEqH, p.bEqV }
	for i = 1, getn(bodyW) do tinsert(p.body, bodyW[i]) end
	for i = 1, getn(p.rows) do tinsert(p.body, p.rows[i]) end
	p.fullH = 446
	p.bMin = T.Button(p, L("mod.mover.btn.min"), 70, 18, function() M.Collapse(M.panel, not M.panel.collapsed) end)
	p.bMin:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
	p:Hide()
	return p
end

-- Reduit un panneau a sa barre de titre (pour voir l'ecran derriere) ou le rouvre.
function M.Collapse(p, on)
	if not p then return end
	on = on and true or false
	p.collapsed = on
	for i = 1, getn(p.body) do
		if on then p.body[i]:Hide() else p.body[i]:Show() end
	end
	if p.bMin then T.SetButtonText(p.bMin, L(on and "mod.mover.btn.max" or "mod.mover.btn.min")) end
	if on then
		p:SetHeight(34)
	else
		p:SetHeight(p.fullH)
		if p == M.panel and M.sel then M.FillPanel(M.sel) end
		if p == M.list then M.FillList() end
	end
end

-- ---------------------------------------------------------------- liste de tous les cadres (recherche), meme caches ou vides
M.LISTROWS = 10
M.listOff = 0
M.listFilter = ""

function M.ListItems()
	local out = {}
	local f = M.listFilter or ""
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec and rec.frame then
			local label = M.Label(rec.id)
			if f == "" or string.find(string.lower(label), f, 1, true) or string.find(string.lower(rec.id), f, 1, true) then
				tinsert(out, { rec = rec, label = label })
			end
		end
	end
	table.sort(out, function(a, b) return string.lower(a.label) < string.lower(b.label) end)
	return out
end

function M.FillList()
	local p = M.list
	if not p then return end
	if p.collapsed then return end
	local items = M.ListItems()
	local n = getn(items)
	if M.listOff >= n then M.listOff = 0 end
	for i = 1, M.LISTROWS do
		local b = p.rows[i]
		local it = items[M.listOff + i]
		if it then
			local label = it.label
			if not M.Visible(it.rec.frame) then label = label .. " (" .. L("mod.mover.l.hidden") .. ")" end
			b.rec = it.rec
			T.SetButtonText(b, label)
			T.SetSelected(b, M.sel == it.rec)
			b:Show()
		else
			b:Hide()
		end
	end
	local pages = floor((n + M.LISTROWS - 1) / M.LISTROWS)
	if pages < 1 then pages = 1 end
	p.page:SetText(L("mod.mover.p.page", floor(M.listOff / M.LISTROWS) + 1, pages) .. "  (" .. n .. ")")
end

local function listPage(dir)
	local n = getn(M.ListItems())
	local off = M.listOff + dir * M.LISTROWS
	if off < 0 or off >= n then return end
	M.listOff = off
	M.FillList()
end

function M.BuildList()
	if M.list then return M.list end
	local p = CreateFrame("Frame", "ShikiUI_MoverList", M.veil)
	M.list = p
	p:SetWidth(260)
	p:SetHeight(310)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:SetFrameLevel(M.veil:GetFrameLevel() + 30)
	p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -130)
	p:EnableMouse(true)
	p:SetMovable(true)
	p:SetClampedToScreen(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", function() this:StartMoving() end)
	p:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	T.Backdrop(p, T.c.bg, T.c.border)
	p.body = {}
	p.fullH = 310
	p.title = T.Text(p, 13, T.c.text, "LEFT")
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
	p.title:SetWidth(170)
	p.title:SetHeight(16)
	p.title:SetText(L("mod.mover.l.title"))
	p.edit = T.Edit(p, 236, 20)
	p.edit:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -34)
	p.edit:SetMaxLetters(24)
	p.edit:SetScript("OnTextChanged", function()
		M.listFilter = string.lower(this:GetText() or "")
		M.listOff = 0
		M.FillList()
	end)
	p.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	tinsert(p.body, p.edit)
	p.rows = {}
	for i = 1, M.LISTROWS do
		local b = T.Button(p, "", 236, 20, function(btn) M.Focus(btn.rec) end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -60 - (i - 1) * 22)
		p.rows[i] = b
		tinsert(p.body, b)
	end
	p.prev = T.Button(p, "<", 30, 20, function() listPage(-1) end)
	p.prev:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -284)
	p.next = T.Button(p, ">", 30, 20, function() listPage(1) end)
	p.next:SetPoint("TOPLEFT", p, "TOPLEFT", 218, -284)
	p.page = T.Text(p, 10, T.c.dim, "CENTER")
	p.page:SetPoint("TOPLEFT", p, "TOPLEFT", 46, -288)
	p.page:SetWidth(168)
	p.page:SetHeight(12)
	tinsert(p.body, p.prev)
	tinsert(p.body, p.next)
	tinsert(p.body, p.page)
	p.bMin = T.Button(p, L("mod.mover.btn.min"), 70, 18, function() M.Collapse(M.list, not M.list.collapsed) end)
	p.bMin:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
	p:Hide()
	return p
end

function M.ToggleList()
	if not M.active or SUI.InCombat() then return end
	M.BuildList()
	if M.list:IsShown() then
		M.list:Hide()
	else
		M.list:Show()
		M.FillList()
	end
	if M.banner then T.SetSelected(M.banner.list, M.list:IsShown()) end
end

function M.ClosePanel()
	if M.panel then M.panel:Hide() end
	M.sel = nil
	M.alignSel = nil
	M.Repaint()
end

function M.Select(rec, quiet)
	local old = M.sel
	M.sel = rec
	if M.raised and M.raised ~= rec then
		local r = M.raised
		M.raised = nil
		M.ApplyLevel(r)
	end
	if old and old ~= rec then M.PaintHandle(old) end
	M.PaintHandle(rec)
	if SUI.InCombat() then return end
	M.BuildPanel()
	if old ~= rec then
		M.alignSel = nil
		M.alignOff = 0
	end
	M.panel:Show()
	M.FillPanel(rec)
end

-- ---------------------------------------------------------------- bandeau, voile, apercus

function M.RefreshBanner()
	local bn = M.banner
	if not bn then return end
	T.SetSelected(bn.grid, C.Get("mover.grid") and true or false)
	T.SetSelected(bn.all, M.showAll)
	T.SetSelected(bn.snap, C.Get("mover.snap") and true or false)
	T.SetButtonText(bn.snap, L("mod.mover.btn.snap", L(C.Get("mover.snap") and "mod.mover.on" or "mod.mover.off")))
	T.SetButtonText(bn.raid, L("mod.mover.btn.raid", M.RAIDSIZES[M.raidIdx]))
	bn.hint:SetText(L("mod.mover.hint"))
	bn.title:SetText(L("mod.mover.title"))
end

function M.ConfirmReset()
	local bn = M.banner
	if M.confirm then
		M.confirm = nil
		T.SetButtonText(bn.reset, L("mod.mover.btn.reset"))
		M.Reset("all")
		SUI.Print(L("msg.mover.reset.all"))
		return
	end
	M.confirm = true
	T.SetButtonText(bn.reset, L("mod.mover.btn.confirm"))
	SUI.After(3, M.ClearConfirm, "mover.confirm")
end

function M.ClearConfirm()
	if M.confirm then
		M.confirm = nil
		if M.banner then T.SetButtonText(M.banner.reset, L("mod.mover.btn.reset")) end
	end
end

function M.OnKeyDown()
	local k = arg1
	if k == "ESCAPE" then
		if (M.ctx and M.ctx:IsShown()) or (M.lkMenu and M.lkMenu:IsShown()) then
			M.CloseCtx()
			return
		end
		if M.prop and M.prop:IsShown() then
			M.ClosePropose()
			return
		end
		M.Exit(true)
	elseif k == "TAB" then
		M.CycleUnder()
	elseif k == "UP" then
		M.Nudge(0, 1)
	elseif k == "DOWN" then
		M.Nudge(0, -1)
	elseif k == "LEFT" then
		M.Nudge(-1, 0)
	elseif k == "RIGHT" then
		M.Nudge(1, 0)
	elseif k == "Z" and IsControlKeyDown() then
		if M.Undo() then SUI.Print(L("msg.mover.undo")) else SUI.Print(L("msg.mover.undo.none")) end
	elseif k == "G" then
		C.Set("mover.grid", not C.Get("mover.grid"))
	elseif k == "S" then
		C.Set("mover.snap", not C.Get("mover.snap"))
	elseif k == "R" or k == "DELETE" then
		local rec = M.sel or M.hover
		if rec and rec.handle and rec.handle:IsShown() and M.Reset(rec.id) then SUI.Print(L("msg.mover.reset.one", M.Label(rec.id))) end
	elseif k == "C" then
		local rec = M.sel or M.hover
		if rec and rec.handle and rec.handle:IsShown() then M.CenterH(rec) end
	end
end

function M.BuildUI()
	if M.veil then return end
	local v = CreateFrame("Frame", "ShikiUI_MoverVeil", UIParent)
	M.veil = v
	v:SetAllPoints(UIParent)
	v:SetFrameStrata("FULLSCREEN")
	v:EnableMouse(true)
	v:EnableKeyboard(true)
	v:SetScript("OnKeyDown", M.OnKeyDown)
	v.tex = v:CreateTexture(nil, "BACKGROUND")
	v.tex:SetTexture(T.tex.white)
	v.tex:SetAllPoints(v)
	v.tex:SetVertexColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 0.35)
	v:Hide()
	M.guideV = v:CreateTexture(nil, "OVERLAY")
	M.guideV:SetTexture(T.tex.white)
	M.guideV:SetWidth(1)
	M.guideV:Hide()
	M.guideH = v:CreateTexture(nil, "OVERLAY")
	M.guideH:SetTexture(T.tex.white)
	M.guideH:SetHeight(1)
	M.guideH:Hide()
	local bn = CreateFrame("Frame", "ShikiUI_MoverBanner", UIParent)
	M.banner = bn
	bn:SetWidth(840)
	bn:SetHeight(94)
	bn:SetFrameStrata("FULLSCREEN_DIALOG")
	bn:SetFrameLevel(v:GetFrameLevel() + 40)
	bn:SetPoint("TOP", UIParent, "TOP", 0, -8)
	bn:EnableMouse(true)
	bn:SetMovable(true)
	bn:SetClampedToScreen(true)
	bn:RegisterForDrag("LeftButton")
	bn:SetScript("OnDragStart", function() this:StartMoving() end)
	bn:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	T.Backdrop(bn, T.c.bg, T.c.border)
	bn:Hide()
	bn.title = T.Text(bn, 14, T.c.text, "LEFT")
	bn.title:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -8)
	bn.title:SetWidth(300)
	bn.title:SetHeight(18)
	bn.hint = T.Text(bn, 10, T.c.dim, "LEFT")
	bn.hint:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -64)
	bn.hint:SetWidth(816)
	bn.hint:SetHeight(26)
	bn.hint:SetJustifyV("TOP")
	bn.exit = T.Button(bn, L("mod.mover.btn.exit"), 170, 22, function() M.Exit(true) end)
	bn.exit:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -32)
	bn.grid = T.Button(bn, L("mod.mover.btn.grid"), 90, 22, function() C.Set("mover.grid", not C.Get("mover.grid")) end)
	bn.grid:SetPoint("LEFT", bn.exit, "RIGHT", 6, 0)
	bn.all = T.Button(bn, L("mod.mover.btn.all"), 120, 22, function() M.SetShowAll(not M.showAll) end)
	bn.all:SetPoint("LEFT", bn.grid, "RIGHT", 6, 0)
	bn.raid = T.Button(bn, "", 90, 22, function() M.CycleRaid() end)
	bn.raid:SetPoint("LEFT", bn.all, "RIGHT", 6, 0)
	bn.snap = T.Button(bn, "", 110, 22, function() C.Set("mover.snap", not C.Get("mover.snap")) end)
	bn.snap:SetPoint("LEFT", bn.raid, "RIGHT", 6, 0)
	bn.sym = T.Button(bn, L("mod.mover.btn.sym"), 210, 22, function() M.MirrorUnits() end)
	bn.sym:SetPoint("LEFT", bn.snap, "RIGHT", 6, 0)
	bn.reset = T.Button(bn, L("mod.mover.btn.reset"), 130, 22, function() M.ConfirmReset() end)
	bn.reset:SetPoint("TOPRIGHT", bn, "TOPRIGHT", -12, -8)
	bn.cancel = T.Button(bn, L("mod.mover.btn.cancel"), 90, 22, function() M.Exit(false) end)
	bn.cancel:SetPoint("RIGHT", bn.reset, "LEFT", -6, 0)
	bn.min = T.Button(bn, L("mod.mover.btn.min"), 120, 22, function() M.CollapseBanner(not M.banner.collapsed) end)
	bn.min:SetPoint("TOPLEFT", bn, "TOPLEFT", 330, -8)
	bn.list = T.Button(bn, L("mod.mover.btn.list"), 130, 22, function() M.ToggleList() end)
	bn.list:SetPoint("TOPLEFT", bn, "TOPLEFT", 456, -8)
	-- Echap ferme le bandeau (UISpecialFrames) : l'OnHide quitte le mode en gardant les changements
	bn:SetScript("OnHide", function()
		if M.active and not M.closing then M.Exit(true) end
	end)
	tinsert(UISpecialFrames, "ShikiUI_MoverBanner")
	T.OnAccent(M.Repaint)
end

-- Bandeau reduit : titre, Verrouiller et quitter, Reduire, Liste (le reste est cache pour voir l'ecran).
function M.CollapseBanner(on)
	local bn = M.banner
	if not bn then return end
	on = on and true or false
	bn.collapsed = on
	local body = { bn.grid, bn.all, bn.raid, bn.snap, bn.sym, bn.reset, bn.cancel, bn.hint }
	for i = 1, getn(body) do
		if on then body[i]:Hide() else body[i]:Show() end
	end
	bn:SetWidth(on and 600 or 840)
	bn:SetHeight(on and 60 or 94)
	T.SetButtonText(bn.min, L(on and "mod.mover.btn.max" or "mod.mover.btn.min"))
end

function M.CycleRaid()
	M.raidIdx = M.raidIdx + 1
	if M.raidIdx > getn(M.RAIDSIZES) then M.raidIdx = 1 end
	M.Sync()
end

-- Plaques de nom d'exemple (non deplacables : leur position suit les unites dans le monde).
function M.SyncDemo()
	local want = M.active and M.showAll
	if not want then
		if M.demo then M.demo:Hide() end
		return
	end
	if not M.demo then
		if SUI.InCombat() then return end
		local d = CreateFrame("Frame", nil, M.veil)
		d:SetFrameStrata("FULLSCREEN_DIALOG")
		d:SetFrameLevel(M.veil:GetFrameLevel() + 3)
		d.cells = {}
		d.label = T.Text(d, 11, T.c.text, "CENTER", true)
		d.label:SetPoint("BOTTOM", d, "TOP", 0, 4)
		d.label:SetWidth(300)
		d.label:SetHeight(14)
		M.demo = d
	end
	local d = M.demo
	local w, h = 100, 12
	if C.defaults["nameplates.width"] ~= nil then w = C.Get("nameplates.width") end
	if C.defaults["nameplates.height"] ~= nil then h = C.Get("nameplates.height") end
	d:SetWidth(3 * (w + 2))
	d:SetHeight(h)
	d:ClearAllPoints()
	d:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	d.label:SetText(L("mod.mover.plates") .. " (" .. L("mod.mover.tag") .. ")")
	M.DrawCells(d, 3, 1, w, h)
	d:Show()
end

function M.SetShowAll(on)
	on = on and true or false
	if M.showAll == on then return end
	M.showAll = on
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec.preview then M.Preview(rec.id, on) end
	end
	if M.active then M.Sync() end
	SUI.Print(L(on and "msg.mover.show.on" or "msg.mover.show.off"))
end

function M.SetGrid(on)
	C.Set("mover.grid", on and true or false)
end

-- ---------------------------------------------------------------- entree / sortie
function M.SetLocked(v)
	if C.Get("ui.locked") == v then return end
	M.syncing = true
	C.Set("ui.locked", v)
	M.syncing = false
end

function M.OnCombat()
	if M.active then
		SUI.Print(L("msg.mover.combatexit"))
		M.Exit(true)
	end
end

function M.EnterLater()
	M.queued = false
	M.Enter()
end

function M.Enter()
	if M.active then return true end
	if SUI.InCombat() then
		if not M.queued then
			M.queued = true
			SUI.WhenSafe(M.EnterLater)
		end
		SUI.Print(L("msg.mover.combat"))
		M.SetLocked(true)
		return false
	end
	M.BuildUI()
	M.snap = { pos = copyPos(C.cur.pos), layout = C.cur.layout }
	M.undo, M.undoId = {}, nil
	M.active = true
	M.showAll = false
	M.sel, M.hover, M.drag, M.confirm = nil, nil, nil, nil
	M.alignMode, M.alignOff, M.alignSel = "y", 0, nil
	M.reopenMenu = false
	local mn = SUI.Menu
	if mn and mn.frame and mn.frame:IsShown() then
		M.reopenMenu = true
		mn.Hide()
	end
	M.SetLocked(false)
	M.veil:Show()
	M.banner:Show()
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	M.GridShow()
	local ct = SUI.ChatTabs
	if ct and ct.on and ct.Refloat then       -- fenetres de chat detachees : verrous et poignees a jour (une fenetre rattachee n'a plus de poignee)
		local ok, err = pcall(ct.Refloat)
		if not ok then SUI.Report("mover chattabs", err) end
	end
	M.Sync()
	if mn and mn.OnMoveMode then mn.OnMoveMode(true) end
	SUI.Print(L("msg.mover.on"))
	return true
end

-- garder = false : revient aux positions d'avant l'entree (Annuler).
function M.Exit(keep)
	if not M.active then return false end
	M.closing = true
	M.CloseCtx()
	if M.rz then M.GripEnd(M.rz.grip) end
	if keep == false then M.Restore() end
	M.active = false
	if M.drag then
		M.drag.h:SetScript("OnUpdate", nil)
		M.drag = nil
	end
	M.ShowGuides(nil, nil)
	M.ShowGaps(nil)
	M.multi = {}
	M.ShowGlow(nil)
	M.ClosePropose()
	for i = 1, getn(M.order) do Layout.ClearPreview(M.order[i]) end
	if M.linkMarks then
		for i = 1, getn(M.linkMarks) do M.linkMarks[i]:Hide() end
	end
	if M.showAll then
		for i = 1, getn(M.order) do
			local rec = M.items[M.order[i]]
			if rec.preview then M.Preview(rec.id, false) end
		end
	end
	M.showAll = false
	for i = 1, getn(M.order) do
		local rec = M.items[M.order[i]]
		if rec.handle then rec.handle:Hide() end
		rec.forced = nil
	end
	SUI.Cancel(M.flashTask)
	M.flashTask, M.flash, M.raised = nil, nil, nil
	if M.panel then M.panel:Hide() end
	if M.list then M.list:Hide() end
	if M.banner and M.banner.list then T.SetSelected(M.banner.list, false) end
	if M.demo then M.demo:Hide() end
	M.sel, M.hover, M.alignSel = nil, nil, nil
	M.GridShow()
	M.veil:Hide()
	M.banner:Hide()
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	M.SetLocked(true)
	M.closing = false
	SUI.Print(L(keep == false and "msg.mover.canceled" or "msg.mover.off"))
	local mn = SUI.Menu
	if mn and mn.OnMoveMode then mn.OnMoveMode(false) end
	if M.reopenMenu then
		M.reopenMenu = false
		mn.Show()
	end
	return true
end

function M.Toggle()
	if M.active then M.Exit(true) else M.Enter() end
end

-- ui.locked modifie ailleurs (case du menu, profil) : le mode suit.
local function onLocked(key, value)
	if M.syncing or key ~= "ui.locked" then return end
	if value == false and not M.active then
		M.Enter()
	elseif value == true and M.active then
		M.Exit(true)
	end
end
C.Watch("ui.locked", onLocked)

local function onCfg(key, value)
	if not M.active then return end
	if key == "mover.grid" or key == "mover.gridsize" then M.GridShow() end
	if key == nil or key == "pos" or key == "mode" or key == "layout" or key == "layout.links" or string.sub(key, 1, 6) == "mover." then M.Sync() end
end
C.Watch("", onCfg)

-- Une base enregistree avec ui.locked faux (ancienne version) : on reverrouille sans bruit au demarrage.
local function onLogin()
	if C.Get("ui.locked") == false then M.SetLocked(true) end
end
SUI.On("PLAYER_LOGIN", onLogin)

-- ---------------------------------------------------------------- commande /sui move
function M.Command(rest)
	local _, _, sub, arg = string.find(rest or "", "^%s*(%S*)%s*(.*)$")
	sub = string.lower(sub or "")
	if sub == "" then
		M.Toggle()
	elseif sub == "reset" then
		arg = string.lower(arg or "")
		if arg == "" or arg == "all" then
			M.Reset("all")
			SUI.Print(L("msg.mover.reset.all"))
		elseif M.Reset(arg) then
			SUI.Print(L("msg.mover.reset.one", M.Label(arg)))
		else
			SUI.Print(L("msg.mover.unknown", arg))
		end
	elseif sub == "grid" then
		M.SetGrid(not C.Get("mover.grid"))
		SUI.Print(L(C.Get("mover.grid") and "msg.mover.grid.on" or "msg.mover.grid.off"))
	elseif sub == "show" then
		if not M.active and not M.Enter() then return end
		M.SetShowAll(not M.showAll)
	elseif sub == "sym" then
		if not M.active and not M.Enter() then return end
		M.MirrorUnits()
	elseif sub == "list" then
		for i = 1, getn(M.order) do
			local id = M.order[i]
			SUI.Print(L("msg.mover.line", id, M.Label(id)))
		end
	else
		SUI.Print(L("help.mover"))
	end
end

-- ---------------------------------------------------------------- boutons autour de la minicarte (deplacables a la souris)
-- SUI.MiniRing.Place(b, cle, defaut) pose le bouton sur le cadran selon l'angle de la cle de reglage (0 droite, 90 haut, 180 gauche, 270 bas) ;
-- SUI.MiniRing.Drag(b, cle, defaut) permet de le glisser autour de la minicarte : l'angle est memorise au lacher.
SUI.MiniRing = {}
local R = SUI.MiniRing

function R.PlaceAt(b, deg)
	local mm = getglobal("Minimap")
	if not mm or not b then return end
	local ang = deg * 3.14159265 / 180
	local rad = (mm:GetWidth() or 140) / 2 + 4
	b:ClearAllPoints()
	b:SetPoint("CENTER", mm, "CENTER", math.cos(ang) * rad, math.sin(ang) * rad)
end

function R.Place(b, key, def)
	R.PlaceAt(b, C.Get(key) or def or 200)
end

local function ringUpdate()
	local mm = getglobal("Minimap")
	local cx, cy = mm:GetCenter()
	local mx, my = GetCursorPosition()
	local s = mm:GetEffectiveScale()
	if not cx or not s or s == 0 then return end
	local deg = math.deg(math.atan2(my / s - cy, mx / s - cx))
	if deg < 0 then deg = deg + 360 end
	deg = floor(deg + 0.5)
	if deg >= 360 then deg = deg - 360 end
	this.ringDeg = deg
	R.PlaceAt(this, deg)
end

local function ringStart()
	this.ringDrag = true
	this:SetScript("OnUpdate", ringUpdate)
end

local function ringStop()
	this:SetScript("OnUpdate", nil)
	this.ringDrag = nil
	if this.ringDeg and this.ringKey then
		local d = this.ringDeg
		this.ringDeg = nil
		C.Set(this.ringKey, d)
	end
end

function R.Drag(b, key, def)
	b.ringKey, b.ringDef = key, def
	b:RegisterForDrag("LeftButton")
	b:SetMovable(false)
	b:SetScript("OnDragStart", ringStart)
	b:SetScript("OnDragStop", ringStop)
end

SUI.RegisterCommand("move", M.Command, "help.mover")
SUI.RegisterCommand("deplacer", M.Command, "help.mover.alias")
