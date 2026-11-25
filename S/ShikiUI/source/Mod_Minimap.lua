-- ShikiUI Minimap : cadre au style choisi, forme ronde / carree, taille, zoom a la molette, coordonnees, zone coloree, heure,
-- icones autour de la minimap (addons + client) regroupees dans un tiroir, masquees ou affichees au survol (v0.4, module "minimap").
-- Principe (relu dans le pfUI installe, MIT, jamais execute par ce projet) : la Minimap est re-parentee a un cadre ShikiUI (donc
-- deplacable par SUI.Layout), les decorations Blizzard sont masquees (Hide) puis rendues a la coupure, le zoom passe par
-- Minimap_ZoomIn / Minimap_ZoomOut, les coordonnees par GetPlayerMapPosition("player").
-- Icones : mode (tiroir / survol / tout masquer) + liste blanche "minimap.keep" (noms de cadres gardes visibles, edition par la fenetre
-- /sui minimap icons ou par le menu). Rien n'est laisse par erreur : les enfants de Minimap, MinimapCluster, MinimapBackdrop et les
-- cadres d'UIParent ancres a la minimap sont recenses par une surveillance (SUI.Every 2 s : nombre d'enfants, recherche complete si
-- ca change, et toutes les 30 s), les icones du client sont retenues (Show neutralise) et re-masquees si le jeu les remontre.
-- Cout : minuteries partagees (coordonnees + heure 0,5 s ; surveillance 2 s ; survol 0,25 s seulement en mode "survol"), texte
-- reecrit seulement s'il change, aucune frame creee en combat, aucune recherche en combat.
-- Lanceur ShikiUI (v0.5) : petit bouton autour de la minimap (option minimap.launcher, angle memorise minimap.launchangle, glisser pour
-- le deplacer) : clic gauche = menu /sui, clic droit = menu rapide (modules on/off, profil, mode, style, Deplacer, aide), Maj + clic = mode
-- Deplacer, clic milieu = tiroir d'icones. Jamais range dans le tiroir (nom ShikiUI_*), pose sur l'anneau des boutons d'addons (zone reservee).
-- Visibilite conditionnelle (minimap.vis / .fade, SUI.Visibility, mode "show") et police des textes (minimap.font / .fontsize, SUI.Look).
-- NON VERIFIE en jeu : masque carre (Interface\ChatFrame\ChatFrameBackground), SetWidth / SetHeight sur la Minimap, GetChildren /
-- GetNumChildren de la Minimap et d'UIParent, MouseIsOver, noms exacts des icones du client (suivi, pierre de rencontre, chat vocal),
-- colonne des icones du client gardees a gauche du cadre, SetMapToCurrentZone a chaque changement de zone.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Minimap = M

local getn, tinsert = table.getn, table.insert
local strfind, strlower, strformat, strsub = string.find, string.lower, string.format, string.sub
local floor, mmin, mmax = math.floor, math.min, math.max

local TICK = 0.5
local WATCH = 2                 -- periode (s) de la surveillance des enfants de la minimap
local WATCH_FULL = 15           -- une recherche complete au moins toutes les 15 surveillances (30 s)
local HOVER_TICK = 0.25
local HOVER_GRACE = 0.6
local HOVER_GAP = 6            -- trou (px) couvert entre minimap et tiroir
local MAXSZ = 45
local ROWS = 12
local COORD_FMT = { "%.0f, %.0f", "%.1f, %.1f", "%.2f, %.2f" }
local PAD = 3
local MASK_ROUND = "Textures\\MinimapMask"                       -- style:ok chemin du jeu (masque rond)
local MASK_SQUARE = "Interface\\ChatFrame\\ChatFrameBackground"  -- style:ok chemin du jeu (masque carre, usage courant des addons)
-- Decors du client sans interet : masques tant que "Masquer les decors" est actif.
local DECOR = { "MinimapBorder", "MinimapBorderTop", "MinimapZoneTextButton" }
-- Icones du client (zoom, carte, suivi, calendrier, pierre de rencontre...) : listees, masquables, a garder visibles au choix.
local BLIZ = { "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapToggleButton", "GameTimeFrame", "MiniMapTrackingFrame",
	"MiniMapTracking", "MiniMapMeetingStoneFrame", "MiniMapLFGFrame", "MiniMapVoiceChatFrame" }
local BLIZ_KEY = { MinimapZoomIn = "mod.minimap.n.zoomin", MinimapZoomOut = "mod.minimap.n.zoomout",
	MiniMapWorldMapButton = "mod.minimap.n.worldmap", MinimapToggleButton = "mod.minimap.n.toggle", GameTimeFrame = "mod.minimap.n.calendar",
	MiniMapTrackingFrame = "mod.minimap.n.tracking", MiniMapTracking = "mod.minimap.n.tracking",
	MiniMapMeetingStoneFrame = "mod.minimap.n.meeting", MiniMapLFGFrame = "mod.minimap.n.lfg", MiniMapVoiceChatFrame = "mod.minimap.n.voice",
	MiniMapMailFrame = "mod.minimap.n.mail", MiniMapBattlefieldFrame = "mod.minimap.n.battle" }
-- Cadres que le tiroir ne touche jamais (prefixes, minuscules) : decors et icones du client (traites a part), cadres ShikiUI,
-- reperes et points de la carte (ce ne sont pas des boutons).
local IGNORE = { "minimapmail", "minimaptracking", "minimapbattlefield", "minimapworldmap", "minimapzoom", "minimapborder",
	"minimapzonetext", "minimaptoggle", "minimapbackdrop", "minimapcluster", "gametime", "shikiui_", "pfminimap", "questienote",
	"questie_note", "gathermatepin", "gathermate_pin", "pfquestnode", "minimapping", "minimappoi", "minimapnorth" }
-- Noms typiques d'un bouton d'addon (LibDBIcon, boutons maison) : reconnus meme sans script de clic visible.
local BTNPAT = { "libdbicon", "minimapbutton", "minimapicon", "minimapbtn", "minimap_button", "minimap_icon", "mmbutton", "sasminimap" }

M.on = false
M.active = false
M.btns = {}            -- boutons d'addons connus : { f, name, kind, parent, point, rel, relPoint, x, y, w, h, disp }
M.nbtn = 0
M.blz = {}             -- icones du client connues : { f, name, kind = "blizzard" }
M.nat = {}             -- icones courrier / file : { f, name, kind = "native" }
M.keep = {}            -- noms gardes visibles (liste blanche)
M.keepStr = nil
M.ngrp = 0             -- boutons actuellement ranges (tiroir)
M.watchN = 0
M.kidCount = -1
M.pending = false
M.lastCoord = nil
M.lastZone = nil
M.lastClock = nil
M.cfg = { shape = "round", size = 140, wheel = true, coords = true, dec = 1, zone = true, zonepvp = true, clock = "off", clutter = true,
	buttons = true, btnmode = "drawer", keep = "", cols = 4, btnsize = 28, alpha = 1, edge = true,
	launcher = true, launchangle = 165, launchsize = 22, coordpos = "bottomleft", coordshow = "always", clockpos = "bottomright",
	clockfmt = "24", zonepos = "top", trackpos = "auto", tracksize = 100 }
-- Emplacements des textes (zone, coordonnees, heure) : { point du texte, point du cadre, dx, dy }. "below" / "above" = hors du cadre.
local TEXTPOS = { top = { "TOP", "TOP", 0, -(PAD + 3) }, bottom = { "BOTTOM", "BOTTOM", 0, PAD + 2 },
	bottomleft = { "BOTTOMLEFT", "BOTTOMLEFT", PAD + 2, PAD + 2 }, bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -(PAD + 2), PAD + 2 },
	below = { "TOP", "BOTTOM", 0, -2 }, above = { "BOTTOM", "TOP", 0, 2 } }
local TRACK = { MiniMapTrackingFrame = true, MiniMapTracking = true }
local CORNER = { topleft = { "TOPLEFT", 2, -2 }, topright = { "TOPRIGHT", -2, -2 }, bottomleft = { "BOTTOMLEFT", 2, 2 },
	bottomright = { "BOTTOMRIGHT", -2, 2 } }

local function noop() end

-- Remplace Show d'un cadre retenu : le jeu peut le rappeler, on note seulement qu'il voulait l'afficher.
local function holdShow(self)
	self.suiPend = true
end

-- ---------------------------------------------------------------- liste blanche
-- "minimap.keep" = noms separes par des virgules ("LibDBIcon10_Foo,GameTimeFrame"). Table nom -> true.
function M.ParseKeep(str)
	local t = {}
	str = tostring(str or "")
	local len = string.len(str)
	local pos = 1
	while pos <= len + 1 do
		local e = strfind(str, ",", pos, true)
		local seg
		if e then
			seg = strsub(str, pos, e - 1)
			pos = e + 1
		else
			seg = strsub(str, pos)
			pos = len + 2
		end
		local trimmed = string.gsub(seg, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" then t[trimmed] = true end
	end
	return t
end

function M.KeepString(map)
	local names = {}
	for k, v in pairs(map) do
		if v then tinsert(names, k) end
	end
	table.sort(names)
	return table.concat(names, ",")
end

function M.IsKept(name)
	return name ~= nil and M.keep[name] == true
end

-- Coche / decoche une icone : ecrit la liste, l'effet est immediat (C.Watch -> ApplyOptions).
function M.SetKeep(name, on)
	if not name or name == "" then return end
	local map = {}
	for k, v in pairs(M.keep) do map[k] = v end
	map[name] = on and true or nil
	C.Set("minimap.keep", M.KeepString(map))
end

function M.ReadConfig()
	local cfg = M.cfg
	cfg.shape = C.Get("minimap.shape")
	cfg.size = C.Get("minimap.size")
	cfg.wheel = C.Get("minimap.wheel")
	cfg.coords = C.Get("minimap.coords")
	cfg.dec = C.Get("minimap.dec")
	cfg.zone = C.Get("minimap.zone")
	cfg.zonepvp = C.Get("minimap.zonepvp")
	cfg.clock = C.Get("minimap.clock")
	cfg.clutter = C.Get("minimap.clutter")
	cfg.buttons = C.Get("minimap.buttons")
	cfg.btnmode = C.Get("minimap.btnmode")
	cfg.keep = C.Get("minimap.keep")
	if cfg.keep ~= M.keepStr then
		M.keepStr = cfg.keep
		M.keep = M.ParseKeep(cfg.keep)
	end
	cfg.cols = C.Get("minimap.cols")
	cfg.btnsize = C.Get("minimap.btnsize")
	cfg.alpha = C.Get("minimap.alpha")
	cfg.edge = C.Get("minimap.edge")
	cfg.launcher = C.Get("minimap.launcher")
	cfg.launchangle = C.Get("minimap.launchangle")
	cfg.launchsize = C.Get("minimap.launchsize")
	cfg.coordpos = C.Get("minimap.coordpos")
	cfg.coordshow = C.Get("minimap.coordshow")
	cfg.clockpos = C.Get("minimap.clockpos")
	cfg.clockfmt = C.Get("minimap.clockfmt")
	cfg.zonepos = C.Get("minimap.zonepos")
	cfg.trackpos = C.Get("minimap.trackpos")
	cfg.tracksize = C.Get("minimap.tracksize")
end

-- ---------------------------------------------------------------- texte : coordonnees, zone, heure
function M.CoordText()
	local x, y = GetPlayerMapPosition("player")
	if not x or (x == 0 and y == 0) then return "--" end
	local f = COORD_FMT[floor(M.cfg.dec) + 1] or COORD_FMT[2]
	return strformat(f, x * 100, y * 100)
end

function M.UpdateCoords()
	local txt = ""
	if M.cfg.coords and (M.cfg.coordshow ~= "hover" or M.coordHover) then txt = M.CoordText() end
	if txt ~= M.lastCoord then
		M.lastCoord = txt
		M.coordText:SetText(txt)
	end
end

-- Coordonnees "au survol" : minuterie (0,25 s) seulement tant que ce mode est choisi ; le texte n'apparait que souris sur la minimap.
function M.CoordHoverTick()
	if not M.on or not M.holder or type(MouseIsOver) ~= "function" then return end
	local over = MouseIsOver(M.holder) and true or false
	if over ~= M.coordHover then
		M.coordHover = over
		M.UpdateCoords()
	end
end

function M.ApplyCoordHover()
	local want = M.on and M.active and M.cfg.coords and M.cfg.coordshow == "hover"
	if want and not M.coordTask then
		M.coordTask = SUI.Every(HOVER_TICK, M.CoordHoverTick, "minimap.coordhover")
	elseif not want and M.coordTask then
		SUI.Cancel(M.coordTask)
		M.coordTask = nil
		M.coordHover = false
	end
end

-- Heure : 24 h (defaut) ou 12 h avec am / pm.
function M.ClockText(h, m)
	if M.cfg.clockfmt == "12" then
		local h12 = SUI.Mod(h, 12)
		if h12 == 0 then h12 = 12 end
		return strformat("%d:%02d%s", h12, m, h >= 12 and "pm" or "am")
	end
	return strformat("%02d:%02d", h, m)
end

function M.UpdateClock()
	local txt = ""
	local mode = M.cfg.clock
	if mode == "local" then
		txt = M.ClockText(tonumber(date("%H")) or 0, tonumber(date("%M")) or 0)
	elseif mode == "server" then
		local h, m = GetGameTime()
		txt = M.ClockText(h, m)
	end
	if txt ~= M.lastClock then
		M.lastClock = txt
		M.clockText:SetText(txt)
	end
end

function M.ZoneColor()
	if not M.cfg.zonepvp then return T.c.text end
	local pvp = GetZonePVPInfo()
	if pvp == "friendly" or pvp == "sanctuary" then return T.c.good end
	if pvp == "hostile" or pvp == "arena" or pvp == "combat" then return T.c.bad end
	if pvp == "contested" then return T.c.warn end
	return T.c.text
end

function M.UpdateZone()
	local txt = ""
	if M.cfg.zone then txt = GetMinimapZoneText() or "" end
	local c = M.ZoneColor()
	if txt ~= M.lastZone or c ~= M.lastZoneColor then
		M.lastZone = txt
		M.lastZoneColor = c
		M.zoneText:SetText(txt)
		M.zoneText:SetTextColor(c[1], c[2], c[3], 1)
	end
end

function M.OnZone()
	local wm = getglobal("WorldMapFrame")
	if SetMapToCurrentZone and not (wm and wm:IsShown()) then SetMapToCurrentZone() end
	M.UpdateZone()
	M.UpdateCoords()
end

-- ---------------------------------------------------------------- zoom
function M.OnWheel()
	if not M.on or not M.cfg.wheel then return end
	if type(Minimap_ZoomIn) ~= "function" or type(Minimap_ZoomOut) ~= "function" then return end
	if arg1 > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end
end

-- ---------------------------------------------------------------- reconnaissance des icones
local function ignored(name)
	if type(name) ~= "string" then return false end
	local low = strlower(name)
	for i = 1, getn(IGNORE) do
		if strfind(low, IGNORE[i], 1, true) == 1 then return true end
	end
	return false
end

local function looksLikeButton(name)
	if type(name) ~= "string" then return false end
	local low = strlower(name)
	for i = 1, getn(BTNPAT) do
		if strfind(low, BTNPAT[i], 1, true) then return true end
	end
	return false
end

-- Cadre porteur sans script lui-meme (ex. SASMinimapFrame de Simple Action Sets) : le clic est sur un Button enfant.
local function clickableKid(f)
	if type(f.GetChildren) ~= "function" then return false end
	local k = { f:GetChildren() }
	for i = 1, getn(k) do
		local c = k[i]
		if c.IsObjectType and c:IsObjectType("Button") and c:GetScript("OnClick") then return true end
	end
	return false
end

local function clickable(f)
	if f:IsObjectType("Button") then
		return (f:GetScript("OnClick") or f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown")) and true or false
	end
	if f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown") then return true end
	return clickableKid(f)
end

-- Un enfant de la minimap est un bouton d'addon : nom de bouton typique (LibDBIcon, "MinimapButton"...) ou cadre de taille raisonnable
-- qui repond au clic (Button, ou Frame avec OnMouseUp / OnMouseDown) ; un Button sans nom n'est retenu que s'il a un OnClick.
-- Jamais : decors et icones du client, cadres ShikiUI, reperes de carte, cadres deja pris en charge.
function M.IsAddonButton(f)
	if f.suiGrouped or f.suiBliz or f.suiHid or f.suiOwn then return false end   -- suiOwn : bouton ShikiUI pose sur la minimap (LFG) : jamais range
	if f == M.holder or f == M.drawer or f == M.toggle or f == M.win then return false end
	local name = f:GetName()
	if name == "" then name = nil end
	if name and ignored(name) then return false end
	-- une INFOBULLE n'est jamais un bouton (ex. LibDBIconTooltip, colle aux boutons LibDBIcon) : forcee dans le tiroir,
	-- son fond vide s'affiche comme une barre sombre
	local kind = f.GetObjectType and f:GetObjectType()
	if kind == "GameTooltip" or (name and (strfind(strlower(name), "tooltip", 1, true) or strfind(strlower(name), "infobulle", 1, true))) then return false end
	if f:GetWidth() > MAXSZ or f:GetHeight() > MAXSZ then return false end
	if name and looksLikeButton(name) then return true end
	if name then
		return clickable(f) and (f:IsObjectType("Button") or f:IsObjectType("Frame"))
	end
	if not f:IsObjectType("Button") or not f:GetScript("OnClick") then return false end
	return f:GetWidth() >= 20 and f:GetHeight() >= 20
end

-- Nom court affiche pour un bouton d'addon (sans le prefixe LibDBIcon10_).
function M.ShortName(name)
	if not name then return "?" end
	local s = name
	local p = strfind(s, "LibDBIcon10_", 1, true)
	if p == 1 then s = strsub(s, 13) end
	if s == "" then s = name end
	return s
end

local function nkids(f)
	if f and type(f.GetNumChildren) == "function" then
		local n = f:GetNumChildren()
		if type(n) == "number" then return n end
	end
	return 0
end

function M.CountKids()
	return nkids(Minimap) + nkids(getglobal("MinimapCluster")) + nkids(getglobal("MinimapBackdrop")) + nkids(UIParent)
end

-- Icones du client et icones courrier / file : recensees une fois (celles qui existent), pour la liste et le masquage.
function M.CollectBliz()
	for i = 1, getn(BLIZ) do
		local name = BLIZ[i]
		local f = getglobal(name)
		if f and not f.suiBliz then
			local par = f:GetParent()
			if not (par and par.suiBliz) then
				f.suiBliz = true
				tinsert(M.blz, { f = f, name = name, kind = "blizzard", lkey = BLIZ_KEY[name] })
			end
		end
	end
	for i = 1, getn(M.NATIVE) do
		local name = M.NATIVE[i][1]
		local f = getglobal(name)
		if f and not f.suiNat then
			f.suiNat = true
			tinsert(M.nat, { f = f, name = name, kind = "native", lkey = BLIZ_KEY[name] })
		end
	end
end

function M.Scan()
	M.pending = false
	if not M.built then return 0 end
	-- purge : un enregistrement dont le cadre ne doit plus etre collecte (ex. une infobulle reconnue tardivement)
	-- est rendu a sa place d'origine et retire de la liste
	for i = M.nbtn, 1, -1 do
		local b = M.btns[i]
		local kind = b.f.GetObjectType and b.f:GetObjectType()
		local nm = b.name
		if kind == "GameTooltip" or (nm and (strfind(strlower(nm), "tooltip", 1, true) or strfind(strlower(nm), "infobulle", 1, true))) then
			if b.disp and b.disp ~= "leave" then M.Restore1(b) end
			b.f.suiGrouped = nil
			table.remove(M.btns, i)
			M.nbtn = M.nbtn - 1
		end
	end
	M.CollectBliz()
	local found = 0
	local kids = {}
	local roots = { Minimap, getglobal("MinimapCluster"), getglobal("MinimapBackdrop") }
	for r = 1, 3 do
		local root = roots[r]
		if root then
			local sub = { root:GetChildren() }
			for i = 1, getn(sub) do tinsert(kids, sub[i]) end
		end
	end
	-- beaucoup d'addons creent leur bouton sous UIParent puis l'accrochent a la minimap : on les reconnait a leur ancre
	local top = { UIParent:GetChildren() }
	local cluster = getglobal("MinimapCluster")
	for i = 1, getn(top) do
		local f = top[i]
		if f ~= M.holder and f ~= M.drawer and f ~= M.win and f.GetPoint then
			local _, rel = f:GetPoint(1)
			local nm = f:GetName()
			-- ancre a la minimap, OU bouton de minimap typique pose a des coordonnees en dur (ancre UIParent) : sinon il reste "en haut a droite"
			if rel and (rel == Minimap or rel == cluster or rel == getglobal("MinimapBackdrop")) then
				tinsert(kids, f)
			elseif type(nm) == "string" and nm ~= "" and not ignored(nm) and (looksLikeButton(nm) or strfind(strlower(nm), "minimap", 1, true)) then
				tinsert(kids, f)
			end
		end
	end
	for i = 1, getn(kids) do
		local f = kids[i]
		if M.IsAddonButton(f) then
			local point, rel, relPoint, x, y = f:GetPoint(1)
			local name = f:GetName()
			if name == "" then name = nil end
			M.nbtn = M.nbtn + 1
			local sc0 = f.GetScale and f:GetScale()
			M.btns[M.nbtn] = { f = f, name = name, kind = "addon", parent = f:GetParent(), point = point, rel = rel, relPoint = relPoint,
				x = x, y = y, w = f:GetWidth(), h = f:GetHeight(), sc0 = (type(sc0) == "number" and sc0 > 0) and sc0 or 1 }
			f.suiGrouped = true
			found = found + 1
		end
	end
	M.HookSAS()
	M.ApplyIcons()
	M.kidCount = M.CountKids()
	if M.win and M.win:IsShown() then M.RefreshList() end
	return found
end

function M.RequestScan()
	if not M.on then return end
	if SUI.InCombat() then
		M.pending = true
	else
		M.Scan()
	end
end

-- Que fait-on de ce bouton d'addon ? "leave" (laisse a sa place : liste blanche, regroupement coupe, module coupe), "drawer" (tiroir,
-- ouvert par le + ou au survol) ou "hide" (tiroir jamais ouvert tout seul : tout masquer).
function M.Disp(rec)
	local cfg = M.cfg
	if not (M.on and cfg.buttons) then return "leave" end
	if rec.name and M.keep[rec.name] then return "leave" end
	if cfg.btnmode == "hide" then return "hide" end
	return "drawer"
end

-- Rend un bouton a son parent, sa position et sa taille d'origine.
function M.Restore1(b)
	b.f:SetParent(b.parent)
	b.f:ClearAllPoints()
	if b.point then b.f:SetPoint(b.point, b.rel, b.relPoint, b.x, b.y) end
	b.f:SetWidth(b.w)
	b.f:SetHeight(b.h)
	if b.sc0 and b.f.SetScale then b.f:SetScale(b.sc0) end   -- l'echelle du tiroir est rendue (cadres non carres)
	b.disp = "leave"
	b.edge = nil
	b.edgeSet = nil
end

-- ---------------------------------------------------------------- boutons sur le bord de la minimap
-- Les addons posent leur bouton "a l'angle A" : ancre a la Minimap (rayon en dur, decalage depuis le coin) ou a MinimapCluster, voire a des
-- coordonnees d'ecran en dur. Une fois la Minimap deplacee / redimensionnee par ShikiUI, ces coordonnees ne tombent plus sur le bord (bouton
-- "en haut a droite, a cheval hors du cadre"). On retrouve donc l'angle d'origine (ancre d'origine + geometrie d'origine de la Minimap), puis
-- on ancre le bouton au CENTRE de la Minimap, au bord du cadre, a ce meme angle, en evitant le texte, les icones et les autres boutons.
local EDGE_DEF = 45                 -- angle (degres, 0 = est, 90 = nord) d'un bouton dont l'angle d'origine est inconnu
local EDGE_STEP = 3
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function normAngle(a)
	while a < 0 do a = a + 360 end
	while a >= 360 do a = a - 360 end
	return a
end

local function angDist(a, b)
	local d = normAngle(a - b)
	if d > 180 then d = 360 - d end
	return d
end

-- Decalage d'un point d'ancrage ("TOPLEFT"...) par rapport au centre d'un cadre de taille w x h.
local function anchorOffset(point, w, h)
	local dx, dy = 0, 0
	if not point then return 0, 0 end
	if strfind(point, "LEFT", 1, true) then dx = -w / 2 elseif strfind(point, "RIGHT", 1, true) then dx = w / 2 end
	if strfind(point, "TOP", 1, true) then dy = h / 2 elseif strfind(point, "BOTTOM", 1, true) then dy = -h / 2 end
	return dx, dy
end

function M.EdgeWanted()
	return M.on and M.cfg.edge and M.holder ~= nil
end

-- Angle d'origine d'un bouton (degres) deduit de son ancre d'origine ; nil si elle ne permet pas de le savoir (coordonnees d'ecran en dur).
function M.AngleOf(b)
	if not b.point or not b.rel then return nil end
	local ow, oh = 140, 140
	if M.origSize and M.origSize[1] and M.origSize[1] > 0 then ow, oh = M.origSize[1], M.origSize[2] end
	local rel = b.rel
	local rp = b.relPoint or b.point
	local ax, ay
	if rel == Minimap then
		ax, ay = anchorOffset(rp, ow, oh)
	elseif rel == M.holder then
		ax, ay = anchorOffset(rp, M.holder:GetWidth() or 0, M.holder:GetHeight() or 0)
	else
		local cluster = getglobal("MinimapCluster")
		local op = M.origPoint
		if not cluster or rel ~= cluster or not op or op[2] ~= cluster then return nil end
		local cw, ch = cluster:GetWidth(), cluster:GetHeight()
		if type(cw) ~= "number" or type(ch) ~= "number" or cw <= 0 or ch <= 0 then return nil end
		local ox1, oy1 = anchorOffset(op[3], cw, ch)
		local ox2, oy2 = anchorOffset(op[1], ow, oh)
		local mcx = ox1 + (op[4] or 0) - ox2         -- centre d'origine de la Minimap dans le repere du centre de MinimapCluster
		local mcy = oy1 + (op[5] or 0) - oy2
		local rx, ry = anchorOffset(rp, cw, ch)
		ax, ay = rx - mcx, ry - mcy
	end
	local bx, by = anchorOffset(b.point, b.w or 0, b.h or 0)
	local cx = ax + (b.x or 0) - bx
	local cy = ay + (b.y or 0) - by
	if math.abs(cx) < 0.01 and math.abs(cy) < 0.01 then return nil end
	return normAngle(math.deg(atan2(cy, cx)))
end

-- L'addon a-t-il deplace lui-meme un bouton place sur le bord (glisser-deposer de l'icone) ?
function M.MovedByAddon(b)
	local s = b.edgeSet
	if not s then return false end
	-- l'addon a rappele SetPoint avec un autre point d'ancrage (sans ClearAllPoints) : deux ancres, le cadre est deforme
	if type(b.f.GetNumPoints) == "function" and b.f:GetNumPoints() > 1 then return true end
	local p, rel, rp, x, y = b.f:GetPoint(1)
	if p ~= s[1] or rel ~= s[2] or rp ~= s[3] then return true end
	return math.abs((x or 0) - s[4]) > 0.5 or math.abs((y or 0) - s[5]) > 0.5
end

-- Nouvelle ancre d'origine = celle que l'addon vient de poser ; l'angle est recalcule.
function M.Learn(b)
	local idx = 1
	if type(b.f.GetNumPoints) == "function" then
		local n = b.f:GetNumPoints()
		if n > 1 then idx = n end                -- l'ancre la plus recente est la derniere
	end
	local p, rel, rp, x, y = b.f:GetPoint(idx)
	if not p then return end
	b.point, b.rel, b.relPoint, b.x, b.y = p, rel, rp, x, y
	b.edgeSet = nil
	local a = M.AngleOf(b)
	if a then b.ang = a end
end

-- Simple Action Sets repose son bouton avec SASMinimap_PosUpdate (a chaque image du glissement, et depuis ses options) : on enveloppe cette
-- fonction pour reprendre le bouton aussitot sur le bord (sinon il reste hors de la minimap jusqu'a la prochaine surveillance).
function M.OnAddonMoved(f)
	if not (M.on and M.built) or SUI.InCombat() then return end
	for i = 1, M.nbtn do
		local b = M.btns[i]
		if b.f == f and b.edge and M.MovedByAddon(b) then
			M.Learn(b)
			M.Arrange()
			return
		end
	end
end

function M.SASWrapped()
	local o = M.sasOrig
	if type(o) == "function" then o() end
	if M.on then M.OnAddonMoved(getglobal("SASMinimapFrame")) end
end

function M.HookSAS()
	local g = getglobal("SASMinimap_PosUpdate")
	if type(g) ~= "function" or g == M.SASWrapped then return end
	M.sasOrig = g
	setglobal("SASMinimap_PosUpdate", M.SASWrapped)
end

-- Centre (x, y) d'un element pose dans le coin "corner" d'un cadre de demi-cote "half", pour un element de demi-taille hs.
local function cornerCenter(corner, half, hs)
	local x, y = half - hs, half - hs
	if corner == "TOPLEFT" or corner == "BOTTOMLEFT" then x = -x end
	if corner == "BOTTOMLEFT" or corner == "BOTTOMRIGHT" then y = -y end
	return x, y
end

-- Zones occupees par du texte / des icones du cadre : { angle central, demi-largeur (degres) } pour un bouton de largeur w a la distance r.
function M.Reserved(half, r, w)
	local out = {}
	local function add(cx, cy, ext)
		if math.abs(cx) < 0.01 and math.abs(cy) < 0.01 then return end
		local hw = math.deg((ext + w / 2 + 2) / r)
		tinsert(out, { normAngle(math.deg(atan2(cy, cx))), hw })
	end
	local function width(fs, def)
		local sw = fs and fs.GetStringWidth and fs:GetStringWidth()
		if type(sw) ~= "number" or sw <= 0 then sw = def end
		if sw > 120 then sw = 120 end
		return sw
	end
	local cfg = M.cfg
	if cfg.zone then add(0, half - 4, width(M.zoneText, 80) / 2) end
	if cfg.coords then
		local wc = width(M.coordText, 56)
		add(-half + PAD + 2 + wc / 2, -half + PAD + 7, wc / 2)
	end
	if cfg.clock ~= "off" then
		local wk = width(M.clockText, 30)
		add(half - PAD - 2 - wk / 2, -half + PAD + 7, wk / 2)
	end
	local ln = M.launcher
	if ln and ln:IsShown() then
		local lx, ly = M.EdgeXY(M.cfg.launchangle, r)
		add(lx, ly, M.cfg.launchsize / 2)
	end
	local n = M.ncfg
	local tg = M.toggle
	if tg and tg:IsShown() and CORNER[n.togglepos] then
		local ts = n.togglesize
		local cx, cy = cornerCenter(CORNER[n.togglepos][1], half, ts / 2)
		add(cx, cy, ts / 2)
	end
	for i = 1, getn(M.NATIVE) do
		local f = getglobal(M.NATIVE[i][1])
		local pos = n[M.NATIVE[i][2]]
		if f and CORNER[pos] and f:IsShown() then
			local hs = n.iconsize / 2
			local cx, cy = cornerCenter(CORNER[pos][1], half, hs)
			add(cx, cy, hs)
		end
	end
	return out
end

-- Premier angle libre en partant de celui voulu (decalages 0, +3, -3, +6...) : hors des zones reservees et des boutons deja poses.
local function freeAngle(want, placed, np, reserved, sep)
	for k = 0, 120 do
		local step = floor((k + 1) / 2) * EDGE_STEP
		if SUI.Mod(k, 2) == 0 then step = -step end
		local a = normAngle(want + step)
		local ok = true
		for i = 1, getn(reserved) do
			if angDist(a, reserved[i][1]) < reserved[i][2] then ok = false break end
		end
		if ok then
			for i = 1, np do
				if angDist(a, placed[i]) < sep then ok = false break end
			end
		end
		if ok then return a end
	end
	return want
end

-- Position (par rapport au centre) d'un point du bord a l'angle donne : cercle (ronde) ou carre (carree), a "r" du centre.
function M.EdgeXY(angle, r)
	local rad = math.rad(angle)
	local c, s = math.cos(rad), math.sin(rad)
	if M.cfg.shape == "square" then
		local m = math.abs(c)
		if math.abs(s) > m then m = math.abs(s) end
		if m > 0 then return c * r / m, s * r / m end
	end
	return c * r, s * r
end

function M.PlaceEdge(list, count)
	if count <= 0 then return end
	local half = M.cfg.size / 2
	local r = half + PAD
	local wmax = 16
	for i = 1, count do
		local b = list[i]
		if not b.ang then b.ang = M.AngleOf(b) or EDGE_DEF end
		local w = b.w
		if type(w) ~= "number" or w < 16 then w = 16 end
		if w > wmax then wmax = w end
	end
	local reserved = M.Reserved(half, r, wmax)
	local sep = math.deg((wmax + 2) / r)
	table.sort(list, function(a, b) return a.ang < b.ang end)
	local placed = {}
	local np = 0
	for i = 1, count do
		local b = list[i]
		local a = freeAngle(b.ang, placed, np, reserved, sep)
		np = np + 1
		placed[np] = a
		local x, y = M.EdgeXY(a, r)
		local f = b.f
		f:SetParent(Minimap)
		f:SetFrameStrata("MEDIUM")
		f:SetFrameLevel(Minimap:GetFrameLevel() + 6)
		f:ClearAllPoints()
		f:SetPoint("CENTER", Minimap, "CENTER", x, y)
		b.edge = true
		b.edgeSet = { "CENTER", Minimap, "CENTER", x, y }
	end
end

function M.Arrange()
	if not M.drawer then return end
	local cfg = M.cfg
	local sz = cfg.btnsize
	local cols = cfg.cols
	local rows = 1
	local n = 0
	local nedge = 0
	local edgeList = {}
	for i = 1, M.nbtn do
		local b = M.btns[i]
		local d = M.Disp(b)
		if d == "leave" then
			if b.disp and b.disp ~= "leave" then M.Restore1(b) end
			if M.EdgeWanted() then
				if b.edge and M.MovedByAddon(b) then M.Learn(b) end
				nedge = nedge + 1
				edgeList[nedge] = b
			elseif b.edge then
				M.Restore1(b)
			end
		else
			b.edge = nil
			b.edgeSet = nil
			b.disp = d
			local col = SUI.Mod(n, cols)
			local row = floor(n / cols)
			b.f:SetParent(M.drawer)
			b.f:SetFrameStrata("HIGH")   -- sinon un bouton de strate plus basse reste cache derriere le fond du tiroir
			b.f:SetFrameLevel(M.drawer:GetFrameLevel() + 2)
			b.f:ClearAllPoints()
			b.f:SetPoint("TOPLEFT", M.drawer, "TOPLEFT", PAD + col * (sz + PAD), -PAD - row * (sz + PAD))
			-- Cadre non carre (ex. TWBGQueueMinimapMenuFrame, un menu de 40x32) : forcer un carre faisait deborder son
			-- contenu (la "barre"). Ses proportions d'origine sont conservees, ramenees a l'echelle du slot par SetScale
			-- (les enfants suivent l'echelle : rien ne deborde) et l'ensemble est centre dans le slot.
			if b.w ~= b.h and b.w > 0 and b.h > 0 then
				b.f:SetWidth(b.w)
				b.f:SetHeight(b.h)
				local sc = mmin(sz / b.w, sz / b.h)
				if sc > 1 then sc = 1 end
				if b.f.SetScale then b.f:SetScale(sc) end
				local ew = floor(b.w * sc + 0.5)
				local eh = floor(b.h * sc + 0.5)
				b.f:SetPoint("TOPLEFT", M.drawer, "TOPLEFT", PAD + col * (sz + PAD) + floor((sz - ew) / 2 + 0.5),
					-(PAD + row * (sz + PAD)) - floor((sz - eh) / 2 + 0.5))
				n = n + 1
				if row + 1 > rows then rows = row + 1 end
			else
				b.f:SetWidth(sz)
				b.f:SetHeight(sz)
				-- Certains addons reprennent la main sur la taille de leur bouton (largeur/hauteur imposees) : force dans le tiroir,
				-- un tel cadre y reste une "barre" qui deborde. On le rend alors a sa place d'origine et il ne compte pas dans la grille.
				local gw, gh = b.f:GetWidth(), b.f:GetHeight()
				if type(gw) ~= "number" or type(gh) ~= "number" or floor(gw + 0.5) ~= sz or floor(gh + 0.5) ~= sz then
					M.Restore1(b)
				else
					n = n + 1
					if row + 1 > rows then rows = row + 1 end
				end
			end
		end
	end
	M.PlaceEdge(edgeList, nedge)
	M.ngrp = n
	local used = n
	if used > cols then used = cols end
	if used < 1 then used = 1 end
	M.drawer:SetWidth(PAD + used * (sz + PAD))
	M.drawer:SetHeight(PAD + rows * (sz + PAD))
end

-- Rend chaque bouton a son parent, sa position et sa taille d'origine.
function M.RestoreButtons()
	for i = 1, M.nbtn do
		local b = M.btns[i]
		if b.disp and b.disp ~= "leave" then M.Restore1(b) end
	end
end

function M.ToggleDrawer()
	if not M.drawer then return end
	M.hoverOpen = false
	if not M.drawer:IsShown() and not SUI.InCombat() then M.Scan() end   -- boutons crees apres le demarrage
	M.Arrange()   -- le fond du tiroir suit TOUJOURS le contenu (jamais de bande vide d'un affichage precedent)
	if M.drawer:IsShown() then M.drawer:Hide() else M.drawer:Show() end
end

-- ---------------------------------------------------------------- icones du client : masquage, conservation, colonne
-- Retient (hide = true) ou rend un cadre du client : Show est neutralise tant qu'il est retenu, son etat d'origine est rendu ensuite.
function M.SetHeld(f, hide)
	if hide then
		if not f.suiHid then
			f.suiHid = true
			f.suiWas = f:IsShown() and true or false
			f.suiShowFn = f.Show
			f.Show = holdShow
		end
		f:Hide()
	elseif f.suiHid then
		f.suiHid = nil
		f.Show = f.suiShowFn
		if f.suiWas or f.suiPend then f:Show() end
		f.suiPend = nil
	end
end

-- Une icone du client est masquee si le module est actif, qu'elle n'est pas gardee, et que les decors sont masques ou "tout masquer".
function M.BlizHidden(name)
	local cfg = M.cfg
	if not M.on then return false end
	if M.keep[name] then return false end
	if TRACK[name] and cfg.trackpos ~= "auto" then return false end   -- un coin choisi pour le suivi = on le veut visible
	if cfg.clutter then return true end
	return cfg.buttons and cfg.btnmode == "hide"
end

-- Icones du client laissees visibles : rangees en colonne a gauche du cadre (la minimap n'est plus a l'ancre d'origine du jeu).
function M.PlaceBliz(r, y)
	local f = r.f
	if not r.o then
		local p, rel, rp, x, yy = f:GetPoint(1)
		r.o = { p = p, rel = rel, rp = rp, x = x, y = yy, parent = f:GetParent() }
	end
	if not r.o.p then return y end
	local tp = TRACK[r.name] and M.cfg.trackpos or "auto"
	if tp ~= "auto" and CORNER[tp] then
		-- suivi : dans le coin choisi de la minimap, a la taille choisie (parent, niveau et echelle d'origine gardes)
		if not r.o.level then r.o.level, r.o.scale = f:GetFrameLevel(), f:GetScale() or 1 end
		local k = (M.cfg.tracksize or 100) / 100
		f:SetParent(M.holder)
		f:SetFrameLevel(Minimap:GetFrameLevel() + 6)
		f:SetScale(k)
		f:ClearAllPoints()
		local c = CORNER[tp]
		f:SetPoint(c[1], M.holder, c[1], c[2] / k, c[3] / k)
		r.placed, r.corner = true, true
		return y
	end
	if r.corner then M.UnplaceBliz(r) end
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", M.holder, "TOPLEFT", -2, y)
	r.placed = true
	local h = f:GetHeight()
	if h < 16 then h = 16 end
	return y - h - 2
end

function M.UnplaceBliz(r)
	if not r.placed then return end
	r.placed = nil
	local o = r.o
	if r.corner then
		r.corner = nil
		if o and o.level then
			r.f:SetParent(o.parent)
			r.f:SetFrameLevel(o.level)
			r.f:SetScale(o.scale or 1)
		end
	end
	r.f:ClearAllPoints()
	if o and o.p then r.f:SetPoint(o.p, o.rel, o.rp, o.x, o.y) end
end

function M.ApplyBliz()
	if not M.holder then return end
	local on = M.on
	for i = 1, getn(DECOR) do
		local f = getglobal(DECOR[i])
		if f then M.SetHeld(f, on and M.cfg.clutter) end
	end
	local y = -2
	for i = 1, getn(M.blz) do
		local r = M.blz[i]
		local hide = M.BlizHidden(r.name)
		M.SetHeld(r.f, hide)
		if on and not hide then
			y = M.PlaceBliz(r, y)
		else
			M.UnplaceBliz(r)
		end
	end
end

-- Tout ce qui concerne les icones : client, courrier / file, tiroir, survol.
function M.ApplyIcons()
	M.ApplyBliz()
	M.StyleNativeIcons()
	M.Arrange()
	M.ApplyHover()
end

-- Nom de l'icone pour l'affichage.
function M.RecLabel(r)
	if r.lkey then return L(r.lkey) end
	if r.name then return M.ShortName(r.name) end
	return L("mod.minimap.noname")
end

-- ---------------------------------------------------------------- tiroir au survol
function M.ApplyHover()
	local want = M.on and M.cfg.buttons and M.cfg.btnmode == "hover" and M.drawer ~= nil
	if want and not M.hoverTask then
		M.hoverTask = SUI.Every(HOVER_TICK, M.HoverTick, "minimap.hover")
	elseif not want and M.hoverTask then
		SUI.Cancel(M.hoverTask)
		M.hoverTask = nil
	end
end

function M.HoverTick()
	local d = M.drawer
	if not d or not M.on or type(MouseIsOver) ~= "function" then return end
	-- marges : le trou entre la minimap et le tiroir est couvert (sinon le tiroir se referme en le traversant)
	local over = MouseIsOver(M.holder, 4, -(HOVER_GAP + 4), -4, 4)
	if not over and d:IsShown() then over = MouseIsOver(d, HOVER_GAP + 4, -4, -4, 4) end
	if over then
		M.leaveAt = nil
		if not d:IsShown() then
			if not SUI.InCombat() then M.Scan() end   -- boutons crees apres le demarrage (comme au clic)
			M.Arrange()
			if M.ngrp > 0 then
				d:Show()
				M.hoverOpen = true
			end
		end
	elseif d:IsShown() and M.hoverOpen then
		local now = GetTime()
		if not M.leaveAt then
			M.leaveAt = now + HOVER_GRACE
		elseif now >= M.leaveAt then
			d:Hide()
			M.hoverOpen = false
			M.leaveAt = nil
		end
	end
end

-- ---------------------------------------------------------------- surveillance (boutons crees tardivement, jeu qui remontre une icone)
function M.Enforce()
	local redo = false
	for i = 1, M.nbtn do
		local b = M.btns[i]
		if b.edge then
			if M.MovedByAddon(b) or b.f:GetParent() ~= Minimap then redo = true end
		elseif b.disp and b.disp ~= "leave" then
			if b.f:GetParent() ~= M.drawer then
				redo = true
			else
				local _, rel = b.f:GetPoint(1)
				if rel ~= M.drawer then redo = true end
			end
		end
	end
	if redo then M.Arrange() end
	for i = 1, getn(M.blz) do
		local f = M.blz[i].f
		if f.suiHid and f:IsShown() then f:Hide() end
	end
	for i = 1, getn(DECOR) do
		local f = getglobal(DECOR[i])
		if f and f.suiHid and f:IsShown() then f:Hide() end
	end
end

function M.Watch()
	if not M.built or not M.on then return end
	M.watchN = M.watchN + 1
	if SUI.InCombat() then return end
	local n = M.CountKids()
	if n ~= M.kidCount or SUI.Mod(M.watchN, WATCH_FULL) == 0 then
		M.Scan()
	end
	M.Enforce()
end

-- ---------------------------------------------------------------- liste des icones (fenetre a cases a cocher)
-- Toutes les icones connues : addons, client, courrier / file ; triees (addons d'abord, puis alphabetique).
function M.List()
	local list = {}
	for i = 1, M.nbtn do tinsert(list, M.btns[i]) end
	for i = 1, getn(M.blz) do tinsert(list, M.blz[i]) end
	for i = 1, getn(M.nat) do tinsert(list, M.nat[i]) end
	for i = 1, getn(list) do
		local r = list[i]
		local rank = "1"
		if r.kind == "blizzard" then rank = "2" elseif r.kind == "native" then rank = "3" end
		r.sort = rank .. strlower(M.RecLabel(r))
	end
	table.sort(list, function(a, b) return a.sort < b.sort end)
	return list
end

function M.KindText(r)
	if r.kind == "addon" then return L("mod.minimap.kind.addon") end
	if r.kind == "native" then return L("mod.minimap.kind.native") end
	return L("mod.minimap.kind.blizzard")
end

function M.OnRowCheck(row, on)
	local r = row.rec
	if r and r.name then M.SetKeep(r.name, on) end
end

function M.BuildWindow()
	if M.win then return end
	local w = T.Panel(UIParent, 340, 66 + ROWS * 22)
	w:SetFrameStrata("FULLSCREEN_DIALOG")
	w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	w:SetClampedToScreen(true)
	w:SetMovable(true)
	w:EnableMouse(true)
	w:SetScript("OnMouseDown", function() this:StartMoving() end)
	w:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
	w:Hide()
	M.win = w
	w.title = T.Text(w, 12, T.c.text, "LEFT")
	w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -8)
	w.hint = T.Text(w, 10, T.c.dim, "LEFT")
	w.hint:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -26)
	w.close = T.Button(w, "x", 18, 18, function() M.win:Hide() end)
	w.close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -6)
	w.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("Frame", nil, w)
		row:SetWidth(318)
		row:SetHeight(20)
		row:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -44 - (i - 1) * 22)
		row.check = T.Check(row, function(on) M.OnRowCheck(row, on) end)
		row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name = T.Text(row, 11, T.c.text, "LEFT")
		row.name:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
		row.kind = T.Text(row, 10, T.c.dim, "RIGHT")
		row.kind:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		w.rows[i] = row
	end
	w.prev = T.Button(w, "<", 22, 18, function() M.ListPage(-1) end)
	w.prev:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 10, 8)
	w.next = T.Button(w, ">", 22, 18, function() M.ListPage(1) end)
	w.next:SetPoint("LEFT", w.prev, "RIGHT", 4, 0)
	w.pageText = T.Text(w, 10, T.c.dim, "LEFT")
	w.pageText:SetPoint("LEFT", w.next, "RIGHT", 8, 0)
	w.scan = T.Button(w, "", 110, 18, function() M.RescanNow() end)
	w.scan:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -10, 8)
	M.page = 1
end

function M.ListPage(d)
	M.page = (M.page or 1) + d
	M.RefreshList()
end

function M.RescanNow()
	if SUI.InCombat() then
		SUI.Print(L("msg.minimap.combat"))
		return
	end
	M.Scan()
	M.RefreshList()
end

function M.RefreshList()
	local w = M.win
	if not w then return end
	local list = M.List()
	local n = getn(list)
	local pages = floor((n + ROWS - 1) / ROWS)
	if pages < 1 then pages = 1 end
	if M.page > pages then M.page = pages end
	if M.page < 1 then M.page = 1 end
	w.title:SetText(L("mod.minimap.win.title"))
	w.hint:SetText(L("mod.minimap.win.hint"))
	T.SetButtonText(w.scan, L("mod.minimap.win.scan"))
	w.pageText:SetText(strformat("%d / %d  (%d)", M.page, pages, n))
	for i = 1, ROWS do
		local row = w.rows[i]
		local r = list[(M.page - 1) * ROWS + i]
		row.rec = r
		if r then
			row.name:SetText(M.RecLabel(r))
			row.kind:SetText(M.KindText(r))
			if r.name then
				T.SetCheck(row.check, M.keep[r.name] == true)
				row.check:Show()
			else
				row.check:Hide()
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

function M.OpenList()
	if not M.built then
		SUI.Print(L("msg.minimap.notready"))
		return
	end
	if not M.on then
		SUI.Print(L("msg.minimap.notready"))
		return
	end
	if SUI.InCombat() then
		SUI.Print(L("msg.minimap.combat"))
		return
	end
	M.Scan()
	M.BuildWindow()
	M.RefreshList()
	M.win:Show()
end

-- ---------------------------------------------------------------- application des reglages
-- Pose un texte a l'emplacement choisi (jamais re-ancre si rien n'a change).
local function placeOne(fs, pos, def)
	local d = TEXTPOS[pos] or TEXTPOS[def]
	fs:ClearAllPoints()
	fs:SetPoint(d[1], M.holder, d[2], d[3], d[4])
end

function M.PlaceTexts()
	local cfg = M.cfg
	local sig = cfg.zonepos .. "/" .. cfg.coordpos .. "/" .. cfg.clockpos
	if sig == M.textSig then return end
	M.textSig = sig
	placeOne(M.zoneText, cfg.zonepos, "top")
	placeOne(M.coordText, cfg.coordpos, "bottomleft")
	placeOne(M.clockText, cfg.clockpos, "bottomright")
end

function M.ApplyOptions()
	if not M.built then return end
	local cfg = M.cfg
	local on = M.on
	local size = cfg.size
	M.holder:SetWidth(size + 2 * PAD)
	M.holder:SetHeight(size + 2 * PAD)
	if on then
		Minimap:SetWidth(size)
		Minimap:SetHeight(size)
		Minimap:SetMaskTexture(cfg.shape == "square" and MASK_SQUARE or MASK_ROUND)
		local V = SUI.Visibility
		if V and V.byFrame[M.holder] then V.SetBase(M.holder, cfg.alpha) else M.holder:SetAlpha(cfg.alpha) end
		if not V or V.Allowed(M.holder) then M.holder:Show() end
	else
		Minimap:SetMaskTexture(MASK_ROUND)
		M.holder:Hide()
	end
	Minimap:EnableMouseWheel(on and cfg.wheel and true or false)
	if on and cfg.coords then M.coordText:Show() else M.coordText:Hide() end
	if on and cfg.zone then M.zoneText:Show() else M.zoneText:Hide() end
	if on and cfg.clock ~= "off" then M.clockText:Show() else M.clockText:Hide() end
	if cfg.btnmode ~= M.lastMode or not (on and cfg.buttons) then
		M.lastMode = cfg.btnmode
		M.hoverOpen = false
		M.drawer:Hide()
	end
	M.PlaceTexts()
	M.ApplyIcons()
	M.LaunchApply()
	M.ApplyCoordHover()
	M.lastCoord, M.lastClock, M.lastZone = nil, nil, nil
	if on then
		M.UpdateCoords()
		M.UpdateClock()
		M.UpdateZone()
	end
end

-- ---------------------------------------------------------------- construction (une seule fois, hors combat)
-- Icones natives (courrier, champ de bataille / file) : ancrees a un coin de la minimap ShikiUI, sans l'anneau dore, avec le fond du style.
M.NATIVE = { { "MiniMapMailFrame", "mailpos", "MiniMapMailBorder", "MiniMapMailIcon" },
	{ "MiniMapBattlefieldFrame", "bgpos", "MiniMapBattlefieldBorder", "MiniMapBattlefieldIcon" } }
local NATIVE = M.NATIVE
M.ncfg = { mailpos = "topright", bgpos = "topleft", iconsize = 24, togglepos = "topleft", togglesize = 16, togglex = 0, toggley = 0 }

-- Rend une icone native a son etat d'origine (parent, ancre, echelle, anneau, decoupe, fond) : reglage "origine" ou module coupe.
function M.RestoreNative(f, def)
	local o = f.suiOrig
	f.SetPoint, f.ClearAllPoints = f.suiSetPoint, f.suiClear
	f.Show = f.suiShow
	f.suiStyled = nil
	M.NativeUnhold(f)
	if not o then return end
	f:SetParent(o.parent)
	f:SetFrameLevel(o.level)
	f:SetScale(o.scale or 1)
	f:ClearAllPoints()
	if o.p then f:SetPoint(o.p, o.rel, o.rp, o.x, o.y) end
	local b = getglobal(def[3])
	if b then b:Show() end
	local ic = getglobal(def[4])
	if ic and ic.SetTexCoord then ic:SetTexCoord(0, 1, 0, 1) end
	local bg = { T.c.bg[1], T.c.bg[2], T.c.bg[3], 0 }
	local bd = { T.c.border[1], T.c.border[2], T.c.border[3], 0 }
	T.Backdrop(f, bg, bd)
	local hnm = getglobal("HasNewMail")
	if type(hnm) == "function" and def[2] == "mailpos" and hnm() then f:Show() end
end

-- Fin du masquage d'une icone native : elle revient si elle etait affichee, ou si le jeu a voulu l'afficher entre-temps.
function M.NativeUnhold(f)
	if not f.suiNatHid then return end
	f.suiNatHid = nil
	local show = f.suiNatWas or f.suiPend
	local hnm = getglobal("HasNewMail")
	if f == getglobal("MiniMapMailFrame") and type(hnm) == "function" then show = hnm() and true or false end   -- courrier lu pendant le masquage
	if show then f:Show() end
	f.suiPend = nil
end

-- Position effective d'une icone native : le choix du menu, sauf "tout masquer" (sans liste blanche) qui la cache.
function M.NativePos(def)
	local pos = M.ncfg[def[2]]
	if M.on and M.cfg.buttons and M.cfg.btnmode == "hide" and not M.keep[def[1]] then pos = "hide" end
	return pos
end

function M.StyleNativeIcons()
	local n = M.ncfg
	n.mailpos = C.Get("minimap.mailpos")
	n.bgpos = C.Get("minimap.bgpos")
	n.iconsize = C.Get("minimap.iconsize")
	n.togglepos = C.Get("minimap.togglepos")
	n.togglesize = C.Get("minimap.togglesize")
	n.togglex = C.Get("minimap.togglex")
	n.toggley = C.Get("minimap.toggley")
	if not M.holder then return end
	local k = n.iconsize / 33
	for i = 1, getn(NATIVE) do
		local f = getglobal(NATIVE[i][1])
		local pos = M.NativePos(NATIVE[i])
		if f then
			if M.on and pos ~= "default" then
				if not f.suiStyled then
					f.suiStyled = true
					f.suiShow = f.Show
					f.suiSetPoint, f.suiClear = f.SetPoint, f.ClearAllPoints
					local p, rel, rp, x, y = f:GetPoint(1)
					f.suiOrig = { parent = f:GetParent(), level = f:GetFrameLevel(), scale = f:GetScale(), p = p, rel = rel, rp = rp,
						x = x, y = y }
					local b = getglobal(NATIVE[i][3])
					if b then b:Hide() end
					local ic = getglobal(NATIVE[i][4])
					if ic and ic.SetTexCoord then ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
					T.Backdrop(f, T.c.bg, T.c.border)
				end
				f.SetPoint, f.ClearAllPoints = f.suiSetPoint, f.suiClear
				f:SetParent(M.holder)
				f:SetFrameLevel(Minimap:GetFrameLevel() + 6)
				f:SetScale(k)
				f:ClearAllPoints()
				if pos == "hide" then
					if not f.suiNatHid then
						f.suiNatHid = true
						f.suiNatWas = f:IsShown() and true or false
					end
					f:Hide()
					f.Show = holdShow
				else
					f.Show = f.suiShow
					M.NativeUnhold(f)
					local c = CORNER[pos] or CORNER.topright
					f:SetPoint(c[1], M.holder, c[1], c[2] / k, c[3] / k)
				end
				f.SetPoint = noop
				f.ClearAllPoints = noop
			elseif f.suiStyled then
				M.RestoreNative(f, NATIVE[i])
			end
		end
	end
	-- bouton "+" du tiroir : coin, taille et decalage au choix ; seulement en mode "tiroir" (survol : le tiroir s'ouvre seul)
	local tg = M.toggle
	if tg then
		if not M.on or not M.cfg.buttons or M.cfg.btnmode ~= "drawer" or n.togglepos == "hide" then
			tg:Hide()
		else
			local c = CORNER[n.togglepos] or CORNER.topleft
			tg:SetWidth(n.togglesize)
			tg:SetHeight(n.togglesize)
			tg:ClearAllPoints()
			tg:SetPoint(c[1], M.holder, c[1], c[2] + n.togglex, c[3] + n.toggley)
			tg:Show()
		end
	end
end

function M.Build()
	if M.built then return end
	if not getglobal("Minimap") then return end            -- pas d'interface Blizzard (hors jeu) : le module reste inactif
	local holder = CreateFrame("Frame", "ShikiUI_Minimap", UIParent)
	holder:SetFrameStrata("LOW")
	T.Backdrop(holder, T.c.bg, T.c.border)
	M.holder = holder
	M.origParent = Minimap:GetParent()
	M.origSize = { Minimap:GetWidth(), Minimap:GetHeight() }
	local p, rel, rp, x, y = Minimap:GetPoint(1)
	M.origPoint = { p, rel, rp, x, y }
	Minimap:SetParent(holder)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("CENTER", holder, "CENTER", 0, 0)
	Minimap:SetScript("OnMouseWheel", M.OnWheel)
	M.coordText = T.Text(holder, 10, T.c.text, "LEFT", true)
	M.coordText:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PAD + 2, PAD + 2)
	M.zoneText = T.Text(holder, 11, T.c.text, "CENTER", true)
	M.zoneText:SetPoint("TOP", holder, "TOP", 0, -(PAD + 3))
	M.clockText = T.Text(holder, 10, T.c.dim, "RIGHT", true)
	M.clockText:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -(PAD + 2), PAD + 2)
	SUI.Look.ApplyText(M.coordText, "minimap", 10, true)
	SUI.Look.ApplyText(M.zoneText, "minimap", 11, true)
	SUI.Look.ApplyText(M.clockText, "minimap", 10, true)
	-- tiroir des boutons d'addons
	local drawer = T.Panel(UIParent, 100, 40)
	drawer:SetFrameStrata("HIGH")
	drawer:SetPoint("TOP", holder, "BOTTOM", 0, -4)
	drawer:Hide()
	M.drawer = drawer
	local tg = T.Button(holder, "+", 16, 16, function() M.ToggleDrawer() end)
	tg:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
	M.toggle = tg
	tg:SetFrameStrata("MEDIUM")   -- au-dessus de la minimap, sinon le clic est avale
	tg:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	SUI.Layout.Register(holder, "minimap", "TOPRIGHT", -20, -20)
	M.built = true
	M.ReadConfig()
	M.CollectBliz()
	if not M.watching then
		M.watching = true
		C.Watch("minimap.", M.OnKey)
		T.OnAccent(M.OnStyle)
	end
	if M.on then M.Activate() end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- lanceur ShikiUI et menu rapide
-- Le lanceur est un petit bouton pose sur l'anneau de la minimap, a l'angle minimap.launchangle (0 = est, 90 = nord). Il est cree a la
-- demande (option active, hors combat) et enfant du cadre ShikiUI : il suit la visibilite, la position et l'opacite de la minimap.
local QW = 212              -- largeur du menu rapide
local QPER = 8              -- modules par page
local QPAD = 6
local LN_TIPS = { "left", "right", "shift", "middle", "drag" }

local function shiftDown()
	local f = getglobal("IsShiftKeyDown")
	return type(f) == "function" and f() and true or false
end

-- Angle (degres) du curseur autour du centre de la minimap ; nil si inconnu.
function M.CursorAngle()
	local gc = getglobal("GetCursorPosition")
	if type(gc) ~= "function" or not M.holder then return nil end
	local cx, cy = gc()
	local mx, my = M.holder:GetCenter()
	if type(cx) ~= "number" or type(cy) ~= "number" or type(mx) ~= "number" or type(my) ~= "number" then return nil end
	local sc = M.holder:GetEffectiveScale()
	if type(sc) ~= "number" or sc <= 0 then sc = 1 end
	local dx, dy = cx / sc - mx, cy / sc - my
	if math.abs(dx) < 1 and math.abs(dy) < 1 then return nil end
	return normAngle(math.deg(atan2(dy, dx)))
end

function M.LaunchPlace(angle)
	local ln = M.launcher
	if not ln or not M.holder then return end
	local x, y = M.EdgeXY(angle or M.cfg.launchangle, M.cfg.size / 2 + PAD)
	ln:ClearAllPoints()
	ln:SetPoint("CENTER", M.holder, "CENTER", x, y)
end

function M.LaunchEnter()
	local b = this
	if M.lnDrag or not GameTooltip then return end
	GameTooltip:SetOwner(b, "ANCHOR_LEFT")
	local c, d = T.c.text, T.c.dim
	GameTooltip:AddLine(L("mod.minimap.ln.title", SUI.VERSION), c[1], c[2], c[3])
	local md = SUI.Mode and SUI.Mode.Name(C.mode) or tostring(C.mode)
	GameTooltip:AddLine(L("mod.minimap.ln.state", tostring(C.curName), md), d[1], d[2], d[3])
	for i = 1, getn(LN_TIPS) do
		GameTooltip:AddLine(L("mod.minimap.ln." .. LN_TIPS[i]), c[1], c[2], c[3], 1)
	end
	GameTooltip:Show()
end

function M.LaunchLeave()
	if GameTooltip then GameTooltip:Hide() end
end

function M.LaunchDown()
	M.lnMoved = false
end

function M.LaunchClick(b, btn)
	if M.lnMoved then
		M.lnMoved = false
		return
	end
	if btn == "RightButton" then
		M.QToggle(b)
		return
	end
	M.QClose()
	if btn == "MiddleButton" then
		M.ToggleDrawer()
	elseif shiftDown() then
		if SUI.Mover then SUI.Mover.Toggle() end
	elseif SUI.Menu then
		SUI.Menu.Toggle()
	end
end

function M.DragTick()
	if not M.lnDrag then return end
	local down = getglobal("IsMouseButtonDown")
	if type(down) == "function" and not down("LeftButton") then
		M.LaunchDragStop()
		return
	end
	local a = M.CursorAngle()
	if a then
		M.lnAngle = a
		M.LaunchPlace(a)
	end
end

function M.LaunchDragStart()
	if not M.launcher then return end
	M.lnDrag = true
	M.lnMoved = true
	M.lnAngle = nil
	M.LaunchLeave()
	M.QClose()
	SUI.Cancel(M.dragTask)
	M.dragTask = SUI.Every(0.03, M.DragTick, "minimap.drag")
end

-- Fin du glissement (relache ou module coupe) : la minuterie s'arrete.
function M.LaunchStopDrag()
	SUI.Cancel(M.dragTask)
	M.dragTask = nil
	M.lnDrag = false
end

-- Relache : l'angle est range dans le reglage, une seule ecriture.
function M.LaunchDragStop()
	if not M.lnDrag then return end
	local a = M.lnAngle
	M.LaunchStopDrag()
	M.lnAngle = nil
	if a then C.Set("minimap.launchangle", normAngle(floor(a + 0.5))) end
end

function M.LaunchBuild()
	local ln = T.Button(M.holder, "S", 22, 22, M.LaunchClick)
	M.launcher = ln
	ln:SetFrameStrata("MEDIUM")
	ln:SetFrameLevel(Minimap:GetFrameLevel() + 7)
	ln:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	ln:RegisterForDrag("LeftButton")
	ln:SetScript("OnDragStart", M.LaunchDragStart)
	ln:SetScript("OnDragStop", M.LaunchDragStop)
	ln:SetScript("OnMouseDown", M.LaunchDown)
	ln:SetScript("OnEnter", M.LaunchEnter)
	ln:SetScript("OnLeave", M.LaunchLeave)
	T.SetSelected(ln, true)
	return ln
end

-- Montre / cache le lanceur selon l'option et l'etat du module ; taille et angle relus.
function M.LaunchApply()
	if not M.holder then return end
	local want = M.on and M.cfg.launcher and true or false
	local ln = M.launcher
	if want and not ln then
		if SUI.InCombat() then
			SUI.WhenSafe(M.LaunchApply)
			return
		end
		ln = M.LaunchBuild()
	end
	if not ln then return end
	if want then
		ln:SetWidth(M.cfg.launchsize)
		ln:SetHeight(M.cfg.launchsize)
		if not M.lnDrag then M.LaunchPlace() end
		ln:Show()
	else
		M.LaunchStopDrag()
		M.QClose()
		ln:Hide()
	end
end

-- La visibilite conditionnelle cache la minimap : le tiroir, le menu rapide et un glissement en cours sont fermes.
function M.OnVis(visible, frame)
	if visible then return end
	if M.drawer then M.drawer:Hide() end
	M.hoverOpen = false
	M.LaunchStopDrag()
	M.QClose()
end

-- ---------------------------------------------------------------- menu rapide
M.qpage = 1
M.qlist = {}

local function cmpMod(a, b)
	if a.key ~= b.key then return a.key < b.key end
	return a.name < b.name
end

-- Modules proposes : tous sauf ceux du socle et la minimap elle-meme (la couper ferait disparaitre le lanceur).
function M.QModules()
	local list = {}
	for i = 1, getn(SUI.moduleOrder) do
		local name = SUI.moduleOrder[i]
		local def = SUI.modules[name]
		if def and not def.core and name ~= "minimap" then
			local label = SUI.Menu and SUI.Menu.ModName(name) or name
			tinsert(list, { name = name, label = label, key = strlower(label) })
		end
	end
	table.sort(list, cmpMod)
	M.qlist = list
	return list
end

function M.QPages()
	local n = floor((getn(M.qlist) + QPER - 1) / QPER)
	if n < 1 then n = 1 end
	return n
end

local function qBorder(b)
	local r, g, bl = T.Accent()
	if b.selected then
		b:SetBackdropBorderColor(r, g, bl, 1)
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

function M.QEnter()
	local b = this
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
	if SUI.Menu and b.tipTitle then SUI.Menu.TipShow(b, b.tipTitle, b.tipText, b.tipExtra) end
end

function M.QLeave()
	qBorder(this)
	if SUI.Menu then SUI.Menu.TipHide() end
end

local function qButton(parent, w, h, onclick)
	local b = T.Button(parent, "", w, h, onclick)
	b:SetScript("OnEnter", M.QEnter)
	b:SetScript("OnLeave", M.QLeave)
	return b
end

function M.QOnWheel()
	if arg1 and arg1 > 0 then M.QPage(-1) else M.QPage(1) end
end

function M.QPage(d)
	local n = M.QPages()
	local p = M.qpage + d
	if p < 1 then p = n end
	if p > n then p = 1 end
	M.qpage = p
	M.QRender()
end

function M.QPageClick(b)
	M.QPage(b.pageDir)
end

function M.QSettings()
	M.QClose()
	if SUI.Menu then SUI.Menu.Show() end
end

function M.QProfile(b, btn)
	if SUI.Menu then SUI.Menu.NextProfile(btn == "RightButton" and -1 or 1) end
	M.QRender()
end

function M.QMode()
	if SUI.Menu then SUI.Menu.ToggleMode() end
	M.QRender()
end

function M.QStyle(b, btn)
	local S = SUI.Style
	if not S or not S.names then return end
	local n = getn(S.names)
	if n < 1 then return end
	local cur = 1
	for i = 1, n do
		if S.names[i] == C.Get("style.name") then cur = i end
	end
	cur = cur + (btn == "RightButton" and -1 or 1)
	if cur < 1 then cur = n end
	if cur > n then cur = 1 end
	C.Set("style.name", S.names[cur])
	M.QRender()
end

function M.QMove()
	M.QClose()
	if SUI.Mover then SUI.Mover.Toggle() end
end

function M.QHelp()
	M.QClose()
	if SUI.Command then SUI.Command("help") end
end

function M.QModClick(b)
	local name = b.mname
	if not name then return end
	C.Set("modules." .. name, not C.Get("modules." .. name))
	M.QRender()
end

local QSTATE = { on = "mod.minimap.q.on", off = "mod.minimap.q.off", wait = "mod.minimap.q.wait" }

-- Remplit les boutons d'action et la page de modules courante (libelles, etats).
function M.QRender()
	local f = M.qm
	if not f then return end
	local Mn = SUI.Menu
	T.SetButtonText(f.bProfile, L("mod.minimap.q.profile", tostring(C.curName)))
	local md = SUI.Mode and SUI.Mode.Name(C.mode) or tostring(C.mode)
	T.SetButtonText(f.bMode, L("mod.minimap.q.mode", md))
	T.SetSelected(f.bMode, C.mode ~= "normal")
	local sn = C.Get("style.name")
	T.SetButtonText(f.bStyle, L("mod.minimap.q.style", SUI.Style and SUI.Style.Label(sn) or tostring(sn)))
	T.SetSelected(f.bMove, SUI.Mover and SUI.Mover.active and true or false)
	local np = M.QPages()
	if M.qpage > np then M.qpage = np end
	f.pageText:SetText(L("mod.minimap.q.mods", M.qpage, np))
	for i = 1, QPER do
		local row = f.rows[i]
		local e = M.qlist[(M.qpage - 1) * QPER + i]
		if e then
			row.mname = e.name
			row.tipTitle = e.label
			row.tipText = Mn and Mn.ModShort(e.name, 120) or ""
			row.tipExtra = L("mod.minimap.q.modtip")
			T.SetButtonText(row, e.label)
			local st = Mn and Mn.State(e.name) or "off"
			local col = Mn and Mn.StateColor(st) or T.c.dim
			row.state:SetText(L(QSTATE[st] or QSTATE.off))
			row.state:SetTextColor(col[1], col[2], col[3], 1)
			T.SetSelected(row, st == "on")
			row:Show()
		else
			row.mname = nil
			row:Hide()
		end
	end
end

function M.QBuild()
	if M.qm then return true end
	if SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return false
	end
	local cat = CreateFrame("Button", "ShikiUI_MinimapQuickCatch", UIParent)
	cat:SetFrameStrata("DIALOG")
	cat:SetAllPoints(UIParent)
	cat:EnableMouse(true)
	cat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cat:SetScript("OnClick", M.QClose)
	cat:Hide()
	M.qcatch = cat
	local f = CreateFrame("Frame", "ShikiUI_MinimapQuick", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(cat:GetFrameLevel() + 2)
	f:SetWidth(QW)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", M.QOnWheel)
	f:SetClampedToScreen(true)
	f:Hide()
	f.title = T.Text(f, 12, T.c.text, "LEFT", true)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", QPAD + 2, -QPAD - 2)
	f.title:SetText(L("mod.minimap.q.title"))
	local bw = QW - 2 * QPAD
	local y = -QPAD - 20
	local names = { { "bSettings", M.QSettings, "settings" }, { "bProfile", M.QProfile, "profile" }, { "bMode", M.QMode, "mode" },
		{ "bStyle", M.QStyle, "style" }, { "bMove", M.QMove, "move" }, { "bHelp", M.QHelp, "help" } }
	for i = 1, getn(names) do
		local b = qButton(f, bw, 20, names[i][2])
		b:SetPoint("TOPLEFT", f, "TOPLEFT", QPAD, y)
		b.tipTitle = L("mod.minimap.q." .. names[i][3] .. ".t")
		b.tipText = L("mod.minimap.q." .. names[i][3] .. ".tip")
		f[names[i][1]] = b
		y = y - 22
	end
	T.SetButtonText(f.bSettings, L("mod.minimap.q.settings"))
	T.SetButtonText(f.bMove, L("mod.minimap.q.move"))
	T.SetButtonText(f.bHelp, L("mod.minimap.q.help"))
	y = y - 4
	f.pageText = T.Text(f, 11, T.c.dim, "LEFT")
	f.pageText:SetPoint("TOPLEFT", f, "TOPLEFT", QPAD + 2, y - 4)
	local nx = qButton(f, 22, 18, M.QPageClick)
	nx:SetPoint("TOPRIGHT", f, "TOPRIGHT", -QPAD, y)
	nx.pageDir = 1
	nx.tipTitle = L("mod.minimap.q.next")
	T.SetButtonText(nx, ">")
	local pv = qButton(f, 22, 18, M.QPageClick)
	pv:SetPoint("RIGHT", nx, "LEFT", -2, 0)
	pv.pageDir = -1
	pv.tipTitle = L("mod.minimap.q.prev")
	T.SetButtonText(pv, "<")
	y = y - 22
	f.rows = {}
	for i = 1, QPER do
		local row = qButton(f, bw, 18, M.QModClick)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", QPAD, y)
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", M.QOnWheel)
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
		row.label:SetJustifyH("LEFT")
		row.state = T.Text(row, 10, T.c.dim, "RIGHT")
		row.state:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		f.rows[i] = row
		y = y - 19
	end
	f.hint = T.Text(f, 10, T.c.dim, "LEFT")
	f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", QPAD + 2, y - 3)
	f.hint:SetText(L("mod.minimap.q.hint"))
	f:SetHeight(-y + 20)
	M.qm = f
	local sp = getglobal("UISpecialFrames")
	if type(sp) == "table" then tinsert(sp, "ShikiUI_MinimapQuick") end
	return true
end

function M.QOpen(anchor)
	if not (M.on and M.built) or not M.QBuild() then return end
	local f = M.qm
	M.QModules()
	M.qpage = 1
	anchor = anchor or M.launcher or M.holder
	local ax, ay = anchor:GetCenter()
	local ux, uy = UIParent:GetCenter()
	local up = type(ay) == "number" and type(uy) == "number" and ay > uy
	local right = type(ax) == "number" and type(ux) == "number" and ax > ux
	local h = right and "RIGHT" or "LEFT"
	f:ClearAllPoints()
	if up then
		f:SetPoint("TOP" .. h, anchor, "BOTTOM" .. h, 0, -2)
	else
		f:SetPoint("BOTTOM" .. h, anchor, "TOP" .. h, 0, 2)
	end
	M.qcatch:Show()
	f:Show()
	M.QRender()
end

function M.QClose()
	if M.qcatch then M.qcatch:Hide() end
	if M.qm and M.qm:IsShown() then
		M.qm:Hide()
		if SUI.Menu then SUI.Menu.TipHide() end
	end
end

function M.QToggle(anchor)
	if M.qm and M.qm:IsShown() then M.QClose() else M.QOpen(anchor) end
end

-- ---------------------------------------------------------------- minuterie, evenements, reglages
function M.Tick()
	M.UpdateCoords()
	M.UpdateClock()
end

function M.OnScanTimer()
	M.RequestScan()
end

function M.OnEnter()
	M.OnZone()
	SUI.After(3, M.OnScanTimer, "minimap.scan")
	SUI.After(10, M.OnScanTimer, "minimap.scan")
	SUI.After(30, M.OnScanTimer, "minimap.scan")
end

function M.OnRegen()
	if M.pending then M.RequestScan() end
end

function M.OnKey(key, value)
	if key == "minimap.iconlist" then
		-- interrupteur du menu : ouvre la fenetre des icones puis se remet a zero
		if value == true then
			C.Set("minimap.iconlist", false)
			M.OpenList()
		end
		return
	end
	M.ReadConfig()
	M.ApplyOptions()
	if key == "minimap.buttons" or key == "minimap.btnmode" or key == nil or strfind(key, "^minimap%.launch") then M.RequestScan() end
	if M.win and M.win:IsShown() then M.RefreshList() end
end

function M.OnStyle()
	M.lastZoneColor = nil
	if M.on and M.built then M.UpdateZone() end
end

function M.Activate()
	if M.active or not M.built then return end
	M.active = true
	SUI.On("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.On("MINIMAP_ZONE_CHANGED", M.OnZone)
	SUI.On("ZONE_CHANGED", M.OnZone)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnEnter)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	M.task = SUI.Every(TICK, M.Tick, "minimap.tick", true)
	M.watchTask = SUI.Every(WATCH, M.Watch, "minimap.watch", true)
	if SUI.Visibility then
		SUI.Visibility.Add(M.holder, "minimap", { mode = "show", module = "minimap", alpha = M.cfg.alpha, onChange = M.OnVis })
	end
	M.OnEnter()
end

function M.VisDrop()
	if not M.active and M.holder and SUI.Visibility then SUI.Visibility.Remove(M.holder) end
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Cancel(M.watchTask)
	M.watchTask = nil
	SUI.Cancel(M.hoverTask)
	M.hoverTask = nil
	SUI.Cancel(M.coordTask)
	M.coordTask = nil
	M.coordHover = false
	-- Remove detache un observateur de la configuration : jamais pendant une notification (Config.Notify parcourt sa liste), donc differe.
	if SUI.Visibility and M.holder then SUI.After(0.05, M.VisDrop, "minimap.visdrop") end
	M.LaunchStopDrag()
	M.QClose()
	SUI.Off("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.Off("MINIMAP_ZONE_CHANGED", M.OnZone)
	SUI.Off("ZONE_CHANGED", M.OnZone)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnEnter)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	SUI.WhenSafe(M.Build)
	if M.built then
		SUI.WhenSafe(function()
			Minimap:SetParent(M.holder)
			Minimap:ClearAllPoints()
			Minimap:SetPoint("CENTER", M.holder, "CENTER", 0, 0)
		end)
		M.Activate()
		M.ApplyOptions()
	end
end

function M.Disable()
	M.on = false
	M.Deactivate()
	if M.win then M.win:Hide() end
	if M.built then
		M.ApplyOptions()
		SUI.WhenSafe(function()
			if M.on then return end
			if M.origParent then Minimap:SetParent(M.origParent) end
			if M.origSize and M.origSize[1] then
				Minimap:SetWidth(M.origSize[1])
				Minimap:SetHeight(M.origSize[2])
			end
			Minimap:ClearAllPoints()
			local o = M.origPoint
			if o[1] then Minimap:SetPoint(o[1], o[2], o[3], o[4], o[5]) end
		end)
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("minimap", 23)

local function opt(key, typ, order, def, extra)
	local o = { key = "minimap." .. key, type = typ, cat = "minimap", label = "opt.minimap." .. key, tip = "tip.minimap." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local MM_OPTIONS = {
		opt("shape", "choice", 10, "round", { choices = { "round", "square" }, simple = true }),
		opt("size", "number", 20, 140, { min = 80, max = 320, step = 10, simple = true }),
		opt("alpha", "number", 25, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("wheel", "bool", 30, true, { simple = true }),
		opt("coords", "bool", 40, true, { simple = true }),
		opt("dec", "number", 41, 1, { min = 0, max = 2, step = 1 }),
		opt("zone", "bool", 50, true),
		opt("zonepvp", "bool", 51, true),
		opt("clock", "choice", 60, "off", { choices = { "off", "local", "server" } }),
		opt("coordpos", "choice", 42, "bottomleft", { choices = { "bottomleft", "bottom", "bottomright", "top", "below", "above" } }),
		opt("coordshow", "choice", 43, "always", { choices = { "always", "hover" } }),
		opt("zonepos", "choice", 52, "top", { choices = { "top", "bottom", "below", "above" } }),
		opt("clockpos", "choice", 61, "bottomright", { choices = { "bottomright", "bottomleft", "bottom", "top", "below", "above" } }),
		opt("clockfmt", "choice", 62, "24", { choices = { "24", "12" } }),
		opt("trackpos", "choice", 94, "auto", { choices = { "auto", "topleft", "topright", "bottomleft", "bottomright" } }),
		opt("tracksize", "number", 95, 100, { min = 60, max = 160, step = 10 }),
		opt("clutter", "bool", 70, true),
		opt("buttons", "bool", 80, true, { simple = true }),
		opt("btnmode", "choice", 81, "drawer", { choices = { "drawer", "hover", "hide" }, simple = true }),
		opt("iconlist", "bool", 82, false, { simple = true }),
		opt("edge", "bool", 86, true, { simple = true }),
		opt("keep", "text", 83, ""),
		opt("cols", "number", 84, 4, { min = 2, max = 8, step = 1 }),
		opt("btnsize", "number", 85, 28, { min = 20, max = 40, step = 2 }),
		opt("togglepos", "choice", 90, "topleft", { choices = { "topleft", "topright", "bottomleft", "bottomright", "hide" } }),
		opt("togglesize", "number", 91, 16, { min = 10, max = 32, step = 2 }),
		opt("togglex", "number", 92, 0, { min = -40, max = 40, step = 1 }),
		opt("toggley", "number", 93, 0, { min = -40, max = 40, step = 1 }),
		opt("mailpos", "choice", 100, "topright", { choices = { "default", "topleft", "topright", "bottomleft", "bottomright", "hide" } }),
		opt("bgpos", "choice", 101, "topleft", { choices = { "default", "topleft", "topright", "bottomleft", "bottomright", "hide" } }),
		opt("iconsize", "number", 102, 24, { min = 16, max = 40, step = 2 }),
		opt("launcher", "bool", 87, true, { simple = true }),
		opt("launchangle", "number", 88, 165, { min = 0, max = 359, step = 1 }),
		opt("launchsize", "number", 89, 22, { min = 16, max = 32, step = 2 }),
}
-- Options communes du socle : visibilite conditionnelle (minimap.vis / .fade) et police des textes (minimap.font / .fontsize).
local function addAll(list)
	for i = 1, getn(list) do tinsert(MM_OPTIONS, list[i]) end
end
if SUI.Visibility then addAll(SUI.Visibility.Options("minimap", { cat = "minimap", order = 800 })) end
if SUI.Look then addAll(SUI.Look.Options("minimap", { font = true, cat = "minimap", order = 820 })) end

SUI.RegisterModule("minimap", {
	default = true,
	cost = "light",
	options = MM_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalents pfUI releves : le module "minimap" de pfUI et ses boutons d'addons ("addonbuttons").
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.minimap then SUI.Migrate.MAP.minimap = { "minimap", "addonbuttons" } end

-- Mode Raid : cadre plus petit, pas de nom de zone (moins de texte a redessiner).
SUI.Config.AddPreset("raid", "*", { ["minimap.size"] = 120, ["minimap.zone"] = false })

SUI.RegisterCommand("minimap", function(rest)
	if rest == "scan" then
		if not M.built then SUI.Print(L("msg.minimap.notready")) return end
		M.RequestScan()
		SUI.Print(L("msg.minimap.scan", M.nbtn))
	elseif rest == "drawer" then
		M.ToggleDrawer()
	elseif rest == "icons" then
		M.OpenList()
	elseif rest == "menu" then
		if not M.built then SUI.Print(L("msg.minimap.notready")) return end
		M.QToggle(M.launcher and M.launcher:IsShown() and M.launcher or M.holder)
	elseif rest == "list" then
		if not M.built then SUI.Print(L("msg.minimap.notready")) return end
		M.RequestScan()
		local list = M.List()
		SUI.Print(L("msg.minimap.listhead", getn(list)))
		for i = 1, getn(list) do
			local r = list[i]
			local tag = L("mod.minimap.state.managed")
			if r.name and M.keep[r.name] then tag = L("mod.minimap.state.kept") end
			SUI.Print(strformat("%s (%s) : %s", M.RecLabel(r), r.name or "?", tag))
		end
	elseif rest == "diag" then
		-- diagnostic du tiroir : chaque enfant reel (nom, classe, taille effective), ses enfants (contenu qui peut deborder)
		-- et chaque bouton collecte
		if not M.built or not M.drawer then SUI.Print(L("msg.minimap.notready")) return end
		SUI.Print("DIAG tiroir : " .. M.nbtn .. " collecte(s), " .. (M.ngrp or 0) .. " en grille")
		local kids = { M.drawer:GetChildren() }
		for i = 1, getn(kids) do
			local k = kids[i]
			SUI.Print(strformat("enfant %d : %s [%s] %dx%d", i, k.GetName and k:GetName() or "?", k.GetObjectType and k:GetObjectType() or "?", k:GetWidth() or 0, k:GetHeight() or 0))
			if k.GetNumChildren then
				local sub = { k:GetChildren() }
				for j = 1, getn(sub) do
					local c = sub[j]
					SUI.Print(strformat("  + %s [%s] %dx%d", c.GetName and c:GetName() or "?", c.GetObjectType and c:GetObjectType() or "?", c:GetWidth() or 0, c:GetHeight() or 0))
				end
			end
		end
		for i = 1, M.nbtn do
			local b = M.btns[i]
			SUI.Print(strformat("btn %d : %s disp=%s w=%d h=%d", i, b.name or "?", tostring(b.disp), b.w or 0, b.h or 0))
		end
	elseif M.built then
		SUI.Print(L("msg.minimap.info", M.CoordText(), M.nbtn))
	else
		SUI.Print(L("msg.minimap.notready"))
	end
end, "help.minimap")
