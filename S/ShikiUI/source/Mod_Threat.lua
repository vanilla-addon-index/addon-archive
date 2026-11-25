-- ShikiUI Threat : fenetre de menace (v0.9, module "threat"), dans l'esprit de TWThreat (TWT) et Tankalyze. Code reecrit, rien de copie.
-- SOURCES CONSULTEES (signatures et protocole uniquement ; licences : TWThreat n'en declare aucune dans son dossier, Tankalyze absent) :
--   TWThreat.lua (AddOns\TWThreat) : le serveur Turtle WoW repond a une DEMANDE envoyee par SendAddonMessage :
--     SendAddonMessage("TWT_UDTSv4" [.. "_TM" en mode tank], "limit=N", "RAID" ou "PARTY")
--   et repond par un message d'addon (evenement CHAT_MSG_ADDON, texte = arg2) de la forme
--     "TWTv4=joueur:tank:menace:pourcentage:melee;joueur:...[#TMTv1=creature:guid:detenteur:pourcentage;...]"
--   (tank et melee valent "1" ou "0" ; pourcentage = part de la menace du tank ; seuil de prise d'aggro 110 % en melee, 130 % a distance).
-- NON VERIFIE EN JEU : tout le protocole ci-dessus (lu dans le code de TWThreat, jamais observe), le chemin du son (releve dans DebuffAlert,
--   Mod_Group), UIErrorsFrame:AddMessage. Sans serveur compatible aucune donnee n'arrive : la fenetre le dit au lieu d'inventer une estimation.
-- PROVOCATION (Taunt, Growl, Mocking Blow, Hand of Reckoning, Earthshaker Slam, cris de defi) : au lancement la fenetre n'attend pas le prochain
--   cycle : demande immediate au serveur puis quelques relances rapprochees, et une ligne PROVISOIRE du joueur placee en tete (menace mise au
--   niveau du plus haut, comme le fait l'effet de provocation) tant qu'aucun paquet ne confirme (M.TAUNT_PROV s). Le lancement est detecte par
--   SuperWoW UNIT_CASTEVENT (lanceur = joueur, type CAST) et Nampower SPELL_GO_SELF (sort -> nom par SpellInfo), ou sans eux par le DEBUT du
--   temps de recharge du sort (ACTIONBAR_UPDATE_COOLDOWN / SPELL_UPDATE_COOLDOWN, grimoire parcouru par GetSpellName). Un echec (journal de
--   combat, vu par Mod_TankTools) annule la ligne provisoire. La ligne du joueur porte "provoque Ns" pendant la duree de l'effet ; le detenteur
--   de l'aggro est marque ">" et le rang du joueur est dans le titre.
-- NON VERIFIE EN JEU (provocation) : noms des evenements SuperWoW / Nampower et ordre de leurs arguments, durees de l'effet (3 s / 6 s),
--   les evenements de temps de recharge du client 1.12, le fait que le serveur Turtle remette bien la menace au niveau du plus haut.
-- Cout : "light". Une seule minuterie partagee (la demande au serveur), enregistrements, historique de debit et lignes preparees a l'avance
--   (aucune table creee en combat), la fenetre n'est repeinte que si un paquet est arrive.
-- Lua 5.0 : pas de #, de %, de select ni de ... ; au plus 32 valeurs externes par fonction.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Threat = M

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, mmax, mmin = math.floor, math.max, math.min
local strfind, strsub, strlen, strformat = string.find, string.sub, string.len, string.format
local strbyte = string.byte
local EMPTY = ""

M.client = false      -- vrai : une fenetre ouverte du compteur affiche la vue menace (voir Mod_Meter M.SyncThreat)
M.PREFIX = "TWT_UDTSv4"
M.PREFIX_TM = "TWT_UDTSv4_TM"
M.API = "TWTv4="
M.TMAPI = "TMTv1="
M.MELEE, M.RANGED = 110, 130
M.MAXREC, M.MAXROWS, M.MAXMOB, M.PREROWS = 45, 30, 12, 15
M.HDR, M.FOOT = 20, 10
M.MINW, M.MAXW, M.MINH, M.MAXH = 120, 500, 60, 700
M.MAXEST = 24        -- cibles suivies par l estimation locale
M.ICONS = { stance = "Interface\\Icons\\Ability_Warrior_DefensiveStance", fury = "Interface\\Icons\\Spell_Holy_SealOfFury",
	salv = "Interface\\Icons\\Spell_Holy_SealOfSalvation" }   -- icones relevees dans OctoMeterModulesThreat.lua (non verifie en jeu)
M.SOUND = "Sound\\Interface\\RaidWarning.wav"
M.WAIT = 5            -- secondes : un paquet n'est accepte que juste apres notre demande
M.FASTRATE, M.FASTSPAN = 0.25, 5   -- debut de combat : demande toutes les 0.25 s pendant 5 s
M.LINGER = 5          -- secondes gardees apres la fin du combat
M.VIEWS = { "players", "mobs" }
M.TANKMODES = { "auto", "on", "off" }
M.REPORT = { "self", "auto", "say", "party", "raid", "guild" }
-- Provocations : nom du sort (anglais) -> duree de l'effet en secondes (non verifie en jeu). TAUNT_AOE : sorts de zone (toutes les cibles).
M.TAUNTS = { ["Taunt"] = 3, ["Growl"] = 3, ["Mocking Blow"] = 6, ["Hand of Reckoning"] = 3, ["Earthshaker Slam"] = 3,
	-- client frFR (OctoWow)
	["Provocation"] = 3, ["Grondement"] = 3, ["Coup moqueur"] = 6, ["Cri d'affrontement"] = 6, ["Rugissement d'affrontement"] = 6, ["Cri de defi"] = 6, ["Rugissement de defi"] = 6,
	["Challenging Shout"] = 6, ["Challenging Roar"] = 6 }
M.TAUNT_AOE = { ["Challenging Shout"] = true, ["Challenging Roar"] = true }
M.TAUNT_PROV = 1.5    -- secondes pendant lesquelles la ligne provisoire du joueur complete les paquets qui n'ont pas encore la provocation
M.TAUNT_STEP = 0.4    -- secondes entre deux demandes rapprochees apres une provocation
M.GCD = 1.5           -- un temps de recharge plus court est le delai global, pas celui du sort
M.MARK = ">"          -- devant le nom de celui qui a l'aggro

M.cfg = { show = true, rows = 10, rowh = 16, width = 220, height = 0, fontsize = 11, estimate = true, spacing = 1, alpha = 0.9, classcolor = true, rate = 1, warn = 85, warncd = 5,
	sound = true, flash = true, showagro = true, showtps = true, shortnum = true, hideooc = false, tankmode = "auto", view = "players",
	pullmsg = true, taunt = true, markholder = true, reportn = 5, reportchan = "self", limit = "limit=8" }

M.rec, M.list, M.n = {}, {}, 0
M.mob, M.mobs, M.mobn = {}, {}, 0
M.hp, M.hist = {}, {}
M.agro = { name = EMPTY, v = 0, pct = 110, cls = nil, agro = true, tank = false, melee = true, tps = 0 }
M.cls = {}
M.est, M.nest, M.mods = {}, 0, {}      -- estimation locale : cible -> { joueur -> menace }, modificateurs en cache
M.ver, M.paintedVer = 0, -1
M.selfPct, M.tankName = 0, nil
M.nrec, M.selfRank, M.holder, M.tauntLeft = 0, 0, nil, 0
M.taunt = { on = false, name = EMPTY, at = 0, untilT = 0, provT = 0, tname = nil, aoe = false, shown = -1 }
M.tname, M.tidx, M.tn, M.tstart = {}, {}, 0, {}   -- provocations du grimoire (nom, indice), derniers departs de temps de recharge vus
M.pguid = nil
M.win = nil

-- ---------------------------------------------------------------- reserves preparees a l'avance
function M.Prime()
	for i = getn(M.rec) + 1, M.MAXREC do
		M.rec[i] = { name = EMPTY, v = 0, pct = 0, cls = nil, tank = false, melee = false, tps = 0 }
		M.hp[i] = { v = 0, t = 0 }
	end
	for i = getn(M.mob) + 1, M.MAXMOB do M.mob[i] = { name = EMPTY, v = 0, pct = 0, cls = nil, holder = EMPTY, creature = EMPTY, guid = EMPTY } end
	if not M.proxy then M.proxy = { name = EMPTY, v = 0, pct = 0, cls = nil, tank = true, melee = true, tps = 0, prov = true } end
	if not M.hfree then
		M.hfree = {}
		for i = 1, M.MAXREC do M.hfree[i] = M.hp[i] end
	end
end

function M.ClearHist()
	for name, h in pairs(M.hist) do
		M.hist[name] = nil
		tinsert(M.hfree, h)
	end
end

function M.Reset()
	M.n, M.mobn, M.nrec = 0, 0, 0
	for i = getn(M.list), 1, -1 do M.list[i] = nil end
	for i = getn(M.mobs), 1, -1 do M.mobs[i] = nil end
	M.ClearHist()
	M.selfPct, M.tankName, M.reqAt, M.warnedFor = 0, nil, nil, nil
	M.selfRank, M.holder = 0, nil
	M.taunt.on, M.taunt.shown = false, -1
	M.agro.v = 0
	M.ClearEst()
	M.ver = M.ver + 1
end

-- ---------------------------------------------------------------- groupe : nom -> classe
local function addUnit(u)
	local name = UnitName(u)
	if name then
		local _, cls = UnitClass(u)
		M.cls[name] = cls
	end
end

function M.ReadGuid()
	M.pguid = SUI.Api and SUI.Api.GUID and SUI.Api.GUID("player") or nil
end

function M.ScanRoster()
	M.rosterDirty = false
	M.ReadGuid()
	for k in pairs(M.cls) do M.cls[k] = nil end
	addUnit("player")
	local nr = GetNumRaidMembers()
	if nr > 0 then
		for i = 1, nr do addUnit("raid" .. i) end
	else
		for i = 1, GetNumPartyMembers() do addUnit("party" .. i) end
	end
	M.ver = M.ver + 1
end

function M.OnRoster()
	M.rosterDirty = true
end

-- ---------------------------------------------------------------- analyse des paquets
local function before(a, b)
	if a.v ~= b.v then return a.v > b.v end
	return a.name < b.name
end

function M.ParseMobs(s, p)
	local n = 0
	local len = strlen(s)
	while p <= len and n < M.MAXMOB do
		local _, e, creature, guid, holder, pc = strfind(s, "^([^:;#]*):([^:;#]*):([^:;#]*):([^:;#]*)", p)
		if e then
			n = n + 1
			local m = M.mob[n]
			m.creature, m.guid, m.holder = creature, guid, holder
			m.pct = tonumber(pc) or 0
			m.v = m.pct
			m.name = creature .. " > " .. holder
			m.cls = M.cls[holder]
			M.mobs[n] = m
			p = e + 1
			if strsub(s, p, p) == ";" then p = p + 1 end
		else
			local sc = strfind(s, ";", p, true)
			if not sc then break end
			p = sc + 1
		end
	end
	for i = getn(M.mobs), n + 1, -1 do M.mobs[i] = nil end
	M.mobn = n
end

-- Retourne le nombre de joueurs lus (nil si le texte n'est pas un paquet de menace).
function M.Parse(s)
	if type(s) ~= "string" then return nil end
	local at = strfind(s, M.API, 1, true)
	if not at then return nil end
	local stop = strlen(s)
	local hash = strfind(s, "#", at, true)
	if hash then
		local tp = strfind(s, M.TMAPI, hash, true)
		if tp then
			stop = hash - 1
			M.ParseMobs(s, tp + strlen(M.TMAPI))
		end
	end
	local now = GetTime()
	local p = at + strlen(M.API)
	local n = 0
	while p <= stop and n < M.MAXREC do
		local _, e, name, tk, th, pc, ml = strfind(s, "^([^:;#]+):([^:;#]*):([^:;#]*):([^:;#]*):([^:;#]*)", p)
		if e then
			n = n + 1
			local r = M.rec[n]
			r.name = name
			r.tank = (tk == "1")
			r.v = tonumber(th) or 0
			r.pct = tonumber(pc) or 0
			r.melee = (ml == "1")
			r.cls = M.cls[name]
			M.Rate(r, now)
			p = e + 1
			if strsub(s, p, p) == ";" then p = p + 1 end
		else
			local sc = strfind(s, ";", p, true)
			if not sc then break end
			p = sc + 1
		end
	end
	if n == 0 and M.estimated and M.cfg.estimate then return 0 end   -- paquet vide : le serveur ne suit pas ce mob, on garde l estimation locale au lieu d afficher "rien"
	M.lastPkt = now
	M.estimated = false
	M.nrec = n
	M.Finish(now)
	return n
end

-- Debit de menace : difference avec un point de reference rafraichi toutes les 5 s.
function M.Rate(r, now)
	local h = M.hist[r.name]
	if not h then
		h = tremove(M.hfree)
		if not h then r.tps = 0 return end
		h.v, h.t = r.v, now
		M.hist[r.name] = h
		r.tps = 0
		return
	end
	local dt = now - h.t
	if dt >= 1 then r.tps = floor((r.v - h.v) / dt) else r.tps = 0 end
	if r.tps < 0 then r.tps = 0 end
	if dt >= 5 then h.v, h.t = r.v, now end
end

-- Ligne PROVISOIRE de la provocation : pendant M.TAUNT_PROV apres le lancement, si les donnees recues ne montrent pas encore le joueur en
-- tete, retourne un enregistrement (M.proxy) a la place de sa ligne : menace au niveau du plus haut, drapeau de detenteur. Les enregistrements
-- recus ne sont jamais modifies (un echec de la provocation restitue donc les vraies valeurs). nil = pas de ligne provisoire.
function M.Lift(me, list, now)
	if not M.proxy or not M.TauntFits(now) or now > M.taunt.provT then return nil end
	if me and me.tank then return nil end
	local top = list[1]
	if not top or top == me then return nil end
	local px = M.proxy
	px.name, px.cls, px.v, px.pct = M.player, M.cls[M.player], top.v, top.pct
	px.melee = (me == nil) or me.melee
	px.tps = me and me.tps or 0
	return px
end

function M.Finish(now)
	local n = M.nrec
	local list = M.list
	for i = 1, n do list[i] = M.rec[i] end
	for i = getn(list), n + 1, -1 do list[i] = nil end
	for i = 2, n do
		local x = list[i]
		local j = i - 1
		while j >= 1 and before(x, list[j]) do
			list[j + 1] = list[j]
			j = j - 1
		end
		list[j + 1] = x
	end
	local me, tank, rank = nil, nil, 0
	for i = 1, n do
		if list[i].name == M.player then me, rank = list[i], i end
		if list[i].tank then tank = list[i] end
	end
	local px = M.Lift(me, list, now)
	if px then
		if me then
			for i = rank, n - 1 do list[i] = list[i + 1] end
			list[n] = nil
			n = n - 1
		end
		for i = n, 1, -1 do list[i + 1] = list[i] end
		list[1] = px
		n = n + 1
		me, tank, rank = px, px, 1
	end
	M.n = n
	M.holder = tank
	M.selfRank = me and rank or 0
	M.selfPct = me and me.pct or 0
	local a = M.agro
	local ref = tank and tank.v or 0
	local mel = (me == nil) or me.melee
	a.pct = mel and M.MELEE or M.RANGED
	a.v = ref * (a.pct / 100)
	a.name = L("msg.threat.agro")
	a.tps = 0
	local tname = tank and tank.name or nil
	if tname and M.tankName and tname ~= M.tankName and M.cfg.pullmsg then
		SUI.Print(L("msg.threat.pull", tname == M.player and L("msg.threat.you") or tname, M.tankName == M.player and L("msg.threat.you") or M.tankName))
	end
	if tname then M.tankName = tname end
	M.ver = M.ver + 1
	M.reqAt = nil
	M.CheckWarn(me, now)
	if M.taunt.on and M.win then M.Paint() end    -- provocation en cours : pas d'attente du prochain cycle
end

function M.CheckWarn(me, now)
	local c = M.cfg
	if c.warn <= 0 or not me or me.tank or me.pct < c.warn then return end
	if M.lastWarn and now - M.lastWarn < c.warncd then return end
	M.lastWarn = now
	M.flashUntil = now + 2
	if c.sound then PlaySoundFile(M.SOUND) end
	local f = getglobal("UIErrorsFrame")
	if c.flash and f and f.AddMessage then
		local col = T.c.bad
		f:AddMessage(L("msg.threat.warn", UnitName("target") or EMPTY, floor(me.pct)), col[1], col[2], col[3], 1, 2)
	end
end

-- Meter (vue "menace") : remplit la liste donnee avec les enregistrements tries ; retourne leur nombre.
function M.GetRows(list)
	for i = 1, M.n do list[i] = M.list[i] end
	return M.n
end

-- ---------------------------------------------------------------- affichage
function M.Short(v)
	if not M.cfg.shortnum then return strformat("%d", floor(v + 0.5)) end
	if v >= 1000000 then return strformat("%.2fM", v / 1000000) end
	if v >= 10000 then return strformat("%.1fk", v / 1000) end
	return strformat("%d", floor(v + 0.5))
end

function M.RowText(r, view)
	if view == "mobs" then return strformat("%d%%", floor(r.pct + 0.5)) end
	local s = M.Short(r.v)
	if M.cfg.showtps and r.tps and r.tps > 0 then s = s .. " " .. M.Short(r.tps) .. "/s" end
	return s .. strformat(" %d%%", floor(r.pct + 0.5))
end

-- Nom affiche : ">" devant le detenteur de l'aggro, "provoque Ns" derriere le joueur tant que son effet de provocation dure.
function M.RowName(r, view)
	if view ~= "players" or r.agro then return r.name end
	local s = r.name
	if M.cfg.markholder and r == M.holder then s = M.MARK .. " " .. s end
	if M.tauntLeft > 0 and r.name == M.player then s = s .. " " .. L("msg.threat.taunted", M.tauntLeft) end
	return s
end

function M.RowColor(r, view)
	local c = M.cfg
	if r.agro then return T.c.warn[1], T.c.warn[2], T.c.warn[3] end
	if view == "players" and (r.prov or (M.tauntLeft > 0 and r.name == M.player)) then return T.Accent() end
	if view == "mobs" then
		local col = (r.holder == M.player) and T.c.good or T.c.bad
		return col[1], col[2], col[3]
	end
	if c.warn > 0 and not r.tank and r.pct >= c.warn then return T.c.bad[1], T.c.bad[2], T.c.bad[3] end
	if c.classcolor and r.cls then
		local cc = RAID_CLASS_COLORS[r.cls]
		if cc then return cc.r, cc.g, cc.b end
	end
	local r, g, b = M.TokenRGB(c.color)
	if r then return r, g, b end
	return T.Accent()
end

-- Design par jetons du style (aucune couleur en dur) : threat.bg = fond de la fenetre (style | panel | bg | inset | none), threat.color =
-- couleur des barres ordinaires (style = accent). Valeurs lues dans T.c.* a chaque application (le style peut changer).
M.BGS = { "style", "panel", "bg", "inset", "none" }
M.COLORS = { "style", "good", "warn", "bad", "dim", "text" }
M.nobg = {}

function M.TokenRGB(name)
	local c = (name and name ~= "style") and T.c[name] or nil
	if c then return c[1], c[2], c[3] end
	return nil
end

-- Fond de la fenetre selon threat.bg ; "none" = meme teinte que le panneau, opacite nulle.
function M.ApplyBack(f, force)
	local tok = M.cfg.bg or "style"
	if f.mbTok == tok and not force then return end     -- redimensionnement a la poignee : pas de nouveau SetBackdrop a chaque pas
	f.mbTok = tok
	if tok == "none" then
		local c = T.c.panel
		local z = M.nobg
		z[1], z[2], z[3], z[4] = c[1], c[2], c[3], 0
		T.Backdrop(f, z, T.c.border)
	elseif tok ~= "style" and T.c[tok] then
		T.Backdrop(f, T.c[tok], T.c.border)
	else
		T.Backdrop(f, T.c.panel, T.c.border)
	end
end

-- Police : retrouve l'enregistrement de style d'un texte (Theme.lua : T.items) pour changer sa taille sans toucher au Theme.
function M.Track(fs)
	local n = getn(T.items)
	local it = T.items[n]
	if not it or it.o ~= fs then
		it = nil
		for i = n, 1, -1 do
			if T.items[i].o == fs then it = T.items[i] break end
		end
	end
	fs.suiTk = it
end

-- Police : threat.font (SUI.Look), taille = reglage threat.fontsize. Look repose seul police et taille quand un reglage ou le style change.
function M.SetFont(fs, size)
	local it = fs.suiTk
	if not it then return end
	if fs.suiLookTracked and it.size == size then return end
	it.size = size
	SUI.Look.ApplyText(fs, "threat", size, it.outline)
end

-- Hauteur de ligne et d'en-tete effectives : jamais plus petites que la police (sinon les lignes se chevauchent).
function M.RowH()
	return mmax(M.cfg.rowh, M.cfg.fontsize + 3)
end

function M.Hdr()
	return mmax(M.HDR, M.cfg.fontsize + 8)
end

-- Largeur, hauteur, lignes (w.liveW / w.liveH : taille provisoire pendant le glissement de la poignee). Hauteur 0 = suit les lignes.
function M.Dims(w)
	local c = M.cfg
	local step = M.RowH() + c.spacing
	local hdr = M.Hdr()
	local width = (w and w.liveW) or c.width
	local height = (w and w.liveH) or (c.height > 0 and c.height) or nil
	local rows
	if height then
		height = mmax(M.MINH, mmin(M.MAXH, height))
		rows = mmax(1, mmin(M.MAXROWS, floor((height - hdr - M.FOOT) / step)))
	else
		rows = mmax(1, mmin(M.MAXROWS, c.rows))
		height = hdr + rows * step + M.FOOT
	end
	return width, height, rows
end

local function onView(b)
	local nv = (M.cfg.view == "players") and "mobs" or "players"
	C.Set("threat.view", nv)
end

-- Bouton de fermeture (x) : meme effet que de decocher "Afficher la fenetre" (reglage memorise, minuterie coupee).
local function onClose(b)
	C.Set("threat.show", false)
	SUI.Print(L("msg.threat.closed"))
end

local function onReport(b, mb)
	if mb == "RightButton" then
		local list, cur = M.REPORT, M.cfg.reportchan
		local idx = 1
		for i = 1, getn(list) do if list[i] == cur then idx = i end end
		idx = idx + 1
		if idx > getn(list) then idx = 1 end
		C.Set("threat.reportchan", list[idx])
		SUI.Print(L("msg.threat.chan", L("choice.threat.reportchan." .. list[idx])))
		return
	end
	M.Report(nil)
end

-- Infobulle des deux petits boutons (R = rapport, V = vue) : sans elle, leur role est invisible.
local function tipEnter()
	local r, g, b = T.Accent()
	this:SetBackdropBorderColor(r, g, b, 1)
	local tt = getglobal("GameTooltip")
	if tt and this.tipKey then
		tt:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		tt:SetText(L(this.tipKey))
		tt:Show()
	end
end

local function tipLeave()
	local c = T.c.border
	this:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	local tt = getglobal("GameTooltip")
	if tt then tt:Hide() end
end

function M.BuildRow(w)
	local b = CreateFrame("Frame", nil, w.f)
	b.bar = T.Bar(b)
	b.bar:SetAllPoints(b)
	b.lookOpts = { height = M.RowH() }
	SUI.Look.ApplyBar(b.bar, "threat", b.lookOpts)
	b.name = T.Text(b.bar, M.cfg.fontsize, T.c.text, "LEFT", true)
	M.Track(b.name)
	b.name:SetPoint("LEFT", b.bar, "LEFT", 3, 0)
	b.val = T.Text(b.bar, M.cfg.fontsize, T.c.text, "RIGHT", true)
	M.Track(b.val)
	b.val:SetPoint("RIGHT", b.bar, "RIGHT", -3, 0)
	b:Hide()
	return b
end

-- Poignee de coin : le coin haut gauche reste fixe, la fenetre suit la souris ; au relacher largeur / hauteur / position sont memorisees
-- (reglages threat.width / threat.height, position dans le Layout sous la cle "threat.win", relue par le Mover).
local function gripTick()
	local w = this.win
	local cx, cy = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	if not s or s <= 0 then s = 1 end
	w.liveW = floor(mmax(M.MINW, mmin(M.MAXW, (cx / s) / w.dsc - w.dl)) + 0.5)
	w.liveH = floor(mmax(M.MINH, mmin(M.MAXH, w.dt - (cy / s) / w.dsc)) + 0.5)
	M.ApplyWindow()
end

local function gripDown()
	local w = this.win
	if arg1 ~= "LeftButton" or w.sizing then return end
	local l, t = w.f:GetLeft(), w.f:GetTop()
	if not l or not t then return end
	w.dl, w.dt, w.dsc = l, t, w.f:GetScale() or 1
	w.f:ClearAllPoints()
	w.f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
	w.sizing = true
	this:SetScript("OnUpdate", gripTick)
end

local function gripUp()
	local w = this.win
	this:SetScript("OnUpdate", nil)
	if not w.sizing then return end
	w.sizing = nil
	M.CommitSize(w)
end

function M.CommitSize(w)
	local nw, nh = w.liveW, w.liveH
	w.liveW, w.liveH = nil, nil
	if not nw or not nh then
		SUI.Layout.Apply("threat.win")
		return
	end
	local _, _, s = C.GetPos(SUI.Layout.ReadKey("threat.win"))
	local sc = w.dsc or 1
	C.SetPos(SUI.Layout.WriteKey("threat.win"), w.dl * sc, (w.dt - nh) * sc, s or 1)
	C.Set("threat.width", nw)
	C.Set("threat.height", nh)
	SUI.Layout.Apply("threat.win")
	if SUI.Mover and SUI.Mover.Sync then SUI.Mover.Sync() end
end

-- Largeur disponible pour le titre : cadre moins la marge gauche (4) et la barre de boutons (x R V = 3 x 16 + 2 espaces + marge droite 2 + 4 d'air).
M.TITLE_RESERVE = 4 + 16 * 3 + 2 + 2 + 4

function M.TitleAvail(width)
	return mmax((width or 190) - M.TITLE_RESERVE, 8)
end

-- Titre sur UNE ligne : tronque (avec "...") pour tenir dans avail pixels. Largeur 0 pendant la mesure (le texte ne passe pas a la ligne),
-- recherche dichotomique (peu d'appels), coupure jamais au milieu d'un caractere UTF-8.
function M.FitTitle(fs, text, avail)
	fs:SetWidth(0)
	fs:SetText(text)
	local sw = fs:GetStringWidth()
	if type(sw) ~= "number" or sw <= avail then
		fs:SetWidth(avail)
		return text
	end
	local lo, hi = 0, strlen(text)
	while lo < hi do
		local mid = floor((lo + hi + 1) / 2)
		local cut = mid
		while cut > 0 do
			local b = strbyte(text, cut + 1)
			if b and b >= 128 and b < 192 then cut = cut - 1 else break end
		end
		fs:SetText(strsub(text, 1, cut) .. "...")
		local w2 = fs:GetStringWidth()
		if type(w2) ~= "number" or w2 <= avail then lo = mid else hi = mid - 1 end
	end
	local cut = lo
	while cut > 0 do
		local b = strbyte(text, cut + 1)
		if b and b >= 128 and b < 192 then cut = cut - 1 else break end
	end
	local out = strsub(text, 1, cut) .. "..."
	fs:SetText(out)
	fs:SetWidth(avail)
	return out
end

-- Niveaux des controles. Le client 1.12 peut changer le niveau du cadre de la fenetre apres sa construction (cadre releve, lien de
-- position) : des boutons restes a un niveau perime passent SOUS le cadre (qui capte la souris) et ne recoivent plus aucun clic.
-- On recale donc boutons (+4) et poignee (+5) sur le niveau reel : a l'affichage, au survol, a chaque passage de la minuterie.
-- Retourne le nombre de cadres recales (aucune table creee : la liste des controles est faite a la construction).
function M.SyncLevels(w)
	local base = w.f:GetFrameLevel() or 0
	local n = 0
	local ctl = w.ctl
	if ctl then
		for i = 1, getn(ctl) do
			if ctl[i]:GetFrameLevel() ~= base + 4 then
				ctl[i]:SetFrameLevel(base + 4)
				n = n + 1
			end
		end
	end
	if w.grip and w.grip:GetFrameLevel() ~= base + 5 then
		w.grip:SetFrameLevel(base + 5)
		n = n + 1
	end
	w.lvl = base
	return n
end

function M.LevelsStale(w)
	local base = w.f:GetFrameLevel() or 0
	if w.lvl ~= base then return true end
	local c1 = w.ctl and w.ctl[1]
	if c1 and c1:GetFrameLevel() ~= base + 4 then return true end
	if w.grip and w.grip:GetFrameLevel() ~= base + 5 then return true end
	return false
end

function M.CheckLevels()
	local w = M.win
	if w and w.f:IsShown() and M.LevelsStale(w) then M.SyncLevels(w) end
end

local function winShow()
	local w = this.win
	if w then M.SyncLevels(w) end
end

local function winEnter()
	local w = this.win
	if w and M.LevelsStale(w) then M.SyncLevels(w) end
end

function M.BuildWindow()
	if M.win then return M.win end
	local f = T.Panel(UIParent, 190, 100)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	local w = { f = f, rows = {} }
	f.win = w
	f:SetScript("OnShow", winShow)
	f:SetScript("OnEnter", winEnter)
	w.title = T.Text(f, M.cfg.fontsize, T.c.text, "LEFT", false)
	M.Track(w.title)
	w.title:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	w.bClose = T.Button(f, "x", 16, 14, onClose)
	w.bReport = T.Button(f, "R", 16, 14, onReport)
	w.bView = T.Button(f, "V", 16, 14, onView)
	w.bClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	w.bReport:SetPoint("RIGHT", w.bClose, "LEFT", -1, 0)
	w.bView:SetPoint("RIGHT", w.bReport, "LEFT", -1, 0)
	w.bReport.tipKey, w.bView.tipKey = "msg.threat.tip.report", "msg.threat.tip.view"
	w.bClose.tipKey = "msg.threat.tip.close"
	w.bClose:SetScript("OnEnter", tipEnter)
	w.bClose:SetScript("OnLeave", tipLeave)
	w.bReport:SetScript("OnEnter", tipEnter)
	w.bReport:SetScript("OnLeave", tipLeave)
	w.bView:SetScript("OnEnter", tipEnter)
	w.bView:SetScript("OnLeave", tipLeave)
	w.empty = T.Text(f, M.cfg.fontsize, T.c.dim, "CENTER", false)
	M.Track(w.empty)
	w.empty:SetPoint("CENTER", f, "CENTER", 0, -8)
	w.grip = T.Button(f, EMPTY, 10, 10, nil)
	w.grip.win = w
	w.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	w.grip:SetScript("OnMouseDown", gripDown)
	w.grip:SetScript("OnMouseUp", gripUp)
	w.ctl = { w.bClose, w.bReport, w.bView }
	for r = 1, M.PREROWS do w.rows[r] = M.BuildRow(w) end
	M.win = w
	M.SyncLevels(w)
	SUI.Layout.Register(f, "threat.win", "BOTTOMRIGHT", -20, 330)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("threat.win", f, { label = "mod.mover.n.threat.win", scale = true })
	end
	f:Hide()
	-- Engrenage au coin bas gauche (la poignee de taille est au coin bas droit) : il ne prend aucune place au titre.
	T.GearButton(f, "threat", { size = 14, point = "BOTTOMLEFT", x = -7, y = -7, title = L("msg.threat.gear"),
		onCreate = function(g) w.gear = g end })
	M.ApplyWindow()
	M.VisAdd()
	return w
end

-- Cree les lignes manquantes (hors combat seulement ; sinon apres le combat).
function M.GrowRows()
	local w = M.win
	if not w then return end
	w.growing = false
	local _, _, n = M.Dims(w)
	for r = getn(w.rows) + 1, n do w.rows[r] = M.BuildRow(w) end
	M.ApplyWindow()
end

function M.ApplyWindow()
	local w = M.win
	if not w then return end
	local c = M.cfg
	local f = w.f
	local width, height, rows = M.Dims(w)
	if getn(w.rows) < rows and not w.growing then
		w.growing = true
		SUI.WhenSafe(M.GrowRows)
	end
	w.nrows = mmin(rows, getn(w.rows))
	f:SetWidth(width)
	f:SetHeight(height)
	M.ApplyBack(f)
	local V = SUI.Visibility
	if V and w.vp and V.byFrame[w.vp] then V.SetBase(w.vp, c.alpha) else f:SetAlpha(c.alpha) end
	w.empty:SetWidth(width - 12)   -- largeur fixe : le texte d'attente passe a la ligne au lieu de depasser du cadre
	w.title:SetWidth(M.TitleAvail(width))
	w.title:SetHeight(c.fontsize + 2)   -- une seule ligne : jamais de retour a la ligne sous les boutons
	M.SetFont(w.title, c.fontsize)
	M.SetFont(w.empty, c.fontsize)
	for r = 1, getn(w.rows) do
		local b = w.rows[r]
		b:SetWidth(width - 4)
		b:SetHeight(M.RowH())
		b.bar:SetHeight(M.RowH())   -- explicite (la barre est aussi SetAllPoints ; le mock de test ne suit pas les points)
		b.lookOpts.height = M.RowH()
		SUI.Look.ApplyBar(b.bar, "threat", b.lookOpts)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -(M.Hdr() + (r - 1) * (M.RowH() + c.spacing)))
		M.SetFont(b.name, c.fontsize)
		M.SetFont(b.val, c.fontsize)
		b.lname, b.lval, b.lcol, b.vis = nil, nil, nil, nil
	end
	w.ttl = nil
	M.ver = M.ver + 1
	if w.sizing then M.Paint() end
end

function M.Paint()
	local w = M.win
	if not w then return end
	local c = M.cfg
	M.paintedVer = M.ver
	local view = c.view
	M.tauntLeft = M.TauntLeft(GetTime())
	local list, n = M.list, M.n
	if view == "mobs" then list, n = M.mobs, M.mobn end
	local extra = (view == "players" and c.showagro and n > 0) and 1 or 0
	local ttl
	if n > 0 then
		if M.selfRank > 0 and M.n > 0 then
			ttl = L(M.estimated and "msg.threat.estitler" or "msg.threat.titler", UnitName("target") or EMPTY, M.selfRank, floor(M.selfPct + 0.5))
		else
			ttl = L(M.estimated and "msg.threat.estitle" or "msg.threat.title", UnitName("target") or EMPTY, floor(M.selfPct + 0.5))
		end
	else
		ttl = L("msg.threat.notitle")
	end
	local avail = M.TitleAvail(w.f:GetWidth())
	if w.ttl ~= ttl or w.tavail ~= avail then
		w.ttl = ttl
		w.tavail = avail
		M.FitTitle(w.title, ttl, avail)
		w.title:SetHeight(c.fontsize + 2)
	end
	local flashing = M.flashUntil and GetTime() < M.flashUntil
	if w.flash ~= flashing then
		w.flash = flashing
		local col = flashing and T.c.bad or T.c.text
		w.title:SetTextColor(col[1], col[2], col[3], 1)
	end
	if n == 0 then w.empty:SetText(L("msg.threat.nodata")) else w.empty:SetText(EMPTY) end
	local top = 1
	if n > 0 then
		if view == "mobs" then top = 100 else top = mmax(M.agro.pct, list[1].pct, 1) end
	end
	local rows = mmin(w.nrows or c.rows, n + extra)
	local ai = 0
	if extra == 1 then
		ai = 1
		for i = 1, n do
			if list[i].pct < M.agro.pct then break end
			ai = ai + 1
		end
	end
	for r = 1, getn(w.rows) do
		local b = w.rows[r]
		local e = nil
		if r <= rows then
			if extra == 1 and r == ai then
				e = M.agro
			elseif extra == 1 and r > ai then
				e = list[r - 1]
			else
				e = list[r]
			end
		end
		if e then
			if not b.vis then b.vis = true b:Show() end
			b.bar:SetMinMaxValues(0, 1)
			b.bar:SetValue(mmin(e.pct / top, 1))
			local cr, cg, cb = M.RowColor(e, view)
			b.bar:SetStatusBarColor(cr, cg, cb, 1)
			local dn = M.RowName(e, view)
			if b.lname ~= dn then
				b.lname = dn
				b.name:SetText(dn)
			end
			local vt = e.agro and strformat("%s %d%%", M.Short(e.v), e.pct) or M.RowText(e, view)
			if b.lval ~= vt then
				b.lval = vt
				b.val:SetText(vt)
			end
		elseif b.vis ~= false then
			b.vis = false
			b:Hide()
		end
	end
end

-- Mandataire de la fenetre aupres du service de visibilite (une simple table, aucune frame) : Show ne montre que ce que le module veut.
-- La regle de visibilite (threat.vis, SUI.Visibility) s'y ajoute : elle fond l'opacite puis cache, sans jamais rouvrir une fenetre fermee.
local function vpSetAlpha(self, a) M.win.f:SetAlpha(a) end
local function vpGetAlpha(self) return M.win.f:GetAlpha() end
local function vpIsShown(self) return M.win.f:IsShown() end
local function vpShow(self)
	local w = M.win
	if M.on and M.cfg.show and not w.f:IsShown() then
		w.f:Show()
		M.ver = M.ver + 1
	end
end
local function vpHide(self)
	local w = M.win
	if w.f:IsShown() then w.f:Hide() end
end

function M.VisAdd()
	local V = SUI.Visibility
	local w = M.win
	if not V or not M.on or not w then return end
	if not w.vp then
		w.vp = { SetAlpha = vpSetAlpha, GetAlpha = vpGetAlpha, IsShown = vpIsShown, Show = vpShow, Hide = vpHide }
	end
	if V.byFrame[w.vp] then return end
	V.Add(w.vp, "threat", { mode = "show", module = "threat", alpha = M.cfg.alpha, cat = "threat" })
end

-- Retire le mandataire quand le module est coupe (differe : Remove detache un observateur, jamais pendant une notification de Config).
function M.VisDrop()
	local V = SUI.Visibility
	local w = M.win
	if M.on or not V or not w then return end
	if w.vp then V.Remove(w.vp) end
end

function M.UpdateVisibility()
	local w = M.win
	if not w then return end
	local V = SUI.Visibility
	local want = M.on and M.cfg.show
	if want and not w.f:IsShown() and (not V or not w.vp or V.Allowed(w.vp)) then
		w.f:Show()
		M.ver = M.ver + 1
	elseif not want and w.f:IsShown() then
		w.f:Hide()
	end
end

-- ---------------------------------------------------------------- estimation locale (sans serveur compatible)
-- Le compteur (Mod_Meter, M.Record) appelle M.Feed pour chaque coup / soin d'un membre du groupe. Sans paquet du serveur depuis M.FRESH
-- secondes, la fenetre montre cette ESTIMATION : menace = degats x modificateur (posture defensive 1.3, Fureur vertueuse 1.6, Salut 0.7,
-- relevees dans OctoMeter) ; soin = 0.5 x montant sur chaque cible suivie. Ce n'est pas la menace du serveur : le titre le dit.
M.FRESH = 6
function M.ClearEst()
	for k in pairs(M.est) do M.est[k] = nil end
	M.nest = 0
	M.estimated = false
	M.estDirty = false
end

function M.AddEst(mob, src, v)
	local t = M.est[mob]
	if not t then
		if M.nest >= M.MAXEST then return end
		t = {}
		M.est[mob] = t
		M.nest = M.nest + 1
	end
	t[src] = (t[src] or 0) + v
end

-- Multiplicateur d'un joueur d'apres ses postures / benedictions (icones), rafraichi toutes les 2 s.
function M.Mod(src, now)
	local c = M.mods[src]
	if c and now - c.t < 2 then return c.m end
	if not c then
		c = { m = 1, t = 0 }
		M.mods[src] = c
	end
	c.t = now
	local m = 1
	local meter = SUI.Meter
	local u = meter and meter.unit and meter.unit[src]
	local buff = getglobal("UnitBuff")
	if u and buff and UnitExists(u) then
		for i = 1, 32 do
			local tex = buff(u, i)
			if not tex then break end
			if tex == M.ICONS.stance then m = m * 1.3
			elseif tex == M.ICONS.fury then m = m * 1.6
			elseif tex == M.ICONS.salv then m = m * 0.7 end
		end
	end
	c.m = m
	return m
end

function M.Feed(kind, src, mob, val, abl)
	if not M.running or not M.cfg.estimate or not val or val <= 0 or not src or not mob then return end
	local m = M.Mod(src, GetTime())
	if kind == "damage" then
		M.AddEst(mob, src, val * m)
	else
		local half = val * 0.5 * m
		for name in pairs(M.est) do M.AddEst(name, src, half) end
	end
	M.estDirty = true
end

-- Montre l'estimation pour la cible actuelle (hors paquet frais du serveur).
function M.Estimate(now)
	local name = UnitName("target")
	local t = nil
	if name and UnitCanAttack("player", "target") then t = M.est[name] end
	if not t then
		if M.estimated then
			M.estimated = false
			M.n, M.nrec = 0, 0
			M.ver = M.ver + 1
		end
		return
	end
	if not M.estDirty and M.estimated and M.estName == name then return end
	M.estDirty = false
	M.estName = name
	local n, top = 0, 0
	for p, v in pairs(t) do
		if n < M.MAXREC then
			n = n + 1
			local r = M.rec[n]
			r.name, r.v, r.cls, r.melee = p, v, M.cls[p], true
			if v > top then top = v end
		end
	end
	for i = 1, n do
		local r = M.rec[i]
		r.pct = top > 0 and r.v * 100 / top or 0
		r.tank = (r.v == top)
		M.Rate(r, now)
	end
	M.nrec = n
	M.estimated = true
	M.Finish(now)
end

function M.OnPull()
	if not M.running then return end
	M.ClearEst()
	M.Boost()
end

-- Debut de combat / nouvelle cible en combat : demande tout de suite (sans attendre la minuterie lente), puis une minuterie rapide
-- (M.FASTRATE) pendant M.FASTSPAN secondes ; la fenetre est montree et repeinte aussitot (pas d'attente du prochain cycle de M.Tick).
function M.Boost()
	local now = GetTime()
	M.fastUntil = now + M.FASTSPAN
	if not M.fastTask then M.fastTask = SUI.Every(M.FASTRATE, M.FastTick, "threat.fast") end
	M.FastTick()
end

function M.FastTick()
	if not M.running then return end
	local now = GetTime()
	if not M.fastUntil or now >= M.fastUntil then
		SUI.Cancel(M.fastTask)
		M.fastTask, M.fastUntil = nil, nil
		return
	end
	if not UnitAffectingCombat("player") then return end
	M.Request(now)
	if M.cfg.estimate and not (M.lastPkt and now - M.lastPkt <= M.FRESH) then M.Estimate(now) end
	M.UpdateVisibility()
	if M.ver ~= M.paintedVer and M.win then M.Paint() end
end

-- ---------------------------------------------------------------- provocation
-- La provocation tient-elle pour la cible affichee ? (sort de zone : toujours ; sinon la cible doit porter le nom de celle visee au lancement)
function M.TauntFits(now)
	local t = M.taunt
	if not M.cfg.taunt or not t.on or now >= t.untilT then return false end
	if t.aoe then return true end
	return t.tname == nil or UnitName("target") == t.tname
end

-- Secondes restantes (arrondies au-dessus) de l'effet de provocation pour la cible affichee ; 0 si aucun.
function M.TauntLeft(now)
	if not M.TauntFits(now) then return 0 end
	return math.ceil(M.taunt.untilT - now)
end

function M.TauntPoll()
	M.tauntTask = nil
	if not M.running then return end
	local now = GetTime()
	if M.taunt.on and now < M.taunt.provT then
		M.Request(now)
		M.tauntTask = SUI.After(M.TAUNT_STEP, M.TauntPoll, "threat.taunt")
	end
end

-- Un sort de provocation vient d'etre lance par le joueur : ligne provisoire, demande immediate, relances rapprochees, repeinture.
function M.OnTaunt(name, now)
	local dur = M.TAUNTS[name]
	local t = M.taunt
	if not dur or not M.running or not M.cfg.taunt then return end
	if t.on and t.name == name and now - t.at < 0.7 then return end     -- meme lancement vu par deux sources
	t.on, t.name, t.at = true, name, now
	t.untilT, t.provT = now + dur, now + M.TAUNT_PROV
	t.aoe = M.TAUNT_AOE[name] and true or false
	t.tname = UnitName("target")
	t.shown = -1
	if M.nrec > 0 then
		if M.estimated then
			M.estDirty = true
			M.Estimate(now)
		else
			M.Finish(now)
		end
	end
	M.Request(now)
	if M.tauntTask then SUI.Cancel(M.tauntTask) end
	M.tauntTask = SUI.After(M.TAUNT_STEP, M.TauntPoll, "threat.taunt")
	M.ver = M.ver + 1
	if M.win and M.win.f:IsShown() then M.Paint() end
end

-- Appele par Mod_TankTools quand une provocation est resistee / ratee / esquivee : la ligne provisoire disparait.
function M.OnTauntFail(name)
	local t = M.taunt
	if not t.on or (name and t.name ~= name) then return end
	t.on, t.shown = false, -1
	if M.estimated then M.estDirty = true end
	if M.running and M.nrec > 0 and not M.estimated then M.Finish(GetTime()) end
	M.ver = M.ver + 1
	if M.running then M.Request(GetTime()) end
	if M.win and M.win.f:IsShown() then M.Paint() end
end

function M.OnCastEvent(ev, a1, a2, a3, a4)
	-- SuperWoW UNIT_CASTEVENT(lanceur, cible, type, sort, duree ms)
	if a3 ~= "CAST" or not M.pguid or a1 ~= M.pguid then return end
	local si = getglobal("SpellInfo")
	local name = si and si(a4)
	if name and M.TAUNTS[name] then M.OnTaunt(name, GetTime()) end
end

function M.OnGoSelf(ev, a1, a2, a3, a4)
	-- Nampower SPELL_GO_SELF(objet, sort, lanceur, cible, ...)
	if not M.pguid or a3 ~= M.pguid then return end
	local si = getglobal("SpellInfo")
	local name = si and si(a2)
	if name and M.TAUNTS[name] then M.OnTaunt(name, GetTime()) end
end

-- Sans SuperWoW ni Nampower : un temps de recharge qui DEBUTE (depart recent, plus long que le delai global) sur une provocation du grimoire.
function M.ScanTaunts()
	M.tauntDirty = false
	M.tn = 0
	local gn = getglobal("GetSpellName")
	if not gn then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	local i = 1
	while i <= 400 do
		local name = gn(i, book)
		if not name then break end
		if M.TAUNTS[name] then
			local k = nil
			for j = 1, M.tn do if M.tname[j] == name then k = j end end
			if not k then
				M.tn = M.tn + 1
				k = M.tn
			end
			M.tname[k], M.tidx[k] = name, i
		end
		i = i + 1
	end
	local gc = getglobal("GetSpellCooldown")
	if gc then
		for j = 1, M.tn do
			local start = gc(M.tidx[j], book)
			M.tstart[M.tname[j]] = start
		end
	end
end

function M.OnCooldown()
	if not M.running or M.tn == 0 then return end
	local gc = getglobal("GetSpellCooldown")
	if not gc then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	local now = GetTime()
	for j = 1, M.tn do
		local start, dur = gc(M.tidx[j], book)
		if start and start > 0 and dur and dur > M.GCD then
			local nm = M.tname[j]
			if M.tstart[nm] ~= start then
				M.tstart[nm] = start
				if now - start < 0.7 then M.OnTaunt(nm, now) end
			end
		end
	end
end

function M.OnBook()
	M.tauntDirty = true
end

-- ---------------------------------------------------------------- demande au serveur
function M.TankMode()
	local m = M.cfg.tankmode
	if m == "on" then return true end
	if m == "off" then return false end
	return C.GetRole() == "tank"
end

function M.Request(now)
	local chan
	if GetNumRaidMembers() > 0 then chan = "RAID" elseif GetNumPartyMembers() > 0 then chan = "PARTY" else return false end
	if not UnitExists("target") or not UnitCanAttack("player", "target") then return false end
	SendAddonMessage(M.TankMode() and M.PREFIX_TM or M.PREFIX, M.cfg.limit, chan)
	M.reqAt = now
	return true
end

function M.OnAddon(ev, a1, a2, a3, a4)
	if not M.running or type(a2) ~= "string" or not M.reqAt then return end
	if GetTime() - M.reqAt > M.WAIT then return end
	if strfind(a2, M.API, 1, true) then
		M.Parse(a2)
		if M.fastTask and M.win and M.ver ~= M.paintedVer then M.Paint() end    -- debut de combat : affichage immediat du paquet
	end
end

function M.OnTarget()
	if not M.running then return end
	local hot = UnitAffectingCombat("player")
	M.n, M.mobn, M.nrec = 0, 0, 0
	M.selfRank, M.holder = 0, nil
	for i = getn(M.list), 1, -1 do M.list[i] = nil end
	for i = getn(M.mobs), 1, -1 do M.mobs[i] = nil end
	M.ClearHist()
	M.tankName, M.selfPct = nil, 0
	M.estimated = false
	M.ver = M.ver + 1
	if hot then M.Boost() end    -- cible changee en plein combat : liste vide jusqu'au prochain paquet, on le demande tout de suite
end

-- ---------------------------------------------------------------- rapport
function M.Report(chan)
	local c = M.cfg
	chan = chan or c.reportchan
	if M.n == 0 then SUI.Print(L("msg.threat.nodata")) return 0 end
	if chan == "auto" then
		if GetNumRaidMembers() > 0 then chan = "raid" elseif GetNumPartyMembers() > 0 then chan = "party" else chan = "say" end
	end
	local out = { L("msg.threat.rephead", UnitName("target") or EMPTY) }
	local k = mmin(c.reportn, M.n)
	for i = 1, k do
		local r = M.list[i]
		out[i + 1] = strformat("%d. %s %s (%d%%)", i, r.name, M.Short(r.v), floor(r.pct + 0.5))
	end
	for i = 1, getn(out) do
		if chan == "self" then SUI.Print(out[i]) else SendChatMessage(out[i], string.upper(chan)) end
	end
	return getn(out)
end

-- ---------------------------------------------------------------- minuterie et reglages
function M.Tick()
	if not M.running then return end
	local now = GetTime()
	if M.rosterDirty then M.ScanRoster() end
	local combat = UnitAffectingCombat("player") and true or false
	M.inCombat = combat
	if not combat and UnitExists("target") and UnitAffectingCombat("target") then
		M.Request(now)    -- cible deja en combat (comme TWThreat) alors que le joueur n'est pas marque en combat
	end
	if combat then
		M.leftAt = nil
		M.Request(now)
		if M.cfg.estimate and not (M.lastPkt and now - M.lastPkt <= M.FRESH) then M.Estimate(now) end
	elseif M.n > 0 or M.mobn > 0 then
		if not M.leftAt then M.leftAt = now
		elseif now - M.leftAt >= M.LINGER then
			M.leftAt = nil
			M.Reset()
		end
	end
	if M.tauntDirty then M.ScanTaunts() end
	local tk = M.taunt
	if tk.on then
		if now >= tk.untilT then
			tk.on, tk.shown = false, -1
			if M.estimated then M.estDirty = true end
			M.ver = M.ver + 1
		else
			local left = math.ceil(tk.untilT - now)
			if left ~= tk.shown then
				tk.shown = left
				M.ver = M.ver + 1
			end
		end
	end
	M.UpdateVisibility()
	M.CheckLevels()
	if M.flashUntil and now >= M.flashUntil then
		M.flashUntil = nil
		M.ver = M.ver + 1
	end
	if M.ver ~= M.paintedVer then M.Paint() end
end

function M.ReadConfig()
	local c = M.cfg
	c.show = C.Get("threat.show")
	c.rows = C.Get("threat.rows")
	c.height = C.Get("threat.height")
	c.fontsize = C.Get("threat.fontsize")
	c.estimate = C.Get("threat.estimate")
	c.rowh = C.Get("threat.rowh")
	c.width = C.Get("threat.width")
	c.spacing = C.Get("threat.spacing")
	c.alpha = C.Get("threat.alpha")
	c.classcolor = C.Get("threat.classcolor")
	c.bg = C.Get("threat.bg")
	c.color = C.Get("threat.color")
	c.rate = C.Get("threat.rate")
	c.warn = C.Get("threat.warn")
	c.sound = C.Get("threat.sound")
	c.flash = C.Get("threat.flash")
	c.showagro = C.Get("threat.showagro")
	c.showtps = C.Get("threat.showtps")
	c.shortnum = C.Get("threat.shortnum")
	c.hideooc = C.Get("threat.hideooc")
	c.tankmode = C.Get("threat.tankmode")
	c.view = C.Get("threat.view")
	c.pullmsg = C.Get("threat.pullmsg")
	c.taunt = C.Get("threat.taunt")
	c.markholder = C.Get("threat.markholder")
	c.reportn = C.Get("threat.reportn")
	c.reportchan = C.Get("threat.reportchan")
	local _, _, nrows = M.Dims(nil)
	c.limit = "limit=" .. floor(nrows)
end

-- Ancien reglage threat.hideooc (cacher hors combat) : migre vers threat.vis = "combat" (SUI.Visibility) et reste synchronise avec lui
-- (la case "Cacher hors combat" est un raccourci de Visibilite = combat seulement).
function M.SyncVis(key)
	local vis, old = C.Get("threat.vis"), C.Get("threat.hideooc")
	if key == "threat.hideooc" then
		if old and vis == "always" then C.Set("threat.vis", "combat")
		elseif not old and vis == "combat" then C.Set("threat.vis", "always") end
		return
	end
	if key == nil and old and vis == "always" then
		vis = "combat"
		C.Set("threat.vis", vis)
	end
	if old ~= (vis == "combat") then C.Set("threat.hideooc", vis == "combat") end
end

function M.OnKey(key, value)
	if key == nil or key == "threat.vis" or key == "threat.hideooc" then M.SyncVis(key) end
	M.ReadConfig()
	if key == "threat.rows" and M.cfg.height > 0 then C.Set("threat.height", 0) end
	if not M.on then return end
	if M.Wanted() then
		M.Start()
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(M.cfg.rate, M.Tick, "threat.tick", true)
	else
		M.Stop()
	end
	if M.win then M.ApplyWindow() else SUI.WhenSafe(M.EnsureWindow) end
	M.UpdateVisibility()
	if key == "threat.estimate" and not M.cfg.estimate and M.estimated then M.OnTarget() end
	if M.win then M.Paint() end    -- effet immediat (couleurs, nombres, vue, lignes) sans attendre la minuterie
end

function M.OnLocale()
	M.ver = M.ver + 1
	if M.win then M.win.ttl = nil end
end

function M.OnAccent()
	M.ver = M.ver + 1
	if M.win then M.ApplyBack(M.win.f, true) end     -- le repeint du style remet le fond du panneau : on repose le choix de l'utilisateur
end

function M.EnsureWindow()
	if not M.on then return end
	M.BuildWindow()
	M.VisAdd()
	M.UpdateVisibility()
	M.Paint()
end

-- Demarre / arrete tout ce qui consomme du CPU : evenements et minuterie. Fenetre fermee (threat.show = false) = tout dort.
function M.Start()
	if M.running then return end
	M.running = true
	M.rosterDirty = true
	M.ReadGuid()
	SUI.On("CHAT_MSG_ADDON", M.OnAddon)
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnPull)
	SUI.On("ACTIONBAR_UPDATE_COOLDOWN", M.OnCooldown)
	SUI.On("SPELL_UPDATE_COOLDOWN", M.OnCooldown)
	SUI.On("SPELLS_CHANGED", M.OnBook)
	if SUI.Api.superwow then SUI.On("UNIT_CASTEVENT", M.OnCastEvent) end
	if SUI.Api.nampower then SUI.On("SPELL_GO_SELF", M.OnGoSelf) end
	M.ScanTaunts()
	M.task = SUI.Every(M.cfg.rate, M.Tick, "threat.tick", true)
end

function M.Stop()
	if not M.running then return end
	M.running = false
	SUI.Off("CHAT_MSG_ADDON", M.OnAddon)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnPull)
	SUI.Off("ACTIONBAR_UPDATE_COOLDOWN", M.OnCooldown)
	SUI.Off("SPELL_UPDATE_COOLDOWN", M.OnCooldown)
	SUI.Off("SPELLS_CHANGED", M.OnBook)
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Off("SPELL_GO_SELF", M.OnGoSelf)
	SUI.Cancel(M.task)
	SUI.Cancel(M.tauntTask)
	SUI.Cancel(M.fastTask)
	M.fastTask, M.fastUntil = nil, nil
	M.task, M.tauntTask = nil, nil
	M.Reset()
end

-- Le module tourne quand sa fenetre est ouverte (threat.show) OU qu'une fenetre ouverte du compteur affiche la vue menace (M.client).
function M.Wanted()
	return M.cfg.show or M.client
end

function M.SetClient(flag)
	flag = flag and true or false
	if M.client == flag then return end
	M.client = flag
	if not M.on then return end
	if M.Wanted() then
		M.Start()
	else
		M.Stop()
	end
end

function M.Enable()
	M.SyncVis(nil)
	M.on = true
	M.ReadConfig()
	-- l'estimation locale est alimentee par le compteur (Mod_Meter.Feed) : sans compteur, pas de donnees.
	if not (SUI.Meter and SUI.Meter.on) and not M.hintShown then
		M.hintShown = true
		SUI.Print(L("msg.threat.nometer"))
	end
	M.Prime()
	M.player = UnitName("player")
	M.ScanRoster()
	if not M.watching then
		M.watching = true
		C.Watch("threat.", M.OnKey)
		C.Watch("ui.locale", M.OnLocale)
		T.OnAccent(M.OnAccent)
	end
	if M.Wanted() then M.Start() end
	if not M.warned then
		M.warned = true
		local isl = getglobal("IsAddOnLoaded")
		if isl and isl("TWThreat") then SUI.Print(L("msg.threat.other", "TWThreat")) end
	end
	SUI.WhenSafe(M.EnsureWindow)
end

function M.Disable()
	M.on = false
	M.Stop()
	if M.win then M.win.f:Hide() end
	if SUI.Visibility then SUI.After(0.05, M.VisDrop, "threat.visdrop") end
end

-- /sui threat show|hide|toggle : rouvre ou ferme la fenetre (active le module si besoin pour "show").
function M.SetShown(want)
	if want and not M.on then C.Set("modules.threat", true) end
	if want and C.Get("threat.vis") ~= "always" then C.Set("threat.vis", "always") end
	if C.Get("threat.show") ~= want then C.Set("threat.show", want) end
	SUI.Print(L(want and "msg.threat.shown" or "msg.threat.hidden"))
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("threat", 47)

local function opt(key, typ, order, def, extra)
	local o = { key = "threat." .. key, type = typ, cat = "threat", label = "opt.threat." .. key, tip = "tip.threat." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function viewText(o, v) return L("choice.threat.view." .. v) end
local function modeText(o, v) return L("choice.threat.tankmode." .. v) end
local function bgText(o, v) return L("choice.threat.bg." .. v) end
local function colText(o, v) return L("choice.threat.color." .. v) end

local SW, SA, SD, SR = "mod.threat.sec.window", "mod.threat.sec.alerts", "mod.threat.sec.data", "mod.threat.sec.report"
local SLK = "mod.threat.sec.look"

-- Options communes du socle : visibilite (threat.vis / .fade), texture de barre, forme et police (threat.bartex / .shape / .font ;
-- la taille de police reste threat.fontsize, deja existante).
local function addCommon(list)
	local d = SUI.Visibility.Options("threat", { cat = "threat", order = 800, simple = true })
	for i = 1, getn(d) do
		d[i].section = SLK
		tinsert(list, d[i])
	end
	d = SUI.Look.Options("threat", { bar = true, shape = true, font = true, cat = "threat", order = 820 })
	for i = 1, getn(d) do
		if d[i].key ~= "threat.fontsize" then
			d[i].section = SLK
			tinsert(list, d[i])
		end
	end
	tinsert(list, opt("bg", "choice", 830, "style", { choices = M.BGS, choiceText = bgText, section = SLK }))
	tinsert(list, opt("color", "choice", 831, "style", { choices = M.COLORS, choiceText = colText, section = SLK }))
	return list
end

SUI.RegisterModule("threat", {
	default = false,
	cost = "light",
	options = addCommon({
		opt("show", "bool", 10, true, { simple = true, section = SW }),
		opt("rows", "number", 20, 10, { min = 3, max = M.MAXROWS, step = 1, simple = true, section = SW }),
		opt("width", "number", 30, 220, { min = M.MINW, max = M.MAXW, step = 10, simple = true, section = SW }),
		opt("height", "number", 35, 0, { min = 0, max = M.MAXH, step = 10, simple = true, section = SW }),
		opt("fontsize", "number", 36, 11, { min = 8, max = 18, step = 1, simple = true, section = SW }),
		opt("warn", "number", 40, 85, { min = 0, max = 100, step = 5, simple = true, section = SA }),
		opt("sound", "bool", 50, true, { simple = true, section = SA }),
		opt("flash", "bool", 60, true, { section = SA }),
		opt("classcolor", "bool", 70, true, { simple = true, section = SW }),
		opt("view", "choice", 80, "players", { choices = M.VIEWS, choiceText = viewText, section = SD }),
		opt("tankmode", "choice", 90, "auto", { choices = M.TANKMODES, choiceText = modeText, section = SD }),
		opt("estimate", "bool", 95, true, { simple = true, section = SD }),
		opt("showagro", "bool", 100, true, { section = SD }),
		opt("showtps", "bool", 110, true, { section = SD }),
		opt("shortnum", "bool", 120, true, { section = SD }),
		opt("pullmsg", "bool", 130, true, { section = SA }),
		opt("taunt", "bool", 132, true, { simple = true, section = SA }),
		opt("markholder", "bool", 105, true, { section = SD }),
		opt("hideooc", "bool", 140, false, { section = SW }),
		opt("rowh", "number", 150, 16, { min = 10, max = 30, step = 1, section = SW }),
		opt("spacing", "number", 160, 1, { min = 0, max = 4, step = 1, section = SW }),
		opt("alpha", "number", 170, 0.9, { min = 0.3, max = 1, step = 0.1, section = SW }),
		opt("rate", "number", 180, 1, { min = 0.5, max = 3, step = 0.5, section = SD }),
		opt("reportn", "number", 190, 5, { min = 3, max = 10, step = 1, section = SR }),
		opt("reportchan", "choice", 200, "self", { choices = M.REPORT, section = SR }),
	}),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Aucun module pfUI equivalent (le module "thirdparty" de pfUI ne fait qu'habiller TWThreat) : pas d'entree dans Migrate.MAP.
-- Mode Raid : version minimale (6 lignes, demande toutes les 2 s, pas de debit).
SUI.Config.AddPreset("raid", "*", { ["threat.rows"] = 6, ["threat.height"] = 0, ["threat.rate"] = 2, ["threat.showtps"] = false, ["threat.view"] = "players" })

SUI.RegisterCommand("threat", function(rest)
	local word, arg = rest or EMPTY, nil
	local sp = strfind(word, " ", 1, true)
	if sp then arg = strsub(word, sp + 1) word = strsub(word, 1, sp - 1) end
	if word == "show" then
		M.SetShown(true)
	elseif word == "hide" then
		M.SetShown(false)
	elseif word == "toggle" then
		M.SetShown(not (M.on and C.Get("threat.show")))
	elseif word == "reset" then
		M.Reset()
		SUI.Print(L("msg.threat.reset"))
	elseif word == "report" then
		local ok = (arg == nil)
		for i = 1, getn(M.REPORT) do if M.REPORT[i] == arg then ok = true end end
		if not ok then SUI.Print(L("msg.threat.badchan", arg)) return end
		M.Report(arg)
	elseif word == "mobs" or word == "players" then
		C.Set("threat.view", word)
	else
		SUI.Print(L("msg.threat.status", M.n, M.mobn, M.cfg.tankmode))
	end
end, "help.threat")
