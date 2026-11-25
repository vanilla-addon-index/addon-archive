-- ShikiUI Units : cadres joueur / cible / cible de la cible / familier / cible de cible de cible / cible du familier / focus.
-- Evenements via le routeur central, rafraichissement groupe par une minuterie partagee (drapeaux 'dirty'),
-- aucune creation d'objet en combat, cibles lues par sondage (pas d'evenement fiable en 1.12 pour ces jetons).
-- v0.2 : reglages PAR CADRE (taille, textes, portrait, indicateurs, auras), couleurs de vie / ressource, focus emule.
--   Reglage par cadre = cle  units.<cadre>.<nom>  (cadre : player target tot pet tott pettarget focus) ; 0 / "default" = suit le reglage global.
--   Focus : il n'existe pas en 1.12. Le focus est un GUID (SuperWoW : UnitExists(guid) lit l'unite meme sans la cibler) et, sans SuperWoW,
--   un NOM relu quand ce nom est ma cible / la cible de ma cible. Hors de portee, le cadre reste affiche, fige et grise.
-- NON VERIFIE EN JEU : jeton "targettargettarget", UnitExists(guid) pour un GUID SuperWoW, SetPortraitTexture sur "pet", coordonnees
--   des icones UI-StateIcon / UI-PVP-*, GetLootMethod (indices de groupe / raid).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local U = {}
SUI.Units = U

local getn = table.getn
local floor = math.floor
local tinsert = table.insert

U.frames = {}
U.order = { "player", "target", "targettarget", "pet", "targettargettarget", "pettarget", "focus" }
U.cfgName = { player = "player", target = "target", targettarget = "tot", pet = "pet", targettargettarget = "tott",
	pettarget = "pettarget", focus = "focus" }
U.built = false
U.active = false
U.dirty = false
U.animating = false
U.blizzHidden = false
U.focusName = nil          -- focus : nom (toujours) et GUID (si SuperWoW / Nampower le donne)
U.focusGuid = nil

local TOT_RATIO = 0.6
local PET_RATIO = 0.8
local FLUSH = 0.10   -- (2026-11-20 : 0.05 = 20 Hz permanents pour rien ; le Flush ne fait rien sans dirty/animating)
local POLL_TOT = 0.2
local POLL_RANGE = 0.25
local MAXA = 8
local BLIZZ = { "PlayerFrame", "TargetFrame", "TargetofTargetFrame", "PetFrame" }
-- cadres lus par sondage (aucun evenement fiable pour leur jeton)
local POLLED = { "targettarget", "targettargettarget", "pettarget", "focus" }
-- proportion (largeur, hauteur) par rapport aux reglages globaux, quand le reglage du cadre vaut 0
local RATIO = { targettarget = { TOT_RATIO, 0.7 }, pet = { PET_RATIO, PET_RATIO }, targettargettarget = { TOT_RATIO, 0.7 },
	pettarget = { TOT_RATIO, 0.7 } }

-- Ce que chaque cadre sait faire : size (largeur / hauteur), power (barre + texte de ressource), text (texte de vie, alignement, taille),
-- port (portrait), mark (marqueur de raid), leader / loot / pvp / combat (indicateurs), auras (rangee d'effets).
local CAPS = {
	player = { size = true, power = true, text = true, port = true, mark = true, leader = true, loot = true, pvp = true, combat = true, fsr = true },
	target = { size = true, power = true, text = true, port = true, mark = true, leader = true, loot = true, pvp = true, combat = true },
	targettarget = { size = true, text = true, port = true, mark = true, auras = true },
	pet = { size = true, power = true, text = true, port = true, mark = true, auras = true, combat = true },
	targettargettarget = { size = true, text = true, mark = true },
	pettarget = { size = true, text = true, mark = true },
	focus = { size = true, power = true, text = true, port = true, mark = true, pvp = true, auras = true },
}
U.caps = CAPS

-- Reglages par cadre : nom, capacite requise, type, defaut, bornes, choix. (Les libelles sont dans Locale_Units.lua.)
local HPTEXT_CHOICES = { "default", "none", "value", "percent", "both", "deficit", "maxvalue" }
local SPEC = {
	{ name = "width", cap = "size", type = "number", def = 0, min = 0, max = 400, step = 5 },
	{ name = "height", cap = "size", type = "number", def = 0, min = 0, max = 80, step = 1 },
	{ name = "powerheight", cap = "power", type = "number", def = 0, min = 0, max = 20, step = 1 },
	{ name = "hptext", cap = "text", type = "choice", def = "default", choices = HPTEXT_CHOICES },
	{ name = "hpalign", cap = "text", type = "choice", def = "right", choices = { "left", "center", "right" } },
	{ name = "textsize", cap = "text", type = "number", def = 11, min = 8, max = 18, step = 1 },
	{ name = "powertext", cap = "power", type = "choice", def = "none", choices = { "none", "value", "percent", "both" } },
	{ name = "portrait", cap = "port", type = "choice", def = "off", choices = { "off", "2d", "3d", "class" } },
	{ name = "portraitside", cap = "port", type = "choice", def = "left", choices = { "left", "right" } },
	{ name = "mark", cap = "mark", type = "bool", def = false },
	{ name = "leader", cap = "leader", type = "bool", def = false },
	{ name = "loot", cap = "loot", type = "bool", def = false },
	{ name = "pvp", cap = "pvp", type = "bool", def = false },
	{ name = "combat", cap = "combat", type = "bool", def = false },
	{ name = "auras", cap = "auras", type = "choice", def = "off", choices = { "off", "buffs", "debuffs", "both" } },
	{ name = "fsr", cap = "fsr", type = "bool", def = false },
	{ name = "nameanchor", cap = "text", type = "choice", def = "default", choices = { "default", "topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright", "off" } },
	{ name = "buffanchor", cap = "auras", type = "choice", def = "default", choices = { "default", "topleft", "topcenter", "topright", "bottomleft", "bottomcenter", "bottomright", "off" } },
	{ name = "debuffanchor", cap = "auras", type = "choice", def = "default", choices = { "default", "topleft", "topcenter", "topright", "bottomleft", "bottomcenter", "bottomright", "off" } },
}
U.spec = SPEC

-- Pseudo : point d'ancrage dans la barre de vie, justification, decalage vertical (le haut / bas gardent 2 px de marge).
local NAMEAT = {
	topleft = { "TOPLEFT", "LEFT", -2 }, top = { "TOP", "CENTER", -2 }, topright = { "TOPRIGHT", "RIGHT", -2 },
	left = { "LEFT", "LEFT", 0 }, center = { "CENTER", "CENTER", 0 }, right = { "RIGHT", "RIGHT", 0 },
	bottomleft = { "BOTTOMLEFT", "LEFT", 2 }, bottom = { "BOTTOM", "CENTER", 2 }, bottomright = { "BOTTOMRIGHT", "RIGHT", 2 },
}

local function specDefault(key, sp)
	if sp.name == "mark" and key == "target" then return true end   -- le marqueur de raid de la cible est utile d'office
	return sp.def
end

-- couleurs d'interface (choix de style, pas des donnees de jeu)
local COL_GRAY = { 0.55, 0.55, 0.55 }
local COL_FRIEND = { 0.35, 0.75, 0.45 }
local COL_ENEMY = { 0.85, 0.25, 0.25 }
local COL_NEUTRAL = { 0.90, 0.78, 0.30 }
local POWER_COL = {
	[0] = { 0.25, 0.45, 0.95 },   -- mana
	[1] = { 0.85, 0.22, 0.22 },   -- rage
	[2] = { 0.90, 0.50, 0.20 },   -- focus
	[3] = { 0.95, 0.85, 0.25 },   -- energie
}
-- surcharges de couleur choisies par l'utilisateur (tables reutilisees, remplies par ReadConfig)
local PC = { [0] = {}, [1] = {}, [3] = {} }
local HPC = {}

-- images du jeu
local TEX_MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local TEX_STATE = "Interface\\CharacterFrame\\UI-StateIcon"
local TEX_LEADER = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local TEX_ASSIST = "Interface\\GroupFrame\\UI-GROUP-AssistantIcon"
local TEX_LOOT = "Interface\\GroupFrame\\UI-Group-MasterLooter"
local TEX_HORDE = "Interface\\TargetingFrame\\UI-PVP-Horde"
local TEX_ALLY = "Interface\\TargetingFrame\\UI-PVP-Alliance"
local TEX_FFA = "Interface\\TargetingFrame\\UI-PVP-FFA"
local TEX_CLASS = "Interface\\WorldStateFrame\\Icons-Classes"
local CLASS_TC = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 }, DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 }, PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}

-- valeurs lues depuis la config (mises a jour par U.ReadConfig)
local cfg = { classcolor = true, showpower = true, hptext = "percent", range = true, smooth = true, incheal = true,
	hpcolor = "auto", aurasize = 14, auramax = 6, indsize = 14, focusmod = "shift" }

local function readColor(key, slot)
	local v = SUI.Config.Get(key)
	local r, g, b
	if type(v) == "string" and v ~= "" and SUI.Style and SUI.Style.ParseHex then r, g, b = SUI.Style.ParseHex(v) end
	if r then
		slot.r, slot.g, slot.b, slot.on = r, g, b, true
	else
		slot.on = false
	end
end

function U.ReadConfig()
	local C = SUI.Config
	cfg.classcolor = C.Get("units.classcolor")
	cfg.showpower = C.Get("units.showpower")
	cfg.hptext = C.Get("units.hptext")
	cfg.range = C.Get("units.range")
	cfg.smooth = C.Get("units.smooth") and not SUI.emergency
	cfg.incheal = C.Get("units.incheal")
	cfg.hpcolor = C.Get("units.hpcolor") or "auto"
	cfg.aurasize = C.Get("units.aurasize") or 14
	cfg.auramax = C.Get("units.auramax") or 6
	cfg.indsize = C.Get("units.indsize") or 14
	cfg.focusmod = C.Get("units.focus.modclick") or "shift"
	readColor("units.c.hp", HPC)
	readColor("units.c.mana", PC[0])
	readColor("units.c.rage", PC[1])
	readColor("units.c.energy", PC[3])
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then
			local key = f.key
			local cf = f.cf
			local caps = CAPS[key]
			local n = U.cfgName[key]
			cf.enabled = C.Get("units." .. n .. ".enabled")
			for j = 1, getn(SPEC) do
				local sp = SPEC[j]
				if caps[sp.cap] then
					local v = C.Get("units." .. n .. "." .. sp.name)
					if v ~= nil then cf[sp.name] = v end
				end
			end
		end
	end
	U.SyncFsr()
	if U.SyncIcons then U.SyncIcons() end
end

function U.Enabled(unit)
	return SUI.Config.Get("units." .. U.cfgName[unit] .. ".enabled")
end

local function abbrev(n)
	if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
	if n >= 10000 then return string.format("%.0fk", n / 1000) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(floor(n))
end
U.Abbrev = abbrev

-- En 1.12 la vie des unites hostiles est un POURCENTAGE (maximum 100) : on n'affiche alors que le pourcentage.
function U.HpString(mode, hp, max)
	if mode == "none" then return "" end
	local pct = (max > 0) and floor(hp / max * 100 + 0.5) or 0
	if mode == "deficit" then
		if max == 100 then
			if pct >= 100 then return "" end
			return "-" .. (100 - pct) .. "%"
		end
		if max - hp <= 0 then return "" end
		return "-" .. abbrev(max - hp)
	end
	if max == 100 then return pct .. "%" end
	if mode == "value" then return abbrev(hp) end
	if mode == "percent" then return pct .. "%" end
	if mode == "maxvalue" then return abbrev(hp) .. "/" .. abbrev(max) end
	return abbrev(hp) .. " | " .. pct .. "%"
end

function U.PowerString(mode, cur, max)
	if mode == "none" or max <= 0 then return "" end
	local pct = floor(cur / max * 100 + 0.5)
	if mode == "value" then return abbrev(cur) end
	if mode == "percent" then return pct .. "%" end
	return abbrev(cur) .. " | " .. pct .. "%"
end

function U.UnitColor(unit, noclass)
	if UnitIsPlayer(unit) then
		if cfg.classcolor and not noclass then
			local _, class = UnitClass(unit)
			local col = class and RAID_CLASS_COLORS[class]
			if col then return col.r, col.g, col.b end
		end
		if UnitCanAttack("player", unit) then return COL_ENEMY[1], COL_ENEMY[2], COL_ENEMY[3] end
		return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3]
	end
	if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then return COL_GRAY[1], COL_GRAY[2], COL_GRAY[3] end
	if UnitIsFriend("player", unit) then return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3] end
	if UnitCanAttack("player", unit) then
		if UnitIsEnemy("player", unit) then return COL_ENEMY[1], COL_ENEMY[2], COL_ENEMY[3] end
		return COL_NEUTRAL[1], COL_NEUTRAL[2], COL_NEUTRAL[3]
	end
	return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3]
end

-- Couleur de la barre de vie selon le mode choisi (units.hpcolor) : auto = classe / reaction (comportement d'origine),
-- reaction = jamais la classe, gradient = rouge -> jaune -> vert selon la vie restante, custom = ma couleur.
function U.HealthColor(unit, ratio)
	local m = cfg.hpcolor
	if m == "gradient" then
		local a, b, t
		if ratio < 0.5 then
			a, b, t = T.c.bad, T.c.warn, ratio * 2
		else
			a, b, t = T.c.warn, T.c.good, (ratio - 0.5) * 2
		end
		return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
	elseif m == "custom" then
		if HPC.on then return HPC.r, HPC.g, HPC.b end
		return T.c.good[1], T.c.good[2], T.c.good[3]
	elseif m == "reaction" then
		return U.UnitColor(unit, true)
	end
	return U.UnitColor(unit)
end

-- ---------------------------------------------------------------- indicateurs d'etat
-- Rang dans le groupe : 2 = chef, 1 = assistant (raid), 0 = rien.
local function rankOf(unit)
	local gnr = getglobal("GetNumRaidMembers")
	local nr = gnr and gnr() or 0
	if nr > 0 then
		local gri = getglobal("GetRaidRosterInfo")
		local nm = UnitName(unit)
		if gri and nm and UnitIsPlayer(unit) then
			for i = 1, nr do
				local n, rank = gri(i)
				if n == nm then return rank or 0 end
			end
		end
		return 0
	end
	local upl = getglobal("UnitIsPartyLeader")
	if upl and upl(unit) then return 2 end
	return 0
end

local function isMaster(unit)
	local glm = getglobal("GetLootMethod")
	if not glm then return false end
	local method, pid, rid = glm()
	if method ~= "master" then return false end
	local uiu = getglobal("UnitIsUnit")
	local me = (unit == "player") or (uiu ~= nil and uiu(unit, "player") and true or false)
	if me and (pid == 0 or (rid and rid > 0 and uiu and uiu("player", "raid" .. rid))) then return true end
	if not uiu then return false end
	if pid and pid > 0 and uiu(unit, "party" .. pid) then return true end
	if rid and rid > 0 and uiu(unit, "raid" .. rid) then return true end
	return false
end

local function pvpTexture(unit)
	local upp = getglobal("UnitIsPVP")
	if not upp or not upp(unit) then return nil end
	local ffa = getglobal("UnitIsPVPFreeForAll")
	if ffa and ffa(unit) then return TEX_FFA end
	local fg = getglobal("UnitFactionGroup")
	local fac = fg and fg(unit)
	if fac == "Horde" then return TEX_HORDE end
	if fac == "Alliance" then return TEX_ALLY end
	return nil
end

local function placeInd(f, tex, x)
	tex:ClearAllPoints()
	tex:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, 2)
	tex:Show()
	return x + cfg.indsize + 1
end

function U.UpdateIcons(f)
	local mk = f.imark
	if not mk then return end
	local cf = f.cf
	local unit = f.unit
	local live = f.live
	-- marqueur de raid (1 a 8) : grille 4 x 2 de l'image du jeu
	local idx = nil
	if cf.mark and live then
		local g = getglobal("GetRaidTargetIndex")
		if g then idx = g(unit) end
	end
	if idx and idx > 0 and idx <= 8 then
		local r4 = floor((idx - 1) / 4)
		local col = (idx - 1 - r4 * 4) * 0.25
		local row = r4 * 0.25
		mk:SetTexCoord(col, col + 0.25, row, row + 0.25)
		mk:Show()
	else
		mk:Hide()
	end
	-- rangee d'indicateurs au-dessus du coin haut gauche
	local x = 0
	local ind = f.ind
	if cf.pvp and live and ind.pvp then
		local tx = pvpTexture(unit)
		if tx then
			ind.pvp:SetTexture(tx)
			x = placeInd(f, ind.pvp, x)
		else
			ind.pvp:Hide()
		end
	elseif ind.pvp then
		ind.pvp:Hide()
	end
	if cf.leader and live and ind.lead then
		local rk = rankOf(unit)
		if rk > 0 then
			ind.lead:SetTexture(rk >= 2 and TEX_LEADER or TEX_ASSIST)
			x = placeInd(f, ind.lead, x)
		else
			ind.lead:Hide()
		end
	elseif ind.lead then
		ind.lead:Hide()
	end
	if cf.loot and live and ind.loot then
		if isMaster(unit) then x = placeInd(f, ind.loot, x) else ind.loot:Hide() end
	elseif ind.loot then
		ind.loot:Hide()
	end
	if cf.combat and live and ind.comb then
		local shown = false
		if UnitAffectingCombat(unit) then
			ind.comb:SetTexCoord(0.5, 1, 0, 0.49)
			shown = true
		elseif unit == "player" then
			local ir = getglobal("IsResting")
			if ir and ir() then
				ind.comb:SetTexCoord(0, 0.5, 0, 0.421875)
				shown = true
			end
		end
		if shown then x = placeInd(f, ind.comb, x) else ind.comb:Hide() end
	elseif ind.comb then
		ind.comb:Hide()
	end
end

-- ---------------------------------------------------------------- portrait
function U.UpdatePortrait(f)
	local p = f.port
	if not p then return end
	local mode = f.cf.portrait
	if mode == "off" or not f.live then
		p:Hide()
		return
	end
	p:Show()
	local tex = p.tex
	local unit = f.unit
	if mode == "3d" then
		-- portrait 3D : modele du personnage (cree a la demande) ; repli sur le portrait 2D si le modele ne peut pas etre cree
		if not p.model then
			local ok, m = pcall(CreateFrame, "PlayerModel", nil, p)
			if ok and m then
				m:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
				m:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
				p.model = m
			end
		end
		local m = p.model
		if m and UnitExists(unit) and UnitIsVisible(unit) then
			tex:Hide()
			m:Show()
			m:SetUnit(unit)
			m:SetCamera(0)
			return
		end
		if m then m:Hide() end
		tex:Show()
	elseif p.model then
		p.model:Hide()
		tex:Show()
	end
	if mode == "class" and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local tc = class and CLASS_TC[class]
		if tc then
			tex:SetTexture(TEX_CLASS)
			tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
			return
		end
	end
	tex:SetTexCoord(0, 1, 0, 1)
	local spt = getglobal("SetPortraitTexture")
	if spt then spt(tex, unit) end
end

-- ---------------------------------------------------------------- auras (cible de la cible, familier, focus...)
local function paintAura(f, i, tex, cnt, dt, bad)
	f.auTex[i]:SetTexture(tex)
	local bd = f.auBd[i]
	local col = nil
	if bad then
		local dc = getglobal("DebuffTypeColor")
		if dc then col = dc[dt or "none"] or dc["none"] end
		if col then bd:SetVertexColor(col.r, col.g, col.b, 1) else bd:SetVertexColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 1) end
	else
		bd:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	end
	if cnt and cnt > 1 then f.auCnt[i]:SetText(tostring(cnt)) else f.auCnt[i]:SetText("") end
	f.auTex[i]:Show()
	bd:Show()
end

-- Reglage de placement d'un groupe d'effets : "default" (ou vide) = rangee d'origine sous le cadre.
local function auraAt(v)
	if type(v) ~= "string" or v == "" or v == "default" then return nil end
	return v
end

-- Place les icones : les nd premieres (malefices) et les nb suivantes (benefices) selon leur reglage ; sans reglage, une seule rangee
-- sous le cadre. Ne repositionne que si quelque chose a change (aucune creation, uniquement des points).
local function placeAuras(f, nd, nb)
	local cf = f.cf
	local da, ba = auraAt(cf.debuffanchor), auraAt(cf.buffanchor)
	local a = cfg.aurasize
	local fw = f:GetWidth() or 0
	local key = nd .. "," .. nb .. "," .. tostring(da) .. "," .. tostring(ba) .. "," .. a .. "," .. fw .. "," .. cfg.indsize
	if f.auKey == key then return end
	f.auKey = key
	local itop = 0
	if cf.leader or cf.loot or cf.pvp or cf.combat then itop = cfg.indsize + 2 elseif cf.mark then itop = floor(cfg.indsize / 2) end
	local step = a + 3
	local rt, rb = 0, 0
	for gi = 1, 2 do
		local n, at, first = nd, da, 0
		if gi == 2 then n, at, first = nb, ba, nd end
		local top, xoff, row = false, 0, 0
		local hj = "LEFT"
		if da == nil and ba == nil then
			xoff = first      -- origine : une seule rangee, benefices apres les malefices
		elseif n > 0 and at ~= nil then
			if string.find(at, "top", 1, true) then top = true end
			if string.find(at, "right", 1, true) then hj = "RIGHT" elseif string.find(at, "center", 1, true) then hj = "CENTER" end
			if top then row = rt rt = rt + 1 else row = rb rb = rb + 1 end
		elseif n > 0 then
			row = rb       -- groupe sans reglage : sous le cadre, a gauche
			rb = rb + 1
		end
		local gwid = (xoff + n) * step - 3
		local x0 = 0
		if hj == "RIGHT" then x0 = fw - gwid elseif hj == "CENTER" then x0 = floor((fw - gwid) / 2) end
		for j = 1, n do
			local i = first + j
			local x = x0 + (xoff + j - 1) * step
			local bd, tx = f.auBd[i], f.auTex[i]
			bd:ClearAllPoints()
			tx:ClearAllPoints()
			if top then
				local y = 2 + itop + row * step
				bd:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, y)
				tx:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x + 1, y + 1)
			else
				local y = -2 - row * step
				bd:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x, y)
				tx:SetPoint("TOPLEFT", f, "BOTTOMLEFT", x + 1, y - 1)
			end
		end
	end
end

function U.UpdateAuras(f)
	if not f.auTex then return end
	local mode = f.cf.auras
	local n = 0
	local nd = 0
	if mode ~= "off" and f.live then
		local unit = f.unit
		local max = cfg.auramax
		if max > MAXA then max = MAXA end
		local ud, ub = getglobal("UnitDebuff"), getglobal("UnitBuff")
		local offD, offB = (f.cf.debuffanchor == "off"), (f.cf.buffanchor == "off")
		if mode ~= "buffs" and ud and not offD then
			for i = 1, 16 do
				if n >= max then break end
				local tex, cnt, dt = ud(unit, i)
				if not tex then break end
				n = n + 1
				paintAura(f, n, tex, cnt, dt, true)
			end
		end
		nd = n
		if mode ~= "debuffs" and ub and not offB then
			for i = 1, 32 do
				if n >= max then break end
				local tex, cnt = ub(unit, i)
				if not tex then break end
				n = n + 1
				paintAura(f, n, tex, cnt, nil, false)
			end
		end
	end
	placeAuras(f, nd, n - nd)
	for i = n + 1, MAXA do
		f.auTex[i]:Hide()
		f.auBd[i]:Hide()
		f.auCnt[i]:SetText("")
	end
end

-- ---------------------------------------------------------------- mise a jour d'un cadre
function U.UpdateHealth(f)
	local unit = f.unit
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	local ratio = (max > 0) and (hp / max) or 0
	if f.dead then ratio = 0 end
	if cfg.smooth and f.drawn then
		f.goal = ratio
		f.anim = true
	else
		f.cur = ratio
		f.goal = ratio
		f.anim = false
		f.hp:SetValue(ratio)
	end
	f.drawn = true
	f.lratio = ratio
	if cfg.hpcolor == "gradient" then
		local r, g, b = U.HealthColor(unit, ratio)
		f.hp:SetStatusBarColor(r, g, b, 1)
	end
	local txt = ""
	if f.dead or f.offline then
		txt = ""
	else
		local mode = f.cf.hptext
		if mode == "default" then mode = cfg.hptext end
		txt = U.HpString(mode, hp, max)
	end
	f.hpText:SetText(txt)
	-- Pre-soin (soins entrants) : barre translucide par-dessus la vie, jamais au-dela du plein
	if f.heal then
		local inc = 0
		if cfg.incheal and not f.dead and SUI.UnitsIncoming then
			inc = SUI.UnitsIncoming(unit, UnitName(unit) or "", SUI.Api.GUID(unit)) or 0
		end
		local hv = ratio
		if inc > 0 and max > 0 then
			hv = (hp + inc) / max
			if hv > 1 then hv = 1 end
		end
		f.heal:SetValue(hv)
	end
	f.lhp, f.lmx = hp, max
end

function U.UpdatePower(f)
	if f.noPower then return end
	local unit = f.unit
	local max = UnitManaMax(unit)
	if not cfg.showpower or max <= 0 or f.dead or f.offline or not f.live then
		f.pw:Hide()
		return
	end
	f.pw:Show()
	local ptype = UnitPowerType(unit)
	local pc = PC[ptype]
	local cur = UnitMana(unit)
	if pc and pc.on then
		f.pw:SetStatusBarColor(pc.r, pc.g, pc.b, 1)
	else
		local col = POWER_COL[ptype] or COL_GRAY
		f.pw:SetStatusBarColor(col[1], col[2], col[3], 1)
	end
	f.pw:SetValue(cur / max)
	f.lpw = cur
	f.pwText:SetText(U.PowerString(f.cf.powertext, cur, max))
end

-- Cadre du focus dont l'unite n'est pas lisible (hors de portee, hors de la zone) : dernier etat connu, grise.
local function refreshFrozen(f)
	f.live = false
	f.dead, f.offline = false, false
	f.nameText:SetText(U.focusName or "")
	f.hp:SetStatusBarColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	f.hp:SetValue(f.lratio or 0)
	f.cur, f.goal, f.anim = f.lratio or 0, f.lratio or 0, false
	f.hpText:SetText("")
	f.statusText:SetText(L("msg.units.focusaway"))
	f.pw:Hide()
	if f.heal then f.heal:SetValue(0) end
	f:SetAlpha(0.55)
	f.lnm = U.focusName
	U.UpdateIcons(f)
	U.UpdatePortrait(f)
	U.UpdateAuras(f)
end

-- Repere "monstre de quete" au coin du cadre (cibles et assimiles, pas le joueur ni les amis)
function U.UpdateQuestMark(f, unit, name)
	local Q = SUI.QuestTrack
	local on = unit ~= "player" and Q and Q.MarkWanted and Q.MarkWanted() and not UnitIsPlayer(unit) and not UnitIsFriend("player", unit)
		and Q.UnitObjective(name) and true or false
	if on then
		if not f.qTex then
			f.qTex = f:CreateTexture(nil, "OVERLAY")
			f.qTex:SetWidth(14)
			f.qTex:SetHeight(14)
			f.qTex:SetTexture(Q.MARK_TEX)
			f.qTex:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 1)
		end
		f.qTex:Show()
	elseif f.qTex then
		f.qTex:Hide()
	end
end

function U.Refresh(f)
	local unit = f.unit
	if f.key == "focus" and not UnitExists(unit) then
		refreshFrozen(f)
		return
	end
	f.live = true
	if f.key == "focus" then f:SetAlpha(1) end
	local name = UnitName(unit) or ""
	f.dead = UnitIsDeadOrGhost(unit) and true or false
	f.offline = (UnitIsPlayer(unit) and not UnitIsConnected(unit)) and true or false
	local prefix = ""
	if unit ~= "player" then
		local lv = UnitLevel(unit)
		if lv and lv > 0 then prefix = lv .. " " elseif lv == -1 then prefix = "?? " end
	end
	f.nameText:SetText(prefix .. name)
	U.UpdateQuestMark(f, unit, name)
	if f.snap then
		f.drawn = false          -- nouvelle unite : la barre saute a la bonne valeur au lieu de glisser depuis l'ancienne
		f.snap = false
	end
	local r, g, b = U.HealthColor(unit, f.lratio or 1)
	f.hp:SetStatusBarColor(r, g, b, 1)
	if f.heal then f.heal:SetStatusBarColor(T.c.good[1], T.c.good[2], T.c.good[3], 0.45) end
	if f.dead then
		f.statusText:SetText(UnitIsGhost(unit) and L("unit.ghost") or L("unit.dead"))
	elseif f.offline then
		f.statusText:SetText(L("unit.offline"))
	else
		f.statusText:SetText("")
	end
	U.UpdateHealth(f)
	U.UpdatePower(f)
	U.UpdateIcons(f)
	U.UpdatePortrait(f)
	U.UpdateAuras(f)
	f.lnm = name
end

-- Un cadre est voulu s'il est actif et que son unite existe (le focus reste voulu, fige, tant qu'un focus est defini).
local function wanted(f)
	if not (U.active and U.Enabled(f.key)) then return false end
	if f.key == "player" or UnitExists(f.unit) then return true end
	return (f.key == "focus" and U.focusName ~= nil)
end

function U.UpdateVisibility(f)
	local want = wanted(f) and true or false
	if want ~= f.vis then
		f.vis = want
		if want then f:Show() else f:Hide() end
		if want then
			f.dAll = true
			f.snap = true
		end
	end
	return want
end

function U.MarkAll()
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then f.dAll = true end
	end
	U.dirty = true
end

-- Appele par le moteur de groupe (Mod_Group) quand un montant de soin entrant change : joueur et cible relisent.
SUI.UnitsHealNotify = function()
	local any = false
	local p, t = U.frames.player, U.frames.target
	if p and p.vis then p.dHp = true any = true end
	if t and t.vis then t.dHp = true any = true end
	if any then U.dirty = true end
end

-- Boucle de rafraichissement groupe (minuterie partagee, ralentie en mode urgence).
function U.Flush()
	if not U.dirty and not U.animating then return end
	U.dirty = false
	local anim = false
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then
			if f.dAll then
				f.dAll, f.dHp, f.dPw, f.dIc, f.dAu, f.dPo = false, false, false, false, false, false
				if U.UpdateVisibility(f) then U.Refresh(f) end
			elseif f.vis then
				if f.dHp then
					f.dHp = false
					U.UpdateHealth(f)
				end
				if f.dPw then
					f.dPw = false
					U.UpdatePower(f)
				end
				if f.dIc then
					f.dIc = false
					U.UpdateIcons(f)
				end
				if f.dAu then
					f.dAu = false
					U.UpdateAuras(f)
				end
				if f.dPo then
					f.dPo = false
					U.UpdatePortrait(f)
				end
			end
			if f.anim then
				local d = f.goal - f.cur
				if d < 0.004 and d > -0.004 then
					f.cur = f.goal
					f.anim = false
				else
					f.cur = f.cur + d * 0.35
				end
				f.hp:SetValue(f.cur)
				if f.anim then anim = true end
			end
		end
	end
	U.animating = anim
end

-- ---------------------------------------------------------------- evenements
local HP_EV = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true }
local PW_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_RAGE = true, UNIT_MAXRAGE = true, UNIT_ENERGY = true,
	UNIT_MAXENERGY = true, UNIT_FOCUS = true, UNIT_MAXFOCUS = true }
local ALL_EV = { UNIT_DISPLAYPOWER = true, UNIT_NAME_UPDATE = true, UNIT_LEVEL = true, UNIT_FLAGS = true, UNIT_FACTION = true }

-- ---------------------------------------------------------------- regle des 5 secondes et tick de mana (joueur)
-- Estimation lue sur les variations de MA mana (evenement UNIT_MANA) : une baisse relance les 5 s sans regeneration d'esprit, une hausse est
-- un tick (toutes les 2 s). Une potion ou une capacite qui rend de la mana decale la phase d'un tick : l'etincelle est indicative.
function U.ManaSample()
	if UnitPowerType("player") ~= 0 then
		U.lastMana = nil
		return
	end
	local mana, now = UnitMana("player"), GetTime()
	local last = U.lastMana
	if last then
		if mana < last then U.fsrEnd = now + 5 elseif mana > last then U.tickAt = now end
	end
	U.lastMana = mana
end

function U.TickSpark()
	local f = U.frames.player
	local sp = f and f.spark
	if not sp then return end
	if not f.vis or f.noPower or not f.pw:IsShown() or UnitPowerType("player") ~= 0 then
		sp:Hide()
		return
	end
	local now = GetTime()
	local d = now - U.tickAt
	local frac = (d - floor(d / 2) * 2) / 2
	sp:ClearAllPoints()
	sp:SetPoint("CENTER", f.pw, "LEFT", frac * (f:GetWidth() - 2), 0)
	local col = (now < U.fsrEnd) and T.c.dim or T.c.good
	sp:SetVertexColor(col[1], col[2], col[3], 1)
	sp:Show()
end

-- Lance / coupe la minuterie de l'etincelle selon l'option du joueur.
function U.SyncFsr()
	local f = U.frames.player
	local on = (U.active and f and f.cf.fsr) and true or false
	if on == (U.fsrOn and true or false) then return end
	U.fsrOn = on
	if on then
		U.tickAt, U.fsrEnd = GetTime(), 0
		U.lastMana = (UnitPowerType("player") == 0) and UnitMana("player") or nil
		U.tFsr = SUI.Every(0.05, U.TickSpark, "units.fsr", true)
	else
		if U.tFsr then SUI.Cancel(U.tFsr) end
		U.tFsr = nil
		if f and f.spark then f.spark:Hide() end
	end
end

local function onUnitEvent(ev, a1)
	if U.fsrOn and a1 == "player" and ev == "UNIT_MANA" then U.ManaSample() end
	if ev == "UNIT_PET" and a1 == "player" then
		local pf = U.frames.pet
		if pf then pf.dAll = true ; U.dirty = true end
		return
	end
	local f = U.frames[a1]
	if not f or not f.vis then return end
	if HP_EV[ev] then f.dHp = true
	elseif PW_EV[ev] then f.dPw = true
	elseif ALL_EV[ev] then f.dAll = true
	elseif ev == "UNIT_AURA" then
		if f.auTex and f.cf.auras ~= "off" then f.dAu = true else return end
	elseif ev == "UNIT_PORTRAIT_UPDATE" then
		if f.port and f.cf.portrait ~= "off" then f.dPo = true else return end
	else return end
	U.dirty = true
end

-- Groupe, butin, marques, combat, repos : on relit les indicateurs des cadres qui en affichent.
local function onIconEvent()
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f and f.vis then
			f.dIc = true
			U.dirty = true
		end
	end
end

local function onTargetChanged()
	local t, tt, t3 = U.frames.target, U.frames.targettarget, U.frames.targettargettarget
	if t then t.dAll = true; t.snap = true; t.rangeTxt = nil end
	if tt then tt.dAll = true; tt.snap = true end
	if t3 then t3.dAll = true; t3.snap = true end
	U.dirty = true
	U.PollTot()
	U.PollRange()
end

local function onPlayerState()
	local p = U.frames.player
	if p then p.dAll = true end
	U.dirty = true
end

local function onWorld()
	U.MarkAll()
	U.dirty = true
end

local UNIT_EVENTS = { "UNIT_PET", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_MAXRAGE",
	"UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FLAGS", "UNIT_FACTION",
	"UNIT_AURA", "UNIT_PORTRAIT_UPDATE" }
local ICON_EVENTS = { "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
	"PARTY_LOOT_METHOD_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING" }

-- Les evenements ne sont ecoutes que si un cadre affiche l'indicateur correspondant : marques de raid (cible d'office) d'un cote, chef /
-- butin / PvP / combat / repos de l'autre (coupes par defaut).
function U.SyncIcons()
	local wm, wo = false, false
	if U.active then
		for i = 1, getn(U.order) do
			local f = U.frames[U.order[i]]
			local cf = f and f.cf
			if cf then
				if cf.mark then wm = true end
				if cf.leader or cf.loot or cf.pvp or cf.combat then wo = true end
			end
		end
	end
	if wm ~= (U.markOn and true or false) then
		U.markOn = wm
		if wm then SUI.On("RAID_TARGET_UPDATE", onIconEvent) else SUI.Off("RAID_TARGET_UPDATE", onIconEvent) end
	end
	if wo ~= (U.iconsOn and true or false) then
		U.iconsOn = wo
		for i = 1, getn(ICON_EVENTS) do
			local ev = ICON_EVENTS[i]
			if ev ~= "RAID_TARGET_UPDATE" then
				if wo then SUI.On(ev, onIconEvent) else SUI.Off(ev, onIconEvent) end
			end
		end
	end
end

-- ---------------------------------------------------------------- focus emule
-- Le jeton d'unite lisible du focus : le GUID (SuperWoW) s'il existe, sinon ma cible / la cible de ma cible quand c'est la meme unite.
local function isFocus(tok)
	if not UnitExists(tok) then return false end
	if U.focusGuid then return SUI.Api.GUID(tok) == U.focusGuid end
	return UnitName(tok) == U.focusName
end

function U.ResolveFocus()
	if not U.focusName then return nil end
	if U.focusGuid and SUI.Api.superwow and UnitExists(U.focusGuid) then return U.focusGuid end
	if isFocus("target") then return "target" end
	if isFocus("targettarget") then return "targettarget" end
	if isFocus("mouseover") then return "mouseover" end
	return nil
end

function U.SetFocus(unit)
	unit = unit or "target"
	if not UnitExists(unit) then
		SUI.Print(L("msg.units.nofocus"))
		return false
	end
	U.focusName = UnitName(unit)
	U.focusGuid = SUI.Api.GUID(unit)
	local said = false
	local cb = SUI.CastBar
	-- la barre d'incantation du focus (Mod_CastBar) suit le meme ennemi quand le GUID est lisible
	if U.focusGuid and unit == "target" and cb and cb.SetFocus then said = cb.SetFocus() and true or false end
	if not said then SUI.Print(L("msg.units.focusset", U.focusName or "?")) end
	local f = U.frames.focus
	if f then
		f.dAll = true
		f.snap = true
		U.dirty = true
	end
	U.PollTot()
	return true
end

function U.ClearFocus()
	local had = U.focusName ~= nil
	U.focusName, U.focusGuid = nil, nil
	local cb = SUI.CastBar
	local said = false
	if cb and cb.focusGuid and cb.ClearFocus then
		cb.ClearFocus()
		said = true
	end
	local f = U.frames.focus
	if f then
		f.unit = "focus"
		f.lratio = nil
		f.dAll = true
		U.dirty = true
	end
	if had and not said then SUI.Print(L("msg.units.focuscleared")) end
end

function U.TargetFocus()
	local f = U.frames.focus
	if not U.focusName then return false end
	if f and f.live and f.unit ~= "target" and UnitExists(f.unit) then
		TargetUnit(f.unit)
		return true
	end
	local tbn = getglobal("TargetByName")
	if tbn then tbn(U.focusName, true) end
	return true
end

-- ---------------------------------------------------------------- sondages (cibles de cibles, focus, distance)
local function pollOne(f)
	if f.key == "focus" then
		local tok = U.ResolveFocus() or "focus"
		if tok ~= f.unit then
			f.unit = tok
			f.snap = true
			f.dAll = true
			U.dirty = true
			return
		end
	end
	local unit = f.unit
	local want = wanted(f) and true or false
	if want ~= (f.vis and true or false) then
		f.dAll = true
		U.dirty = true
		return
	end
	if not want or not UnitExists(unit) then return end
	local hp, mx, nm = UnitHealth(unit), UnitHealthMax(unit), UnitName(unit)
	local pw = f.noPower and 0 or UnitMana(unit)
	if hp ~= f.lhp or mx ~= f.lmx or nm ~= f.lnm or (not f.noPower and pw ~= f.lpw) then
		if nm ~= f.lnm then f.snap = true end
		f.dAll = true
		U.dirty = true
	elseif f.auTex and f.cf.auras ~= "off" then
		f.auTick = (f.auTick or 0) + 1
		if f.auTick >= 2 then
			f.auTick = 0
			f.dAu = true
			U.dirty = true
		end
	end
end

function U.PollTot()
	if not U.active then return end
	for i = 1, getn(POLLED) do
		local f = U.frames[POLLED[i]]
		if f and f.cf.enabled then pollOne(f) end
	end
end

function U.PollRange()
	local f = U.frames.target
	if not f or not f.vis then return end
	if not cfg.range then
		if f.rangeTxt ~= "" then
			f.rangeTxt = ""
			f.rangeText:SetText("")
			f:SetAlpha(1)
		end
		return
	end
	local d, src = SUI.Api.Distance("target")
	local txt = ""
	if src then
		if d then txt = SUI.Api.FormatDistance(d, src) else txt = ">28 yd" end
	end
	if txt ~= f.rangeTxt then
		f.rangeTxt = txt
		f.rangeText:SetText(txt)
	end
	local sight = SUI.Api.InSight("target")
	local alpha = (sight == false) and 0.55 or 1
	if alpha ~= f.alphaNow then
		f.alphaNow = alpha
		f:SetAlpha(alpha)
	end
end

-- ---------------------------------------------------------------- interactions
local MODFN = { shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown", alt = "IsAltKeyDown" }
local function modDown(m)
	local n = MODFN[m]
	local fn = n and getglobal(n)
	return (fn and fn()) and true or false
end

-- Clic avec modificateur : sur la cible / sa cible = definir le focus ; sur le cadre du focus = l'effacer.
function U.FocusClick(f, btn)
	if btn ~= "LeftButton" or cfg.focusmod == "off" or not modDown(cfg.focusmod) then return false end
	if f.key == "focus" then
		U.ClearFocus()
		return true
	end
	if (f.key == "target" or f.key == "targettarget") and U.Enabled("focus") then
		U.SetFocus(f.unit)
		return true
	end
	return false
end

local function onClick()
	local f = this
	local unit = f.unit
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.ClickSolo and ch.ClickSolo(unit, arg1, f) then return end   -- soins au clic sur soi / la cible (Mod_ClickHeal)
	if U.FocusClick(f, arg1) then return end
	if arg1 == "RightButton" then
		U.OpenMenu(f)
		return
	end
	if f.key == "focus" then
		U.TargetFocus()
	elseif SpellIsTargeting() then
		SpellTargetUnit(unit)
	elseif CursorHasItem() then
		DropItemOnUnit(unit)
	else
		TargetUnit(unit)
	end
end

function U.OpenMenu(f)
	local name = (f.unit == "player") and "PlayerFrameDropDown" or ((f.unit == "target") and "TargetFrameDropDown" or nil)
	local dd = name and getglobal(name)
	if dd and ToggleDropDownMenu then
		pcall(ToggleDropDownMenu, 1, nil, dd, "cursor")
	end
end

local function onWheel()
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.WheelSolo then ch.WheelSolo(this.unit, arg1, this) end
end

-- Roulette : activee seulement si une liaison de clic-soin en utilise (appelee par Mod_ClickHeal).
function U.SyncWheel()
	local ch = SUI.ClickHeal
	local on = (ch and ch.on and ch.hasWheel) and true or false
	local p, t = U.frames.player, U.frames.target
	if p then p:EnableMouseWheel((on and ch.SoloOn("player")) and true or false) end
	if t then t:EnableMouseWheel((on and ch.SoloOn("target")) and true or false) end
end

local function onEnter()
	local f = this
	if not UnitExists(f.unit) then return end
	SUI.Api.SetMouseover(f.unit)
	if GameTooltip then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:SetUnit(f.unit)
		local ch = SUI.ClickHeal
		if ch and ch.on and ch.AddHints and ch.SoloOn(f.unit) then ch.AddHints(GameTooltip, f) end
		GameTooltip:Show()
	end
end

local function onLeave()
	SUI.Api.SetMouseover(nil)
	if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- construction (hors combat uniquement)
local function mkText(parent, size, col, just)
	local fs = T.Text(parent, size, col, just, true)
	fs.suiTk = T.items[getn(T.items)]       -- enregistrement de style du texte : la taille se change sans toucher au Theme
	return fs
end

local function fontSize(fs, size)
	local it = fs.suiTk
	if not it or it.size == size then return end
	it.size = size
	local px = floor(size * T.fontScale + 0.5)
	if px < 6 then px = 6 end
	local flags = T.outline
	if it.outline and flags == "" then flags = "OUTLINE" end
	pcall(fs.SetFont, fs, T.font, px, flags)
end

function U.Create(unit)
	local caps = CAPS[unit]
	local f = CreateFrame("Button", "ShikiUI_Unit_" .. unit, UIParent)
	f.unit = unit
	f.key = unit
	f.noPower = not caps.power
	f.live = true
	f.cf = { enabled = false }
	for j = 1, getn(SPEC) do f.cf[SPEC[j].name] = specDefault(unit, SPEC[j]) end
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	T.Backdrop(f, T.c.bg, T.c.border)
	-- Barre de pre-soin (soins entrants) SOUS la barre de vie : tout sauf les petits cadres sans ressource
	if caps.power then
		f.heal = T.Bar(f)
		f.heal:SetFrameLevel(f:GetFrameLevel() + 1)
	end
	f.hp = T.Bar(f)
	f.hp:SetFrameLevel(f:GetFrameLevel() + 2)
	-- le fond opaque de la barre de vie cacherait la barre de pre-soin placee dessous : le fond est celui de la barre de pre-soin
	if f.heal and f.hp.bg then f.hp.bg:Hide() end
	f.pw = T.Bar(f)
	f.pw:SetFrameLevel(f:GetFrameLevel() + 2)
	f.nameText = mkText(f.hp, 11, T.c.text, "LEFT")
	f.hpText = mkText(f.hp, 11, T.c.text, "RIGHT")
	f.statusText = mkText(f.hp, 11, T.c.warn, "CENTER")
	f.statusText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
	if caps.power then
		f.pwText = mkText(f.pw, 9, T.c.text, "CENTER")
		f.pwText:SetPoint("CENTER", f.pw, "CENTER", 0, 0)
	end
	if unit == "target" then
		f.rangeText = T.Text(f, 10, T.c.dim, "RIGHT", true)
		f.rangeText:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
	end
	-- calque au-dessus des barres : marqueur de raid, indicateurs, effets
	f.ov = CreateFrame("Frame", nil, f)
	f.ov:SetFrameLevel(f:GetFrameLevel() + 6)
	f.ov:SetAllPoints(f)
	f.imark = f.ov:CreateTexture(nil, "OVERLAY")
	f.imark:SetTexture(TEX_MARK)
	f.imark:Hide()
	f.ind = {}
	if caps.pvp then f.ind.pvp = f.ov:CreateTexture(nil, "OVERLAY") end
	if caps.leader then f.ind.lead = f.ov:CreateTexture(nil, "OVERLAY") end
	if caps.loot then
		f.ind.loot = f.ov:CreateTexture(nil, "OVERLAY")
		f.ind.loot:SetTexture(TEX_LOOT)
	end
	if caps.combat then
		f.ind.comb = f.ov:CreateTexture(nil, "OVERLAY")
		f.ind.comb:SetTexture(TEX_STATE)
	end
	for _, tx in pairs(f.ind) do tx:Hide() end
	if caps.fsr then
		f.spark = f.ov:CreateTexture(nil, "OVERLAY")
		f.spark:SetTexture(T.tex.white)
		f.spark:SetWidth(2)
		f.spark:Hide()
	end
	if caps.port then
		f.port = CreateFrame("Frame", nil, f)
		T.Backdrop(f.port, T.c.bg, T.c.border)
		f.port.tex = f.port:CreateTexture(nil, "ARTWORK")
		f.port.tex:SetPoint("TOPLEFT", f.port, "TOPLEFT", 1, -1)
		f.port.tex:SetPoint("BOTTOMRIGHT", f.port, "BOTTOMRIGHT", -1, 1)
		f.port:Hide()
	end
	if caps.auras then
		f.auTex, f.auBd, f.auCnt = {}, {}, {}
		for i = 1, MAXA do
			local bd = f.ov:CreateTexture(nil, "BACKGROUND")
			bd:SetTexture(T.tex.white)
			bd:Hide()
			local tx = f.ov:CreateTexture(nil, "ARTWORK")
			tx:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			tx:Hide()
			local ct = mkText(f.ov, 9, T.c.text, "RIGHT")
			f.auBd[i], f.auTex[i], f.auCnt[i] = bd, tx, ct
		end
	end
	f:SetScript("OnClick", onClick)
	f:SetScript("OnMouseWheel", onWheel)
	f:SetScript("OnEnter", onEnter)
	f:SetScript("OnLeave", onLeave)
	f.dAll = true
	f:Hide()
	return f
end

local function layoutOne(f, w, h, gph)
	local key = f.key
	local cf = f.cf
	local caps = CAPS[key]
	local ra = RATIO[key]
	local rw, rh = 1, 1
	if ra then rw, rh = ra[1], ra[2] end
	local fw = (cf.width > 0) and cf.width or floor(w * rw)
	local fh = math.max(14, (cf.height > 0) and cf.height or floor(h * rh))
	local ph = (cf.powerheight > 0) and cf.powerheight or gph
	f:SetWidth(fw)
	f:SetHeight(fh)
	local withPower = cfg.showpower and caps.power
	local hpH = withPower and (fh - 3 - ph) or (fh - 2)
	if f.heal then
		f.heal:ClearAllPoints()
		f.heal:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.heal:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		f.heal:SetHeight(hpH)
	end
	f.hp:ClearAllPoints()
	f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	f.hp:SetHeight(hpH)
	f.pw:ClearAllPoints()
	f.pw:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	f.pw:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.pw:SetHeight(ph)
	if not withPower then f.pw:Hide() end
	if f.spark then f.spark:SetHeight(ph + 2) end
	-- textes : taille, alignement du texte de vie (le nom prend l'autre cote)
	local ts = cf.textsize
	fontSize(f.nameText, ts)
	fontSize(f.hpText, ts)
	fontSize(f.statusText, ts)
	if f.pwText then fontSize(f.pwText, math.max(8, ts - 2)) end
	f.nameText:ClearAllPoints()
	f.hpText:ClearAllPoints()
	local al = cf.hpalign
	local na = NAMEAT[cf.nameanchor or "default"]
	if al == "left" then
		f.hpText:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
		f.hpText:SetJustifyH("LEFT")
		f.nameText:SetPoint("RIGHT", f.hp, "RIGHT", -4, 0)
		f.nameText:SetJustifyH("RIGHT")
		f.nameText:SetWidth(floor(fw * 0.55))
	elseif al == "center" then
		f.hpText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
		f.hpText:SetJustifyH("CENTER")
		f.nameText:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
		f.nameText:SetJustifyH("LEFT")
		f.nameText:SetWidth(floor(fw * 0.4))
	else
		f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -4, 0)
		f.hpText:SetJustifyH("RIGHT")
		f.nameText:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
		f.nameText:SetJustifyH("LEFT")
		f.nameText:SetWidth(floor(fw * 0.62))
	end
	if na then
		-- pseudo place par le reglage : 9 positions dans la barre de vie
		f.nameText:ClearAllPoints()
		f.nameText:SetPoint(na[1], f.hp, na[1], (na[2] == "LEFT") and 4 or ((na[2] == "RIGHT") and -4 or 0), na[3])
		f.nameText:SetJustifyH(na[2])
		f.nameText:SetWidth(fw - 8)
	end
	if cf.nameanchor == "off" then f.nameText:Hide() else f.nameText:Show() end
	f.nameText:SetHeight(ts + 1)
	f.hpText:SetHeight(ts + 1)
	if f.pwText then
		f.pwText:SetHeight(math.max(8, ts - 2) + 1)
	end
	-- portrait, a gauche ou a droite, carre de la hauteur du cadre
	if f.port then
		f.port:SetWidth(fh)
		f.port:SetHeight(fh)
		f.port:ClearAllPoints()
		if cf.portraitside == "right" then
			f.port:SetPoint("LEFT", f, "RIGHT", 2, 0)
		else
			f.port:SetPoint("RIGHT", f, "LEFT", -2, 0)
		end
	end
	-- indicateurs
	local s = cfg.indsize
	f.imark:SetWidth(s)
	f.imark:SetHeight(s)
	f.imark:ClearAllPoints()
	f.imark:SetPoint("CENTER", f, "TOP", 0, 0)
	for k, tx in pairs(f.ind) do
		local sz = (k == "pvp") and floor(s * 1.4) or s
		tx:SetWidth(sz)
		tx:SetHeight(sz)
	end
	-- groupes d'effets (positions posees par placeAuras a la prochaine relecture des effets)
	if f.auTex then
		local a = cfg.aurasize
		f.auKey = nil
		f.dAu = true
		for i = 1, MAXA do
			local bd, tx, ct = f.auBd[i], f.auTex[i], f.auCnt[i]
			bd:SetWidth(a + 2)
			bd:SetHeight(a + 2)
			tx:SetWidth(a)
			tx:SetHeight(a)
			ct:ClearAllPoints()
			ct:SetPoint("BOTTOMRIGHT", tx, "BOTTOMRIGHT", 1, 0)
			ct:SetWidth(a)
			ct:SetHeight(10)
		end
	end
	SUI.Layout.Apply("unit." .. key)
end

function U.ApplyLayout()
	local C = SUI.Config
	local w = C.Get("units.width")
	local h = C.Get("units.height")
	local ph = C.Get("units.powerheight")
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then layoutOne(f, w, h, ph) end
	end
	U.dirty = true
end

function U.Build()
	if U.built then return end
	U.built = true
	local defaults = { player = { -230, -150 }, target = { 230, -150 }, targettarget = { 230, -196 }, pet = { -160, -196 },
		targettargettarget = { 230, -236 }, pettarget = { -160, -236 }, focus = { 230, -100 } }
	for i = 1, getn(U.order) do
		local unit = U.order[i]
		local f = U.Create(unit)
		U.frames[unit] = f
		SUI.Layout.Register(f, "unit." .. unit, "CENTER", defaults[unit][1], defaults[unit][2])
	end
	U.ReadConfig()
	U.ApplyLayout()
end

-- Les cadres Blizzard ne sont masques que si aucun autre addon (pfUI) ne s'en charge deja.
local function blizzFree()
	return not (SUI.Migrate and SUI.Migrate.BlizzOwned())
end

function U.HideBlizzard()
	for i = 1, getn(BLIZZ) do
		local fr = getglobal(BLIZZ[i])
		if fr then
			fr:UnregisterAllEvents()
			fr:Hide()
		end
	end
	U.blizzHidden = true
end

local function onConfig(key, value)
	if not U.built then return end
	U.ReadConfig()
	if key == "units.incheal" and SUI.GroupEngine and SUI.GroupEngine.SyncCast then
		SUI.GroupEngine.SyncCast()   -- le moteur re-evalue s'il doit ecouter mes incantations
	end
	if key == "units.hideblizz" then
		if value then
			if blizzFree() then U.HideBlizzard() end
		elseif U.blizzHidden then
			SUI.Print(L("msg.reload"))
		end
	end
	if key == nil or string.sub(key, 1, 6) == "units." then
		U.ApplyLayout()
		U.MarkAll()
	end
end

local function onEmergency(on)
	U.ReadConfig()
	U.MarkAll()
end

-- ---------------------------------------------------------------- commandes /focus, /clearfocus, /targetfocus
local function slashTaken(word)
	local sl = getglobal("SlashCmdList")
	if type(sl) ~= "table" then return true end
	for k in pairs(sl) do
		for j = 1, 4 do
			if getglobal("SLASH_" .. k .. j) == word then return true end
		end
	end
	return false
end

local function slashFocus(msg)
	msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
	local low = string.lower(msg)
	if msg == "" then
		U.SetFocus("target")
	elseif low == "clear" or low == "off" then
		U.ClearFocus()
	else
		U.focusName, U.focusGuid = msg, nil
		SUI.Print(L("msg.units.focusset", msg))
		local f = U.frames.focus
		if f then f.dAll = true U.dirty = true end
		U.PollTot()
	end
end

-- Commandes de confort : jamais en double d'un autre addon (pfUI a les siennes, on s'efface alors).
function U.RegisterSlash()
	if U.slash then return end
	U.slash = true
	local sl = getglobal("SlashCmdList")
	if type(sl) ~= "table" then return end
	if not slashTaken("/focus") then
		setglobal("SLASH_SHIKIUIFOCUS1", "/focus")
		sl["SHIKIUIFOCUS"] = slashFocus
	end
	if not slashTaken("/clearfocus") then
		setglobal("SLASH_SHIKIUICLEARFOCUS1", "/clearfocus")
		sl["SHIKIUICLEARFOCUS"] = function() U.ClearFocus() end
	end
	if not slashTaken("/targetfocus") then
		setglobal("SLASH_SHIKIUITARGETFOCUS1", "/targetfocus")
		sl["SHIKIUITARGETFOCUS"] = function() U.TargetFocus() end
	end
end

function U.Activate()
	U.active = true
	if SUI.Config.Get("units.hideblizz") and blizzFree() then U.HideBlizzard() end
	for i = 1, getn(UNIT_EVENTS) do SUI.On(UNIT_EVENTS[i], onUnitEvent) end
	SUI.On("PLAYER_TARGET_CHANGED", onTargetChanged)
	SUI.On("PLAYER_DEAD", onPlayerState)
	SUI.On("PLAYER_ALIVE", onPlayerState)
	SUI.On("PLAYER_UNGHOST", onPlayerState)
	SUI.On("PLAYER_ENTERING_WORLD", onWorld)
	U.tFlush = SUI.Every(FLUSH, U.Flush, "units.flush", true)
	U.tTot = SUI.Every(POLL_TOT, U.PollTot, "units.tot", true)
	U.tRange = SUI.Every(POLL_RANGE, U.PollRange, "units.range", true)
	-- Le moteur de groupe doit ecouter mes incantations pour la barre de pre-soin joueur / cible
	if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
	U.RegisterSlash()
	U.SyncFsr()
	U.SyncIcons()
	U.MarkAll()
end

function U.Deactivate()
	U.active = false
	for i = 1, getn(UNIT_EVENTS) do SUI.Off(UNIT_EVENTS[i], onUnitEvent) end
	U.SyncIcons()
	SUI.Off("PLAYER_TARGET_CHANGED", onTargetChanged)
	SUI.Off("PLAYER_DEAD", onPlayerState)
	SUI.Off("PLAYER_ALIVE", onPlayerState)
	SUI.Off("PLAYER_UNGHOST", onPlayerState)
	SUI.Off("PLAYER_ENTERING_WORLD", onWorld)
	SUI.Cancel(U.tFlush)
	SUI.Cancel(U.tTot)
	SUI.Cancel(U.tRange)
	U.SyncFsr()
	if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then
			f.vis = false
			f:Hide()
		end
	end
end

local function enable()
	SUI.WhenSafe(function()
		if not U.watching then
			U.watching = true
			SUI.Config.Watch("units.", onConfig)
			SUI.Config.Watch("ui.", onConfig)
			SUI.Perf.OnEmergency(onEmergency)
		end
		U.Build()
		U.Activate()
	end)
end

-- ---------------------------------------------------------------- options
SUI.RegisterCategory("units", 2)

local function choiceText(o, v)
	return L("choice.units.f." .. o.spec .. "." .. tostring(v))
end

local OPTS = {
	{ key = "units.player.enabled", type = "bool", cat = "units", label = "opt.units.player.enabled", tip = "tip.units.player.enabled", default = true, order = 10 },
	{ key = "units.target.enabled", type = "bool", cat = "units", label = "opt.units.target.enabled", tip = "tip.units.target.enabled", default = true, order = 20 },
	{ key = "units.tot.enabled", type = "bool", cat = "units", label = "opt.units.tot.enabled", tip = "tip.units.tot.enabled", default = true, order = 30 },
	{ key = "units.pet.enabled", type = "bool", cat = "units", label = "opt.units.pet.enabled", tip = "tip.units.pet.enabled", default = true, order = 35 },
	{ key = "units.tott.enabled", type = "bool", cat = "units", label = "opt.units.tott.enabled", tip = "tip.units.tott.enabled", default = false, order = 36 },
	{ key = "units.pettarget.enabled", type = "bool", cat = "units", label = "opt.units.pettarget.enabled", tip = "tip.units.pettarget.enabled", default = false, order = 37 },
	{ key = "units.focus.enabled", type = "bool", cat = "units", label = "opt.units.focus.enabled", tip = "tip.units.focus.enabled", default = false, simple = true, order = 38 },
	{ key = "units.width", type = "number", cat = "units", label = "opt.units.width", tip = "tip.units.width", min = 100, max = 320, step = 5, default = 180, order = 40 },
	{ key = "units.height", type = "number", cat = "units", label = "opt.units.height", tip = "tip.units.height", min = 16, max = 60, step = 1, default = 28, order = 50 },
	{ key = "units.powerheight", type = "number", cat = "units", label = "opt.units.powerheight", tip = "tip.units.powerheight", min = 2, max = 12, step = 1, default = 4, order = 60 },
	{ key = "units.showpower", type = "bool", cat = "units", label = "opt.units.showpower", tip = "tip.units.showpower", default = true, order = 70 },
	{ key = "units.classcolor", type = "bool", cat = "units", label = "opt.units.classcolor", tip = "tip.units.classcolor", default = true, simple = true, order = 80 },
	{ key = "units.hptext", type = "choice", cat = "units", label = "opt.units.hptext", tip = "tip.units.hptext", choices = { "none", "value", "percent", "both", "deficit", "maxvalue" }, default = "percent", simple = true, order = 90 },
	{ key = "units.range", type = "bool", cat = "units", label = "opt.units.range", tip = "tip.units.range", default = true, simple = true, order = 100 },
	{ key = "units.smooth", type = "bool", cat = "units", label = "opt.units.smooth", tip = "tip.units.smooth", default = true, order = 110 },
	{ key = "units.incheal", type = "bool", cat = "units", label = "opt.units.incheal", tip = "tip.units.incheal", default = true, order = 115 },
	{ key = "units.hideblizz", type = "bool", cat = "units", label = "opt.units.hideblizz", tip = "tip.units.hideblizz", default = true, order = 120, reload = true },
	-- couleurs, effets, indicateurs (communs a tous les cadres)
	{ key = "units.hpcolor", type = "choice", cat = "units", label = "opt.units.hpcolor", tip = "tip.units.hpcolor", choices = { "auto", "reaction", "gradient", "custom" }, default = "auto", order = 130 },
	{ key = "units.aurasize", type = "number", cat = "units", label = "opt.units.aurasize", tip = "tip.units.aurasize", min = 10, max = 24, step = 1, default = 14, order = 140 },
	{ key = "units.auramax", type = "number", cat = "units", label = "opt.units.auramax", tip = "tip.units.auramax", min = 1, max = 8, step = 1, default = 6, order = 150 },
	{ key = "units.indsize", type = "number", cat = "units", label = "opt.units.indsize", tip = "tip.units.indsize", min = 10, max = 24, step = 1, default = 14, order = 160 },
	{ key = "units.c.hp", type = "color", cat = "units", label = "opt.units.c.hp", tip = "tip.units.c.hp", default = "", order = 170 },
	{ key = "units.c.mana", type = "color", cat = "units", label = "opt.units.c.mana", tip = "tip.units.c.mana", default = "", order = 171 },
	{ key = "units.c.rage", type = "color", cat = "units", label = "opt.units.c.rage", tip = "tip.units.c.rage", default = "", order = 172 },
	{ key = "units.c.energy", type = "color", cat = "units", label = "opt.units.c.energy", tip = "tip.units.c.energy", default = "", order = 173 },
	{ key = "units.focus.modclick", type = "choice", cat = "units", label = "opt.units.focus.modclick", tip = "tip.units.focus.modclick", choices = { "shift", "ctrl", "alt", "off" }, default = "shift", order = 1999 },
}
-- reglages par cadre : une serie de cles units.<cadre>.<nom> pour chaque capacite du cadre (ordre : 1000 + 40 par cadre)
for i = 1, getn(U.order) do
	local key = U.order[i]
	local n = U.cfgName[key]
	local caps = CAPS[key]
	for j = 1, getn(SPEC) do
		local sp = SPEC[j]
		if caps[sp.cap] then
			local o = { key = "units." .. n .. "." .. sp.name, type = sp.type, cat = "units", label = "opt.units." .. n .. "." .. sp.name,
				tip = "tip.units.f." .. sp.name, default = specDefault(key, sp), order = 1000 + i * 40 + j, spec = sp.name }
			if sp.type == "number" then o.min, o.max, o.step = sp.min, sp.max, sp.step end
			if sp.type == "choice" then
				o.choices = sp.choices
				o.choiceText = choiceText
			end
			tinsert(OPTS, o)
		end
	end
end

SUI.RegisterModule("units", {
	default = true,
	core = true,
	cost = "medium",
	options = OPTS,
	enable = enable,
	disable = function() U.Deactivate() end,
})
