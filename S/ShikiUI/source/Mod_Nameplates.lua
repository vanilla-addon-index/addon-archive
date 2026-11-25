-- ShikiUI Nameplates : plaques de nom des ennemis (v0.4, module "nameplates") : barre de vie, menace, debuffs PERSONNELS, barre d'incantation
-- de l'ennemi, marqueurs, distance.
-- Plaques (releve dans pfUI libs nameplates.lua, MIT, pas copie) : ce sont des enfants Button du WorldFrame ; plaque:GetName(1) renvoie le GUID
--   (SuperWoW) ; healthbar, castbar = plaque:GetChildren() ; regions dans l'ordre bordure, lueur, nom, niveau, icone de niveau, marqueur.
--   Les objets d'origine sont neutralises (texture vide, texte sans largeur) et NON restaures a la coupure (/reload pour les retrouver).
-- Menace : UnitIsUnit(guid.."target", "player") : l'ennemi vise-t-il le joueur ? (jeton "<guid>target" NON VERIFIE en jeu).
--   Couleur de la barre (comme TankSuite ; chaque couleur est un JETON du theme, reglable) : role TANK : 1 j'ai l'aggro (surete, vert), 3 je risque
--   de la perdre (alerte, orange, seuil threatwarn), 2 un autre l'a (danger, rouge), 4 un main tank du raid l'a, 5 un familier l'a, 6 l'ennemi a
--   ete PROVOQUE par moi (SuperWoW UNIT_CASTEVENT / Nampower SPELL_GO_SELF : sort de provocation lance par le joueur sur ce GUID, duree de l'effet),
--   7 l'ennemi est en combat sans personne pour cible. Role DPS / soigneur (inverse) : l'ennemi me vise = danger (rouge), je vais la prendre =
--   alerte, un autre l'a = surete (vert, option dpssafe). Mode "auto" : tank si le role du profil est tank, sinon dps. Pourcentage de menace sur la plaque : paquets d'addon du serveur
--   (CHAT_MSG_ADDON, meme protocole que TWThreat/TankSuite : "TWTv4=joueur:tank:menace:pct:melee;..." [+ "#TMTv1=creature:id:joueur:pct;..."]),
--   ecoutes passivement (TWThreat, la fenetre Menace ou le compteur peuvent les demander) et demandes nous-memes en groupe si personne ne le fait.
--   Le serveur n'envoie que la PARTIE BASSE de l'id de la creature : rapprochee des derniers chiffres hexa du GUID de la plaque ET du nom.
--   Rien n'est invente : pas de paquet recent = pas de chiffre. Hors groupe, le serveur ne repond pas (aucun chiffre).
-- Debuffs personnels : Nampower AURA_CAST_ON_OTHER(sort, lanceur, cible, effet, aura, amplitude, valeur, duree ms, etat) avec la CVar
--   NP_EnableAuraCastEvents ; retrait par DEBUFF_REMOVED_OTHER(guid, indice, sort, ...) et UNIT_DIED(guid). Texture via SpellInfo(sort)
--   (SuperWoW). Sans Nampower : UnitDebuff("target") sur la plaque de la cible seulement, sans duree.
-- Incantation ennemie : SuperWoW UNIT_CASTEVENT(lanceur, cible, type, sort, duree ms) et Nampower SPELL_START_OTHER / SPELL_FAILED_OTHER.
--   Sans eux : la barre d'origine de la plaque (valeurs lues, sans nom).
-- Cout declare : HEAVY. Reservoir de 40 emplacements construits hors combat (3 cadres chacun), UNE minuterie partagee (0,1 s),
--   aucun OnUpdate, aucune frame creee en combat, ecritures seulement si la valeur change. Les plaques sont redecouvertes quand le nombre
--   d'enfants du WorldFrame change (une table temporaire a ce moment seulement).
-- NON VERIFIE en jeu : tout ce qui precede, la lecture de GetValue() de la barre de vie d'origine (valeurs ou pourcentage), la detection
--   de plaque (bouton sans nom + texture de bordure), la cible reperee par GUID.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Nameplates = M

local getn = table.getn
local floor, abs = math.floor, math.abs
local strformat, strfind = string.format, string.find

local MAXSLOT = 100
local HEAVY = 24          -- au-dela : les plaques sans enjeu passent en mode compact (barre seule, plus petite) et se rafraichissent 1 tick sur 3
local COMPACT_SCALE = 0.75
local function mod3(x) return x - floor(x / 3) * 3 end
local MAXDEB = 6
local POOL = 128
local EMPTY = ""
local MARKTEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"   -- style:ok donnee de jeu
local BORDER_KEY = "Nameplate"
local THR_API, THR_TM = "TWTv4=", "TMTv1="
local THR_REQ, THR_REQ_TM = "TWT_UDTSv4", "TWT_UDTSv4_TM"
local THR_FRESH = 3.5      -- secondes : age maximal d'un chiffre affiche
local THR_SETTLE = 0.6     -- secondes apres un changement de cible pendant lesquelles une reponse simple peut etre celle de l'ancienne cible
local THR_MAXP = 15

M.on = false
M.built = false
M.slots = {}
M.free = {}
M.nFree = 0
M.nUsed = 0
M.slotOf = {}             -- plaque -> emplacement
M.byGuid = {}             -- guid -> emplacement
M.known = {}              -- enfant du WorldFrame -> vrai (plaque) | faux
M.plateList = {}
M.nPlates = 0
M.nWorld = -1
M.targetGuid = nil
M.playerGuid = nil
M.sname = {}
M.sicon = {}
-- reservoir de debuffs personnels (tableaux paralleles, aucune table creee a l'usage)
M.dGuid, M.dSpell, M.dEnd, M.dDur, M.dTex = {}, {}, {}, {}, {}
M.nd = 0
-- menace du serveur (tableaux prepares une fois ; aucune table creee a l'arrivee d'un paquet)
M.pl = { n = 0, at = -100, guid = nil, who = {}, tank = {}, perc = {} }        -- reponse simple : menace sur MA CIBLE
M.tm = { n = 0, at = -100, id = {}, creature = {}, who = {}, perc = {} }       -- mode tank : un enregistrement par creature que je tanke
M.mt = {}                 -- nom -> vrai : main tanks du raid
M.thrOn = false
M.pktAt, M.reqAt, M.targetAt = -100, -100, -100
M.nPkt, M.nReq = 0, 0
M.cfg = { width = 90, height = 10, hptext = true, name = true, level = true, classcolor = false, threat = true, tmode = "tank",
	targetglow = true, outline = "auto", targetscale = 1.2, debuffs = true, debuffmax = 4, debufftimer = true, debuffsize = 14, castbar = true,
	castheight = 8, casticon = true, castname = true, markers = true, markersize = 20, distance = "target", friendly = false,
	maxplates = 40, rate = 0.1, threatpct = true, threatwarn = 80, threatpos = "right", threatrequest = true, threattank = true,
	dpssafe = true, threatnone = true, threattaunt = true }
M.mode = "tank"           -- mode effectif ("tank" ou "dps") : le reglage "auto" suit le role du profil
M.tokOK = false           -- vrai des qu'un jeton "<guid>target" a repondu : seulement alors "sans cible" a un sens
M.tGuid, M.tUntil, M.tAllUntil = nil, 0, 0     -- derniere provocation lancee par le joueur (cible, fin d'effet, fin d'effet de zone)
-- Jetons de couleur par etat de menace (indice = etat, voir HolderState / ColorState) ; remplis par ReadConfig.
M.TOKENS = { "good", "warn", "bad", "accent", "text", "dim", "border", "panel" }
M.STATEKEY = { [1] = "colsafe", [2] = "coldanger", [3] = "colwarn", [4] = "colmt", [5] = "colpet", [6] = "coltaunt", [7] = "colnone" }
M.stateTok = { [1] = "good", [2] = "bad", [3] = "warn", [4] = "accent", [5] = "dim", [6] = "text", [7] = "border" }
M.MODES = { "auto", "tank", "dps" }

function M.ReadConfig()
	local cfg = M.cfg
	cfg.width = C.Get("nameplates.width")
	cfg.height = C.Get("nameplates.height")
	cfg.hptext = C.Get("nameplates.hptext")
	cfg.name = C.Get("nameplates.name")
	cfg.level = C.Get("nameplates.level")
	cfg.classcolor = C.Get("nameplates.classcolor")
	cfg.threat = C.Get("nameplates.threat")
	cfg.tmode = C.Get("nameplates.threatmode")
	cfg.targetglow = C.Get("nameplates.targetglow")
	cfg.outline = C.Get("nameplates.outline")
	cfg.targetscale = C.Get("nameplates.targetscale")
	cfg.debuffs = C.Get("nameplates.debuffs")
	cfg.debuffmax = C.Get("nameplates.debuffmax")
	cfg.debufftimer = C.Get("nameplates.debufftimer")
	cfg.debuffsize = C.Get("nameplates.debuffsize")
	cfg.castbar = C.Get("nameplates.castbar")
	cfg.castheight = C.Get("nameplates.castheight")
	cfg.casticon = C.Get("nameplates.casticon")
	cfg.castname = C.Get("nameplates.castname")
	cfg.markers = C.Get("nameplates.markers")
	cfg.markersize = C.Get("nameplates.markersize")
	cfg.distance = C.Get("nameplates.distance")
	cfg.friendly = C.Get("nameplates.friendly")
	cfg.maxplates = C.Get("nameplates.maxplates")
	cfg.rate = C.Get("nameplates.rate")
	cfg.threatpct = C.Get("nameplates.threatpct")
	cfg.threatwarn = C.Get("nameplates.threatwarn")
	cfg.threatpos = C.Get("nameplates.threatpos")
	cfg.threatrequest = C.Get("nameplates.threatrequest")
	cfg.threattank = C.Get("nameplates.threattank")
	cfg.dpssafe = C.Get("nameplates.dpssafe")
	cfg.threatnone = C.Get("nameplates.threatnone")
	cfg.threattaunt = C.Get("nameplates.threattaunt")
	for st, key in pairs(M.STATEKEY) do
		local v = C.Get("nameplates." .. key)
		if type(v) == "string" and (v == "accent" or T.c[v]) then M.stateTok[st] = v end
	end
	M.ResolveMode()
end

-- Mode effectif : "auto" = tank si le role du profil est tank, dps sinon (role inconnu : tank, comme avant l'ajout du mode auto).
function M.ResolveMode()
	local m = M.cfg.tmode
	if m ~= "tank" and m ~= "dps" then
		local role = C.GetRole()
		if role == nil or role == "tank" then m = "tank" else m = "dps" end
	end
	M.mode = m
	return m
end

-- Couleur (r, g, b) du jeton choisi pour un etat de menace.
function M.StateColor(st)
	local name = M.stateTok[st]
	if name == "accent" then return T.Accent() end
	local c = T.c[name]
	if not c then c = T.c.text end
	return c[1], c[2], c[3]
end

-- ---------------------------------------------------------------- temps des debuffs
local function timeText(t)
	if t >= 60 then return strformat("%dm", floor(t / 60 + 0.5)) end
	return strformat("%d", floor(t))
end
M.TimeText = timeText

-- ---------------------------------------------------------------- reservoir de debuffs personnels
function M.DropDebuff(i)
	local n = M.nd
	if i < 1 or i > n then return end
	M.dGuid[i], M.dSpell[i], M.dEnd[i], M.dDur[i], M.dTex[i] = M.dGuid[n], M.dSpell[n], M.dEnd[n], M.dDur[n], M.dTex[n]
	M.dGuid[n], M.dSpell[n], M.dEnd[n], M.dDur[n], M.dTex[n] = nil, nil, nil, nil, nil
	M.nd = n - 1
end

function M.AddDebuff(guid, spell, dur, now)
	for i = 1, M.nd do
		if M.dGuid[i] == guid and M.dSpell[i] == spell then
			M.dEnd[i] = now + dur
			M.dDur[i] = dur
			return
		end
	end
	if M.nd >= POOL then M.DropDebuff(1) end
	local n = M.nd + 1
	M.nd = n
	M.dGuid[n], M.dSpell[n], M.dEnd[n], M.dDur[n], M.dTex[n] = guid, spell, now + dur, dur, M.IconOf(spell)
end

function M.IconOf(spell)
	local t = M.sicon[spell]
	if t ~= nil then return t or nil end
	local info = getglobal("SpellInfo")
	if info then
		local n, r, tex = info(spell)
		M.sname[spell] = n
		M.sicon[spell] = tex or false
		return tex
	end
	M.sicon[spell] = false
	return nil
end

function M.NameOf(spell)
	if M.sicon[spell] == nil then M.IconOf(spell) end
	return M.sname[spell]
end

local function argN(n) return getglobal("arg" .. n) end

function M.OnAura(ev, a1, a2, a3)
	-- AURA_CAST_ON_OTHER(sort, lanceur, cible, effet, aura, amplitude, valeur, duree ms, etat)
	if not M.playerGuid or a2 ~= M.playerGuid then return end
	local dur = tonumber(argN(8)) or 0
	if dur <= 0 or not a3 then return end
	M.AddDebuff(a3, a1, dur / 1000, GetTime())
end

function M.OnDebuffRemoved(ev, a1, a2, a3)
	-- DEBUFF_REMOVED_OTHER(guid, indice, sort, ...)
	for i = M.nd, 1, -1 do
		if M.dGuid[i] == a1 and M.dSpell[i] == a3 then M.DropDebuff(i) end
	end
end

function M.OnDied(ev, a1)
	for i = M.nd, 1, -1 do
		if M.dGuid[i] == a1 then M.DropDebuff(i) end
	end
	local s = M.byGuid[a1]
	if s then M.EndCast(s) end
end

-- ---------------------------------------------------------------- incantations des ennemis
function M.StartCast(guid, spell, now, dur, chan)
	local s = M.byGuid[guid]
	if not s or dur <= 0 then return end
	if s.casting and s.cSpell == spell and abs(now - s.cT0) < 0.3 then return end
	s.casting, s.cSpell, s.cT0, s.cT1, s.cChan = true, spell, now, now + dur, chan
	s.cIcon = M.IconOf(spell)
	s.cName = M.NameOf(spell)
	s.cDirty = true
end

function M.EndCast(s)
	if not s.casting then return end
	s.casting = false
	s.cDirty = true
end

-- Une provocation lancee par le joueur : la creature visee (ou toutes, pour un sort de zone) est marquee pendant la duree de l'effet.
function M.NoteTaunt(spellId, target)
	local th = SUI.Threat
	local si = getglobal("SpellInfo")
	if not th or not th.TAUNTS or not si or not spellId then return end
	local name = si(spellId)
	local dur = name and th.TAUNTS[name]
	if not dur then return end
	local now = GetTime()
	if th.TAUNT_AOE[name] then
		M.tAllUntil = now + dur
	elseif target then
		M.tGuid, M.tUntil = target, now + dur
	end
end

function M.OnGoSelf(ev, a1, a2, a3, a4)
	-- SPELL_GO_SELF(objet, sort, lanceur, cible, ...)
	if M.playerGuid and a3 == M.playerGuid then M.NoteTaunt(a2, a4) end
end

function M.OnCastEvent(ev, a1, a2, a3, a4)
	-- UNIT_CASTEVENT(lanceur, cible, type, sort, duree ms)
	if not a1 then return end
	if a3 == "CAST" and a1 == M.playerGuid then M.NoteTaunt(a4, a2) end
	if a3 == "START" then
		local ms = tonumber(argN(5)) or 0
		M.StartCast(a1, a4, GetTime(), ms / 1000, false)
	elseif a3 == "CHANNEL" then
		local ms = tonumber(argN(5)) or 0
		M.StartCast(a1, a4, GetTime(), ms / 1000, true)
	elseif a3 == "CAST" or a3 == "FAIL" then
		local s = M.byGuid[a1]
		if s and s.cSpell == a4 then M.EndCast(s) end
	end
end

function M.OnNampower(ev, a1, a2, a3)
	if ev == "SPELL_START_OTHER" then
		-- (objet, sort, lanceur, cible, drapeaux, temps d'incantation ms, ...)
		local ms = tonumber(argN(6)) or 0
		M.StartCast(a3, a2, GetTime(), ms / 1000, false)
	elseif ev == "SPELL_FAILED_OTHER" then
		local s = M.byGuid[a1]
		if s then M.EndCast(s) end
	end
end

-- ---------------------------------------------------------------- construction (hors combat)
local function newSlot(i)
	local s = { i = i }
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetWidth(110)
	f:SetHeight(10)
	T.Backdrop(f, T.c.bg, T.c.border)
	s.f = f
	s.bar = T.Bar(f)
	s.nameFs = T.Text(f, 9, T.c.text, "CENTER", true)
	s.qTex = f:CreateTexture(nil, "OVERLAY")
	s.qTex:SetWidth(12)
	s.qTex:SetHeight(12)
	s.qTex:Hide()
	s.hpFs = T.Text(s.bar, 8, T.c.text, "CENTER", true)
	s.distFs = T.Text(f, 8, T.c.dim, "RIGHT", true)
	s.thrFs = T.Text(f, 9, T.c.text, "LEFT", true)
	s.cb =CreateFrame("Frame", nil, f)
	s.cb:SetWidth(110)
	s.cb:SetHeight(8)
	T.Backdrop(s.cb, T.c.bg, T.c.border)
	s.cbar = T.Bar(s.cb)
	s.cIconTex = s.cb:CreateTexture(nil, "ARTWORK")
	s.cIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	s.cNameFs = T.Text(s.cbar, 8, T.c.text, "LEFT", true)
	s.cb:Hide()
	if SUI.Look then      -- police et taille des textes : nameplates.font / nameplates.fontsize
		SUI.Look.ApplyText(s.nameFs, "nameplates", 9, true)
		SUI.Look.ApplyText(s.hpFs, "nameplates", 8, true)
		SUI.Look.ApplyText(s.distFs, "nameplates", 8, true)
		SUI.Look.ApplyText(s.thrFs, "nameplates", 9, true)
		SUI.Look.ApplyText(s.cNameFs, "nameplates", 8, true)
	end
	s.dTex, s.dFs, s.dKey = {}, {}, {}
	for k = 1, MAXDEB do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		t:Hide()
		s.dTex[k] = t
		s.dFs[k] = T.Text(f, 8, T.c.text, "CENTER", true)
		if SUI.Look then SUI.Look.ApplyText(s.dFs[k], "nameplates", 8, true) end
		s.dKey[k] = -1
	end
	f:Hide()
	return s
end

function M.Build()
	if M.built then return end
	for i = 1, MAXSLOT do
		M.slots[i] = newSlot(i)
		M.free[i] = M.slots[i]
	end
	M.nFree = MAXSLOT
	M.clearTok = { T.c.bg[1], T.c.bg[2], T.c.bg[3], 0 }     -- fond / bordure invisibles (plaques amies sans cadre)
	M.built = true
	M.ApplyOptions()
end

-- Geometrie d'un emplacement selon les reglages.
function M.Layout(s)
	local c = M.cfg
	local w, h = c.width, c.height
	s.f:SetWidth(w)
	s.f:SetHeight(h)
	-- barres ancrees par UN point + taille explicite (et non deux coins) : la forme "fine" peut alors changer leur hauteur, centree
	s.bar:ClearAllPoints()
	s.bar:SetPoint("LEFT", s.f, "LEFT", 1, 0)
	s.bar:SetWidth(w - 2)
	s.bar:SetHeight(h - 2)
	if SUI.Look then SUI.Look.ApplyBar(s.bar, "nameplates", { height = h - 2, segments = 10 }) end
	s.nameFs:ClearAllPoints()
	s.nameFs:SetPoint("BOTTOM", s.f, "TOP", 0, 2)
	s.hpFs:ClearAllPoints()
	s.hpFs:SetPoint("CENTER", s.bar, "CENTER", 0, 0)
	s.distFs:ClearAllPoints()
	s.distFs:SetPoint("BOTTOMRIGHT", s.f, "TOPRIGHT", 0, 2)
	-- pourcentage de menace : a droite (ou a gauche) de la barre, la ou rien d'autre n'est dessine
	s.thrFs:ClearAllPoints()
	if c.threatpos == "left" then
		s.thrFs:SetPoint("RIGHT", s.f, "LEFT", -3, 0)
		s.thrFs:SetJustifyH("RIGHT")
	else
		s.thrFs:SetPoint("LEFT", s.f, "RIGHT", 3, 0)
		s.thrFs:SetJustifyH("LEFT")
	end
	s.thrFs:SetText(EMPTY)
	s.thrKey = nil
	local ch = c.castheight
	s.cb:SetWidth(w)
	s.cb:SetHeight(ch)
	s.cb:ClearAllPoints()
	s.cb:SetPoint("TOP", s.f, "BOTTOM", 0, -2)
	s.cIconTex:ClearAllPoints()
	s.cIconTex:SetPoint("RIGHT", s.cb, "LEFT", -2, 0)
	s.cIconTex:SetWidth(ch + 2)
	s.cIconTex:SetHeight(ch + 2)
	s.cbar:ClearAllPoints()
	s.cbar:SetPoint("LEFT", s.cb, "LEFT", 1, 0)
	s.cbar:SetWidth(w - 2)
	s.cbar:SetHeight(ch - 2)
	if SUI.Look then SUI.Look.ApplyBar(s.cbar, "nameplates", { height = ch - 2, segments = 10 }) end
	s.cNameFs:ClearAllPoints()
	s.cNameFs:SetPoint("LEFT", s.cbar, "LEFT", 2, 0)
	local sz = c.debuffsize
	local y = -(ch + 4)
	for k = 1, MAXDEB do
		local t = s.dTex[k]
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", s.f, "BOTTOMLEFT", (k - 1) * (sz + 1), y)
		t:SetWidth(sz)
		t:SetHeight(sz)
		s.dFs[k]:ClearAllPoints()
		s.dFs[k]:SetPoint("CENTER", t, "CENTER", 0, 0)
	end
	if not c.hptext then s.hpFs:SetText(EMPTY) s.lastPct = nil end
	if not c.name then s.nameFs:SetText(EMPTY) s.lastName = nil end
	s.lastR = nil
	s.lastScale = nil
	s.lastDist = nil
	s.lastV = nil          -- le texte de vie est reecrit au prochain passage (reglage "hptext" rallume)
	s.lastLvl = nil
	s.lastName = nil
	s.distFs:SetText(EMPTY)
	s.cDirty = true
end

function M.ApplyOptions()
	if not M.built then return end
	for i = 1, MAXSLOT do M.Layout(M.slots[i]) end
	for i = 1, MAXSLOT do
		local s = M.slots[i]
		if s.plate then M.SetMark(s) end
	end
	-- limite abaissee en direct : les plaques en trop sont rendues au jeu tout de suite
	if M.nUsed > M.cfg.maxplates then
		for i = MAXSLOT, 1, -1 do
			local s = M.slots[i]
			if M.nUsed <= M.cfg.maxplates then break end
			if s.plate then
				local pl = s.plate
				M.Release(s)
				M.Unskin(pl)
			end
		end
	end
	if M.active then
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(M.cfg.rate, M.Tick, "nameplates.tick", true)
	end
end

-- ---------------------------------------------------------------- plaques du jeu
local function hasBorder(r)
	if not r or not r.GetTexture then return false end
	local tex = r:GetTexture()
	return (type(tex) == "string" and string.find(tex, BORDER_KEY, 1, true) ~= nil)
end

-- Reconnue : bouton sans nom dont l'une des deux premieres regions porte la texture de bordure (ordre exact NON VERIFIE).
local function isPlate(f)
	if not f or not f.GetObjectType or f:GetObjectType() ~= "Button" then return false end
	if f:GetName() then return false end
	local r1, r2 = f:GetRegions()
	return hasBorder(r1) or hasBorder(r2)
end
M.IsPlate = isPlate

function M.Scan(n)
	M.nWorld = n
	local list = { WorldFrame:GetChildren() }
	for i = 1, getn(list) do
		local ch = list[i]
		if M.known[ch] == nil then
			local ok = isPlate(ch)
			M.known[ch] = ok
			if ok then
				M.nPlates = M.nPlates + 1
				M.plateList[M.nPlates] = ch
			end
		end
	end
end

-- Etat d'origine d'une texture / d'une barre (pour tout rendre a la coupure du module : Unskin).
local function saveTex(r)
	if not r or type(r.GetTexture) ~= "function" then return nil end
	local o = { tex = r:GetTexture() }
	if type(r.GetTexCoord) == "function" then o.a, o.b, o.c, o.d, o.e, o.f, o.g, o.h = r:GetTexCoord() end
	return o
end

local function loadTex(r, o)
	if not r or not o then return end
	if o.tex then r:SetTexture(o.tex) end
	if o.h then r:SetTexCoord(o.a, o.b, o.c, o.d, o.e, o.f, o.g, o.h)
	elseif o.d then r:SetTexCoord(o.a, o.b, o.c, o.d) end
end

local function barTex(b)
	if not b or type(b.GetStatusBarTexture) ~= "function" then return nil end
	local t = b:GetStatusBarTexture()
	if type(t) == "table" and type(t.GetTexture) == "function" then return t:GetTexture() end
	return nil
end

-- Neutralise les objets d'origine d'une plaque (une seule fois par plaque). L'etat d'origine est garde : Unskin le rend.
-- Le jeu peut rendre a une plaque recyclee ses textures d'origine : on la neutralise de nouveau si la bordure est revenue.
function M.CheckSkin(plate)
	local o = plate.suiOrig
	if plate.suiSkin and o and hasBorder(o.borderR) then
		plate.suiSkin = nil
		M.Skin(plate)
	end
end

function M.Skin(plate)
	if plate.suiSkin then return end
	plate.suiSkin = true
	local hb, cb = plate:GetChildren()
	local border, glow, name, level, licon, ricon = plate:GetRegions()
	plate.suiHb, plate.suiCb, plate.suiName, plate.suiLevel, plate.suiRicon = hb, cb, name, level, ricon
	local o = { hbTex = barTex(hb), cbTex = barTex(cb), border = saveTex(border), glow = saveTex(glow), licon = saveTex(licon),
		borderR = border, glowR = glow, liconR = licon }
	if name and type(name.GetWidth) == "function" then o.nameW = name:GetWidth() end
	if level and type(level.GetWidth) == "function" then o.levelW = level:GetWidth() end
	if ricon and type(ricon.GetPoint) == "function" then
		o.rp, o.rrel, o.rrp, o.rx, o.ry = ricon:GetPoint(1)
		o.rw, o.rh = ricon:GetWidth(), ricon:GetHeight()
	end
	plate.suiOrig = o
	if hb then hb:SetStatusBarTexture(EMPTY) end
	if cb then cb:SetStatusBarTexture(EMPTY) end
	if border then border:SetTexture(EMPTY) border:SetTexCoord(0, 0, 0, 0) end
	if glow then glow:SetTexture(EMPTY) glow:SetTexCoord(0, 0, 0, 0) end
	if licon then licon:SetTexture(EMPTY) licon:SetTexCoord(0, 0, 0, 0) end
	if name then name:SetWidth(0.001) end
	if level then level:SetWidth(0.001) end
end

-- Rend a une plaque ses objets d'origine (coupure du module, plaque hors limite) ; elle sera re-neutralisee a la prochaine prise en charge.
function M.Unskin(plate)
	if not plate.suiSkin then return end
	local o = plate.suiOrig
	plate.suiSkin = nil
	plate.suiOrig = nil
	if not o then return end
	if plate.suiHb and o.hbTex then plate.suiHb:SetStatusBarTexture(o.hbTex) end
	if plate.suiCb and o.cbTex then plate.suiCb:SetStatusBarTexture(o.cbTex) end
	loadTex(o.borderR, o.border)
	loadTex(o.glowR, o.glow)
	loadTex(o.liconR, o.licon)
	if plate.suiName and o.nameW then plate.suiName:SetWidth(o.nameW) end
	if plate.suiLevel and o.levelW then plate.suiLevel:SetWidth(o.levelW) end
	local ri = plate.suiRicon
	if ri and o.rp then
		ri:ClearAllPoints()
		ri:SetPoint(o.rp, o.rrel, o.rrp, o.rx, o.ry)
		if o.rw then ri:SetWidth(o.rw) end
		if o.rh then ri:SetHeight(o.rh) end
	end
end

-- Le marqueur d'origine est reancre sur notre cadre (ses coordonnees de texture restent celles du jeu).
function M.SetMark(s)
	local ri = s.plate.suiRicon
	if not ri then return end
	ri:ClearAllPoints()
	local sz = M.cfg.markers and M.cfg.markersize or 0.001
	ri:SetWidth(sz)
	ri:SetHeight(sz)
	ri:SetPoint("BOTTOM", s.f, "TOP", 0, M.cfg.name and 14 or 2)
end

function M.Assign(plate)
	-- limite : hors combat (ville pleine d'allies, plaques "nom seul" legeres) on prend toutes les plaques disponibles ;
	-- en combat (gros pull) on s'en tient a maxplates
	local lim = M.cfg.maxplates
	if not (UnitAffectingCombat and UnitAffectingCombat("player")) then lim = MAXSLOT end
	if M.nFree == 0 or M.nUsed >= lim then
		M.Skin(plate)    -- plaque en trop : on masque quand meme la plaque du jeu (sinon elle double la notre, enorme)
		return nil
	end
	M.Skin(plate)
	local s = M.free[M.nFree]
	M.free[M.nFree] = nil
	M.nFree = M.nFree - 1
	M.nUsed = M.nUsed + 1
	s.plate = plate
	M.slotOf[plate] = s
	s.guid = nil
	s.f:SetParent(plate)
	s.f:ClearAllPoints()
	s.f:SetPoint("CENTER", plate, "CENTER", 0, 0)
	s.f:Show()
	M.SetMark(s)
	M.Rebind(s, plate:GetName(1))
	return s
end

-- Un meme objet de plaque sert a des unites differentes : on repart de zero quand le GUID change.
-- Derniers chiffres hexa du GUID (4, 6, 8) : le serveur de menace n'envoie que la partie basse de l'id de la creature.
local function tailId(h, len, n)
	if len < n then return nil end
	return tonumber(string.sub(h, len - n + 1), 16)
end

function M.Rebind(s, guid)
	if s.guid and M.byGuid[s.guid] == s then M.byGuid[s.guid] = nil end
	s.guid = guid
	s.id16, s.id24, s.id32 = nil, nil, nil
	if guid then
		M.byGuid[guid] = s
		s.ttoken = guid .. "target"
		if type(guid) == "string" then
			local h = string.sub(guid, 3)
			local len = string.len(h)
			s.id16, s.id24, s.id32 = tailId(h, len, 4), tailId(h, len, 6), tailId(h, len, 8)
		end
	else
		s.ttoken = nil
	end
	s.thrState = 0
	s.thrKey = nil
	s.thrFs:SetText(EMPTY)
	s.casting = false
	s.cDirty = true
	s.lastName, s.lastPct, s.lastR, s.lastDist, s.lastScale = nil, nil, nil, nil, nil
	for k = 1, MAXDEB do s.dKey[k] = -1 s.dTex[k]:Hide() s.dFs[k]:SetText(EMPTY) end
	s.dShown = 0
	s.cb:Hide()
end

function M.Release(s)
	if s.guid and M.byGuid[s.guid] == s then M.byGuid[s.guid] = nil end
	if s.plate then M.slotOf[s.plate] = nil end
	s.plate, s.guid, s.ttoken, s.casting = nil, nil, nil, false
	s.f:Hide()
	s.f:SetParent(UIParent)
	s.f:ClearAllPoints()
	M.nFree = M.nFree + 1
	M.free[M.nFree] = s
	M.nUsed = M.nUsed - 1
end

-- ---------------------------------------------------------------- mise a jour d'un emplacement
-- ---------------------------------------------------------------- menace du serveur (paquets d'addon)
-- Deux sources, comme TWThreat : la reponse "simple" (la menace de chaque joueur sur MA CIBLE) et la liste du mode tank
-- (pour chaque creature que je tanke : le joueur suivant dans sa liste et son % de MA menace ; 110 melee / 130 distance = il la prend).
function M.ClearThreat()
	M.pl.n, M.pl.guid, M.pl.at = 0, nil, -100
	M.tm.n, M.tm.at = 0, -100
end

function M.ThrParse(s, at, now)
	local pl, tm = M.pl, M.tm
	local stop = string.len(s)
	local tmFrom = nil
	local hash = strfind(s, "#", at, true)
	if hash then
		local tp = strfind(s, THR_TM, hash, true)
		if tp then
			stop = hash - 1
			tmFrom = tp + string.len(THR_TM)
		end
	end
	M.nPkt = M.nPkt + 1
	M.pktAt = now
	-- reponse simple : joueur:tank:menace:pct:melee;...  (valable pour ma cible, sauf juste apres un changement de cible)
	if M.targetGuid and now - M.targetAt > THR_SETTLE then
		local p, n = at + string.len(THR_API), 0
		while p <= stop and n < THR_MAXP do
			local _, e, who, tk, th, pc = strfind(s, "^([^:;#]+):([^:;#]*):([^:;#]*):([^:;#]*)", p)
			if e then
				n = n + 1
				pl.who[n] = who
				pl.tank[n] = (tk == "1")
				pl.perc[n] = tonumber(pc) or 0
				p = e + 1
			end
			local sc = strfind(s, ";", p, true)
			if not sc then break end
			p = sc + 1
		end
		pl.n, pl.guid, pl.at = n, M.targetGuid, now
	end
	-- mode tank : creature:id:joueur:pct;...
	if tmFrom then
		local p, n = tmFrom, 0
		local len = string.len(s)
		while p <= len and n < THR_MAXP do
			local _, e, creature, id, who, pc = strfind(s, "^([^:;#]*):([^:;#]*):([^:;#]*):([^:;#]*)", p)
			if e then
				n = n + 1
				tm.creature[n] = creature
				tm.id[n] = tonumber(id)
				tm.who[n] = who
				tm.perc[n] = tonumber(pc) or 0
				p = e + 1
			end
			local sc = strfind(s, ";", p, true)
			if not sc then break end
			p = sc + 1
		end
		tm.n, tm.at = n, now
	end
end

function M.OnAddon(ev, a1, a2)
	if type(a2) ~= "string" then return end
	local at = strfind(a2, THR_API, 1, true)
	if not at then return end
	M.ThrParse(a2, at, GetTime())
end

-- Chiffre de menace de la plaque : pct, joueur, vrai si c'est moi qui tiens la creature. nil = aucune donnee fraiche.
function M.ThreatFor(s, now)
	if not s.guid then return nil end
	local tm = M.tm
	if tm.n > 0 and now - tm.at <= THR_FRESH then
		local nm = UnitName(s.guid)
		for i = 1, tm.n do
			local id = tm.id[i]
			if id and (id == s.id16 or id == s.id24 or id == s.id32) and (not nm or tm.creature[i] == nm) then
				return tm.perc[i], tm.who[i], true
			end
		end
	end
	local pl = M.pl
	if pl.n > 0 and pl.guid == s.guid and now - pl.at <= THR_FRESH then
		local me = M.player
		local mine = nil
		for i = 1, pl.n do
			if pl.who[i] == me then mine = i end
		end
		if mine then
			if pl.tank[mine] then
				-- je la tiens : le challenger le plus proche et son % de ma menace
				local best = nil
				for i = 1, pl.n do
					if i ~= mine and (not best or pl.perc[i] > pl.perc[best]) then best = i end
				end
				if best then return pl.perc[best], pl.who[best], true end
				return 0, nil, true
			end
			return pl.perc[mine], nil, false
		end
	end
	return nil
end

function M.ScanMT()
	M.mtDirty = false
	for k in pairs(M.mt) do M.mt[k] = nil end
	local n = GetNumRaidMembers()
	if n <= 0 or type(GetRaidRosterInfo) ~= "function" then return end
	for i = 1, n do
		local name, _, _, _, _, _, _, _, _, role = GetRaidRosterInfo(i)
		if name and (role == "maintank" or role == "MAINTANK") then M.mt[name] = true end
	end
end

function M.OnRoster() M.mtDirty = true end

-- Demande au serveur (groupe seulement), seulement si personne d'autre n'a obtenu de reponse depuis un instant.
function M.ThreatRequest(now)
	local cfg = M.cfg
	if not cfg.threatrequest or now - M.reqAt < 1 or now - M.pktAt < 0.9 then return end
	if type(SendAddonMessage) ~= "function" then return end
	if not UnitAffectingCombat("player") or not UnitExists("target") or not UnitCanAttack("player", "target") then return end
	local chan = nil
	if GetNumRaidMembers() > 0 then chan = "RAID" elseif GetNumPartyMembers() > 0 then chan = "PARTY" end
	if not chan then return end
	M.reqAt = now
	M.nReq = M.nReq + 1
	SendAddonMessage(M.mode == "tank" and THR_REQ_TM or THR_REQ, "limit=5", chan)
end

-- Les donnees ne sont ecoutees que si une option les utilise (pourcentage affiche ou couleur d'alerte) : coupe = aucun cout.
function M.WantData()
	local c = M.cfg
	return (M.active and (c.threatpct or (c.threat and c.threatwarn > 0))) and true or false
end

function M.SyncThreat()
	if M.WantData() then
		if not M.thrOn then
			M.thrOn = true
			SUI.On("CHAT_MSG_ADDON", M.OnAddon)
			SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
			M.mtDirty = true
		end
	elseif M.thrOn then
		M.thrOn = false
		SUI.Off("CHAT_MSG_ADDON", M.OnAddon)
		SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
		M.ClearThreat()
	end
end

-- Etat de couleur : 0 jeu, 1 je tiens (vert), 2 un autre joueur (rouge) / moi en role dps, 3 alerte (jaune), 4 main tank, 5 familier.
function M.HolderState(s)
	if M.cfg.threattank then
		local nm = UnitName(s.ttoken)
		if nm and M.mt[nm] then return 4 end
	end
	if type(UnitPlayerControlled) == "function" and UnitPlayerControlled(s.ttoken) and not UnitIsPlayer(s.ttoken) then return 5 end
	return 2
end

-- Mon dernier sort de provocation tient-il sur cet emplacement ? (sort cible : son GUID ; sort de zone : toutes les creatures)
function M.Taunted(s, now)
	if not M.cfg.threattaunt then return false end
	if now < M.tAllUntil then return true end
	return s.guid ~= nil and s.guid == M.tGuid and now < M.tUntil
end

function M.ColorState(s, onMe, pct, holds, now)
	local cfg = M.cfg
	local warn = cfg.threatwarn
	if M.mode == "tank" then
		if onMe then
			if M.Taunted(s, now) then return 6 end
			if pct and holds and warn > 0 and pct >= warn then return 3 end
			return 1
		end
		return M.HolderState(s)
	end
	-- dps / soigneur : l'inverse (l'ennemi me vise = danger ; un autre l'a = surete)
	if onMe then return 2 end
	if pct and not holds and warn > 0 and pct >= warn then return 3 end
	if cfg.dpssafe then return 1 end
	return 0
end

function M.PaintThreat(s, pct, who, holds)
	local fs = s.thrFs
	if not M.cfg.threatpct or not pct then
		if s.thrKey then
			s.thrKey = nil
			fs:SetText(EMPTY)
		end
		return
	end
	local ip = floor(pct + 0.5)
	if ip ~= s.thrPct or who ~= s.thrWho or holds ~= s.thrHold or not s.thrKey then
		s.thrPct, s.thrWho, s.thrHold, s.thrKey = ip, who, holds, true
		local warn = M.cfg.threatwarn
		if warn <= 0 then warn = 80 end
		local st = 1
		if ip >= 100 then st = 2 elseif ip >= warn then st = 3 end
		local r, g, b = M.StateColor(st)
		fs:SetTextColor(r, g, b, 1)
		if who then fs:SetText(strformat("%s %d%%", string.sub(who, 1, 6), ip)) else fs:SetText(strformat("%d%%", ip)) end
	end
end

-- Mise a jour de la menace d'un emplacement : etat de couleur (s.thrState) et pourcentage ecrit.
function M.UpdateThreat(s, now, friendly)
	local cfg = M.cfg
	local st, pct, who, holds = 0, nil, nil, nil
	if s.guid and not friendly and (cfg.threat or cfg.threatpct) and (not UnitAffectingCombat or UnitAffectingCombat(s.guid)) then
		if UnitExists(s.ttoken) then
			M.tokOK = true
			if M.thrOn then pct, who, holds = M.ThreatFor(s, now) end
			if cfg.threat then
				local onMe = UnitIsUnit(s.ttoken, "player") and true or false
				st = M.ColorState(s, onMe, pct, holds, now)
			end
		elseif M.tokOK and cfg.threat and cfg.threatnone and not UnitIsPlayer(s.guid) then
			st = 7       -- en combat, personne pour cible (fuite, retour a la case depart...) ; jamais avant d'avoir vu un jeton repondre
		end
	end
	s.thrState = st
	M.PaintThreat(s, pct, who, holds)
end

function M.UpdateBar(s, plate, friendly)
	local cfg = M.cfg
	local hb = plate.suiHb
	if not hb then return end
	local v = hb:GetValue()
	local lo, hi = hb:GetMinMaxValues()
	if friendly and not cfg.friendly then
		s.bar:Hide()
		s.hpFs:SetText(EMPTY)
		return
	end
	s.bar:Show()
	if v ~= s.lastV or hi ~= s.lastHi then
		s.lastV, s.lastHi = v, hi
		s.bar:SetMinMaxValues(lo, hi)
		s.bar:SetValue(v)
		if cfg.hptext and not s.compact and hi > lo then
			local pct = floor((v - lo) / (hi - lo) * 100 + 0.5)
			if pct ~= s.lastPct then
				s.lastPct = pct
				s.hpFs:SetText(strformat("%d%%", pct))
			end
		end
	end
	local r, g, b = hb:GetStatusBarColor()
	if cfg.classcolor and s.guid and UnitIsPlayer(s.guid) then
		local _, cls = UnitClass(s.guid)
		local tbl = getglobal("RAID_CLASS_COLORS")
		local cc = tbl and cls and tbl[cls]
		if cc then r, g, b = cc.r, cc.g, cc.b end    -- style:ok couleur de classe (donnee de jeu)
	end
	local th = s.thrState
	if th and th > 0 then r, g, b = M.StateColor(th) end
	if r ~= s.lastR or g ~= s.lastG or b ~= s.lastB then
		s.lastR, s.lastG, s.lastB = r, g, b
		s.bar:SetStatusBarColor(r, g, b, 1)
	end
end

function M.UpdateName(s, plate)
	local cfg = M.cfg
	if not cfg.name then return end
	local nm = plate.suiName and plate.suiName:GetText() or EMPTY
	local lv = (cfg.level and plate.suiLevel) and plate.suiLevel:GetText() or nil
	local Q = SUI.QuestTrack
	local qk = (Q and Q.MarkWanted and Q.MarkWanted()) and (nm .. "|" .. Q.ver) or false
	if qk ~= s.lastQ then
		s.lastQ = qk
		if qk and Q.UnitObjective(nm) then
			s.qTex:SetTexture(Q.MARK_TEX)
			s.qTex:ClearAllPoints()
			s.qTex:SetPoint("RIGHT", s.nameFs, "LEFT", -1, 0)
			s.qTex:Show()
		else
			s.qTex:Hide()
		end
	end
	if nm ~= s.lastName or lv ~= s.lastLvl then
		s.lastName, s.lastLvl = nm, lv
		if lv and lv ~= EMPTY then s.nameFs:SetText(lv .. " " .. (nm or EMPTY)) else s.nameFs:SetText(nm or EMPTY) end
	end
end

function M.UpdateTarget(s, plate)
	local cfg = M.cfg
	local isT
	if s.guid and M.targetGuid then isT = (s.guid == M.targetGuid)
	else isT = (plate:GetAlpha() >= 0.99 and UnitExists("target") ~= nil) end
	local scale = (isT and cfg.targetglow) and cfg.targetscale or 1
	if s.compact and not isT then scale = COMPACT_SCALE end
	if scale ~= s.lastScale then
		s.lastScale = scale
		s.f:SetScale(scale)
	end
	M.PaintBorder(s, isT)
	return isT
end

-- Contour : en mode "auto" il suit la couleur de la barre (sombre pour les plaques ordinaires, clair pour la cible), de sorte que
-- la cible ressorte parmi plusieurs plaques et que le contour ne jure jamais avec l'interieur. Mode "style" : bordure du style.
function M.PaintBorder(s, isT)
	if s.boxHidden then return end      -- plaque amie sans cadre : la bordure reste invisible
	local cfg = M.cfg
	local auto = (cfg.outline ~= "style")
	local r, g, b = s.lastR, s.lastG, s.lastB
	if not auto or not r then r, g, b = 0, 0, 0 end
	if isT == s.bT and r == s.bR and g == s.bG and b == s.bB and auto == s.bAuto then return end
	s.bT, s.bR, s.bG, s.bB, s.bAuto = isT, r, g, b, auto
	if auto and s.lastR then
		if isT then
			s.f:SetBackdropBorderColor(0.8 + r * 0.2, 0.8 + g * 0.2, 0.8 + b * 0.2, 1)  -- style:ok contour derive de la barre
		else
			s.f:SetBackdropBorderColor(r * 0.3, g * 0.3, b * 0.3, 1)  -- style:ok contour derive de la barre
		end
	elseif isT and cfg.targetglow then
		local ar, ag, ab = T.Accent()
		s.f:SetBackdropBorderColor(ar, ag, ab, 1)
	else
		local c = T.c.border
		s.f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

function M.UpdateDebuffs(s, isT, now)
	local cfg = M.cfg
	local n = 0
	if cfg.debuffs and s.guid then
		local maxd = cfg.debuffmax
		for i = 1, M.nd do
			if M.dGuid[i] == s.guid and n < maxd then
				n = n + 1
				local left = M.dEnd[i] - now
				local tex = M.dTex[i]
				local t = s.dTex[n]
				if t.suiTex ~= tex then t.suiTex = tex t:SetTexture(tex) t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
				t:Show()
				local fkey = -1
				if cfg.debufftimer and left > 0 then fkey = floor(left) end
				if fkey ~= s.dKey[n] then
					s.dKey[n] = fkey
					if fkey < 0 then s.dFs[n]:SetText(EMPTY) else s.dFs[n]:SetText(timeText(left)) end
				end
			end
		end
		if n == 0 and isT then
			-- repli sans Nampower : debuffs de la cible, sans duree
			for k = 1, maxd do
				local tex = UnitDebuff("target", k)
				if not tex then break end
				n = n + 1
				local t = s.dTex[n]
				if t.suiTex ~= tex then t.suiTex = tex t:SetTexture(tex) t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
				t:Show()
				if s.dKey[n] ~= -2 then s.dKey[n] = -2 s.dFs[n]:SetText(EMPTY) end
			end
		end
	end
	for k = n + 1, s.dShown or 0 do
		s.dTex[k]:Hide()
		s.dTex[k].suiTex = nil
		s.dFs[k]:SetText(EMPTY)
		s.dKey[k] = -1
	end
	s.dShown = n
end

function M.UpdateCast(s, plate, now)
	local cfg = M.cfg
	local cb = s.cb
	if not cfg.castbar then
		if s.cbShown then cb:Hide() s.cbShown = false end
		return
	end
	local ratio, name, icon
	if s.casting then
		if now >= s.cT1 + 0.2 then
			M.EndCast(s)
		else
			local span = s.cT1 - s.cT0
			ratio = (now - s.cT0) / span
			if ratio > 1 then ratio = 1 end
			if s.cChan then ratio = 1 - ratio end
			name, icon = s.cName, s.cIcon
		end
	end
	if ratio == nil then
		local ob = plate.suiCb
		if ob and ob:IsShown() then
			local lo, hi = ob:GetMinMaxValues()
			if hi > lo then ratio = (ob:GetValue() - lo) / (hi - lo) end
		end
	end
	if ratio == nil then
		if s.cbShown then cb:Hide() s.cbShown = false s.lastCName = nil end
		return
	end
	if not s.cbShown then cb:Show() s.cbShown = true end
	s.cbar:SetValue(ratio)
	if name ~= s.lastCName or s.cDirty then
		s.lastCName = name
		s.cDirty = false
		if cfg.castname and name then s.cNameFs:SetText(name) else s.cNameFs:SetText(EMPTY) end
		if cfg.casticon and icon then
			s.cIconTex:SetTexture(icon)
			s.cIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			s.cIconTex:Show()
		else
			s.cIconTex:Hide()
		end
	end
end

function M.UpdateDist(s, isT)
	local cfg = M.cfg
	local mode = cfg.distance
	local show = s.guid and (mode == "all" or (mode == "target" and isT))
	if not show then
		if s.lastDist then s.lastDist = nil s.distFs:SetText(EMPTY) end
		return
	end
	local d = SUI.Api.Distance(s.guid)
	local key = d and floor(d + 0.5) or -1
	if key ~= s.lastDist then
		s.lastDist = key
		if key < 0 then s.distFs:SetText(EMPTY) else s.distFs:SetText(strformat("%dm", key)) end
	end
end

-- Mode compact (gros pull) : seule la barre de vie reste ; textes, effets, incantation et distance sont masques (moins de frames dessinees, moins de travail).
function M.SetCompact(s, on)
	on = on and true or false
	if s.compact == on then return end
	s.compact = on
	s.lastScale = nil
	if on then
		s.nameFs:Hide() s.hpFs:Hide() s.distFs:Hide() s.thrFs:Hide()
		if s.cbShown then s.cb:Hide() s.cbShown = false end
		for k = 1, MAXDEB do s.dKey[k] = -1 s.dTex[k]:Hide() s.dFs[k]:SetText(EMPTY) end
	else
		s.nameFs:Show() s.hpFs:Show() s.distFs:Show() s.thrFs:Show()
		s.lastName, s.lastV, s.lastDist, s.thrKey = nil, nil, nil, nil
	end
end

function M.UpdateSlot(s, now)
	local plate = s.plate
	local g = plate:GetName(1)
	if g ~= s.guid then M.Rebind(s, g) end
	local friendly = false
	if s.guid then
		friendly = UnitIsFriend("player", s.guid) and true or false
	else
		local hb = plate.suiHb
		if hb then
			local r, g2 = hb:GetStatusBarColor()
			friendly = (r < 0.5 and g2 > 0.5)
		end
	end
	-- plaque amie sans l'option "friendly" : le nom seul, sans cadre ni fond vide
	local hideBox = friendly and not M.cfg.friendly
	if hideBox ~= s.boxHidden then
		s.boxHidden = hideBox
		s.lastScale = nil
		if hideBox then
			T.Backdrop(s.f, M.clearTok, M.clearTok)
		else
			T.Backdrop(s.f, T.c.bg, T.c.border)
		end
	end
	local imp = (s.guid and s.guid == M.targetGuid) or s.cbShown or (s.thrState == 2 or s.thrState == 3 or s.thrState == 6)
	-- le mode compact masque le nom : inutile (et nuisible) pour une plaque amie qui n affiche QUE le nom
	M.SetCompact(s, M.heavy and not imp and not hideBox)
	M.UpdateThreat(s, now, friendly)
	M.UpdateBar(s, plate, friendly)
	if not s.compact then M.UpdateName(s, plate) end
	local isT = M.UpdateTarget(s, plate)
	if s.compact then return end
	if friendly and not M.cfg.friendly then
		M.UpdateDebuffs(s, false, now)
		if s.cbShown then s.cb:Hide() s.cbShown = false end
		return
	end
	M.UpdateDebuffs(s, isT, now)
	M.UpdateCast(s, plate, now)
	M.UpdateDist(s, isT)
end

function M.Tick()
	if not M.built then return end
	local now = GetTime()
	local n = WorldFrame:GetNumChildren()
	if n ~= M.nWorld then M.Scan(n) end
	M.ResolveMode()
	if M.thrOn then
		if M.mtDirty then M.ScanMT() end
		M.ThreatRequest(now)
	end
	for i = M.nd, 1, -1 do
		if M.dEnd[i] < now then M.DropDebuff(i) end
	end
	M.phase = (M.phase or 0) + 1 if M.phase > 2 then M.phase = 0 end
	local heavy = M.nUsed > HEAVY
	M.heavy = heavy
	for i = 1, M.nPlates do
		local plate = M.plateList[i]
		local s = M.slotOf[plate]
		if plate:IsShown() then
			if mod3(i + M.phase) == 0 then M.CheckSkin(plate) end
			local fresh = false
			if not s then s = M.Assign(plate) fresh = true end
			if s then
				-- gros pull : au-dela de HEAVY plaques, chacune n'est rafraichie qu'un tick sur 3 (cible, incantation et plaque neuve : a chaque tick)
				if fresh or not heavy or s.cbShown or (s.guid and s.guid == M.targetGuid) or (s.thrState == 2 or s.thrState == 3 or s.thrState == 6) or mod3(i + M.phase) == 0 then
					M.UpdateSlot(s, now)
				end
			end
		elseif s then
			M.Release(s)
		end
	end
end

function M.OnTarget()
	local g = nil
	if UnitExists("target") then g = SUI.Target.GUID("target") end
	M.targetGuid = g
	M.targetAt = GetTime()
	M.pl.n, M.pl.guid = 0, nil
end

function M.OnRegen()
	M.ClearThreat()
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	M.ReadConfig()
	M.SyncThreat()
	M.ApplyOptions()
end

function M.Activate()
	if M.active then return end
	M.active = true
	M.playerGuid = SUI.Api.GUID("player")
	M.player = UnitName("player")
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnTarget)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	M.SyncThreat()
	if not M.warned then
		M.warned = true
		local isl = getglobal("IsAddOnLoaded")
		if isl then
			local others = { "TankSuite", "TankPlates" }
			for i = 1, getn(others) do
				if isl(others[i]) then SUI.Print(L("msg.nameplates.other", others[i])) end
			end
		end
	end
	if SUI.Api.superwow then SUI.On("UNIT_CASTEVENT", M.OnCastEvent) end
	if SUI.Api.nampower then
		SUI.On("AURA_CAST_ON_OTHER", M.OnAura)
		SUI.On("DEBUFF_REMOVED_OTHER", M.OnDebuffRemoved)
		SUI.On("UNIT_DIED", M.OnDied)
		SUI.On("SPELL_START_OTHER", M.OnNampower)
		SUI.On("SPELL_FAILED_OTHER", M.OnNampower)
		SUI.On("SPELL_GO_SELF", M.OnGoSelf)
	end
	M.nWorld = -1
	M.task = SUI.Every(M.cfg.rate, M.Tick, "nameplates.tick", true)
	M.OnTarget()
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnTarget)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	M.SyncThreat()
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Off("AURA_CAST_ON_OTHER", M.OnAura)
	SUI.Off("DEBUFF_REMOVED_OTHER", M.OnDebuffRemoved)
	SUI.Off("UNIT_DIED", M.OnDied)
	SUI.Off("SPELL_START_OTHER", M.OnNampower)
	SUI.Off("SPELL_FAILED_OTHER", M.OnNampower)
	SUI.Off("SPELL_GO_SELF", M.OnGoSelf)
	SUI.Cancel(M.task)
	M.task = nil
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	if not M.watching then
		M.watching = true
		C.Watch("nameplates.", M.OnKey)
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.Activate()
		M.ApplyOptions()
	end)
end

function M.Disable()
	M.on = false
	M.Deactivate()
	if M.built then
		for i = 1, MAXSLOT do
			local s = M.slots[i]
			if s.plate then M.Release(s) end
		end
		-- les plaques du jeu retrouvent leur apparence d'origine (sans /reload)
		for i = 1, M.nPlates do M.Unskin(M.plateList[i]) end
	end
	M.nd = 0
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("nameplates", 24)

local function opt(key, typ, order, def, extra)
	local o = { key = "nameplates." .. key, type = typ, cat = "nameplates", label = "opt.nameplates." .. key, tip = "tip.nameplates." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function tokText(o, v) return L("choice.nameplates.tok." .. v) end

local NP_OPTIONS = {
		opt("width", "number", 10, 90, { min = 50, max = 200, step = 5, simple = true }),
		opt("height", "number", 20, 10, { min = 4, max = 24, step = 1, simple = true }),
		opt("hptext", "bool", 30, true, { simple = true }),
		opt("name", "bool", 40, true),
		opt("level", "bool", 50, true),
		opt("classcolor", "bool", 60, false),
		opt("threat", "bool", 70, true, { simple = true }),
		opt("threatmode", "choice", 80, "auto", { choices = M.MODES, simple = true }),
		opt("dpssafe", "bool", 81, true),
		opt("threatnone", "bool", 83, true),
		opt("threattaunt", "bool", 85, true),
		opt("colsafe", "choice", 88.1, "good", { choices = M.TOKENS, choiceText = tokText }),
		opt("colwarn", "choice", 88.2, "warn", { choices = M.TOKENS, choiceText = tokText }),
		opt("coldanger", "choice", 88.3, "bad", { choices = M.TOKENS, choiceText = tokText }),
		opt("colmt", "choice", 88.4, "accent", { choices = M.TOKENS, choiceText = tokText }),
		opt("colpet", "choice", 88.5, "dim", { choices = M.TOKENS, choiceText = tokText }),
		opt("coltaunt", "choice", 88.6, "text", { choices = M.TOKENS, choiceText = tokText }),
		opt("colnone", "choice", 88.7, "border", { choices = M.TOKENS, choiceText = tokText }),
		opt("threatpct", "bool", 82, true, { simple = true }),
		opt("threatwarn", "number", 84, 80, { min = 0, max = 100, step = 5, simple = true }),
		opt("threattank", "bool", 86, true),
		opt("threatpos", "choice", 87, "right", { choices = { "right", "left" } }),
		opt("threatrequest", "bool", 88, true),
		opt("targetglow", "bool", 90, true),
		opt("outline", "choice", 91, "auto", { choices = { "auto", "style" }, choiceText = function(o2, v) return L("choice.nameplates.outline." .. v) end, simple = true }),
		opt("targetscale", "number", 100, 1.2, { min = 1, max = 1.6, step = 0.1 }),
		opt("debuffs", "bool", 110, true, { simple = true }),
		opt("debuffmax", "number", 120, 4, { min = 1, max = 6, step = 1 }),
		opt("debufftimer", "bool", 130, true),
		opt("debuffsize", "number", 140, 14, { min = 10, max = 24, step = 1 }),
		opt("castbar", "bool", 150, true, { simple = true }),
		opt("castheight", "number", 160, 8, { min = 4, max = 14, step = 1 }),
		opt("casticon", "bool", 170, true),
		opt("castname", "bool", 180, true),
		opt("markers", "bool", 190, true),
		opt("markersize", "number", 200, 20, { min = 12, max = 40, step = 2 }),
		opt("distance", "choice", 210, "target", { choices = { "off", "target", "all" } }),
		opt("friendly", "bool", 220, false),
		opt("maxplates", "number", 230, 40, { min = 10, max = 100, step = 5 }),
		opt("rate", "number", 240, 0.1, { min = 0.05, max = 0.5, step = 0.05 }),
}
-- Options communes du socle : texture, forme (barres de vie et d'incantation), police et taille des textes.
if SUI.Look then
	local lo = SUI.Look.Options("nameplates", { bar = true, shape = true, font = true, cat = "nameplates", order = 820 })
	for i = 1, table.getn(lo) do table.insert(NP_OPTIONS, lo[i]) end
end

SUI.RegisterModule("nameplates", {
	default = false,
	cost = "heavy",
	options = NP_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : le module "nameplates".
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.nameplates then SUI.Migrate.MAP.nameplates = { "nameplates" } end

-- Mode Raid : plaques plus etroites, moins d'icones, pas de distance, relecture plus lente.
SUI.Config.AddPreset("raid", "*", { ["nameplates.width"] = 90, ["nameplates.debuffmax"] = 3, ["nameplates.distance"] = "off",
	["nameplates.rate"] = 0.2, ["nameplates.maxplates"] = 25 })

SUI.RegisterCommand("nameplates", function(rest)
	if rest == "threat" then
		local now = GetTime()
		SUI.Print(L("msg.nameplates.thr", M.nPkt, M.nReq, M.tm.n, M.pl.n, M.thrOn and floor(now - M.pktAt) or -1))
		return
	end
	local src = SUI.Api.nampower and "Nampower" or "-"
	if SUI.Api.superwow then src = src .. " SuperWoW" end
	SUI.Print(L("msg.nameplates.info", M.nUsed, M.nPlates, M.nd, src))
end, "help.nameplates")
