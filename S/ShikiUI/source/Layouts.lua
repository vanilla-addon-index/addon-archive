-- ShikiUI Layouts : presets de MISE EN PAGE (positions et tailles des cadres, par role), distincts du style visuel.
-- Un preset s'APPLIQUE (comme un role) : il ecrit les positions dans le profil (Cfg.SetPos) et les tailles dans le profil de base
-- (Cfg.SetBase) ; il ne touche jamais au style (couleurs, textures, polices : Style.lua).
-- Priorite de fusion (valeur d'un reglage, de la plus a la moins prioritaire), identique pour les tailles et pour le style.* :
--   1. ecart de l'utilisateur dans le mode courant (profil.mm[mode])               [modes autres que Normal]
--   2. preset de mode livre : role+classe > classe > role > generique > module 'raid = "off"'     [Cfg.AddPreset]
--   3. profil de base : modele de role, mise en page appliquee, reglage manuel - le DERNIER ecrit gagne
--   4. valeur par defaut
-- Les positions (profil.pos) sont par profil ; une position peut etre propre a un mode (cle "cadre|raid", ecrite par le Mover en mode Raid,
-- repli sur la cle Normal) ; le dernier preset applique ou le dernier glisser-deposer gagne (un preset efface les deux cles, Cfg.ClearPosAll). Style x mise en page x mode x role / classe se combinent donc sans conflit : le style ne porte aucune
-- position, la mise en page ne porte aucune couleur.
-- LIENS entre modules (section "liens" en bas du fichier) : un cadre ENFANT peut etre accroche a un cote (TOP / BOTTOM / LEFT / RIGHT) d'un
-- cadre PARENT ; il est alors place par rapport au rectangle du parent (centre sur l'axe transversal, plus un decalage dx, dy) et le suit quand
-- il bouge, change d'echelle ou de taille. Un lien est un reglage du profil, PAR MODE : cle "@enfant>parent*C[|mode]" dans profil.pos
-- (l = dx, b = dy ; C = T B L R, ou N = detache explicitement). Sans entree, le lien conseille (Layout.DefaultLinks) s'applique tant que
-- l'enfant n'a PAS de position enregistree : les anciennes positions sont respectees. Un lien detache le reste (marqueur N).
-- Une entree de position est { ax, ay, dx, dy [, "c" | "r"] } (c = centre le cadre sur le point, r = bord droit) : fractions de l'ecran (0..1) plus decalage en unites d'UIParent, evalue a
-- l'application (independant de la resolution). Une entree "reset" efface toutes les positions.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
-- Garde d'ordre : Theme.lua definit SUI.Layout et DOIT etre charge avant ce fichier (l'ordre du .toc est generate : ne pas le changer).
if not SUI.Layout then error("ShikiUI: Theme.lua doit etre charge avant Layouts.lua (verifie l'ordre du .toc)", 0) end
local C = SUI.Config
local L = SUI.L
local Layout = SUI.Layout

local getn, tinsert = table.getn, table.insert

SUI.layouts = {}
SUI.layoutOrder = {}
Layout.applied = 0

-- SUI.RegisterLayout("centre", { label = "mod.layout.name.centre", reset = false,
--     pos = { ["unit.player"] = { 0.5, 0.3, -300, 0 } }, v = { ["units.width"] = 180 },
--     roles = { tank = { pos = {...}, v = {...} }, heal = {...} } })
function SUI.RegisterLayout(id, def)
	if type(id) ~= "string" or not string.find(id, "^[a-z][a-z0-9]+$") or string.len(id) > 24 or type(def) ~= "table" then return false end
	if SUI.layouts[id] then return false end
	SUI.layouts[id] = def
	tinsert(SUI.layoutOrder, id)
	return true
end

function Layout.Label(id)
	local def = SUI.layouts[id]
	if def and def.label and SUI.locales.fr[def.label] ~= nil then return L(def.label) end
	return tostring(id)
end

-- Etendue reelle de UIParent (GetWidth peut etre plus petit que l ecran quand l echelle UI est reduite)
function Layout.ScreenSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local r, t = UIParent:GetRight(), UIParent:GetTop()
	if r and t and r > w and t > h then w, h = r - (UIParent:GetLeft() or 0), t - (UIParent:GetBottom() or 0) end
	return w, h
end

local function place(key, e)
	if type(key) ~= "string" or type(e) ~= "table" then return false end
	local ax, ay, dx, dy = e[1], e[2], e[3] or 0, e[4] or 0
	if type(ax) ~= "number" or type(ay) ~= "number" then return false end
	local w, h = Layout.ScreenSize()
	C.ClearPosAll(key)
	if Layout.ClearLink then Layout.ClearLink(key) end       -- une mise en page place le cadre : plus de lien explicite (le lien conseille cede a la position)
	local x = ax * w + dx
	-- 5e valeur : "c" = centre horizontal du cadre sur x, "r" = bord DROIT sur x (le cadre garde sa taille reelle, barres et cadres de toute largeur)
	local it = Layout.items[key]
	local y = ay * h + dy
	local fl = type(e[5]) == "string" and e[5] or ""
	if it and it.frame and fl ~= "" then
		local k = (it.frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
		local r = 1
		if type(e[6]) == "number" then r = (C.Get("ui.scale") or 1) * e[6] / (it.frame:GetScale() or 1) end
		local fw, fh = (it.frame:GetWidth() or 0) * k * r, (it.frame:GetHeight() or 0) * k * r
		if string.find(fl, "c", 1, true) then x = x - fw / 2 elseif string.find(fl, "r", 1, true) then x = x - fw end
		if string.find(fl, "t", 1, true) then y = y - fh end
	end
	local cx
	if fl ~= "" and string.find(fl, "c", 1, true) then cx = ax * w + dx end
	C.SetPos(key, x, y, type(e[6]) == "number" and e[6] or nil, cx)
	if it then Layout.Apply(key) end
	return true
end

local function applyPart(part)
	local ok, bad = 0, 0
	if type(part) ~= "table" then return ok, bad end
	if type(part.pos) == "table" then
		for key, e in pairs(part.pos) do
			if place(key, e) then ok = ok + 1 else bad = bad + 1 end
		end
	end
	if type(part.v) == "table" then
		for k, val in pairs(part.v) do
			if C.SetBase(k, val) then ok = ok + 1 else bad = bad + 1 end
		end
	end
	return ok, bad
end

-- Applique un preset : partie generale puis partie du role (role = celui du profil si omis). Retourne ok, cle de message, applique, ignore.
function Layout.ApplyPreset(id, role)
	local def = SUI.layouts[id]
	if not def then return false, "msg.layout.unknown", 0, 0 end
	if def.reset then C.ResetPositions() end
	local ok, bad = applyPart(def)
	role = role or C.GetRole()
	if role and type(def.roles) == "table" and def.roles[role] then
		local o2, b2 = applyPart(def.roles[role])
		ok, bad = ok + o2, bad + b2
	end
	C.cur.layout = id
	Layout.applied = Layout.applied + 1
	C.Notify("layout", id)
	-- Les elements LIES par defaut (castbar, buffs/debuffs joueur et cible) ne suivent les cadres que si
-- aucune position enregistree ne fait obstacle : apres un reset complet on re-ecrit les liens explicites,
-- ainsi ils se collent aux NOUVEAUX cadres au lieu de rester a leur ancienne place (chevauchements vus en jeu).
	if def.reset and Layout.WriteLink and Layout.GapOffsets then
		local relink = {
			-- la CHAINE d'origine : buffs au-dessus du cadre, armes au-dessus des buffs, debuffs joueur a gauche ;
			-- cible : debuffs au-dessus du cadre, buffs au-dessus des debuffs ; castbars dessous
			{ "castbar.player", "unit.player", "BOTTOM" },
			{ "castbar.target", "unit.target", "BOTTOM" },
			{ "auras.pb", "unit.player", "TOP" },
			{ "auras.pw", "auras.pb", "TOP" },
			{ "auras.pd", "unit.player", "LEFT" },
			{ "auras.td", "unit.target", "TOP" },
			{ "auras.tb", "auras.td", "TOP" },
		}
		local ri
		for ri = 1, table.getn(relink) do
			local child, parent, side = relink[ri][1], relink[ri][2], relink[ri][3]
			if Layout.items[child] and Layout.items[parent] then
				if Layout.ResetLink then Layout.ResetLink(child) end
				local gx, gy = Layout.GapOffsets(side)
				Layout.WriteLink(child, parent, side, gx, gy)
			end
		end
	end
	-- liens propres au preset (ecrits APRES les liens d'origine, qu'ils remplacent) : { enfant, parent, cote [, dx, dy] }
	if def.links and Layout.WriteLink then
		local li
		for li = 1, table.getn(def.links) do
			local l = def.links[li]
			if Layout.items[l[1]] and Layout.items[l[2]] then
				if Layout.ResetLink then Layout.ResetLink(l[1]) end
				Layout.WriteLink(l[1], l[2], l[3], l[4], l[5])
			end
		end
	end
	if type(def.rpos) == "table" then
		-- (2026-11-20) les valeurs rpos sont des FRACTIONS de l'ecran ({0.0-1.0, 0.0-1.0}) : converties au
		-- moment de l'application pour etre resolues sur TOUTES les resolutions (les anciennes valeurs
		-- absolues 0-1280 cassaient les autres tailles d'ecran).
		local rk, re
		local aw, ah = UIParent.GetWidth and UIParent:GetWidth() or 1280, UIParent.GetHeight and UIParent:GetHeight() or 768
		for rk, re in pairs(def.rpos) do
			C.SetPos(rk .. "|raid", (re[1] or 0) * aw, (re[2] or 0) * ah)
			if Layout.items[rk] then Layout.Apply(rk) end
		end
	end
	if SUI.Auras and SUI.Auras.ApplyOptions then pcall(SUI.Auras.ApplyOptions) end     -- les icones d'auras suivent le cote de leur lien (au-dessus / dessous)
	return true, "msg.layout.applied", ok, bad
end

function Layout.Current()
	return C.cur.layout
end

-- Quand le role change, la mise en page memorisee suit (option layout.followrole).
C.Watch("role", function(key, value)
	if key == "role" and C.Get("layout.followrole") and C.cur.layout and SUI.layouts[C.cur.layout] then
		Layout.ApplyPreset(C.cur.layout, value)
	end
end)

-- ---------------------------------------------------------------- reglage et commande
SUI.RegisterCategory("layout", 6)
SUI.RegisterOption({ key = "layout.followrole", type = "bool", cat = "layout", label = "opt.layout.followrole", tip = "tip.layout.followrole",
	default = true, order = 10 })

local function out(msg)
	SUI.Print(msg)
end

local function firstWord(s)
	local _, _, w, rest = string.find(s or "", "^%s*(%S+)%s*(.*)$")
	if not w then return "", "" end
	return string.lower(w), rest or ""
end

local function cmd(rest)
	local sub, arg = firstWord(rest)
	if sub == "" or sub == "list" then
		local cur = C.cur.layout
		for i = 1, getn(SUI.layoutOrder) do
			local id = SUI.layoutOrder[i]
			out(L("msg.layout.line", id == cur and "*" or " ", id, Layout.Label(id)))
		end
		out(L("help.layout"))
	elseif sub == "use" then
		local id, r = firstWord(arg)
		local role = (r ~= "") and string.lower(r) or nil
		if role and not C.roles[role] then
			out(L("msg.layout.badrole", role))
			return
		end
		local ok, key, n, bad = Layout.ApplyPreset(id, role)
		if ok then out(L(key, Layout.Label(id), n, bad)) else out(L(key, id)) end
	elseif sub == "reset" then
		C.ResetPositions()
		C.cur.layout = nil
		Layout.ApplyAll()
		out(L("msg.layout.reset"))
	else
		out(L("help.layout"))
	end
end

SUI.RegisterCommand("layout", cmd, "help.layout")

-- ---------------------------------------------------------------- presets livres (dispositions de depart, modifiables a la main)
SUI.RegisterLayout("classic", { label = "mod.layout.name.classic", reset = true })









-- ================================================================ LIENS entre modules
-- API (stable, utilisee par le Mover, le menu et l'apercu) :
--   Layout.SetLink(enfant, parent, cote, dx, dy) -> ok [, raison]     cote = TOP | BOTTOM | LEFT | RIGHT ; dx, dy omis = ecart standard
--   Layout.GetLink(enfant) -> parent, cote, dx, dy, source            source = "user" | "default" ; nil si libre / detache
--   Layout.Unlink(enfant) -> ok [, raison]                            detache EXPLICITEMENT (le cadre reste ou il est)
--   Layout.Children(parent) / Layout.Descendants(parent)              listes triees de cles ; Layout.IsDescendant(cle, ancetre)
--   Layout.DefaultLinks[enfant] = { parent, side, dx, dy } ; Layout.DefaultLink(enfant, parent, cote, dx, dy)
--   Layout.LinkedParent(enfant) -> parent, cote, dx, dy, source       lien EFFECTIF (option active, parent present, pas de cycle)
--   Layout.Rect(cle) -> gauche, bas, largeur, hauteur, echelle        rectangle calcule (unites d'UIParent), lien compris
--   Layout.LinkOffsets / NearestSide / PreviewMove / ClearPreview / ClearLink / ResetLink / LinksEnabled / RefreshLinks
local floor, abs = math.floor, math.abs

Layout.GAP = 4
Layout.LINKFAR = 160                    -- distance (unites d'UIParent) au-dela de laquelle glisser un enfant le detache
Layout.SIDES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }
Layout.DefaultLinks = {}
local SIDECODE = { TOP = "T", BOTTOM = "B", LEFT = "L", RIGHT = "R" }
local CODESIDE = { T = "TOP", B = "BOTTOM", L = "LEFT", R = "RIGHT" }

SUI.RegisterOption({ key = "layout.links", type = "bool", cat = "layout", label = "opt.layout.links", tip = "tip.layout.links",
	default = true, order = 12 })

function Layout.LinksEnabled()
	return C.Get("layout.links") ~= false
end

-- Ecart standard d'un cote : colle au parent avec un petit espace.
function Layout.GapOffsets(side)
	if side == "TOP" then return 0, Layout.GAP end
	if side == "BOTTOM" then return 0, -Layout.GAP end
	if side == "LEFT" then return -Layout.GAP, 0 end
	return Layout.GAP, 0
end

-- Liens conseilles : un enfant garde sa place libre s'il a deja une position enregistree. Ne cite que des cles de positions reelles.
function Layout.DefaultLink(child, parent, side, dx, dy)
	if type(child) ~= "string" or type(parent) ~= "string" or child == parent or not SIDECODE[side] then return false end
	local gx, gy = Layout.GapOffsets(side)
	Layout.DefaultLinks[child] = { parent = parent, side = side, dx = dx or gx, dy = dy or gy }
	return true
end

-- ---------------------------------------------------------------- lecture des liens enregistres
local lkIdx, lkPos = nil, nil      -- enfant -> { normal = entree, <mode> = entree } ; reconstruit si profil.pos change

local function buildIndex()
	lkPos = C.cur.pos
	lkIdx = {}
	for key, e in pairs(lkPos) do
		if type(key) == "string" and string.sub(key, 1, 1) == "@" and type(e) == "table" and type(e.l) == "number" and type(e.b) == "number" then
			local _, _, child, parent, code, mode = string.find(key, "^@([^>]+)>([^*]+)%*([TBLRN])|?(.*)$")
			if child then
				local rec = lkIdx[child]
				if not rec then
					rec = {}
					lkIdx[child] = rec
				end
				if mode == "" then mode = "normal" end
				local ent = { key = key, dx = e.l, dy = e.b }
				if CODESIDE[code] and parent ~= "-" then
					ent.parent, ent.side = parent, CODESIDE[code]
				else
					ent.none = true
				end
				rec[mode] = ent
			end
		end
	end
end

local function index()
	if lkIdx == nil or lkPos ~= C.cur.pos then buildIndex() end
	return lkIdx
end

function Layout.InvalidateLinks()
	lkIdx = nil
	if Layout.PollWake then Layout.PollWake() end
end

local function entryIn(child, mode)
	local rec = index()[child]
	if not rec then return nil end
	if mode and mode ~= "normal" and rec[mode] then return rec[mode] end
	return rec.normal
end

-- Lien declare de l'enfant dans le mode courant : parent, cote, dx, dy, source. nil = libre ou detache.
function Layout.GetLink(child)
	local e = entryIn(child, C.mode)
	if e then
		if e.none then return nil end
		return e.parent, e.side, e.dx, e.dy, "user"
	end
	local d = Layout.DefaultLinks[child]
	if d and not C.GetPos(Layout.ReadKey(child)) then return d.parent, d.side, d.dx, d.dy, "default" end
	return nil
end

-- Parent d'un enfant dans un mode donne (pour la detection de cycles, sans regle de position).
local function parentIn(child, mode)
	local e = entryIn(child, mode)
	if e then return e.parent end
	local d = Layout.DefaultLinks[child]
	return d and d.parent or nil
end

local function wouldCycle(child, parent)
	if child == parent then return true end
	local modes = C.modeOrder
	for i = 1, getn(modes) do
		local q, n = parent, 0
		while q and n < 16 do
			if q == child then return true end
			q = parentIn(q, modes[i])
			n = n + 1
		end
	end
	return false
end

-- Lien effectif : option active, deux cadres presents, pas de cycle. Un parent sans cadre (module coupe) : l'enfant retombe sur sa place libre.
function Layout.LinkedParent(child)
	if not Layout.LinksEnabled() then return nil end
	local it = Layout.items[child]
	if not it or not it.frame then return nil end
	local p, side, dx, dy, src = Layout.GetLink(child)
	if not p then return nil end
	local pit = Layout.items[p]
	if not pit or not pit.frame then return nil end
	local q, n = p, 0
	while q and n < 16 do
		if q == child then return nil end
		q = Layout.GetLink(q)
		n = n + 1
	end
	return p, side, dx, dy, src
end

-- ---------------------------------------------------------------- geometrie (unites d'UIParent)
local function anchorFrac(p)
	local ax, ay = 0.5, 0.5
	p = p or "CENTER"
	if string.find(p, "LEFT") then ax = 0 elseif string.find(p, "RIGHT") then ax = 1 end
	if string.find(p, "TOP") then ay = 1 elseif string.find(p, "BOTTOM") then ay = 0 end
	return ax, ay
end

local function effScale(key, it)
	local _, _, s = C.GetPos(Layout.ReadKey(key))
	local sc = C.Get("ui.scale") * (s or 1)
	if type(it.mul) == "function" then
		local m = it.mul()
		if type(m) == "number" and m > 0 then sc = sc * m end
	end
	return sc
end

local function sizeOf(it, sc)
	local f = it.frame
	local w, h = f:GetWidth(), f:GetHeight()
	if type(w) ~= "number" then w = 0 end
	if type(h) ~= "number" then h = 0 end
	return w * sc, h * sc
end

-- Coin bas-gauche d'un cadre accroche a (pl, pb, pw, ph) par 'side' : centre sur l'axe transversal, decalage dx / dy.
local function sidePlace(pl, pb, pw, ph, cw, ch, side, dx, dy)
	if side == "TOP" then return pl + pw / 2 - cw / 2 + dx, pb + ph + dy end
	if side == "BOTTOM" then return pl + pw / 2 - cw / 2 + dx, pb - ch + dy end
	if side == "LEFT" then return pl - cw + dx, pb + ph / 2 - ch / 2 + dy end
	return pl + pw + dx, pb + ph / 2 - ch / 2 + dy
end

local resolve
-- Position (gauche, bas) du cadre, largeur, hauteur et echelle effectives : apercu en cours > lien > position enregistree > position par defaut.
resolve = function(key, depth)
	local it = Layout.items[key]
	local sc = effScale(key, it)
	local w, h = sizeOf(it, sc)
	if it.pvl then return it.pvl, it.pvb, w, h, sc end
	if depth < 12 then
		local p, side, dx, dy = Layout.LinkedParent(key)
		if p then
			local pl, pb, pw, ph = resolve(p, depth + 1)
			local l, b = sidePlace(pl, pb, pw, ph, w, h, side, dx, dy)
			return l, b, w, h, sc
		end
	end
	local l, b = C.GetPos(Layout.ReadKey(key))
	if l then return l, b, w, h, sc end
	local ax, ay = anchorFrac(it.point)
	local pw, ph = Layout.ScreenSize()
	return pw * ax + (it.x or 0) * sc - w * ax, ph * ay + (it.y or 0) * sc - h * ay, w, h, sc
end

function Layout.Rect(key)
	local it = Layout.items[key]
	if not it or not it.frame then return nil end
	return resolve(key, 0)
end

-- Ecarts (dx, dy) d'un enfant dont le coin bas-gauche est (cl, cb) par rapport au cote 'side' du parent. snap : l'ecart principal devient l'ecart standard.
function Layout.LinkOffsets(child, parent, side, cl, cb, snap)
	local it, pit = Layout.items[child], Layout.items[parent]
	if not it or not pit or not SIDECODE[side] then return 0, 0 end
	local pl, pb, pw, ph = resolve(parent, 0)
	local cw, ch = sizeOf(it, effScale(child, it))
	local dx, dy
	if side == "TOP" then
		dx, dy = cl + cw / 2 - (pl + pw / 2), cb - (pb + ph)
	elseif side == "BOTTOM" then
		dx, dy = cl + cw / 2 - (pl + pw / 2), cb + ch - pb
	elseif side == "LEFT" then
		dx, dy = cl + cw - pl, cb + ch / 2 - (pb + ph / 2)
	else
		dx, dy = cl - (pl + pw), cb + ch / 2 - (pb + ph / 2)
	end
	if snap then
		local gx, gy = Layout.GapOffsets(side)
		if side == "TOP" or side == "BOTTOM" then dy = gy else dx = gx end
	end
	return floor(dx + 0.5), floor(dy + 0.5)
end

-- Cote du parent le plus proche du centre de l'enfant (coin bas-gauche cl, cb).
function Layout.NearestSide(child, parent, cl, cb)
	local it, pit = Layout.items[child], Layout.items[parent]
	if not it or not pit then return "TOP" end
	local pl, pb, pw, ph = resolve(parent, 0)
	local cw, ch = sizeOf(it, effScale(child, it))
	local nx = (cl + cw / 2 - (pl + pw / 2)) / ((pw + cw) / 2 + 0.001)
	local ny = (cb + ch / 2 - (pb + ph / 2)) / ((ph + ch) / 2 + 0.001)
	if abs(ny) >= abs(nx) then
		if ny > 0 then return "TOP" end
		return "BOTTOM"
	end
	if nx > 0 then return "RIGHT" end
	return "LEFT"
end

-- ---------------------------------------------------------------- placement
local function placeLinked(key, it)
	local l, b, w, h, sc = resolve(key, 0)
	local f = it.frame
	f:SetScale(sc)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / sc, b / sc)
	it.lkPlaced = true
	it.lsig = l + b * 3.1 + w * 5.3 + h * 7.7 + sc * 11.3
end

-- En combat rien ne bouge : la mise a jour est remise a la fin du combat (une seule fois).
function Layout.Defer()
	if Layout.deferred then return end
	Layout.deferred = true
	SUI.WhenSafe(Layout.RunDeferred)
end

function Layout.RunDeferred()
	Layout.deferred = false
	Layout.RefreshLinks(true)
end

-- Replace les descendants de 'key' (apres un deplacement, un changement d'echelle ou de taille).
local function follow(key, depth)
	if depth > 8 then return end
	for k2, it2 in pairs(Layout.items) do
		if k2 ~= key and Layout.LinkedParent(k2) == key then
			if it2.lkPlaced and SUI.InCombat() then
				Layout.Defer()
			else
				placeLinked(k2, it2)
				follow(k2, depth + 1)
			end
		end
	end
end

local origApply = Layout.Apply
function Layout.Apply(key)
	local it = Layout.items[key]
	if not it then return end
	if Layout.LinkedParent(key) then
		if it.lkPlaced and SUI.InCombat() then Layout.Defer() else placeLinked(key, it) end
	else
		it.lkPlaced = nil
		origApply(key)
	end
	follow(key, 0)
end

-- Recalcule les cadres accroches dont le rectangle du parent (ou le leur) a change ; force = tous. Jamais en combat.
function Layout.RefreshLinks(force)
	if SUI.InCombat() then
		if force then Layout.Defer() end
		return 0
	end
	local n = 0
	for key, it in pairs(Layout.items) do
		if Layout.LinkedParent(key) then
			local l, b, w, h, sc = resolve(key, 0)
			local sig = l + b * 3.1 + w * 5.3 + h * 7.7 + sc * 11.3
			if force or it.lsig ~= sig or not it.lkPlaced then
				placeLinked(key, it)
				n = n + 1
			end
		end
	end
	return n
end

-- Apercu pendant un glissement : le cadre 'key' est a (l, b) (sans sauvegarde) et ses descendants le suivent.
function Layout.PreviewMove(key, l, b)
	local it = Layout.items[key]
	if not it then return end
	it.pvl, it.pvb = l, b
	follow(key, 0)
end

function Layout.ClearPreview(key)
	local it = Layout.items[key]
	if it then it.pvl, it.pvb = nil, nil end
end

-- ---------------------------------------------------------------- ecriture des liens
local function linkKey(child, parent, code, mode)
	local k = "@" .. child .. ">" .. parent .. "*" .. code
	if mode and mode ~= "normal" then k = k .. "|" .. mode end
	return k
end

local function writeMode()
	local m = C.mode
	if m and m ~= "normal" then return m end
	return "normal"
end

local function clampOff(v)
	v = tonumber(v) or 0
	if v > 2000 then v = 2000 elseif v < -2000 then v = -2000 end
	return floor(v + 0.5)
end

-- Retire les entrees enregistrees de l'enfant dans un mode (mode == nil : tous les modes). Ne notifie pas.
local function dropEntries(child, mode)
	local rec = index()[child]
	if not rec then return false end
	local any = false
	for m, e in pairs(rec) do
		if mode == nil or m == mode then
			C.cur.pos[e.key] = nil
			any = true
		end
	end
	lkIdx = nil
	return any
end

function Layout.ClearLink(child)
	return dropEntries(child, nil)
end

-- Remet le lien conseille de l'enfant (efface ses entrees dans tous les modes).
function Layout.ResetLink(child)
	local any = dropEntries(child, nil)
	if any then C.Notify("pos", nil) end
	return any
end

-- Ecrit un lien sans notifier ni replacer (le Mover groupe ses ecritures). Retourne ok [, raison].
function Layout.WriteLink(child, parent, side, dx, dy)
	if type(child) ~= "string" or type(parent) ~= "string" then return false, "args" end
	if not SIDECODE[side] then return false, "side" end
	if not Layout.items[child] or not Layout.items[parent] then return false, "unknown" end
	if Layout.PollWake then Layout.PollWake() end
	if wouldCycle(child, parent) then return false, "cycle" end
	local mode = writeMode()
	local key = linkKey(child, parent, SIDECODE[side], mode)
	if string.len(key) > 40 then return false, "long" end
	dropEntries(child, mode)
	if dx == nil or dy == nil then
		local gx, gy = Layout.GapOffsets(side)
		if dx == nil then dx = gx end
		if dy == nil then dy = gy end
	end
	C.SetPos(key, clampOff(dx), clampOff(dy))
	lkIdx = nil
	return true
end

function Layout.SetLink(child, parent, side, dx, dy)
	if SUI.InCombat() then return false, "combat" end
	local ok, why = Layout.WriteLink(child, parent, side, dx, dy)
	if not ok then return false, why end
	C.Notify("pos", nil)
	return true
end

-- Detache EXPLICITEMENT : le cadre reste ou il est (sa place est enregistree), le marqueur N empeche tout re-lien automatique.
function Layout.Unlink(child)
	if SUI.InCombat() then return false, "combat" end
	local it = Layout.items[child]
	if not it or not it.frame then return false, "unknown" end
	if not Layout.GetLink(child) then return false, "nolink" end
	local l, b = resolve(child, 0)
	local mode = writeMode()
	dropEntries(child, mode)
	local _, _, s = C.GetPos(Layout.ReadKey(child))
	C.SetPos(Layout.WriteKey(child), l, b, s)
	C.SetPos(linkKey(child, "-", "N", mode), 0, 0)
	lkIdx = nil
	C.Notify("pos", nil)
	return true
end

-- ---------------------------------------------------------------- parcours
function Layout.Children(parent)
	local out = {}
	for k, _ in pairs(Layout.items) do
		if Layout.GetLink(k) == parent then tinsert(out, k) end
	end
	table.sort(out)
	return out
end

function Layout.IsDescendant(key, ancestor)
	local q, n = key, 0
	while q and n < 16 do
		q = Layout.GetLink(q)
		if q == ancestor then return true end
		n = n + 1
	end
	return false
end

function Layout.Descendants(parent)
	local out, seen = {}, { [parent] = true }
	local queue, qi = { parent }, 1
	while queue[qi] do
		local kids = Layout.Children(queue[qi])
		for i = 1, getn(kids) do
			if not seen[kids[i]] then
				seen[kids[i]] = true
				tinsert(out, kids[i])
				tinsert(queue, kids[i])
			end
		end
		qi = qi + 1
	end
	table.sort(out)
	return out
end

-- ---------------------------------------------------------------- reactions
-- Cle des liens (profil, mode) ou option changee : tout est replace. Les changements de TAILLE d'un cadre (reglages des modules) sont vus par la
-- minuterie ci-dessous (pas de minuterie par reglage : une seule, toujours la meme).
C.Watch("", function(key, value)
	if key == nil then
		-- reset de profil (v/pos/mm effaces) : tout est replace IMMEDIATEMENT, pas au prochain poll
		Layout.InvalidateLinks()
		Layout.ApplyAll()
	end
	if key == "layout.links" then Layout.ApplyAll() end
end)

-- Filet de securite : un cadre parent qui change de taille sans passer par Layout.Apply (reglage d'un module, contenu variable).
-- Cadence ADAPTEE : 0,3 s quand des liens bougent, 1,5 s apres ~2,4 s sans aucun changement (economie permanente :
-- la plupart des profils n'ont aucun lien, la boucle ne sert qu'au cas ou). Relance rapide par Layout.PollWake().
Layout.POLL_FAST, Layout.POLL_SLOW = 0.3, 1.5
Layout.pollFast = true
Layout.pollIdle = 0
local function pollTick()
	local n = Layout.RefreshLinks(false)
	if n > 0 then
		Layout.pollIdle = 0
		if not Layout.pollFast then Layout.PollWake() end
		return
	end
	Layout.pollIdle = Layout.pollIdle + 1
	if Layout.pollFast and Layout.pollIdle >= 8 then
		Layout.pollFast = false
		SUI.Cancel(Layout.pollTask)
		Layout.pollTask = SUI.Every(Layout.POLL_SLOW, pollTick, "layout.links")
	end
end
function Layout.PollWake()
	Layout.pollIdle = 0
	if not Layout.pollFast then
		Layout.pollFast = true
		SUI.Cancel(Layout.pollTask)
		

	end
end
Layout.pollTask = SUI.Every(Layout.POLL_FAST, pollTick, "layout.links")

-- ---------------------------------------------------------------- liens conseilles (cles de positions reelles uniquement)
local D = Layout.DefaultLink
-- joueur : incantation dessous, buffs et enchantements au-dessus, debuffs a gauche
D("castbar.player", "unit.player", "BOTTOM")
D("auras.pb", "unit.player", "TOP")
D("auras.pw", "auras.pb", "TOP")
D("auras.pd", "unit.player", "LEFT")
-- cible : incantation dessous, debuffs puis buffs au-dessus, cible de la cible a droite
D("castbar.target", "unit.target", "BOTTOM")
D("auras.td", "unit.target", "TOP")
D("auras.tb", "auras.td", "TOP")
D("unit.targettarget", "unit.target", "RIGHT")
-- familier : a gauche du joueur (suit son deplacement)
D("unit.pet", "unit.player", "LEFT")
-- barres d'action : empilees au-dessus de la principale ; formes / familier de part et d'autre ; barre 5 a gauche de la barre 4
D("bars.bar2", "bars.main", "TOP", 0, 6)
D("bars.bar3", "bars.bar2", "TOP", 0, 6)
D("bars.stance", "bars.bar3", "TOP", -250, 6)
D("bars.pet", "bars.bar3", "TOP", 250, 6)
D("bars.bar5", "bars.bar4", "LEFT", -4, 0)

-- ================================================================ PRESETS COMPLETS (tout est place)
-- Ces dispositions positionnent TOUT l'ecran : barres d'action, cadres perso, groupe/raid, compteur, menace,
-- alarmes de boss, marques, castbar, minimap, totems/tanktools. Choisissez-en une dans le menu Mise en page
-- et l'ecran entier passe a la disposition (vos positions personnalisees sont remplacees).
-- Positions = { fraction largeur, fraction hauteur, dx, dy } en unites d'UIParent (origine en bas-gauche).

-- SHIKI (disposition recommandee a l'installation) : cadres joueur / cible centres en bas juste au-dessus des barres, compteur et menace
-- cote a cote en bas a droite, micro-menu puis bijoux / jeux d'equipement en haut a gauche, groupe / raid a gauche, minimap en haut a droite.
SUI.RegisterLayout("shiki", { label = "mod.layout.name.shiki", reset = true,
	v = { ["units.width"] = 200, ["actionbars.size"] = 30, ["meter.width"] = 190, ["meter.height"] = 140, ["threat.width"] = 170, ["threat.height"] = 140,
		["actionbars.micro.scale"] = 65, ["items.size"] = 28, ["items.hover"] = true,
		["auras.size"] = 24, ["auras.perrow"] = 8, ["auras.tsize"] = 24, ["auras.tperrow"] = 8, ["auras.spacing"] = 2,
		["chat.width"] = 400, ["chat.height"] = 150 },
	pos = {
		["bars.stance"] = { 0.5, 0.0, 0, 6, "c" }, ["bars.main"] = { 0.5, 0.0, 0, 42, "c" },
		["unit.player"] = { 0.5, 0.0, -110, 235, "r" }, ["unit.target"] = { 0.5, 0.0, 110, 235 },
		["chat.main"] = { 0.0, 0.0, 6, 34 },
		["lootroll"] = { 0.68, 0.66, 0, 0 }, ["lootwin"] = { 0.68, 0.46, 0, 0 }, ["loot"] = { 0.68, 0.30, 0, 0 },
		["bossmods.msg"] = { 0.5, 0.50, 0, 0, "c" }, ["bossmods.bwbars"] = { 0.5, 1.0, 0, -90, "ct" }, ["bossmods.bwemph"] = { 0.5, 1.0, 0, -200, "ct" },
		["bossmods.bwmsg"] = { 0.5, 0.56, 0, 0, "c" }, ["bossmods.bwsign"] = { 0.5, 0.68, 0, 0, "c" },
		["bars.micro"] = { 0.0, 1.0, 6, -6, "t" }, ["items"] = { 0.0, 1.0, 6, -50, "t", 0.75 }, ["hud"] = { 0.5, 1.0, 0, -2, "ct" },
		["minimap"] = { 1.0, 1.0, -6, -6, "rt" },
		["meter.win1"] = { 1.0, 0.0, -6, 34, "r" },
		["group"] = { 0.0, 0.5, 12, 0 }, ["raid"] = { 0.0, 0.5, 12, 0 },
		["bossmods.win"] = { 1.0, 0.99, -260, -230 },
	},
	-- positions propres au mode Raid (cle|raid, en unites absolues bas-gauche) : raid a gauche sous le micro-menu, BigWigs en haut
	rpos = { ["raid"] = { 0.0, 0.904 }, ["grouppets"] = { 0.0, 0.549 }, ["bossmods.bwbars"] = { 0.313, 0.948 }, ["bossmods.bwemph"] = { 0.281, 0.688 },
		["bossmods.bwmsg"] = { 0.813, 0.750 }, ["bossmods.bwsign"] = { 0.500, 0.792 }, ["meter.win2"] = { 0.844, 0.044 } },
	links = {
		{ "bars.bar3", "bars.main", "LEFT" }, { "bars.pet", "bars.bar2", "TOP" },
		{ "threat.win", "meter.win1", "LEFT" }, { "tracker", "meter.win1", "BOTTOM" }, { "datatext.win", "minimap", "BOTTOM" }, 
		{ "chat.tabs", "chat.main", "TOP" }, { "marks.bar", "chat.tabs", "TOP" }, { "chat.copybtn", "chat.tabs", "RIGHT", -26, 5 }, { "chat.menubtn", "chat.copybtn", "LEFT", -3, 0 },
		{ "unit.targettarget", "unit.target", "LEFT" },
		{ "auras.pb", "minimap", "LEFT", -40, 0 }, { "auras.pw", "auras.pb", "BOTTOM" }, { "castbar.player", "unit.player", "BOTTOM" },
		{ "auras.pd", "castbar.player", "BOTTOM" }, { "auras.tb", "unit.target", "TOP" }, { "castbar.target", "unit.target", "BOTTOM" },
		{ "auras.td", "castbar.target", "BOTTOM" },
	} })



-- ---------------------------------------------------------------- variantes DERIVEES de "shiki" (meme base, quelques reglages par role)
local function copyT(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do r[k] = copyT(v) end
	return r
end

local function derive(id, over)
	local base = SUI.layouts["shiki"]
	local def = { label = "mod.layout.name." .. id, reset = true, v = copyT(base.v), pos = copyT(base.pos), rpos = copyT(base.rpos), links = copyT(base.links) }
	if over.v then for k, v in pairs(over.v) do def.v[k] = v end end
	if over.pos then for k, v in pairs(over.pos) do def.pos[k] = v end end
	if over.rpos then for k, v in pairs(over.rpos) do def.rpos[k] = v end end
	if over.norpos then for i = 1, table.getn(over.norpos) do def.rpos[over.norpos[i]] = nil end end
	SUI.RegisterLayout(id, def)
end

-- Soigneur : le groupe et le raid se rapprochent du centre (au-dessus du chat), compteur et menace inchanges.
derive("shikiheal", { pos = { ["group"] = { 0.12, 0.30, 0, 0 }, ["raid"] = { 0.12, 0.30, 0, 0 } }, norpos = { "raid" } })
-- Tank : fenetre de menace plus grande, compteur plus petit, outils de tank affiches.
derive("shikitank", { v = { ["threat.width"] = 230, ["threat.height"] = 170, ["meter.height"] = 110, ["tanktools.show"] = true } })
-- Compact : tout en plus petit, pour un ecran moins grand ou un jeu plus degage.
derive("shikicompact", { v = { ["units.width"] = 170, ["actionbars.size"] = 26, ["meter.width"] = 160, ["meter.height"] = 110, ["threat.width"] = 150,
	["threat.height"] = 110, ["items.size"] = 24, ["auras.size"] = 20, ["auras.tsize"] = 20, ["chat.width"] = 340, ["chat.height"] = 120 } })

-- Profil de DEPART (installation neuve) : les modules et les reglages du profil de reference, sans donnees personnelles.
SUI.STARTER = {
	modules = { "esport", "nameplates", "groupfx", "auction", "group", "items", "messages", "buffwatch", "macros", "loot", "vendor", "cooldowns",
		"clickheal", "social", "actionbars", "datatext", "raid", "finder", "pallypower", "tracker", "castbar", "meter", "threat", "cursor",
		"powerauras", "mail", "auras", "tanktools", "skin", "bags", "bulletin" },
	v = { ["style.name"] = "graphite", ["group.manabar"] = "healers", ["chat.shortchan"] = true, ["chat.quiet"] = true, ["chat.stamp"] = false,
		["raid.dispelsize"] = 22, ["raid.dispelmode"] = "all", ["raid.iconsize"] = 16, ["raid.lowhp"] = 35, ["raid.hots"] = 3, ["raid.tankhots"] = 3,
		["raid.debuffs"] = 3, ["raid.roletag"] = true, ["raid.powerheight"] = 4, ["raid.dispelonly"] = false,
		["group.iconsize"] = 16, ["group.dispelmode"] = "all", ["group.dispelsize"] = 22, ["group.dispelonly"] = true, ["group.hots"] = 3,
		["group.tankhots"] = 3, ["group.lowhp"] = 35, ["group.solo"] = true,
		["minimap.shape"] = "square", ["minimap.clock"] = "local", ["castbar.width"] = 160, ["castbar.owidth"] = 160,
		["actionbars.bar3.perrow"] = 4, ["actionbars.bar3.scale"] = 90, ["actionbars.bar4.enabled"] = true, ["actionbars.bar4.show"] = "hover",
		["actionbars.bar5.enabled"] = true, ["actionbars.bar5.show"] = "hover", ["actionbars.stance.scale"] = 75, ["actionbars.tooltips"] = "safe",
		["actionbars.keybinds"] = false, ["actionbars.macrotext"] = false,
		["tooltip.bordercolor"] = false, ["tooltip.combathide"] = true, ["tooltip.scale"] = 0.7, ["tanktools.show"] = false,
		["units.height"] = 32, ["units.powerheight"] = 3, ["units.hptext"] = "both", ["units.focus.enabled"] = true,
		["perf.auto"] = true, ["perf.autofps"] = 45, ["perf.hud"] = true, ["meter.view1"] = "dps", ["layout.followrole"] = false,
		["social.mark"] = true, ["social.keyword"] = "inv;+1", ["loot.announcewinner"] = true, ["mover.snap"] = false, ["mover.grid"] = true },
}

function SUI.ApplyStarter()
	local st = SUI.STARTER
	for i = 1, getn(st.modules) do C.SetBase("modules." .. st.modules[i], true) end
	for k, v in pairs(st.v) do C.SetBase(k, v) end
end

-- ================================================================ COMPLEMENT : TOUS LES MODULES
-- Les 6 presets d'ecran ci-dessus placent l'essentiel ; ce bloc ajoute TOUS les autres modules positionnables
-- (sacs, chat-copie, messages, chercheur, tracker, pallypower, powerauras, butin, bijoux, courrier, HDV, HUD,
-- annonces de boss, compteur 2/3) a CHAQUE preset qui ne les couvre pas deja. Zones choisies pour eviter les
-- elements deja poses par les presets (centre libre, colonnes laterales moyennes).
local EXTRA_KEYS = { "chat.main", "bags.window", "bags.bank", "chat.copy", "messages.win", "messages.hist", "messages.badge",
	"messages.toasts", "finder.win", "tracker.win", "pp.win", "powerauras.banner", "esport.win", "loot",
	"lootwin", "lootroll", "items", "mail", "auction", "hud", "bossmods.msg", "meter.win2", "meter.win3", "chat.tabs2" }
local EXTRAS = {
	["chat.main"] = { 0.0, 0.02, 12, 40 },          -- chat TOUJOURS visible en bas-gauche apres un preset (le reset effacait sa position)
	["bags.window"] = { 0.99, 0.30, -24, 0 },       -- colonne droite, sous la zone compteur/menace
	["bags.bank"] = { 0.01, 0.30, 24, 0 },          -- colonne gauche, milieu
	["chat.copy"] = { 0.5, 0.75, 0, 0, "ct" },
	["messages.win"] = { 0.5, 0.86, 0, 0 },
	["messages.hist"] = { 0.65, 0.92, 0, 0 },
	["messages.badge"] = { 0.99, 0.70, -60, 0 },
	["messages.toasts"] = { 0.99, 0.50, -40, 0 },
	["finder.win"] = { 0.35, 0.80, 0, 0 },
	["esport.win"] = { 0.99, 0.18, -24, 0 },          -- fenetre PvP esport (colonne droite, sous la durabilite)
	["tracker.win"] = { 0.99, 0.58, -24, 0 },
	["pp.win"] = { 0.65, 0.80, 0, 0 },
	["powerauras.banner"] = { 0.5, 0.62, 0, 0 },
	["loot"] = { 0.5, 0.50, 140, 0 },
	["lootwin"] = { 0.5, 0.50, -260, 0 },
	["lootroll"] = { 0.35, 0.55, 0, 0 },
	["items"] = { 0.02, 0.12, 0, 0 },
	["mail"] = { 0.5, 0.5, 0, 0 },
	["auction"] = { 0.5, 0.5, 0, 0 },
	["hud"] = { 0.5, 0.94, 0, 0 },
	["bossmods.msg"] = { 0.5, 0.70, 0, 0 },
	["meter.win2"] = { 0.99, 0.60, -520, 0 },
	["meter.win3"] = { 0.99, 0.60, -780, 0 },
}
-- Exceptions par preset (aucune pour l'instant).
local EXTRA_TWEAK = {}
for i = 1, table.getn(SUI.layoutOrder) do
	local id = SUI.layoutOrder[i]
	local def = SUI.layouts[id]
	if def and def.pos and def.reset then
		local tweak = EXTRA_TWEAK[id]
		for j = 1, table.getn(EXTRA_KEYS) do
			local k = EXTRA_KEYS[j]
			if not def.pos[k] then
				def.pos[k] = (tweak and tweak[k]) or EXTRAS[k]
			end
		end
	end
end

-- ---------------------------------------------------------------- cadres centres : suivent un changement de largeur
-- (barre de formes / d'auras selon la classe, redimensionnement) : le centre memorise reste le centre a l'ecran.
C.cxWidth = function(key)
	local it = Layout.items[key]
	if not it or not it.frame then return nil end
	local w = it.frame:GetWidth()
	if not w or w <= 1 then return nil end
	return w * (it.frame:GetScale() or 1)
end
local function cxWatch()
	local key, it
	for key, it in pairs(Layout.items) do
		local p = C.cur and C.cur.pos and C.cur.pos[Layout.ReadKey(key)]
		if p and type(p.cx) == "number" and it.frame and not Layout.LinkedParent(key) then
			local w = C.cxWidth(key)
			if w and it.cxw ~= w then
				it.cxw = w
				Layout.Apply(key)
			end
		end
	end
end
-- (2026-11-20) Les timers socle demarrent au LOGIN (plus au load du fichier) : rien ne tourne avant
-- que le profil soit charge, et rien ne tourne du tout si aucun lien/pos.cx n'existe (economie permanente).
Layout.socleTimersStarted = false
function Layout.StartSocleTimers()
	if Layout.socleTimersStarted then return end
	Layout.socleTimersStarted = true
	Layout.pollTask = SUI.Every(Layout.POLL_FAST, pollTick, "layout.links")
	SUI.Every(2, cxWatch, "layout.cx", true)
end
SUI.On("PLAYER_LOGIN", function() SUI.WhenSafe(Layout.StartSocleTimers) end)
SUI.On("PLAYER_ENTERING_WORLD", function() SUI.After(3, cxWatch, "layout.cx0") end)
SUI.Every(2, cxWatch, "layout.cx", true)
