-- ShikiUI Group : cadres de groupe (5), ennemis epingles (boss / arene) et MOTEUR partage des cadres de groupe (SUI.GroupEngine,
-- utilise aussi par le module "raid" : il ne sert que A L'EXECUTION, jamais au chargement, donc aucune dependance d'ordre de fichiers).
-- Cout declare : MEDIUM (groupe) ; le moteur est ecrit pour 40 cadres (voir Mod_Raid.lua : HEAVY).
--
-- PERFORMANCE (raid 40 d'abord)
--   * un evenement UNIT_* ne touche que SON cadre (table unite -> cadre), il pose un drapeau (dH vie, dP puissance, dA auras, dI infos) et
--     range le cadre dans une file circulaire PREALLOUEE ; une minuterie partagee (SUI.Every) vide la file avec un BUDGET par passage ;
--   * une seconde minuterie fait un tour de "lent" en rotation (portee, mort / hors ligne, aggro Banzai, soins entrants HealComm) sur
--     quelques cadres par passage ; sans UnitXP / SuperWoW la portee retombe sur les tranches 1.12 (CheckInteractDistance : <=28 yd) ;
--   * aucune table ni frame creee en combat : les cadres sont construits UNE fois (SUI.WhenSafe), tout le reste ecrit dans des champs
--     existants ; un texte n'est reecrit que s'il change ; les evenements inutiles (puissance, auras) ne sont pas ecoutes si l'option
--     correspondante est a zero ; un module desactive n'ecoute rien et n'a aucune minuterie.
-- SOURCES (relevees dans les addons installes, rien n'est copie) : evenements UNIT_HEALTH / UNIT_MAXHEALTH / UNIT_MANA... / UNIT_AURA /
--   UNIT_FLAGS / UNIT_NAME_UPDATE / RAID_ROSTER_UPDATE / PARTY_MEMBERS_CHANGED / PARTY_LEADER_CHANGED / PARTY_MEMBER_ENABLE / _DISABLE /
--   RAID_TARGET_UPDATE / SPELLS_CHANGED (pfUI api/unitframes.lua, Puppeteer core/EventHandler.lua) ; UnitDebuff(unit, i) -> texture,
--   applications, type (Puppeteer libs/PTUnit.lua, Rinse.lua) ; sorts de dissipation par classe (Puppeteer PuppeteerSettings.lua, Rinse.lua) ;
--   HealComm-1.0 (AceLibrary) getHeal(NOM) et Banzai-1.0 GetUnitAggroByUnitId(unite) (Puppeteer) ; GetRaidRosterInfo(i) -> nom, rang,
--   sous-groupe, niveau, classe, fichier-classe, zone, en ligne, mort ; GetRaidTargetIndex / SetRaidTargetIconTexture (Puppeteer, pfUI) ;
--   PlaySoundFile("Sound\\Interface\\RaidWarning.wav") (DebuffAlert) ; cadres Blizzard "PartyMemberFrame1..4" masques comme pfUI le fait.
-- NON VERIFIE EN JEU : TOUT (aucun de ces evenements / appels n'a tourne dans le client par ce projet) ; en particulier : les jetons
--   d'unite recus en raid (raidN et/ou player pour soi), PARTY_MEMBER_* (argument), le texte exact des types de debuff selon la langue
--   du client (comparaison anglaise : Magic / Curse / Poison / Disease), UnitIsVisible, GetRaidTargetIndex, l'usage d'un GUID SuperWoW
--   comme jeton d'unite pour les ennemis epingles (UnitHealth(guid), TargetUnit(guid)), le menu contextuel des cadres de raid.
-- AJOUTS (2e passe) : HoT / boucliers du joueur avec duree (hots), type de debuff a dissiper avec priorite et teinte du cadre
--   (dispelprio / dispelstyle), resurrection en cours (resinfo), soins entrants via Puppeteer (PTHealPredict) a defaut de HealComm.
--   Duree des HoT : sorts lances par le joueur uniquement (UNIT_CASTEVENT SuperWoW, sinon relevee par Mod_ClickHeal) ; sur le cadre du
--   joueur le temps restant vient de GetPlayerBuffTimeLeft. Durees de base ([memoire], non relevees dans un addon) : voir E.HOTS.
-- AJOUTS (3e passe) : MES soins en cours (barre de soin entrant sans addon) : SPELLCAST_START / STOP / FAILED / INTERRUPTED + nom du sort ->
--   montant estime (E.HEALS, rang du grimoire, GetSpellBonusHealing si le client l'offre) ; cible = lancement annonce par Mod_ClickHeal
--   (E.NoteCast), sinon GUID SuperWoW (UNIT_CASTEVENT), sinon cible amie du jeu, sinon soi-meme. Reglage <prefixe>incsrc : me / all (all : le plus
--   grand de HealComm / Puppeteer et de mon estimation, jamais la somme). Noms de sorts anglais + francais (a verifier en jeu).
-- Roles : aucune API 1.12 ne les donne ; ils viennent d'une liste manuelle (/sui group role) ou, en option, d'une devinette par classe.
-- "Aggro" = a defaut de Banzai : l'unite visee par la CIBLE du joueur (cible hostile -> cible de la cible), pas une vraie menace.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local floor, ceil = math.floor, math.ceil
local sfind, ssub, slen, sbyte, sformat = string.find, string.sub, string.len, string.byte, string.format

local E = {}
SUI.GroupEngine = E
local M = {}
SUI.Group = M

local FLUSH = 0.1             -- secondes entre deux vidages de la file (doublees en mode urgence)
local SLOW = 0.25             -- secondes entre deux tours "lents"
local MAXAUR = 16             -- 1.12 : 16 debuffs lisibles

-- ---------------------------------------------------------------- donnees du JEU (pas du style)
-- Couleurs des types de debuff (DebuffTypeColor de FrameXML ; memes valeurs dans Rinse) : donnees de jeu.
E.DEBUFF_COL = {
	Magic = { 0.20, 0.60, 1.00 },    -- style:ok donnee de jeu (type de debuff)
	Curse = { 0.60, 0.00, 1.00 },    -- style:ok donnee de jeu (type de debuff)
	Disease = { 0.60, 0.40, 0.00 },  -- style:ok donnee de jeu (type de debuff)
	Poison = { 0.00, 0.60, 0.00 },   -- style:ok donnee de jeu (type de debuff)
}
-- Couleurs de ressource (mana, rage, focus, energie) : donnees de jeu.
E.POWER_COL = {
	[0] = { 0.25, 0.45, 0.95 },      -- style:ok donnee de jeu (ressource)
	[1] = { 0.85, 0.22, 0.22 },      -- style:ok donnee de jeu (ressource)
	[2] = { 0.90, 0.50, 0.20 },      -- style:ok donnee de jeu (ressource)
	[3] = { 0.95, 0.85, 0.25 },      -- style:ok donnee de jeu (ressource)
}
-- Sorts de dissipation et types qu'ils retirent (Puppeteer PuppeteerSettings.lua, Rinse.lua). Noms anglais du client.
E.CURES = {
	["Cleanse"] = { Poison = true, Disease = true, Magic = true },
	["Purify"] = { Poison = true, Disease = true },
	["Cure Disease"] = { Disease = true },
	["Abolish Disease"] = { Disease = true },
	["Dispel Magic"] = { Magic = true },
	["Cure Poison"] = { Poison = true },
	["Abolish Poison"] = { Poison = true },
	["Remove Curse"] = { Curse = true },
	["Remove Lesser Curse"] = { Curse = true },
}
-- Ordre de base des types a dissiper (le type choisi par l'option dispelprio passe en premier).
E.PRIO_BASE = { "Magic", "Curse", "Poison", "Disease" }
E.PRIO_KEY = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease" }
-- HoT / boucliers suivis sur les allies : nom du sort -> duree de base en secondes ([memoire] : Rejuvenation 12, Regrowth 21, Renew 15,
-- Power Word: Shield 30, Abolish 8 ; seul le texte de duree en depend, l'icone vient de l'aura reelle).
E.HOTS = { ["Rejuvenation"] = 12, ["Regrowth"] = 21, ["Renew"] = 15, ["Power Word: Shield"] = 30, ["Abolish Poison"] = 8,
	["Abolish Disease"] = 8,
	-- cooldowns defensifs / utilitaires poses sur un allie (surtout le tank), meme suivi que les HoT [memoire] : Hand of Protection 10,
	-- Hand of Freedom 16, Hand of Sacrifice 30, Power Infusion 15, Innervate 20 (Lay on Hands ne laisse pas de buff : non suivi)
	["Hand of Protection"] = 10, ["Hand of Freedom"] = 16, ["Hand of Sacrifice"] = 30, ["Power Infusion"] = 15,
	["Innervate"] = 20 }
-- Resurrections par nom de sort (releve dans HealPredict.lua de Puppeteer).
E.RES = { ["Resurrection"] = true, ["Redemption"] = true, ["Ancestral Spirit"] = true, ["Rebirth"] = true, ["Revive Champion"] = true }
E.CLASS_RANK = { WARRIOR = 1, PALADIN = 2, DRUID = 3, PRIEST = 4, SHAMAN = 5, ROGUE = 6, HUNTER = 7, MAGE = 8, WARLOCK = 9 }
E.ROLE_RANK = { T = 1, H = 2, D = 3 }
-- Devinette par classe (option roleguess = class) : seulement les classes sans ambiguite RELATIVE ; les hybrides restent sans role.
E.GUESS = { PRIEST = "H", MAGE = "D", WARLOCK = "D", ROGUE = "D", HUNTER = "D" }
-- Barre de mana (option manabar) : classes a mana. Soigneurs = classes qui soignent ; lanceurs = toutes les classes a mana (le chasseur
-- seulement si l'option manahunter est cochee). Un role manuel H force la barre ; T / D la retirent en mode "soigneurs".
E.HEALER_CLASS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
E.CASTER_CLASS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true, MAGE = true, WARLOCK = true }
E.SOUND_ALERT = "Sound\\Interface\\RaidWarning.wav"   -- releve dans DebuffAlert.lua

local MAXBUF = 32            -- buffs lus pour reperer les HoT
local RESN = 6               -- resurrections suivies en meme temps
E.hotEnd = {}                -- sort -> { [nom] = fin (GetTime) } : tables creees une fois
for sp in pairs(E.HOTS) do E.hotEnd[sp] = {} end
-- Listes de suivi modifiables (reglages <prefixe>hotlist / hotoff) : E.HOTS_BASE garde la liste d'origine, E.hotOff les sorts retires.
E.HOTS_BASE = {}
for sp, d in pairs(E.HOTS) do E.HOTS_BASE[sp] = d end
E.hotOff = {}
E.hotTmp = {}                -- liste de travail reutilisee (aucune table creee au rafraichissement)
E.hotTex = {}                -- texture -> nom du sort (releve dans le grimoire)
E.res = {}                   -- resurrections en cours : { c = lanceur, t = cible, u = fin }
for i = 1, RESN do E.res[i] = { c = "", t = "", u = 0 } end
E.NUM = {}                   -- "0".."99" precalcules (aucune chaine creee au rafraichissement)
for i = 0, 99 do E.NUM[i] = tostring(i) end
E.idName = {}                -- cache identifiant de sort -> nom (SuperWoW SpellInfo)
E.idN = 0

local PU = { "player", "party1", "party2", "party3", "party4", "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local RU = {}
for i = 1, 40 do RU[i] = "raid" .. i end
E.RAID_UNITS = RU

-- Valeurs de repli quand un module n'a pas declare une cle (le moteur sert au groupe, au raid et aux ennemis epingles).
E.CFGKEYS = { solo = false, hideinraid = true, pets = false, maxgroup = 8, width = 100, height = 34, powerheight = 4, spacing = 2,
	groupgap = 6, sort = "none", orient = "vertical", perline = 5, hpcolor = "class", hptext = "percent", namelen = 10, range = true,
	rangeyd = 40, outalpha = 0.45, debuffs = 3, buffs = 0, iconsize = 12, dispelmode = "known", dispelonly = false, aggro = true,
	incoming = true, incsrc = "all", roletag = true, leader = true, marks = true, target = true, tooltip = true, alerts = true, alertsound = "none",
	alertlist = "", roles = "", roleguess = "none", budget = 10, slowstep = 10, hots = 0, hotall = false, dispelstyle = "both",
	dispelprio = "magic", resinfo = true, manabar = "all", manahunter = false, manatext = false, dispelbig = false, dispelsize = 20,
	dispelpos = "center", tankhots = 0, hotwarn = 0, lowhp = 0,
	-- 4e passe : pseudo place librement, icones de dissipation multiples, contour decoupe, effets de boss et aggro (SUI.GroupFx)
	nameanchor = "left", nameicons = "off", dispelbigmax = 1, dispelsmall = false, dispelsmallpos = "bottomleft", dispelsmallsize = 9,
	dispelthick = 2, fxframes = true, fxsize = 20, fxpos = "left", fxmax = 2, aggroframes = true,
	-- 5e passe (soigneur) : disposition libre, textes places, transparences distinctes, ligne de vue, couleurs, listes de HoT, densite auto
	fill = "tl", grpperline = 8, grouptitle = false, hppos = "right", manapos = "center", manacontent = "percent",
	deadalpha = 0, offalpha = 0, los = false, losalpha = 0.6, markpos = "topleft", marksize = 0, hotlist = "", hotoff = "",
	hpcustom = "", deadcolor = "", inccolor = "", autosize = false, scale20 = 0.9, scale25 = 0.8, scale40 = 0.7,
	-- 6e passe : role / chef place et dimensionne
	tagpos = "topright", tagsize = 9 }

-- Types de debuff : indice stable (les tables par cadre sont indexees 1..4), ordre de base = E.PRIO_BASE.
E.TYPES = { "Magic", "Curse", "Poison", "Disease" }
E.TIDX = { Magic = 1, Curse = 2, Poison = 3, Disease = 4 }
-- Place du pseudo : { point d'ancrage sur la barre de vie, justification, signe horizontal, decalage vertical }.
E.NAME_AT = {
	topleft = { "TOPLEFT", "LEFT", 1, -2 }, topcenter = { "TOP", "CENTER", 0, -2 }, topright = { "TOPRIGHT", "RIGHT", -1, -2 },
	left = { "LEFT", "LEFT", 1, 0 }, center = { "CENTER", "CENTER", 0, 0 }, right = { "RIGHT", "RIGHT", -1, 0 },
	bottomleft = { "BOTTOMLEFT", "LEFT", 1, 2 }, bottomcenter = { "BOTTOM", "CENTER", 0, 2 }, bottomright = { "BOTTOMRIGHT", "RIGHT", -1, 2 },
}
E.NUMM = {}                  -- "0m".."99m" precalcules (minuteurs longs des effets de boss)
for i = 0, 99 do E.NUMM[i] = i .. "m" end
E.SPLITMAX = 8               -- segments du contour decoupe (4 types : 7 au plus)
E.FXMAX = 3                  -- grosses icones d'effets de boss par cadre
E.BIGMAX = 3                 -- grosses icones de dissipation par cadre

E.alertHooks = {}         -- fonctions fn(instance, unite, fragment, texture) : point d'entree du futur DebuffAlert configurable
E.cure = {}               -- type de debuff -> true : ce que le joueur sait dissiper (grimoire)
E.instances = {}

-- ---------------------------------------------------------------- utilitaires
-- Remplit 'out' (tableau reutilise) avec les mots separes par ';' ; renvoie leur nombre. Aucune nouvelle table.
function E.ParseList(str, out)
	for i = getn(out), 1, -1 do out[i] = nil end
	local n = 0
	for w in string.gfind(str or "", "[^;]+") do
		local _, _, t = sfind(w, "^%s*(.-)%s*$")
		if t and t ~= "" then
			n = n + 1
			out[n] = t
		end
	end
	return n
end

-- "Nom:T;Nom2:H" -> map[nom] = "T" | "H" | "D" (table reutilisee)
function E.ParseRoles(str, map)
	for k in pairs(map) do map[k] = nil end
	for w in string.gfind(str or "", "[^;]+") do
		local _, _, nm, r = sfind(w, "^%s*(.-)%s*:%s*([THDthd])%s*$")
		if nm and nm ~= "" then map[nm] = string.upper(r) end
	end
end

-- Lit le grimoire : quels types de debuff le joueur peut-il dissiper ? (hors combat ou non : lecture seule, aucune table creee)
function E.ScanCures()
	for k in pairs(E.cure) do E.cure[k] = nil end
	for k in pairs(E.hotTex) do E.hotTex[k] = nil end
	local gn = getglobal("GetSpellName")
	if not gn then return end
	local gt = getglobal("GetSpellTexture")
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 1000 do
		local name = gn(i, book)
		if not name then break end
		local types = E.CURES[name]
		if types then
			for ty in pairs(types) do E.cure[ty] = true end
		end
		if gt and E.HOTS[name] and not E.hotOff[name] then
			local ok, tx = pcall(gt, i, book)
			if ok and tx then E.hotTex[tx] = name end
		end
	end
end

-- Reconstruit la liste des HoT / sorts suivis : liste d'origine + ajouts "Sort:duree;Sort2" (reglage hotlist, duree 15 s par defaut)
-- - sorts retires (reglage hotoff), reunis sur toutes les instances (groupe et raid partagent la meme table). Seuls les sorts du
-- GRIMOIRE du joueur donnent une texture a reconnaitre (E.ScanCures releve la texture). Tables reutilisees.
function E.RebuildHotList()
	for sp in pairs(E.HOTS) do
		if E.HOTS_BASE[sp] == nil then E.HOTS[sp] = nil end
	end
	for sp, d in pairs(E.HOTS_BASE) do E.HOTS[sp] = d end
	for sp in pairs(E.hotOff) do E.hotOff[sp] = nil end
	local tmp = E.hotTmp
	for i = 1, getn(E.instances) do
		local cfg = E.instances[i].cfg
		local n = E.ParseList(cfg.hotlist, tmp)
		for k = 1, n do
			local _, _, nm, d = sfind(tmp[k], "^(.-)%s*:%s*(%d+)$")
			if not nm then nm, d = tmp[k], 15 end
			if nm ~= "" then
				E.HOTS[nm] = tonumber(d) or 15
				if not E.hotEnd[nm] then E.hotEnd[nm] = {} end
			end
		end
		n = E.ParseList(cfg.hotoff, tmp)
		for k = 1, n do E.hotOff[tmp[k]] = true end
	end
	for k = getn(tmp), 1, -1 do tmp[k] = nil end
end

local function abbrev(n)
	if n >= 1000000 then return sformat("%.1fm", n / 1000000) end
	if n >= 10000 then return sformat("%.0fk", n / 1000) end
	if n >= 1000 then return sformat("%.1fk", n / 1000) end
	return tostring(floor(n))
end

-- Texte de vie. pctOnly : unites hostiles (en 1.12 leur vie est un pourcentage, maximum 100).
function E.HpText(mode, hp, mx, pctOnly)
	if mode == "none" then return "" end
	local pct = (mx > 0) and floor(hp / mx * 100 + 0.5) or 0
	if pctOnly or mx == 100 then return pct .. "%" end
	if mode == "value" then return abbrev(hp) end
	if mode == "percent" then return pct .. "%" end
	if mode == "deficit" then
		if mx - hp > 0 then return "-" .. abbrev(mx - hp) end
		return ""
	end
	if mode == "deficitpct" then
		if mx - hp > 0 then return "-" .. (100 - pct) .. "%" end
		return ""
	end
	return abbrev(hp) .. " | " .. pct .. "%"
end

-- Texte de ressource : "percent" (par defaut), "value" (valeur abregee) ou "deficit" (manque abrege, vide si plein).
function E.PowerText(mode, cur, mx)
	if mode == "value" then return abbrev(cur) end
	if mode == "deficit" then
		if mx - cur > 0 then return "-" .. abbrev(mx - cur) end
		return ""
	end
	local pc = floor(cur * 100 / mx + 0.5)
	if pc > 100 then pc = 100 end
	if pc < 0 then pc = 0 end
	return E.NUM[pc] or "100"
end

-- Couleur reglee (RRGGBB) -> slot { r, g, b } reutilise ; nil si pas de surcharge ("" = couleur du style).
function E.ReadHex(slot, hex)
	if type(hex) ~= "string" or hex == "" or not SUI.Style or not SUI.Style.ParseHex then return nil end
	local r, g, b = SUI.Style.ParseHex(hex)
	if not r then return nil end
	slot[1], slot[2], slot[3] = r, g, b
	return slot
end

-- Facteur de densite selon l'effectif visible (reglage autosize) : 1 jusqu'a 10, puis les trois paliers 20 / 25 / 40.
function E.AutoFactor(cfg, n)
	if not cfg.autosize or n <= 10 then return 1 end
	if n <= 20 then return cfg.scale20 end
	if n <= 25 then return cfg.scale25 end
	return cfg.scale40
end

-- Taille effective : tailles reglees (cfg.rw / rh / ri) x facteur de densite. Renvoie true si une dimension a change.
function E.ApplyAuto(g)
	local cfg = g.cfg
	local f = E.AutoFactor(cfg, g.nOrder)
	local w, h, i = cfg.rw, cfg.rh, cfg.ri
	if f ~= 1 then
		w, h, i = floor(w * f + 0.5), floor(h * f + 0.5), floor(i * f + 0.5)
		if w < 24 then w = 24 end
		if h < 10 then h = 10 end
		if i < 6 then i = 6 end
	end
	if w == cfg.width and h == cfg.height and i == cfg.iconsize then return false end
	cfg.width, cfg.height, cfg.iconsize = w, h, i
	return true
end

-- Coupe un nom a n octets sans couper un caractere UTF-8 en deux.
function E.Cut(name, n)
	if slen(name) <= n then return name end
	local b = sbyte(name, n + 1)
	while n > 0 and b and b >= 128 and b < 192 do
		n = n - 1
		b = sbyte(name, n + 1)
	end
	return ssub(name, 1, n)
end

-- ---------------------------------------------------------------- instance
-- def : { name, title, prefix, kind = "party" | "raid" | "pins", max, maxDeb, maxBuf, layoutKey, defX, defY, after = fn(g) }
function E.New(def)
	local g = { name = def.name, title = def.title or def.name, prefix = def.prefix, kind = def.kind, max = def.max, maxDeb = def.maxDeb,
		maxBuf = def.maxBuf, layoutKey = def.layoutKey, defX = def.defX, defY = def.defY, after = def.after, cfg = {}, frames = {},
		byUnit = {}, names = {}, order = {}, nOrder = 0, q = {}, qh = 1, qt = 1, qn = 0, rr = 1, built = false, active = false,
		rosterDirty = true, arrangeDirty = true, evOn = {}, alerts = {}, nAlerts = 0, roles = {}, pins = {}, nPins = 0,
		slowInterval = def.slowInterval or SLOW, tags = {}, sig = "", maxHot = def.maxHot or 0, dprio = {},
		lx = {}, ly = {}, tx = {}, ty = {}, tj = {}, ttl = {}, titles = {}, tShown = {}, look = def.prefix and ssub(def.prefix, 1, -2) or def.name,
		colSlot = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } } }
	g.cap = g.max + 2
	g.fnFlush = function() E.Flush(g) end
	g.fnSlow = function() E.Slow(g) end
	g.hUnit = function(ev, a1)
		local f = g.byUnit[a1]
		if not f or not f.vis then return end
		local k = E.EVFLAG[ev]
		if not k then return end
		f[k] = true
		if not f.inq then E.Push(g, f) end
	end
	g.hRoster = function() g.rosterDirty = true end
	g.hTarget = function() E.OnTarget(g) end
	g.hMarks = function() E.UpdateMarks(g) end
	g.hMember = function(ev, a1)
		if a1 and g.byUnit[a1] then g.hUnit(ev, a1) else g.rosterDirty = true end
	end
	g.fnHot = function() E.TickHots(g) end
	-- SUI.GroupFx previent quand les effets de boss ou l'aggro d'une unite changent : on ne redessine que ce cadre
	g.hFx = function(unit, what)
		local f = g.byUnit[unit]
		if not f or not f.vis then return end
		f.dF = true
		if not f.inq then E.Push(g, f) end
		if not g.tHot and g.active then E.SyncHots(g) end
	end
	g.hSpells = function()
		E.ScanCures()
		if E.wantInc then E.ScanHeals() end
		E.MarkAll(g, "dA")
		-- respec : le grimoire n'est complet qu'apres la rafale d'evenements ; second passage 2 s plus tard (le premier suffisait mal)
		if g.bookTask then SUI.Cancel(g.bookTask) end
		g.bookTask = SUI.After(2, function()
			g.bookTask = nil
			if not g.active then return end
			E.ScanCures()
			if E.wantInc then E.ScanHeals() end
			E.MarkAll(g, "dA")
		end, g.title .. ".book")
	end
	tinsert(E.instances, g)
	return g
end

E.EVFLAG = { UNIT_HEALTH = "dH", UNIT_MAXHEALTH = "dH", UNIT_MANA = "dP", UNIT_MAXMANA = "dP", UNIT_RAGE = "dP", UNIT_MAXRAGE = "dP",
	UNIT_ENERGY = "dP", UNIT_MAXENERGY = "dP", UNIT_FOCUS = "dP", UNIT_MAXFOCUS = "dP", UNIT_DISPLAYPOWER = "dP", UNIT_AURA = "dA",
	UNIT_NAME_UPDATE = "dI", UNIT_FLAGS = "dI", PARTY_MEMBER_ENABLE = "dH", PARTY_MEMBER_DISABLE = "dH" }

-- Lit les reglages "<prefixe>cle" (repli : E.CFGKEYS) et prepare les listes derivees (alertes, roles, textes de role).
-- Oublie ce qui a ete peint (couleurs, libelles) pour que le prochain dessin le refasse : changement de style / de langue / de reglage.
function E.ResetPaint(f)
	f.bigPaint = nil
	for k = 1, 4 do f.smI[k] = 0 end
	for k = 1, 3 do
		f.bigKT[k] = 0
		f.nicKey[k] = false
	end
	f.splitSig = nil
end

function E.ReadConfig(g)
	local cfg = g.cfg
	for k, d in pairs(E.CFGKEYS) do
		local key = g.prefix .. k
		if C.meta[key] ~= nil then cfg[k] = C.Get(key) else cfg[k] = d end
	end
	if g.after then g.after(g) end
	cfg.rw, cfg.rh, cfg.ri = cfg.width, cfg.height, cfg.iconsize        -- tailles reglees ; la densite automatique ajuste width / height / iconsize
	E.ApplyAuto(g)
	if cfg.grpperline < 1 then cfg.grpperline = 1 end
	g.colHp = E.ReadHex(g.colSlot[1], cfg.hpcustom)                    -- couleurs personnalisees (nil = couleur du style)
	g.colDead = E.ReadHex(g.colSlot[2], cfg.deadcolor)
	g.colInc = E.ReadHex(g.colSlot[3], cfg.inccolor)
	if cfg.hotlist ~= g.hotRaw or cfg.hotoff ~= g.hotOffRaw then
		local idle = ((g.hotRaw or "") == "" and (g.hotOffRaw or "") == "" and cfg.hotlist == "" and cfg.hotoff == "")
		g.hotRaw, g.hotOffRaw = cfg.hotlist, cfg.hotoff
		if not idle then
			E.RebuildHotList()
			E.ScanCures()
		end
	end
	cfg.hotany = (cfg.tankhots > cfg.hots) and cfg.tankhots or cfg.hots   -- icones de HoT voulues sur au moins un cadre
	if cfg.alertlist ~= g.alertRaw then
		g.alertRaw = cfg.alertlist
		g.nAlerts = E.ParseList(cfg.alertlist, g.alerts)
	end
	if cfg.roles ~= g.rolesRaw then
		g.rolesRaw = cfg.roles
		E.ParseRoles(cfg.roles, g.roles)
	end
	g.tags.T = L("msg." .. g.name .. ".role.t")
	g.tags.H = L("msg." .. g.name .. ".role.h")
	g.tags.D = ""
	g.tags.R = L("msg." .. g.name .. ".res")
	g.dtl = g.dtl or {}
	g.dtl.Magic = L("msg." .. g.name .. ".dt.magic")
	g.dtl.Curse = L("msg." .. g.name .. ".dt.curse")
	g.dtl.Poison = L("msg." .. g.name .. ".dt.poison")
	g.dtl.Disease = L("msg." .. g.name .. ".dt.disease")
	for s = 1, 8 do g.ttl[s] = L("msg." .. g.name .. ".gtitle", s) end
	for i = 1, getn(g.frames) do E.ResetPaint(g.frames[i]) end
	-- priorite des types a dissiper : le type choisi d'abord, puis l'ordre de base (table reutilisee)
	local first = E.PRIO_KEY[cfg.dispelprio] or "Magic"
	local rk = 1
	g.dprio[first] = rk
	for i = 1, getn(E.PRIO_BASE) do
		local ty = E.PRIO_BASE[i]
		if ty ~= first then
			rk = rk + 1
			g.dprio[ty] = rk
		end
	end
	-- ordre des types par priorite (indices E.TYPES) : sert aux listes de types presents sur un cadre
	g.dord = g.dord or { 1, 2, 3, 4 }
	for ty, rk2 in pairs(g.dprio) do g.dord[rk2] = E.TIDX[ty] end
	if cfg.dispelbigmax > E.BIGMAX then cfg.dispelbigmax = E.BIGMAX end
	if cfg.dispelbigmax < 1 then cfg.dispelbigmax = 1 end
	if cfg.fxmax > E.FXMAX then cfg.fxmax = E.FXMAX end
	if cfg.fxmax < 1 then cfg.fxmax = 1 end
	E.ResolveSources(g)
end

-- Banzai / HealComm / Puppeteer : optionnels (AceLibrary / PTHealPredict presents ?), relus ici puis toutes les 5 s tant qu'il en manque
-- (un addon charge apres ShikiUI est alors repris sans /reload).
function E.ResolveSources(g)
	local cfg = g.cfg
	g.HC, g.banzai, g.PT = nil, nil, nil
	local AL = getglobal("AceLibrary")
	if AL and AL.HasInstance then
		if (cfg.incoming or cfg.resinfo) and AL:HasInstance("HealComm-1.0") then g.HC = AL("HealComm-1.0") end
		if cfg.aggro and AL:HasInstance("Banzai-1.0") then g.banzai = AL("Banzai-1.0") end
	end
	if g.HC and type(g.HC.getHeal) ~= "function" then g.HC = nil end
	if g.banzai and type(g.banzai.GetUnitAggroByUnitId) ~= "function" then g.banzai = nil end
	local pt = getglobal("PTHealPredict")
	if cfg.incoming and not g.HC and SUI.Api.superwow and type(pt) == "table" and type(pt.getHeal) == "function" then g.PT = pt end
end

-- ---------------------------------------------------------------- file des cadres a mettre a jour (circulaire, preallouee)
function E.Push(g, f)
	if f.inq then return end
	f.inq = true
	g.q[g.qt] = f
	g.qt = g.qt + 1
	if g.qt > g.cap then g.qt = 1 end
	g.qn = g.qn + 1
end

local function pop(g)
	local f = g.q[g.qh]
	g.q[g.qh] = false
	g.qh = g.qh + 1
	if g.qh > g.cap then g.qh = 1 end
	g.qn = g.qn - 1
	f.inq = false
	return f
end

function E.MarkAll(g, flag)
	for i = 1, g.nOrder do
		local f = g.order[i]
		f[flag] = true
		E.Push(g, f)
	end
end

-- ---------------------------------------------------------------- infos d'un cadre (nom, classe, role, sous-groupe)
function E.Info(g, f)
	local unit, cfg = f.unit, g.cfg
	local name = UnitName(unit) or ""
	local _, class = UnitClass(unit)
	local oName, oClass, oSub, oRole = f.name, f.class, f.sub, f.role
	f.name, f.class = name, class
	f.isPlayer = UnitIsPlayer(unit) and true or false
	f.guid = nil
	if SUI.Api.superwow then
		local _, gd = UnitExists(unit)
		f.guid = gd
	end
	f.isSelf = (UnitIsUnit(unit, "player") and true) or false
	f.classRank = E.CLASS_RANK[class] or 99
	local role = g.roles[name]
	if not role and cfg.roleguess == "class" then role = E.GUESS[class] end
	f.role = role
	f.roleRank = E.ROLE_RANK[role or "D"]
	if g.kind == "raid" then
		local _, rank, sub = GetRaidRosterInfo(f.idx)
		f.rank = rank or 0
		f.sub = sub or 1
	elseif g.kind == "party" then
		f.sub = 1
		f.rank = (UnitIsPartyLeader(unit) and 2) or 0
	else
		f.sub = 1
		f.rank = 0
	end
	if name ~= oName or class ~= oClass or f.sub ~= oSub or role ~= oRole then g.arrangeDirty = true end
end

function E.UpdateName(g, f)
	local cfg = g.cfg
	local nm = E.Cut(f.name, cfg.namelen)
	if nm ~= f.nameShown then
		f.nameShown = nm
		f.nameText:SetText(nm)
		f.nicPlaced = false                       -- les petites icones a cote du pseudo suivent sa largeur
	end
	local tag = ""
	if cfg.roletag and f.role then tag = g.tags[f.role] or "" end
	if cfg.leader then
		if f.rank == 2 then tag = tag .. "*" elseif f.rank == 1 and g.kind == "raid" then tag = tag .. "+" end
	end
	if tag ~= f.tagShown then
		f.tagShown = tag
		f.tagText:SetText(tag)
		E.PlaceName(g, f)
	end
end

function E.UpdateMark(g, f)
	local mk = f.mark
	local idx = nil
	if g.cfg.marks and g.kind ~= "pins" then idx = GetRaidTargetIndex(f.unit) end
	if idx ~= f.markIdx then
		f.markIdx = idx
		E.PlaceName(g, f)
		if idx then
			local fn = getglobal("SetRaidTargetIconTexture")
			if fn then fn(mk, idx) end
			mk:Show()
		else
			mk:Hide()
		end
	end
end

function E.UpdateMarks(g)
	for i = 1, g.nOrder do E.UpdateMark(g, g.order[i]) end
end

-- ---------------------------------------------------------------- couleurs
function E.HpColor(g, f, ratio)
	local mode = g.cfg.hpcolor
	if f.state ~= 0 then
		local c = g.colDead or T.c.dim
		return c[1], c[2], c[3]
	end
	if g.kind == "pins" and not f.isPlayer then
		local c = T.c.bad
		return c[1], c[2], c[3]
	end
	if mode == "class" then
		local col = f.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[f.class]
		if col then return col.r, col.g, col.b end    -- style:ok couleur de classe (donnee de jeu)
	elseif mode == "health" then
		local a, b, t
		if ratio > 0.5 then
			a, b, t = T.c.good, T.c.warn, (1 - ratio) * 2
		else
			a, b, t = T.c.warn, T.c.bad, (0.5 - ratio) * 2
		end
		return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
	elseif mode == "custom" and g.colHp then
		local c = g.colHp
		return c[1], c[2], c[3]
	end
	local c = T.c.good
	return c[1], c[2], c[3]
end

-- Transparence : mort (deadalpha) et hors ligne (offalpha) si reglees (0 = comme hors portee), hors portee (outalpha), en portee mais
-- hors ligne de vue (losalpha, reglage los). Le premier cas vrai gagne.
function E.ApplyAlpha(g, f)
	local cfg = g.cfg
	local a = 1
	local st = f.state
	if st == 1 and cfg.deadalpha > 0 then
		a = cfg.deadalpha
	elseif st == 2 and cfg.offalpha > 0 then
		a = cfg.offalpha
	elseif st ~= 0 or f.inRange == false then
		a = cfg.outalpha
	elseif f.noSight then
		a = cfg.losalpha
	end
	if a ~= f.alphaNow then
		f.alphaNow = a
		f:SetAlpha(a)
	end
end

-- Surbrillance : alerte (rouge) > aggro (orange) > cible (accent). Se repeint aussi au changement de style (voir Build).
function E.PaintState(g, f)
	local cfg = g.cfg
	local r, gg, b, a
	local kind = 0
	if f.agFrame then
		kind = 4                                  -- aggro sur un non-tank (SUI.GroupFx.Aggro) : rouge, prioritaire
		r, gg, b, a = T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.45
	elseif f.alertTex then
		kind = 3
		r, gg, b, a = T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.35
	elseif f.aggro and cfg.aggro then
		kind = 2
		r, gg, b, a = T.c.warn[1], T.c.warn[2], T.c.warn[3], 0.30
	elseif f.isTarget and cfg.target then
		kind = 1
		r, gg, b = T.Accent()
		a = 0.22
	end
	f.kind = kind
	if kind == 0 then
		f.hl:Hide()
		if T.edge and T.edge.file then
			local c = T.c.border
			f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
		end
	else
		f.hl:SetVertexColor(r, gg, b, a)
		f.hl:Show()
		if T.edge and T.edge.file then f:SetBackdropBorderColor(r, gg, b, 1) end
	end
end

function E.PaintFixed(g)
	for i = 1, getn(g.frames) do
		local f = g.frames[i]
		local c = g.colInc or T.c.good
		f.heal:SetStatusBarColor(c[1], c[2], c[3], 0.45)
		f.hv = nil
		f.pty = nil
		local d = T.c.warn
		f.dispelTx:SetVertexColor(d[1], d[2], d[3], 1)
		f.dispelType = nil
		f.dispelStyle = nil
		f.bigPaint = nil
		f.lowShown = nil
		f.splitSig = nil                      -- couleurs relues au prochain dessin (changement de style)
		for k = 1, 4 do f.smI[k] = 0 end
		for k = 1, 3 do f.nicKey[k] = false end
		for k = 1, E.FXMAX do f.fxKey[k] = false end
		f.fxTintKey = false
		f.agPaint = false
	end
end

-- ---------------------------------------------------------------- mises a jour d'un cadre
function E.UpdateHealth(g, f)
	local unit, cfg = f.unit, g.cfg
	local hp, mx = UnitHealth(unit), UnitHealthMax(unit)
	local state = 0
	if UnitIsConnected(unit) then
		if UnitIsDeadOrGhost(unit) then state = 1 end
	else
		state = 2
	end
	local ratio = 0
	if state == 0 and mx > 0 then
		ratio = hp / mx
		if ratio > 1 then ratio = 1 end
	end
	if state ~= f.state then
		f.state = state
		f.dP = true
		E.ApplyAlpha(g, f)
	end
	if ratio ~= f.ratio then
		f.ratio = ratio
		f.hp:SetValue(ratio)
	end
	local r, gg, b = E.HpColor(g, f, ratio)
	if r ~= f.cr or gg ~= f.cg or b ~= f.cb then
		f.cr, f.cg, f.cb = r, gg, b
		f.hp:SetStatusBarColor(r, gg, b, 1)
	end
	local hpTxt, stTxt = "", ""
	local isRes = false
	if state == 1 then
		isRes = (cfg.resinfo and f.res) and true or false
		if isRes then
			stTxt = g.tags.R
		else
			stTxt = (UnitIsGhost(unit) and L("unit.ghost")) or L("unit.dead")
		end
	elseif state == 2 then
		stTxt = L("unit.offline")
	else
		if hp ~= f.lhp or mx ~= f.lmx or cfg.hptext ~= f.lmode then
			f.lhp, f.lmx, f.lmode = hp, mx, cfg.hptext
			f.hpStr = E.HpText(cfg.hptext, hp, mx, g.kind == "pins")
		end
		hpTxt = f.hpStr or ""
	end
	if hpTxt ~= f.hpShown then
		f.hpShown = hpTxt
		f.hpText:SetText(hpTxt)
	end
	local low = (state == 0 and cfg.lowhp > 0 and ratio * 100 < cfg.lowhp) and true or false
	if low ~= f.lowShown then
		f.lowShown = low
		local lc = low and T.c.bad or T.c.text
		f.hpText:SetTextColor(lc[1], lc[2], lc[3], lc[4] or 1)
	end
	if isRes ~= f.resShown then
		f.resShown = isRes
		local sc = isRes and T.c.good or T.c.warn
		f.statusText:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
	end
	if stTxt ~= f.stShown then
		f.stShown = stTxt
		f.statusText:SetText(stTxt)
	end
	local hv = 0
	local inc = f.inc or 0
	local im = f.incMine or 0
	if im > inc then inc = im end
	if inc > 0 and mx > 0 and state == 0 then
		hv = (hp + inc) / mx
		if hv > 1 then hv = 1 end
	end
	if hv ~= f.hv then
		f.hv = hv
		f.heal:SetValue(hv)
	end
end

-- La barre de mana de ce cadre est-elle voulue ? "all" : toutes les ressources (comportement d'origine) ; "none" : aucune ;
-- "healers" / "casters" : mana seulement (jamais rage / energie), selon la classe (et le role manuel). Aucune allocation.
function E.ManaWanted(g, f)
	local mode = g.cfg.manabar
	if mode == "all" then return true end
	if mode == "none" or not mode then return false end
	local role, class = f.role, f.class
	if role == "H" then return true end
	if mode == "healers" then
		if role == "T" or role == "D" then return false end
		return E.HEALER_CLASS[class] == true
	end
	if E.CASTER_CLASS[class] then return true end
	return (class == "HUNTER" and g.cfg.manahunter) and true or false
end

-- Hauteur de la barre de vie : l'espace de la barre de puissance est rendu quand elle est cachee.
function E.HpHeight(g, f)
	local cfg = g.cfg
	if cfg.powerheight > 0 and f.pwShown ~= false then return cfg.height - 3 - cfg.powerheight end
	return cfg.height - 2
end

function E.UpdatePower(g, f)
	local unit = f.unit
	local pw = f.pw
	local cfg = g.cfg
	local mx = 0
	local pty = 0
	local all = (cfg.manabar == "all")
	if cfg.powerheight > 0 and f.state == 0 and E.ManaWanted(g, f) then
		pty = UnitPowerType(unit)
		-- hors "all" : seule la mana compte (un druide en ours / felin n'a plus de mana lisible)
		if all or pty == 0 then mx = UnitManaMax(unit) end
	end
	if mx <= 0 then
		if f.pwShown ~= false then
			f.pwShown = false
			pw:Hide()
			f.pwText:Hide()
			f.pwTxt = nil
			E.Resize(g, f)
		end
		return
	end
	if not f.pwShown then
		f.pwShown = true
		pw:Show()
		E.Resize(g, f)
	end
	if pty ~= f.pty then
		f.pty = pty
		local col = E.POWER_COL[pty] or T.c.dim
		pw:SetStatusBarColor(col[1], col[2], col[3], 1)
	end
	local cur = UnitMana(unit)
	pw:SetValue(cur / mx)
	if cfg.manatext then
		local pt = f.pwTxt
		local key = (cfg.manacontent == "percent") and floor(cur * 100 / mx + 0.5) or (cfg.manacontent == "value" and cur or mx - cur)
		if f.pwKey ~= key or not pt then
			f.pwKey = key
			f.pwTxt = E.PowerText(cfg.manacontent, cur, mx)
			f.pwText:SetText(f.pwTxt)
		end
		f.pwText:Show()
	elseif f.pwTxt then
		f.pwTxt = nil
		f.pwKey = nil
		f.pwText:Hide()
	end
end

local function edgeColor(f, k, dt)
	local e = f.dEdge[k]
	local col = dt and E.DEBUFF_COL[dt]
	if col then
		e:SetVertexColor(col[1], col[2], col[3], 1)
	else
		local c = T.c.border
		e:SetVertexColor(c[1], c[2], c[3], 1)
	end
end

-- Grosse icone du debuff a dissiper (option dispelbig) : icone de l'aura prioritaire, bord colore du type, abreviation du type, et
-- bordure du cadre (sauf style "lisere"). dtype nil = rien a dissiper. Aucun objet cree : champs et textures existants.
function E.UpdateBigDispel(g, f, wantBorder, wantIcon, dtype, tex)
	local icon = (wantIcon and dtype and tex) and true or false
	local border = (wantBorder and dtype) and true or false
	local col = dtype and E.DEBUFF_COL[dtype]
	if not col then
		icon, border = false, false
	end
	if dtype ~= f.bigType then
		f.bigType = dtype
		f.bigPaint = nil
	end
	if (icon or border) and not f.bigPaint then
		f.bigPaint = true
		f.dispelEdge:SetVertexColor(col[1], col[2], col[3], 1)
		for k = 1, 4 do f.dispelBd[k]:SetVertexColor(col[1], col[2], col[3], 1) end
		local lb = g.dtl[dtype] or ""
		f.dispelLbl:SetText(lb)
	end
	if icon then
		if tex ~= f.bigTex then
			f.bigTex = tex
			f.dispelIcon:SetTexture(tex)
			f.dispelIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	end
	if icon ~= f.bigIcon then
		f.bigIcon = icon
		if icon then
			f.dispelEdge:Show()
			f.dispelIcon:Show()
			f.dispelLbl:Show()
		else
			f.dispelEdge:Hide()
			f.dispelIcon:Hide()
			f.dispelLbl:Hide()
		end
	end
	if border ~= f.bigBd then
		f.bigBd = border
		for k = 1, 4 do
			if border then f.dispelBd[k]:Show() else f.dispelBd[k]:Hide() end
		end
	end
end

-- ---------------------------------------------------------------- contour decoupe (dispelstyle = "split")
-- Decoupe le contour (epaisseur th) d'un cadre w x h en n parts EGALES : 1 type = 1 couleur, 2 types = 50 % / 50 %, 3 types = 3 x 33 %,
-- 4 types = 4 x 25 %. Parcours : haut (gauche -> droite), droite (haut -> bas), bas (droite -> gauche), gauche (bas -> haut). Remplit
-- out[1..m] = { k = part (1..n), x, y, w, h } (depuis le coin haut gauche) et renvoie m (n + 3 au plus). out doit deja contenir
-- E.SPLITMAX tables : aucune allocation. Fonction PURE : le cadre reel et l'apercu du menu s'en servent tous les deux.
function E.SplitLayout(w, h, th, n, out)
	if n < 1 or w <= 0 or h <= 0 then return 0 end
	if th * 2 > h then th = h / 2 end
	if th * 2 > w then th = w / 2 end
	local l1, l2, l3, l4 = w, h - th, w - th, h - 2 * th
	local total = l1 + l2 + l3 + l4
	local m = 0
	local o = 0
	for e = 1, 4 do
		local len = l4
		if e == 1 then len = l1 elseif e == 2 then len = l2 elseif e == 3 then len = l3 end
		for k = 1, n do
			local lo, hi = (k - 1) * total / n, k * total / n
			if lo < o then lo = o end
			if hi > o + len then hi = o + len end
			if hi - lo > 0.01 and m < E.SPLITMAX then
				m = m + 1
				local r = out[m]
				local t1 = hi - o
				r.k = k
				if e == 1 then
					r.x, r.y, r.w, r.h = lo - o, 0, hi - lo, th
				elseif e == 2 then
					r.x, r.y, r.w, r.h = w - th, th + (lo - o), th, hi - lo
				elseif e == 3 then
					r.x, r.y, r.w, r.h = (w - th) - t1, h - th, hi - lo, th
				else
					r.x, r.y, r.w, r.h = 0, (h - th) - t1, th, hi - lo
				end
			end
		end
		o = o + len
	end
	return m
end

-- Dessine le contour decoupe d'un cadre (on = style "split" voulu). Ne se repeint que si les types presents (ou la taille) changent.
function E.PaintSplit(g, f, on)
	local n = on and f.oN or 0
	local sig = n * 1000 + f.oI[1] + 5 * f.oI[2] + 25 * f.oI[3] + 125 * f.oI[4]
	if sig == f.splitSig then return end
	f.splitSig = sig
	local m = 0
	if n > 0 then
		m = E.SplitLayout(f:GetWidth(), f:GetHeight(), g.cfg.dispelthick, n, f.splitR)
		for i = 1, m do
			local r, tx = f.splitR[i], f.splitTx[i]
			local col = E.DEBUFF_COL[f.oT[r.k]]
			tx:SetVertexColor(col[1], col[2], col[3], 1)
			tx:ClearAllPoints()
			tx:SetPoint("TOPLEFT", f, "TOPLEFT", r.x, -r.y)
			tx:SetWidth(r.w)
			tx:SetHeight(r.h)
			tx:Show()
		end
	end
	for i = m + 1, f.splitN do f.splitTx[i]:Hide() end
	f.splitN = m
end

-- ---------------------------------------------------------------- grosses icones de dissipation (1 a 3, une par type)
-- Ancre les grosses icones : cnt = nombre affiche (sert au centrage). La 1re (f.dispelEdge...) est celle du type prioritaire.
function E.PlaceBig(g, f, cnt)
	local cfg = g.cfg
	local bsz = cfg.dispelsize
	local fh = f:GetHeight()
	if bsz > fh - 2 then bsz = fh - 2 end
	if bsz < 8 then bsz = 8 end
	local gap = bsz + 3
	local pos = cfg.dispelpos
	for k = 1, E.BIGMAX do
		local ed, ic, lb = f.bigE[k], f.bigI[k], f.bigL[k]
		ed:ClearAllPoints()
		if pos == "right" then
			ed:SetPoint("RIGHT", f, "RIGHT", -2 - (k - 1) * gap, 0)
		elseif pos == "left" then
			ed:SetPoint("LEFT", f, "LEFT", 4 + (k - 1) * gap, 0)
		else
			ed:SetPoint("CENTER", f, "CENTER", (k - (cnt + 1) / 2) * gap, 0)
		end
		ed:SetWidth(bsz + 2)
		ed:SetHeight(bsz + 2)
		ic:ClearAllPoints()
		ic:SetPoint("CENTER", ed, "CENTER", 0, 0)
		ic:SetWidth(bsz)
		ic:SetHeight(bsz)
		lb:ClearAllPoints()
		lb:SetPoint("BOTTOM", ic, "BOTTOM", 0, 0)
		lb:SetWidth(bsz + 8)
		lb:SetHeight(10)
	end
	f.bigPlaced = cnt
end

-- Grosses icones 2 et 3 (la 1re est geree par E.UpdateBigDispel) : type, texture et affichage ne changent que si besoin.
function E.UpdateBigMore(g, f)
	local cfg = g.cfg
	local cnt = 0
	if cfg.dispelbig then
		cnt = f.oN
		if cnt > cfg.dispelbigmax then cnt = cfg.dispelbigmax end
	end
	if cnt > 0 and cnt ~= f.bigPlaced then E.PlaceBig(g, f, cnt) end
	for k = 2, E.BIGMAX do
		if k <= cnt then
			local ti, tex = f.oI[k], f.oX[k]
			if f.bigKT[k] ~= ti then
				f.bigKT[k] = ti
				local col = E.DEBUFF_COL[f.oT[k]]
				f.bigE[k]:SetVertexColor(col[1], col[2], col[3], 1)
				f.bigL[k]:SetText(g.dtl[f.oT[k]] or "")
			end
			if tex ~= f.bigKX[k] then
				f.bigKX[k] = tex
				f.bigI[k]:SetTexture(tex)
				f.bigI[k]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			if not f.bigOn[k] then
				f.bigOn[k] = true
				f.bigE[k]:Show()
				f.bigI[k]:Show()
				f.bigL[k]:Show()
			end
		elseif f.bigOn[k] then
			f.bigOn[k] = false
			f.bigE[k]:Hide()
			f.bigI[k]:Hide()
			f.bigL[k]:Hide()
		end
	end
end

-- ---------------------------------------------------------------- petites icones de dissipation (en ligne, dans un coin)
function E.UpdateSmall(g, f)
	local n = g.cfg.dispelsmall and f.oN or 0
	for k = 1, 4 do
		if k <= n then
			local ti, tex = f.oI[k], f.oX[k]
			if f.smI[k] ~= ti then
				f.smI[k] = ti
				local col = E.DEBUFF_COL[f.oT[k]]
				f.smE[k]:SetVertexColor(col[1], col[2], col[3], 1)
			end
			if f.smX[k] ~= tex then
				f.smX[k] = tex
				f.smP[k]:SetTexture(tex)
				f.smP[k]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			if not f.smOn[k] then
				f.smOn[k] = true
				f.smE[k]:Show()
				f.smP[k]:Show()
			end
		elseif f.smOn[k] then
			f.smOn[k] = false
			f.smE[k]:Hide()
			f.smP[k]:Hide()
		end
	end
end

-- ---------------------------------------------------------------- pseudo place librement + petites icones sur la meme ligne
function E.PlaceName(g, f)
	local cfg = g.cfg
	local at = E.NAME_AT[cfg.nameanchor] or E.NAME_AT.left
	local dx = at[3] * 3
	if cfg.nameanchor == "topleft" and f.markIdx and cfg.markpos == "topleft" then dx = dx + E.MarkSize(cfg) + 2 end   -- sous le marqueur de raid
	local tp = cfg.tagpos
	if f.tagShown and f.tagShown ~= "" then
		if cfg.nameanchor == "topright" and tp == "topright" then dx = dx - 12 end    -- a gauche du role / chef
		if cfg.nameanchor == "topleft" and tp == "topleft" then dx = dx + 12 end      -- a droite du role / chef
		if cfg.nameanchor == "bottomright" and tp == "bottomright" then dx = dx - 12 end
		if cfg.nameanchor == "bottomleft" and tp == "bottomleft" then dx = dx + 12 end
	end
	if f.namePt == at[1] and f.nameDx == dx and f.nameDy == at[4] then return end
	f.namePt, f.nameDx, f.nameDy = at[1], dx, at[4]
	f.nameText:ClearAllPoints()
	f.nameText:SetPoint(at[1], f.hp, at[1], dx, at[4])
	f.nameText:SetJustifyH(at[2])
	f.nicPlaced = false
end

-- Taille du marqueur de raid : reglage marksize, 0 = taille des icones.
function E.MarkSize(cfg)
	if cfg.marksize > 0 then return cfg.marksize end
	return cfg.iconsize
end

-- Place du role / chef (texte) : quatre coins, taille reglable. "topright" = emplacement d'origine.
E.TAG_AT = { topright = { "TOPRIGHT", "RIGHT", -2, -2 }, topleft = { "TOPLEFT", "LEFT", 2, -2 },
	bottomright = { "BOTTOMRIGHT", "RIGHT", -2, 2 }, bottomleft = { "BOTTOMLEFT", "LEFT", 2, 2 } }
function E.PlaceTag(g, f)
	local at = E.TAG_AT[g.cfg.tagpos] or E.TAG_AT.topright
	f.tagText:ClearAllPoints()
	f.tagText:SetPoint(at[1], f, at[1], at[3], at[4])
	f.tagText:SetJustifyH(at[2])
	f.tagText:SetHeight(10)
	if SUI.Look then SUI.Look.ApplyText(f.tagText, g.look .. ".tag", g.cfg.tagsize, true) end
	f.namePt = nil
	E.PlaceName(g, f)
end

-- Place du marqueur de raid : coin haut gauche (par defaut), haut centre ou centre du cadre.
function E.PlaceMark(g, f)
	local cfg = g.cfg
	local sz = E.MarkSize(cfg)
	f.mark:ClearAllPoints()
	if cfg.markpos == "topcenter" then
		f.mark:SetPoint("TOP", f, "TOP", 0, -2)
	elseif cfg.markpos == "center" then
		f.mark:SetPoint("CENTER", f, "CENTER", 0, 0)
	else
		f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
	end
	f.mark:SetWidth(sz)
	f.mark:SetHeight(sz)
end

-- Texte de vie : place choisie (memes neuf places que le pseudo ; "right" = emplacement d'origine). Texte de ressource : gauche / centre / droite.
function E.PlaceHpText(g, f)
	local at = E.NAME_AT[g.cfg.hppos] or E.NAME_AT.right
	f.hpText:ClearAllPoints()
	f.hpText:SetPoint(at[1], f.hp, at[1], at[3] * 3, at[4])
	f.hpText:SetJustifyH(at[2])
end

E.PW_AT = { left = { "LEFT", "LEFT", 2 }, center = { "CENTER", "CENTER", 0 }, right = { "RIGHT", "RIGHT", -2 } }
function E.PlacePwText(g, f)
	local at = E.PW_AT[g.cfg.manapos] or E.PW_AT.center
	f.pwText:ClearAllPoints()
	f.pwText:SetPoint(at[1], f.pw, at[1], at[3], 0)
	f.pwText:SetJustifyH(at[2])
end

function E.PlaceNameIcons(g, f)
	f.nicPlaced = true
	local cfg = g.cfg
	local at = E.NAME_AT[cfg.nameanchor] or E.NAME_AT.left
	local sz = cfg.dispelsmallsize
	local sw = f.nameText:GetStringWidth() or 0
	local maxw = f.nameText:GetWidth() or 60
	if sw > maxw then sw = maxw end
	local just = at[2]
	for k = 1, f.nicN do
		local ic = f.nicI[k]
		local off = (k - 1) * (sz + 1)
		ic:ClearAllPoints()
		if just == "LEFT" then
			ic:SetPoint("LEFT", f.nameText, "LEFT", sw + 2 + off, 0)
		elseif just == "RIGHT" then
			ic:SetPoint("RIGHT", f.nameText, "RIGHT", -(sw + 2 + off), 0)
		else
			ic:SetPoint("LEFT", f.nameText, "CENTER", sw / 2 + 2 + off, 0)
		end
		ic:SetWidth(sz)
		ic:SetHeight(sz)
	end
end

local function setNameIcon(f, k, key, tex, tname)
	if f.nicKey[k] == key then return end
	f.nicKey[k] = key
	local ic = f.nicI[k]
	if tex then
		ic:SetTexture(tex)
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:SetVertexColor(1, 1, 1, 1)    -- style:ok teinte neutre : icone de sort non teintee
	else
		local col = E.DEBUFF_COL[tname]
		ic:SetTexture(T.tex.white)
		ic:SetTexCoord(0, 1, 0, 1)
		ic:SetVertexColor(col[1], col[2], col[3], 1)
	end
end

-- Petites icones a cote du pseudo (option nameicons) : types de dissipation (carres colores) puis effets de boss (leur icone), 3 au plus.
function E.UpdateNameIcons(g, f)
	local mode = g.cfg.nameicons
	local k = 0
	if mode ~= "off" then
		if mode == "dispel" or mode == "both" then
			for i = 1, f.oN do
				if k < 3 then
					k = k + 1
					setNameIcon(f, k, -f.oI[i], nil, f.oT[i])
				end
			end
		end
		if mode == "fx" or mode == "both" then
			for i = 1, f.fxN do
				if k < 3 then
					k = k + 1
					setNameIcon(f, k, f.fxTex[i], f.fxTex[i], nil)
				end
			end
		end
	end
	if k ~= f.nicN then
		for i = k + 1, f.nicN do f.nicI[i]:Hide() end
		for i = f.nicN + 1, k do f.nicI[i]:Show() end
		f.nicN = k
		f.nicPlaced = false
	end
	if k > 0 and not f.nicPlaced then E.PlaceNameIcons(g, f) end
end

-- ---------------------------------------------------------------- effets de boss (SUI.GroupFx.Effects) : grosses icones + minuteur + teinte
function E.PlaceFx(g, f, cnt)
	local cfg = g.cfg
	local sz = cfg.fxsize
	local fh = f:GetHeight()
	if sz > fh - 2 then sz = fh - 2 end
	if sz < 10 then sz = 10 end
	local gap = sz + 3
	local pos = cfg.fxpos
	for k = 1, E.FXMAX do
		local ed, ic, tt = f.fxE[k], f.fxI[k], f.fxT[k]
		ed:ClearAllPoints()
		if pos == "right" then
			ed:SetPoint("RIGHT", f, "RIGHT", -2 - (k - 1) * gap, 0)
		elseif pos == "center" then
			ed:SetPoint("CENTER", f, "CENTER", (k - (cnt + 1) / 2) * gap, 0)
		else
			ed:SetPoint("LEFT", f, "LEFT", 2 + (k - 1) * gap, 0)
		end
		ed:SetWidth(sz + 2)
		ed:SetHeight(sz + 2)
		ic:ClearAllPoints()
		ic:SetPoint("CENTER", ed, "CENTER", 0, 0)
		ic:SetWidth(sz)
		ic:SetHeight(sz)
		tt:ClearAllPoints()
		tt:SetPoint("CENTER", ic, "CENTER", 0, 0)
		tt:SetWidth(sz + 8)
		tt:SetHeight(12)
	end
	f.fxPlaced = cnt
end

-- Redessine les effets de boss ET l'aggro d'un cadre. Tout est garde par une comparaison : relancer ne coute presque rien (le minuteur
-- de TickHots s'en sert). Pose f.dB si l'etat rouge du cadre change (le fond est repeint par PaintState).
function E.UpdateFx(g, f)
	local cfg = g.cfg
	local G = SUI.GroupFx
	local list, n = nil, 0
	local wI, wT, wM = false, false, false
	if G and cfg.fxframes and g.kind ~= "pins" and f.unit then
		list, n = G.Effects(f.unit)
		if n > 0 then
			if n > cfg.fxmax then n = cfg.fxmax end
			wI, wT, wM = G.Want("icon"), G.Want("tint"), G.Want("timer")
		end
	end
	if not (wI or wT) then n = 0 end
	local nIcon = wI and n or 0
	if nIcon > 0 and nIcon ~= f.fxPlaced then E.PlaceFx(g, f, nIcon) end
	for k = 1, E.FXMAX do
		if k <= nIcon then
			local r = list[k]
			if f.fxTex[k] ~= r.texture then
				f.fxTex[k] = r.texture
				f.fxI[k]:SetTexture(r.texture)
				f.fxI[k]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			if f.fxKey[k] ~= r.key then
				f.fxKey[k] = r.key
				local cr, cg, cb = G.Color(r)
				f.fxE[k]:SetVertexColor(cr, cg, cb, 1)
			end
			if not f.fxOn[k] then
				f.fxOn[k] = true
				f.fxE[k]:Show()
				f.fxI[k]:Show()
				f.fxT[k]:Show()
			end
			local s = -1
			if wM and r.left > 0 then s = ceil(r.left) end
			if s ~= f.fxSec[k] then
				f.fxSec[k] = s
				local txt = ""
				if s >= 100 then
					local mn = floor(s / 60)
					if mn > 99 then mn = 99 end
					txt = E.NUMM[mn]
				elseif s >= 0 then
					txt = E.NUM[s]
				end
				f.fxT[k]:SetText(txt)
				local warn = (s >= 0 and s <= 3)
				if warn ~= f.fxWarn[k] then
					f.fxWarn[k] = warn
					local wc = warn and T.c.bad or T.c.text
					f.fxT[k]:SetTextColor(wc[1], wc[2], wc[3], wc[4] or 1)
				end
			end
		elseif f.fxOn[k] then
			f.fxOn[k] = false
			f.fxSec[k] = -2
			f.fxE[k]:Hide()
			f.fxI[k]:Hide()
			f.fxT[k]:Hide()
		end
	end
	f.fxN = nIcon
	f.fxTick = (wM and nIcon > 0) and true or false
	if wT and n > 0 then
		local r = list[1]
		if f.fxTintKey ~= r.key then
			f.fxTintKey = r.key
			local cr, cg, cb = G.Color(r)
			f.fxHl:SetVertexColor(cr, cg, cb, 0.30)
		end
		if not f.fxTintOn then
			f.fxTintOn = true
			f.fxHl:Show()
		end
	elseif f.fxTintOn then
		f.fxTintOn = false
		f.fxTintKey = false
		f.fxHl:Hide()
	end
	E.UpdateAggroFx(g, f)
	E.UpdateNameIcons(g, f)
end

-- Aggro de SUI.GroupFx : cadre rouge + icone "!" si un non-tank a l'aggro (alerte), fine barre discrete si c'est un tank (option aggrotank).
function E.UpdateAggroFx(g, f)
	local cfg = g.cfg
	local G = SUI.GroupFx
	local st = "none"
	if G and cfg.aggroframes and g.kind ~= "pins" and f.unit then st = G.Aggro(f.unit) end
	local off = (st == "offrole")
	local wFrame = (off and G.Want("aggroframe")) and true or false
	local wIcon = (off and G.Want("aggroicon")) and true or false
	local wTank = (st == "tank" and G.Want("aggrotank")) and true or false
	if wFrame ~= f.agFrame then
		f.agFrame = wFrame
		f.dB = true
	end
	if (wIcon or wTank) and not f.agPaint then
		f.agPaint = true
		local bc = T.c.bad
		f.agIc:SetVertexColor(bc[1], bc[2], bc[3], 1)
		local ar, ag2, ab = T.Accent()
		f.agBar:SetVertexColor(ar, ag2, ab, 0.8)
	end
	if wIcon ~= f.agIcOn then
		f.agIcOn = wIcon
		if wIcon then
			f.agIc:Show()
			f.agTx:Show()
		else
			f.agIc:Hide()
			f.agTx:Hide()
		end
	end
	if wTank ~= f.agBarOn then
		f.agBarOn = wTank
		if wTank then f.agBar:Show() else f.agBar:Hide() end
	end
end

-- Debuffs (cure / alertes / icones) puis buffs. Aucune table : seulement des champs existants.
function E.UpdateAuras(g, f)
	local cfg = g.cfg
	local unit = f.unit
	local wantD, wantB = cfg.debuffs, cfg.buffs
	local mode = cfg.dispelmode
	local nd = 0
	local dtype, alertTex, alertFrag = nil, nil, nil
	local bestTex = nil
	local useAlerts = cfg.alerts and g.nAlerts > 0
	local tp, tx = f.tp, f.tx                 -- types presents (1..4 = E.TYPES) et texture du 1er debuff de chaque type
	for k = 1, 4 do tp[k] = false end
	if wantD > 0 or mode ~= "off" or useAlerts then
		for i = 1, MAXAUR do
			local tex, count, dt = UnitDebuff(unit, i)
			if not tex then break end
			local cureOk = false
			if dt and dt ~= "" then
				if mode == "all" then cureOk = true elseif mode == "known" then cureOk = E.cure[dt] and true or false end
				if cureOk then
					local ti = E.TIDX[dt]
					if ti and not tp[ti] then
						tp[ti] = true
						tx[ti] = tex
					end
				end
			end
			if useAlerts and not alertTex then
				for k = 1, g.nAlerts do
					if sfind(tex, g.alerts[k], 1, true) then
						alertTex, alertFrag = tex, g.alerts[k]
						break
					end
				end
			end
			if nd < wantD and nd < g.maxDeb and (cureOk or not cfg.dispelonly) then
				nd = nd + 1
				if f.dTex[nd] ~= tex then
					f.dTex[nd] = tex
					f.dIcon[nd]:SetTexture(tex)
					f.dIcon[nd]:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- recadrage repose apres la texture
				end
				if f.dType[nd] ~= (dt or false) then
					f.dType[nd] = dt or false
					edgeColor(f, nd, dt)
				end
			end
		end
	end
	if nd ~= f.dN then
		local lo, hi = nd + 1, f.dN
		if f.dN < nd then lo, hi = f.dN + 1, nd end
		for k = lo, hi do
			if k <= nd then
				f.dIcon[k]:Show()
				f.dEdge[k]:Show()
			else
				f.dIcon[k]:Hide()
				f.dEdge[k]:Hide()
			end
		end
		f.dN = nd
	end
	-- types presents, du plus prioritaire au moins prioritaire (f.oI = indice de type, f.oT = nom, f.oX = texture)
	local no = 0
	for r = 1, 4 do
		local ti = g.dord[r]
		if tp[ti] then
			no = no + 1
			f.oI[no] = ti
			f.oT[no] = E.TYPES[ti]
			f.oX[no] = tx[ti]
		end
	end
	for k = no + 1, 4 do
		f.oI[k] = 0
		f.oT[k] = false
		f.oX[k] = false
	end
	f.oN = no
	if no > 0 then
		dtype = f.oT[1]
		bestTex = f.oX[1]
	end
	-- types de debuff a dissiper : lisere colore a gauche et/ou voile (le contour decoupe est gere a part, voir E.PaintSplit)
	local dstyle = cfg.dispelstyle
	if dtype ~= f.dispelType or dstyle ~= f.dispelStyle then
		f.dispelType = dtype
		f.dispelStyle = dstyle
		if dtype then
			local col = E.DEBUFF_COL[dtype]
			if col then
				f.dispelTx:SetVertexColor(col[1], col[2], col[3], 1)
				f.dispelHl:SetVertexColor(col[1], col[2], col[3], 0.32)
			end
			if dstyle == "stripe" or dstyle == "both" then f.dispelTx:Show() else f.dispelTx:Hide() end
			if dstyle == "frame" or dstyle == "both" then f.dispelHl:Show() else f.dispelHl:Hide() end
		else
			f.dispelTx:Hide()
			f.dispelHl:Hide()
		end
	end
	E.UpdateBigDispel(g, f, cfg.dispelbig and (dstyle == "frame" or dstyle == "both") and true or false, cfg.dispelbig, dtype, bestTex)
	E.UpdateBigMore(g, f)
	E.PaintSplit(g, f, dstyle == "split")
	E.UpdateSmall(g, f)
	E.UpdateNameIcons(g, f)
	-- alerte
	if alertTex ~= f.alertTex then
		local isNew = (alertTex ~= nil and f.alertTex == nil)
		f.alertTex = alertTex
		if alertTex then
			f.alertIcon:SetTexture(alertTex)
			f.alertIcon:Show()
		else
			f.alertIcon:Hide()
		end
		f.dB = true
		if isNew then E.FireAlert(g, f, alertFrag, alertTex) end
	end
	-- buffs
	local nb = 0
	if wantB > 0 then
		for i = 1, wantB do
			if nb >= g.maxBuf then break end
			local tex = UnitBuff(unit, i)
			if not tex then break end
			nb = nb + 1
			if f.bTex[nb] ~= tex then
				f.bTex[nb] = tex
				f.bIcon[nb]:SetTexture(tex)
				f.bIcon[nb]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
		end
	end
	if nb ~= f.bN then
		local lo, hi = nb + 1, f.bN
		if f.bN < nb then lo, hi = f.bN + 1, nb end
		for k = lo, hi do
			if k <= nb then f.bIcon[k]:Show() else f.bIcon[k]:Hide() end
		end
		f.bN = nb
	end
	E.UpdateHots(g, f)
end

-- ---------------------------------------------------------------- HoT / boucliers du joueur (icone + duree)
-- Temps restant d'un buff du JOUEUR (API 1.12 GetPlayerBuff*), nil si indisponible.
function E.PlayerLeft(tex)
	local gb, gx, gl = getglobal("GetPlayerBuff"), getglobal("GetPlayerBuffTexture"), getglobal("GetPlayerBuffTimeLeft")
	if type(gb) ~= "function" or type(gx) ~= "function" or type(gl) ~= "function" then return nil end
	for i = 0, 31 do
		local idx = gb(i, "HELPFUL")
		if not idx or idx < 0 then break end
		if gx(idx) == tex then return gl(idx) end
	end
	return nil
end

-- Un sort suivi vient d'etre lance par le joueur sur 'name' : memorise sa fin et redessine le cadre (aucune table creee en regime).
function E.NoteHot(name, spell)
	local d = E.HOTS[spell]
	local rec = E.hotEnd[spell]
	if not d or not rec or not name or name == "" then return end
	rec[name] = GetTime() + d
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.cfg.hotany > 0 then
			local f = g.names[name]
			if f then
				f.dA = true
				E.Push(g, f)
			end
		end
	end
end

-- Pose / retire les icones de HoT d'un cadre (jusqu'a cfg.hots, plafonne a g.maxHot).
function E.UpdateHots(g, f)
	local cfg = g.cfg
	local want = cfg.hots
	local isTank = (f.role == "T") and true or false
	if isTank and cfg.tankhots > want then want = cfg.tankhots end
	if want > g.maxHot then want = g.maxHot end
	local nh = 0
	if want > 0 then
		local unit, name = f.unit, f.name
		local now = GetTime()
		for i = 1, MAXBUF do
			local tex = UnitBuff(unit, i)
			if not tex then break end
			local sp = E.hotTex[tex]
			if sp then
				local ex = E.hotEnd[sp][name]
				if ex and ex <= now then ex = nil end
				if ex and f.isSelf then
					local left = E.PlayerLeft(tex)
					if left and left > 0 then ex = now + left end
				end
				if ex or cfg.hotall or isTank then
					nh = nh + 1
					if f.hTex[nh] ~= tex then
						f.hTex[nh] = tex
						f.hIcon[nh]:SetTexture(tex)
						f.hIcon[nh]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end
					f.hExp[nh] = ex or false
					f.hSec[nh] = nil
					if nh >= want then break end
				end
			end
		end
	end
	if nh ~= f.hN then
		local lo, hi = nh + 1, f.hN
		if f.hN < nh then lo, hi = f.hN + 1, nh end
		for k = lo, hi do
			if k <= nh then
				f.hIcon[k]:Show()
				f.hTime[k]:Show()
			else
				f.hIcon[k]:Hide()
				f.hTime[k]:Hide()
				f.hTime[k]:SetText("")
				f.hSec[k] = nil
				f.hWarn[k] = nil
			end
		end
		f.hN = nh
	end
	E.TickFrameHots(g, f, GetTime())
end

-- Texte de duree de chaque icone (reecrit seulement quand la seconde change) ; une icone expiree relance l'analyse du cadre.
function E.TickFrameHots(g, f, now)
	for k = 1, f.hN do
		local ex = f.hExp[k]
		local s = -1
		if ex then
			s = ceil(ex - now)
			if s <= 0 then
				f.dA = true
				E.Push(g, f)
				s = -1
			end
		end
		local warn = (s >= 0 and s <= g.cfg.hotwarn) and true or false
		if warn ~= f.hWarn[k] then
			f.hWarn[k] = warn
			local wc = warn and T.c.bad or T.c.text
			f.hTime[k]:SetTextColor(wc[1], wc[2], wc[3], wc[4] or 1)
		end
		if s ~= f.hSec[k] then
			f.hSec[k] = s
			local txt = ""
			if s >= 100 then
				txt = floor(s / 60) .. "m"
			elseif s >= 0 then
				txt = E.NUM[s]
			end
			f.hTime[k]:SetText(txt)
		end
	end
end

function E.TickHots(g)
	if not g.active or not g.built then return end
	local now = GetTime()
	for i = 1, g.nOrder do
		local f = g.order[i]
		if f.hN > 0 then E.TickFrameHots(g, f, now) end
		if f.fxTick then          -- minuteur des effets de boss
			E.UpdateFx(g, f)
			if f.dB then E.Push(g, f) end
		end
	end
end

-- Minuterie des durees : seulement si des HoT sont demandes.
function E.SyncHots(g)
	local G = SUI.GroupFx
	local need = g.active and ((g.maxHot > 0 and g.cfg.hotany > 0) or (g.kind ~= "pins" and g.cfg.fxframes and G and G.on)) and true or false
	if need and not g.tHot then
		g.tHot = SUI.Every(0.5, g.fnHot, g.title .. ".hot", true)
	elseif not need and g.tHot then
		SUI.Cancel(g.tHot)
		g.tHot = nil
	end
end

-- ---------------------------------------------------------------- resurrection en cours (SuperWoW : UNIT_CASTEVENT ; sinon HealComm)
local function spellName(id)
	if not id then return nil end
	local nm = E.idName[id]
	if nm ~= nil then return nm or nil end
	local si = getglobal("SpellInfo")
	if type(si) ~= "function" then return nil end
	local ok, n = pcall(si, id)
	nm = (ok and type(n) == "string") and n or false
	if E.idN < 400 then
		E.idN = E.idN + 1
		E.idName[id] = nm
	end
	return nm or nil
end

-- true si quelqu'un est en train de ressusciter le cadre f.
function E.IsResurrecting(g, f)
	local now = GetTime()
	local gd = f.guid
	if gd then
		for i = 1, RESN do
			local s = E.res[i]
			if s.u > now and s.t == gd then return true end
		end
		local pt = getglobal("PTHealPredict")
		if type(pt) == "table" and type(pt.IsBeingResurrected) == "function" then
			local ok, v = pcall(pt.IsBeingResurrected, gd)
			if ok and v then return true end
		end
	end
	if g.HC and type(g.HC.UnitisResurrecting) == "function" then
		local ok, v = pcall(g.HC.UnitisResurrecting, g.HC, f.name)
		if ok and v then return true end
	end
	return false
end

-- Evaluation immediate des cadres morts d'une cible de resurrection.
local function refreshRes(guid)
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built then
			for k = 1, g.nOrder do
				local f = g.order[k]
				if f.guid == guid and f.state == 1 then
					f.res = E.IsResurrecting(g, f)
					f.dH = true
					E.Push(g, f)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- mes soins en cours (barre de soin entrant : ma propre incantation)
-- Soin direct moyen par rang (rang 1 d'abord), SANS bonus. Estimation : talents (Soins ameliores, Soins spirituels...) et critiques ne sont
-- pas pris en compte ; le bonus de soins vient de GetSpellBonusHealing quand le client l'offre, ponderee par le temps d'incantation / 3.5 s.
-- Valeurs relevees de memoire (non verifiees en jeu). Les HoT et les soins instantanes n'ont pas de barre d'incantation : ils n'y sont pas.
E.HEALS = {
	["Lesser Heal"] = { 51, 78, 146 },
	["Heal"] = { 330, 476, 624, 781 },
	["Greater Heal"] = { 956, 1219, 1523, 1902, 2194 },
	["Flash Heal"] = { 215, 286, 360, 439, 567, 704, 885 },
	["Holy Light"] = { 46, 88, 181, 345, 538, 758, 1022, 1343, 1680 },
	["Flash of Light"] = { 67, 113, 162, 218, 294, 369 },
	["Healing Touch"] = { 44, 100, 219, 404, 634, 818, 1028, 1313, 1656, 2060, 2472 },
	["Regrowth"] = { 100, 176, 257, 339, 431, 543, 685, 859, 1061 },
	["Healing Wave"] = { 39, 71, 142, 292, 408, 579, 797, 1092, 1464, 1735 },
	["Lesser Healing Wave"] = { 174, 264, 359, 486, 668, 880 },
	["Chain Heal"] = { 357, 449, 607 },
}
-- Noms francais (octets UTF-8 ecrits en decimal : la source reste ASCII). Non verifie en jeu.
E.HEALALIAS = {
	["Soins inf\195\169rieurs"] = "Lesser Heal",
	["Soins"] = "Heal",
	["Soins sup\195\169rieurs"] = "Greater Heal",
	["Soins rapides"] = "Flash Heal",
	["Lumi\195\168re sacr\195\169e"] = "Holy Light",
	["\195\137clair lumineux"] = "Flash of Light",
	["Toucher gu\195\169risseur"] = "Healing Touch",
	["R\195\169tablissement"] = "Regrowth",
	["Vague de soins"] = "Healing Wave",
	["Vague de soins inf\195\169rieurs"] = "Lesser Healing Wave",
	["Salve de gu\195\169rison"] = "Chain Heal",
}
E.bookRank = {}              -- sort de E.HEALS -> plus haut rang connu
E.mine = { name = nil, amount = 0, at = 0, endAt = 0, src = nil }   -- ma incantation de soin en cours : cible (nom) et montant estime
E.pend = { spell = nil, rank = nil, unit = nil, at = 0 }            -- dernier lancement annonce par ShikiUI (clic sur un cadre)
E.others = {}                 -- soins des AUTRES soigneurs (SuperWoW) : [guid lanceur] = { t = nom cible, amt, endAt }
E.INC_EV = { "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED" }

-- Nom de E.HEALS correspondant a un nom de sort du client (anglais ou francais), ou nil.
function E.HealKey(name)
	if not name then return nil end
	if E.HEALS[name] then return name end
	return E.HEALALIAS[name]
end

-- Plus haut rang connu de chaque soin de la liste (relu quand le grimoire change).
function E.ScanHeals()
	local br = E.bookRank
	for k in pairs(br) do br[k] = nil end
	local gn = getglobal("GetSpellName")
	if type(gn) ~= "function" then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 800 do
		local name, rank = gn(i, book)
		if not name then break end
		local key = E.HealKey(name)
		if key then
			local _, _, n = sfind(rank or "", "(%d+)")
			n = tonumber(n) or 1
			if n > (br[key] or 0) then br[key] = n end
		end
	end
end

-- Montant estime d'un soin : rang demande (sinon le plus haut connu) + bonus de soins ponderee par le temps d'incantation (ms).
function E.HealAmount(key, rank, castMs)
	local t = E.HEALS[key]
	if not t then return 0 end
	local r = rank or E.bookRank[key] or getn(t)
	if r > getn(t) then r = getn(t) end
	if r < 1 then r = 1 end
	local v = t[r]
	local fb = getglobal("GetSpellBonusHealing")
	if type(fb) == "function" then
		local ok, b = pcall(fb)
		if ok and type(b) == "number" and b > 0 then
			local coef = (tonumber(castMs) or 0) / 3500
			if coef > 1 then coef = 1 end
			v = v + b * coef
		end
	end
	return floor(v + 0.5)
end

-- Annonce un lancement fait par ShikiUI (Mod_ClickHeal) : la cible est connue exactement, meme si la cible du jeu est rendue aussitot.
-- spell : "Nom" ou "Nom(Rank n)" ; unit : jeton d'unite.
function E.NoteCast(spell, unit)
	if type(spell) ~= "string" or not unit then return end
	local _, _, base, rank = sfind(spell, "^(.-)%s*%(%D*(%d+)%)$")
	local p = E.pend
	p.spell = base or spell
	p.rank = tonumber(rank)
	p.unit = unit
	p.at = GetTime()
end

-- Un cadre dont le nom est 'name' doit relire ma part de soin entrant.
function E.RefreshMine(name)
	if not name then return end
	local m = E.mine
	local v = (m.name == name) and m.amount or 0
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.kind ~= "pins" then
			local f = g.names[name]
			if f and (f.incMine or 0) ~= v then
				f.incMine = v
				f.dH = true
				E.Push(g, f)
			end
		end
	end
	if SUI.UnitsHealNotify then SUI.UnitsHealNotify() end   -- cadres joueur / cible de Units.lua
end

function E.SetMine(tname, amount, dur, src)
	local m = E.mine
	local old = m.name
	m.name, m.amount, m.src = tname, amount, src
	m.at = GetTime()
	m.endAt = m.at + (dur or 0) + 1
	if old and old ~= tname then E.RefreshMine(old) end
	E.RefreshMine(tname)
end

function E.ClearMine()
	local m = E.mine
	local old = m.name
	if not old then return end
	m.name, m.amount, m.src = nil, 0, nil
	E.RefreshMine(old)
end

-- Soins entrants pour un cadre HORS instances (Units.lua : joueur, cible). Retourne le meilleur montant connu
-- (mon incantation en cours, puis HealComm / PTHealPredict pour les autres soigneurs). 0 si rien.
function E.IncomingFor(name, guid)
	local inc = 0
	local m = E.mine
	if name and m.name == name and m.amount > inc then inc = m.amount end
	-- soins des autres soigneurs notes par SuperWoW (UNIT_CASTEVENT), entrees expirees ignorees et purgees
	local now = GetTime()
	local k, v
	for k, v in pairs(E.others) do
		if v.endAt < now then
			E.others[k] = nil
		elseif name and v.t == name and v.amt > inc then
			inc = v.amt
		end
	end
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.kind ~= "pins" and g.cfg.incoming and g.cfg.incsrc ~= "me" then
			if g.HC and name and name ~= "" then
				local ok, v = pcall(g.HC.getHeal, g.HC, name)
				if ok and type(v) == "number" and v > inc then inc = v end
			elseif g.PT and guid then
				local ok, v = pcall(g.PT.getHeal, guid)
				if ok and type(v) == "number" and v > inc then inc = v end
			end
		end
	end
	return inc
end

-- Consommateur des soins entrants pour les cadres joueur / cible de Units.lua (charge avant ce fichier).
SUI.UnitsIncoming = function(unit, name, guid)
	return E.IncomingFor(name, guid)
end

-- Vrai si le lancement annonce par ShikiUI correspond a ce sort (et est recent).
local function pendingFor(key, now)
	local p = E.pend
	return p.spell and p.unit and now - p.at < 2 and E.HealKey(p.spell) == key
end

-- SPELLCAST_START (nom du sort, duree en ms) / STOP / FAILED / INTERRUPTED : mon incantation de soin et sa cible.
function E.OnMyCast(ev, a1, a2)
	if ev ~= "SPELLCAST_START" then
		E.ClearMine()
		return
	end
	local now = GetTime()
	local m = E.mine
	if m.name and m.src == "sw" and now - m.at < 1 then return end      -- SuperWoW a deja donne la cible exacte
	local key = E.HealKey(a1)
	if not key then
		E.ClearMine()
		return
	end
	local tname, rank = nil, nil
	if pendingFor(key, now) then
		tname, rank = UnitName(E.pend.unit), E.pend.rank
		E.pend.spell = nil
	elseif UnitExists("target") and UnitIsFriend("player", "target") then
		tname = UnitName("target")
	else
		tname = UnitName("player")
	end
	if not tname then
		E.ClearMine()
		return
	end
	E.SetMine(tname, E.HealAmount(key, rank, a2), (tonumber(a2) or 0) / 1000, "ev")
end

-- Cible d'un lancement SuperWoW : le nom du cadre portant ce GUID (nil si la cible n'est pas dans un groupe).
local function nameOfGuid(gd)
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.kind ~= "pins" then
			for k = 1, g.nOrder do
				local f = g.order[k]
				if f.guid == gd then return f.name end
			end
		end
	end
	return nil
end

-- Soins des AUTRES soigneurs (SuperWoW, UNIT_CASTEVENT) : on note l'incantation de lanceurs qui ne sont pas moi.
-- Montant estime au rang le plus haut connu du grimoire (le rang du lanceur est inconnu) ; expire apres l'incantation.
function E.OtherCastEvent(a1, a2, a3, a4)
	local now = GetTime()
	local e = E.others[a1]
	if a3 == "FAIL" or a3 == "CAST" then
		if e then E.others[a1] = nil end
		return
	end
	if a3 ~= "START" then return end
	local key = E.HealKey(spellName(a4))
	if not key then return end
	local tgt = a2
	if not tgt or tgt == "" then return end
	local tname = nameOfGuid(tgt)
	if not tname then
		-- cadres joueur / cible de Units.lua : hors instances de groupe, on resout le joueur et la cible du jeu
		if tgt == E.myGuid then
			tname = UnitName("player")
		elseif SUI.Api and SUI.Api.GUID then
			local tg = SUI.Api.GUID("target")
			if tg and tg == tgt then tname = UnitName("target") end
		end
	end
	if not tname then return end
	if e and e.t == tname then return end        -- deja note vers la meme cible (anti-doublon)
	local ms = tonumber(getglobal("arg5")) or 0
	local amt = E.HealAmount(key, nil, ms)
	if amt <= 0 then return end
	-- purge des entrees expirees si la table grossit (cap 16)
	if not e then
		local n, k, v = 0
		for k, v in pairs(E.others) do
			n = n + 1
			if n > 16 or v.endAt < now then E.others[k] = nil end
		end
	end
	E.others[a1] = { t = tname, amt = amt, endAt = now + (ms / 1000) + 1.5 }
	if SUI.UnitsHealNotify then SUI.UnitsHealNotify() end
end

-- UNIT_CASTEVENT (SuperWoW) pour moi : START donne la cible exacte, CAST / FAIL la fin.
function E.MyCastEvent(a2, a3, a4)
	if a3 == "START" then
		local key = E.HealKey(spellName(a4))
		if not key then return end
		local tgt = a2
		if not tgt or tgt == "" then tgt = E.myGuid end
		local tname = nameOfGuid(tgt)
		if not tname then return end
		local ms = tonumber(getglobal("arg5")) or 0
		local rank = nil
		local now = GetTime()
		if pendingFor(key, now) then rank = E.pend.rank end
		E.SetMine(tname, E.HealAmount(key, rank, ms), ms / 1000, "sw")
	elseif a3 == "CAST" or a3 == "FAIL" then
		E.ClearMine()
	end
end

-- UNIT_CASTEVENT : a1 lanceur, a2 cible, a3 type (START / CAST / FAIL...), a4 sort ; la duree (ms) est le 5e argument.
function E.OnCastEvent(ev, a1, a2, a3, a4)
	if not a1 then return end
	if not E.myGuid then
		local _, gd = UnitExists("player")
		E.myGuid = gd
	end
	if E.wantInc and a1 == E.myGuid and (a3 == "START" or a3 == "CAST" or a3 == "FAIL") then E.MyCastEvent(a2, a3, a4) end
	if E.wantInc and a1 ~= E.myGuid then E.OtherCastEvent(a1, a2, a3, a4) end
	if a3 == "CAST" and a1 == E.myGuid and E.wantHots then
		local nm = spellName(a4)
		if nm and E.HOTS[nm] then
			local tgt = a2
			if not tgt or tgt == "" then tgt = a1 end
			for i = 1, getn(E.instances) do
				local g = E.instances[i]
				if g.active and g.built and g.cfg.hotany > 0 then
					for k = 1, g.nOrder do
						local f = g.order[k]
						if f.guid == tgt then E.NoteHot(f.name, nm) end
					end
				end
			end
		end
	end
	if not E.wantRes then return end
	if a3 == "START" or a3 == "CAST" then
		local nm = spellName(a4)
		if nm and E.RES[nm] and a2 and a2 ~= "" then
			local now = GetTime()
			local slot = nil
			for i = 1, RESN do
				if E.res[i].c == a1 then
					slot = E.res[i]
					break
				end
			end
			if not slot then
				for i = 1, RESN do
					if E.res[i].u <= now then
						slot = E.res[i]
						break
					end
				end
			end
			if not slot then slot = E.res[1] end
			slot.c, slot.t = a1, a2
			if a3 == "START" then
				slot.u = now + (tonumber(getglobal("arg5")) or 10000) / 1000 + 1
			else
				slot.u = now + 30        -- incantation terminee : la cible a 30 s pour accepter
			end
			refreshRes(a2)
		end
	elseif a3 == "FAIL" then
		for i = 1, RESN do
			local s = E.res[i]
			if s.c == a1 and s.u > 0 then
				local t = s.t
				s.u = 0
				refreshRes(t)
			end
		end
	end
end

-- Ecoute UNIT_CASTEVENT seulement si une instance active a besoin des HoT ou de la resurrection (SuperWoW requis).
function E.SyncCast()
	local hots, res, inc = false, false, false
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.kind ~= "pins" then
			if g.cfg.hotany > 0 and g.maxHot > 0 then hots = true end
			if g.cfg.resinfo then res = true end
			if g.cfg.incoming then inc = true end
		end
	end
	-- Les cadres joueur / cible de Units.lua consomment aussi les soins entrants (barre de pre-soin sur soi).
	if not inc and SUI.Units and SUI.Units.active and SUI.Config.Get("units.incheal") then inc = true end
	E.wantHots, E.wantRes = hots, res
	if inc ~= E.wantInc then
		E.wantInc = inc
		for i = 1, getn(E.INC_EV) do
			if inc then SUI.On(E.INC_EV[i], E.OnMyCast) else SUI.Off(E.INC_EV[i], E.OnMyCast) end
		end
		if inc then E.ScanHeals() else E.ClearMine() end
	end
	if SUI.Api.superwow and (hots or res or inc) then SUI.On("UNIT_CASTEVENT", E.OnCastEvent) else SUI.Off("UNIT_CASTEVENT", E.OnCastEvent) end
end

-- Alerte nouvelle sur un cadre : crochets externes (futur DebuffAlert) puis son optionnel.
function E.FireAlert(g, f, frag, tex)
	for i = 1, getn(E.alertHooks) do
		local ok, err = pcall(E.alertHooks[i], g, f.unit, frag, tex)
		if not ok then SUI.Report("alerthook", err) end
	end
	local mode = g.cfg.alertsound
	if mode == "none" then return end
	if mode == "self" and not UnitIsUnit(f.unit, "player") then return end
	local now = GetTime()
	if g.lastSound and now - g.lastSound < 2 then return end
	g.lastSound = now
	PlaySoundFile(E.SOUND_ALERT)
end

-- Ajoute / retire un crochet d'alerte (retourne true si ajoute / retire).
function E.OnAlert(fn)
	for i = 1, getn(E.alertHooks) do
		if E.alertHooks[i] == fn then return false end
	end
	tinsert(E.alertHooks, fn)
	return true
end

function E.OffAlert(fn)
	for i = getn(E.alertHooks), 1, -1 do
		if E.alertHooks[i] == fn then
			table.remove(E.alertHooks, i)
			return true
		end
	end
	return false
end

function E.UpdateFrame(g, f)
	if not f.vis then
		f.dI, f.dH, f.dP, f.dA, f.dB, f.dF = false, false, false, false, false, false
		return
	end
	if f.dI then
		f.dI = false
		E.Info(g, f)
		E.UpdateName(g, f)
		E.UpdateMark(g, f)
		f.dH, f.dP, f.dA, f.dB, f.dF = true, true, true, true, true
		f.isTarget = (UnitIsUnit(f.unit, "target") and true) or false
	end
	if f.dH then
		f.dH = false
		E.UpdateHealth(g, f)
	end
	if f.dP then
		f.dP = false
		E.UpdatePower(g, f)
	end
	if f.dA then
		f.dA = false
		E.UpdateAuras(g, f)
	end
	if f.dF then
		f.dF = false
		E.UpdateFx(g, f)
	end
	if f.dB then
		f.dB = false
		E.PaintState(g, f)
	end
end

-- Vide la file (budget par passage) ; roster et disposition d'abord.
function E.Flush(g)
	if not g.built or not g.active then return end
	if g.rosterDirty then
		g.rosterDirty = false
		E.Rebuild(g)
	end
	local n = g.cfg.budget
	while n > 0 and g.qn > 0 do
		E.UpdateFrame(g, pop(g))
		n = n - 1
	end
	if g.arrangeDirty then E.Arrange(g) end
end

-- ---------------------------------------------------------------- tour lent (portee, etat, aggro, soins entrants)
function E.Range(unit, cfg)
	if UnitIsUnit(unit, "player") then return true end
	if not UnitIsVisible(unit) then return false end
	local d, src = SUI.Api.Distance(unit)
	if src == "xp" or src == "pos" then return d <= cfg.rangeyd end
	if src == "band" then return d ~= nil end
	return nil
end

function E.SlowFrame(g, f)
	local cfg = g.cfg
	local unit = f.unit
	local st = 0
	if UnitIsConnected(unit) then
		if UnitIsDeadOrGhost(unit) then st = 1 end
	else
		st = 2
	end
	if st ~= f.state then
		f.dH = true
		E.Push(g, f)
	end
	if cfg.range then
		local r = E.Range(unit, cfg)
		if r ~= f.inRange then
			f.inRange = r
			E.ApplyAlpha(g, f)
		end
	elseif f.inRange ~= nil then
		f.inRange = nil
		E.ApplyAlpha(g, f)
	end
	if cfg.los then
		-- ligne de vue (UnitXP "inSight") : seulement pour un allie vivant, en ligne, a portee ; inconnue (nil) = visible
		local ns = false
		if st == 0 and f.inRange ~= false and not f.isSelf and f.vis then ns = (SUI.Api.InSight(unit) == false) end
		if ns ~= f.noSight then
			f.noSight = ns
			E.ApplyAlpha(g, f)
		end
	elseif f.noSight then
		f.noSight = false
		E.ApplyAlpha(g, f)
	end
	if g.banzai and cfg.aggro then
		local ok, v = pcall(g.banzai.GetUnitAggroByUnitId, g.banzai, unit)
		local ag = (ok and v) and true or false
		if ag ~= f.aggro then
			f.aggro = ag
			f.dB = true
			E.Push(g, f)
		end
	end
	if cfg.resinfo and st == 1 then
		local rs = E.IsResurrecting(g, f)
		if rs ~= f.res then
			f.res = rs
			f.dH = true
			E.Push(g, f)
		end
	elseif f.res then
		f.res = false
		f.dH = true
		E.Push(g, f)
	end
	if (g.HC or g.PT) and cfg.incoming and cfg.incsrc ~= "me" then
		local ok, inc
		if g.HC then
			ok, inc = pcall(g.HC.getHeal, g.HC, f.name)
		elseif f.guid then
			ok, inc = pcall(g.PT.getHeal, f.guid)
		end
		if not ok or type(inc) ~= "number" then inc = 0 end
		if inc ~= f.inc then
			f.inc = inc
			f.dH = true
			E.Push(g, f)
		end
	elseif f.inc and f.inc ~= 0 then
		f.inc = 0
		f.dH = true
		E.Push(g, f)
	end
end

-- Ennemis epingles : aucun evenement par GUID, on interroge (au plus 4 cadres).
function E.PollPin(g, f)
	local unit = f.unit
	if not UnitExists(unit) then
		if not f.gone then
			f.gone = true
			f.dI = true
			E.Push(g, f)
		end
		return
	end
	local hp, mx, nm = UnitHealth(unit), UnitHealthMax(unit), UnitName(unit)
	if f.gone or hp ~= f.lhp or mx ~= f.lmx or nm ~= f.name then
		f.gone = false
		f.dI = true
		E.Push(g, f)
	end
end

function E.Slow(g)
	if not g.active or not g.built then return end
	local cfg = g.cfg
	if g.fxDirty then          -- un reglage de groupfx.* a change (icone, teinte, minuteur, aggro...) : tout redessiner
		g.fxDirty = false
		E.SyncHots(g)
		E.MarkAll(g, "dF")
	end
	if E.mine.name and GetTime() > E.mine.endAt then E.ClearMine() end
	local n = g.nOrder
	if n == 0 then return end
	if g.kind == "pins" then
		for i = 1, n do E.PollPin(g, g.order[i]) end
		return
	end
	if (cfg.incoming or cfg.resinfo or cfg.aggro) and not (g.HC or g.PT) then
		local now = GetTime()
		if now >= (g.srcAt or 0) then
			g.srcAt = now + 5
			E.ResolveSources(g)
		end
	end
	if cfg.aggro and not g.banzai then
		local nf = nil
		if UnitExists("target") and UnitExists("targettarget") and UnitCanAttack("player", "target") then
			nf = g.names[UnitName("targettarget") or ""]
		end
		if nf ~= g.aggroFrame then
			local old = g.aggroFrame
			g.aggroFrame = nf
			if old then
				old.aggro = false
				old.dB = true
				E.Push(g, old)
			end
			if nf then
				nf.aggro = true
				nf.dB = true
				E.Push(g, nf)
			end
		end
	end
	local step = cfg.slowstep
	if step > n then step = n end
	local i = g.rr
	for _ = 1, step do
		if i > n then i = 1 end
		E.SlowFrame(g, g.order[i])
		i = i + 1
	end
	g.rr = i
	-- Les soins des AUTRES soigneurs (HealComm / PTHealPredict) changent sans evenement :
	-- les cadres joueur / cible relisent a chaque passage lent (pas seulement les cadres de groupe).
	if (g.HC or g.PT) and cfg.incoming and cfg.incsrc ~= "me" and SUI.UnitsHealNotify then
		SUI.UnitsHealNotify()
	end
end

function E.OnTarget(g)
	if not g.active then return end
	for i = 1, g.nOrder do
		local f = g.order[i]
		local t = (UnitIsUnit(f.unit, "target") and true) or false
		if t ~= f.isTarget then
			f.isTarget = t
			E.PaintState(g, f)
		end
	end
end

-- ---------------------------------------------------------------- roster et disposition
local function setVisible(g, f, want)
	if want == f.vis then return end
	f.vis = want
	if want then
		f:Show()
		f.dI = true
		E.Push(g, f)
	else
		f:Hide()
		f.dI, f.dH, f.dP, f.dA, f.dB = false, false, false, false, false
		f.alertTex = nil
		f.aggro = false
		f.res = false
		f.inRange = nil
		f.noSight = false
		f.state = nil
		f.lhp = nil
	end
end

function E.Rebuild(g)
	local cfg = g.cfg
	for k in pairs(g.names) do g.names[k] = nil end
	if g.kind == "raid" then g.byUnit["player"] = nil end
	local nr = GetNumRaidMembers()
	local np = GetNumPartyMembers()
	if g.kind == "party" then
		local hide = (nr > 0 and cfg.hideinraid)
		local baseOn = (not hide) and (np > 0 or cfg.solo)
		for i = 1, g.max do
			local f = g.frames[i]
			local want
			if i == 1 then
				want = baseOn
			elseif i <= 5 then
				want = baseOn and np >= i - 1 and UnitExists(f.unit) and true or false
			else
				want = baseOn and cfg.pets and UnitExists(f.unit) and true or false
			end
			setVisible(g, f, want)
		end
	elseif g.kind == "raid" then
		for i = 1, g.max do
			local f = g.frames[i]
			local want = false
			if i <= nr then
				local nm, _, sub = GetRaidRosterInfo(i)
				if nm and (sub or 1) <= cfg.maxgroup then want = true end
			end
			setVisible(g, f, want)
			if want and UnitIsUnit(f.unit, "player") then g.byUnit["player"] = f end
		end
	else
		for i = 1, g.max do
			local f = g.frames[i]
			f.unit = g.pins[i]
			setVisible(g, f, i <= g.nPins)
		end
	end
	-- liste ordonnee des cadres visibles (tableau reutilise)
	local n = 0
	for i = 1, g.max do
		local f = g.frames[i]
		if f.vis then
			n = n + 1
			g.order[n] = f
			if f.lastUnit ~= f.unit then
				f.lastUnit = f.unit
				f.dI = true
				E.Push(g, f)
			end
			E.Info(g, f)
			if f.name ~= "" then g.names[f.name] = f end
			local im = (E.mine.name == f.name) and E.mine.amount or 0      -- ma part de soin entrant suit le NOM, pas le jeton d unite
			if (f.incMine or 0) ~= im then
				f.incMine = im
				f.dH = true
				E.Push(g, f)
			end
		end
	end
	g.nOrder = n
	if g.rr > n then g.rr = 1 end
	if E.ApplyAuto(g) and g.built then E.ApplyGeometry(g) end      -- densite automatique : l'effectif a change de palier
	g.arrangeDirty = true
	E.Arrange(g)
	if g.container then
		if n > 0 then g.container:Show() else g.container:Hide() end
	end
end

local function less(g, a, b)
	local s = g.cfg.sort
	if s == "group" then
		if a.sub ~= b.sub then return a.sub < b.sub end
	elseif s == "role" then
		if a.roleRank ~= b.roleRank then return a.roleRank < b.roleRank end
		if a.classRank ~= b.classRank then return a.classRank < b.classRank end
	elseif s == "class" then
		if a.classRank ~= b.classRank then return a.classRank < b.classRank end
	elseif s == "name" then
		if a.name ~= b.name then return a.name < b.name end
	end
	return a.idx < b.idx
end

E.TITLEH = 11                -- hauteur reservee au titre de chaque groupe (reglage grouptitle)
E.lcnt = {}                  -- membres par sous-groupe (table de travail reutilisee)
for i = 1, 8 do E.lcnt[i] = 0 end

-- Geometrie de la grille, PURE (sert aux vrais cadres et a l'apercu du menu) : ord[1..n] = objets avec .sub dans l'ordre d'affichage ;
-- remplit px[k] / py[k] (coin haut gauche, depuis le coin du conteneur), tx[s] / ty[s] / tj[s] = place du titre du groupe s (tx nil si
-- le groupe est absent ou sans titre ; tj : titre accroche a droite). Renvoie largeur et hauteur totales.
-- Tri "group" : un groupe par colonne (orientation verticale) ou par ligne (horizontale), grpperline groupes par bande puis retour a la ligne ;
-- autres tris : perline cadres par ligne. fill : coin de depart (tl / tr / bl / br) : la grille entiere est retournee, titres compris.
-- Dimensions de la grille pleine (cap cadres, sous-groupes de 5 dans l'ordre) : tables de travail reutilisees, aucune allocation en regime etabli.
E.cord, E.cpx, E.cpy, E.ctx, E.cty, E.ctj = {}, {}, {}, {}, {}, {}
function E.CapExtent(cfg, cap)
	local o = E.cord
	for k = 1, cap do
		local e = o[k]
		if not e then e = {}; o[k] = e end
		e.sub = floor((k - 1) / 5) + 1
		if e.sub > 8 then e.sub = 8 end
	end
	return E.Layout(cfg, o, cap, E.cpx, E.cpy, E.ctx, E.cty, E.ctj)
end

function E.Layout(cfg, ord, n, px, py, tx, ty, tj, cap)
	local w, h = cfg.width, cfg.height
	local sp, gap = cfg.spacing, cfg.groupgap
	local sortGroup = (cfg.sort == "group")
	local vertical = (cfg.orient == "vertical")
	local perline = cfg.perline
	if perline < 1 then perline = 1 end
	local gpl = cfg.grpperline
	if gpl < 1 then gpl = 1 end
	local th = (sortGroup and cfg.grouptitle) and E.TITLEH or 0
	local cnt = E.lcnt
	for i = 1, 8 do
		cnt[i] = 0
		tx[i] = nil
	end
	local maxc = 0
	if sortGroup then
		for k = 1, n do
			local s = ord[k].sub
			if s > 8 then s = 8 end
			if s < 1 then s = 1 end
			cnt[s] = cnt[s] + 1
			if cnt[s] > maxc then maxc = cnt[s] end
		end
	end
	local bandH = th + maxc * (h + sp) - sp + gap
	local bandW = maxc * (w + sp) - sp + gap
	local line, pos, lastSub, gi, col, band = 0, 0, nil, -1, 0, 0
	local maxX, maxY = 0, 0
	for k = 1, n do
		local f = ord[k]
		local x, y
		if sortGroup then
			if f.sub ~= lastSub then
				gi = gi + 1
				pos = 0
				lastSub = f.sub
				band = floor(gi / gpl)
				col = gi - band * gpl
				if th > 0 then
					local s = f.sub
					if s > 8 then s = 8 end
					if s < 1 then s = 1 end
					if vertical then
						tx[s], ty[s] = col * (w + gap), band * bandH
					else
						tx[s], ty[s] = band * bandW, col * (th + h + gap)
					end
					tj[s] = false
				end
			end
			if vertical then
				x = col * (w + gap)
				y = band * bandH + th + pos * (h + sp)
			else
				x = band * bandW + pos * (w + sp)
				y = col * (th + h + gap) + th
			end
		else
			line = floor((k - 1) / perline)
			pos = (k - 1) - line * perline
			if vertical then
				x = line * (w + sp)
				y = pos * (h + sp)
			else
				x = pos * (w + sp)
				y = line * (h + sp)
			end
		end
		px[k], py[k] = x, y
		if x + w > maxX then maxX = x + w end
		if y + h > maxY then maxY = y + h end
		pos = pos + 1
	end
	local fill = cfg.fill
	local right = (fill == "tr" or fill == "br")
	local bottom = (fill == "bl" or fill == "br")
	-- grille retournee : on la retourne dans les dimensions de la CAPACITE (groupe plein / raid complet), pas de l'effectif courant, sinon
	-- le premier cadre change de place a chaque arrivee ou depart (le conteneur garde son bord gauche et son haut fixes a l'ecran)
	if (right or bottom) and cap and cap > n then
		local cx, cy = E.CapExtent(cfg, cap)
		if right and cx > maxX then maxX = cx end
		if bottom and cy > maxY then maxY = cy end
	end
	if right then
		for k = 1, n do px[k] = maxX - px[k] - w end
	end
	if bottom then
		for k = 1, n do py[k] = maxY - py[k] - h end
	end
	if th > 0 then
		for s = 1, 8 do
			if tx[s] then
				if right then
					if vertical then
						tx[s] = maxX - tx[s] - w
					else
						tx[s] = maxX - tx[s]
						tj[s] = true
					end
				end
				if bottom then ty[s] = maxY - ty[s] - th end
			end
		end
	end
	return maxX, maxY
end

-- Tri par insertion (sans allocation) puis placement ; ne repose un point que s'il change.
function E.Arrange(g)
	g.arrangeDirty = false
	local cfg = g.cfg
	local order, n = g.order, g.nOrder
	for i = 2, n do
		local f = order[i]
		local j = i - 1
		while j >= 1 and less(g, f, order[j]) do
			order[j + 1] = order[j]
			j = j - 1
		end
		order[j + 1] = f
	end
	local w = cfg.width
	local cap
	if g.kind == "raid" then cap = (cfg.maxgroup or 8) * 5 elseif g.kind == "party" then cap = 5 end
	local maxX, maxY = E.Layout(cfg, order, n, g.lx, g.ly, g.tx, g.ty, g.tj, cap)
	for k = 1, n do
		local f = order[k]
		local x, y = g.lx[k], g.ly[k]
		if x ~= f.px or y ~= f.py then
			f.px, f.py = x, y
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", g.container, "TOPLEFT", x, -y)
		end
	end
	if g.container then
		g.container:SetWidth(maxX > 0 and maxX or w)
		g.maxY = maxY
	end
	E.PlaceTitles(g)
end

-- Titres de groupe ("G1"...) : crees UNE fois a la construction (hors combat), places seulement s'ils changent.
function E.PlaceTitles(g)
	local ts = g.titles
	for s = 1, 8 do
		local t = ts[s]
		if t then
			local x, y = g.tx[s], g.ty[s]
			if x and g.cfg.grouptitle and g.cfg.sort == "group" then
				local sig = x .. "|" .. y .. "|" .. tostring(g.tj[s]) .. "|" .. g.cfg.width .. "|" .. g.ttl[s]
				if g.tShown[s] ~= sig then
					g.tShown[s] = sig
					t:ClearAllPoints()
					if g.tj[s] then
						t:SetPoint("TOPRIGHT", g.container, "TOPLEFT", x, -y)
						t:SetJustifyH("RIGHT")
					else
						t:SetPoint("TOPLEFT", g.container, "TOPLEFT", x, -y)
						t:SetJustifyH("LEFT")
					end
					t:SetWidth(g.cfg.width)
					t:SetText(g.ttl[s])
					t:Show()
				end
			elseif g.tShown[s] then
				g.tShown[s] = nil
				t:Hide()
			end
		end
	end
end

-- ---------------------------------------------------------------- clics, survol
local function onEnter()
	local f = this
	E.hover = f                       -- cadre survole : lu par les touches de soin au clavier (Mod_ClickHeal M.Key)
	SUI.Api.SetMouseover(f.unit)
	local g = f.g
	if g.cfg.tooltip and GameTooltip and UnitExists(f.unit) then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:SetUnit(f.unit)
		local ch = SUI.ClickHeal
		if ch and ch.on and ch.AddHints then ch.AddHints(GameTooltip, f) end
		GameTooltip:Show()
	end
end

local function onLeave()
	if E.hover == this then E.hover = nil end
	SUI.Api.SetMouseover(nil)
	if GameTooltip then GameTooltip:Hide() end
end

function E.OpenMenu(f)
	local unit = f.unit
	local dd
	if unit == "player" then
		dd = getglobal("PlayerFrameDropDown")
	else
		local _, _, n = sfind(unit, "^party(%d)$")
		if n then dd = getglobal("PartyMemberFrame" .. n .. "DropDown") end
	end
	if not dd then
		TargetUnit(unit)
		dd = getglobal("TargetFrameDropDown")
	end
	if dd and ToggleDropDownMenu then pcall(ToggleDropDownMenu, 1, nil, dd, "cursor") end
end

function E.DefaultClick(f, btn)
	local unit = f.unit
	if btn == "RightButton" then
		E.OpenMenu(f)
		return
	end
	if SpellIsTargeting() then
		SpellTargetUnit(unit)
	elseif CursorHasItem() then
		DropItemOnUnit(unit)
	else
		TargetUnit(unit)
	end
end

local function onClick()
	local f = this
	local btn = arg1
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.Click(f.unit, btn, f) then return end
	E.DefaultClick(f, btn)
end

local function onWheel()
	local f = this
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.Wheel then ch.Wheel(f.unit, arg1, f) end
end

-- ---------------------------------------------------------------- construction (hors combat uniquement)
function E.CreateUnitFrame(g, i)
	local f = CreateFrame("Button", "ShikiUI_" .. g.title .. "_" .. i, g.container)
	f.g = g
	f.idx = i
	f.unit = g.units and g.units[i] or nil
	if f.unit then g.byUnit[f.unit] = f end
	f.state = nil
	f.name = ""
	f.sub = 1
	f.rank = 0
	f.roleRank = 3
	f.classRank = 99
	f.dN, f.bN, f.hN = 0, 0, 0
	f.dTex, f.dType, f.bTex = {}, {}, {}
	f.dIcon, f.dEdge, f.bIcon = {}, {}, {}
	f.hTex, f.hIcon, f.hTime, f.hExp, f.hSec, f.hWarn = {}, {}, {}, {}, {}, {}
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	T.Backdrop(f, T.c.bg, T.c.border)
	f.heal = T.Bar(f)
	f.heal:SetFrameLevel(f:GetFrameLevel() + 1)
	f.heal.bg:Hide()
	f.hp = T.Bar(f)
	f.hp:SetFrameLevel(f:GetFrameLevel() + 2)
	f.hp.bg:Hide()
	f.pw = T.Bar(f)
	f.pw:SetFrameLevel(f:GetFrameLevel() + 2)
	f.pw:Hide()
	f.ov = CreateFrame("Frame", nil, f)
	f.ov:SetFrameLevel(f:GetFrameLevel() + 6)
	f.ov:SetAllPoints(f)
	f.hl = f.ov:CreateTexture(nil, "OVERLAY")
	f.hl:SetTexture(T.tex.white)
	f.hl:SetAllPoints(f)
	f.hl:Hide()
	f.dispelHl = f.ov:CreateTexture(nil, "ARTWORK")
	f.dispelHl:SetTexture(T.tex.white)
	f.dispelHl:SetAllPoints(f)
	f.dispelHl:Hide()
	f.dispelTx = f.ov:CreateTexture(nil, "OVERLAY")
	f.dispelTx:SetTexture(T.tex.white)
	f.dispelTx:Hide()
	-- debuff a dissiper en GRAND : bordure du cadre + grosse icone (couleur du type) + abreviation du type (lisible sans la couleur)
	f.dispelBd = {}
	for k = 1, 4 do
		local bd = f.ov:CreateTexture(nil, "OVERLAY")
		bd:SetTexture(T.tex.white)
		bd:Hide()
		f.dispelBd[k] = bd
	end
	-- grosses icones de dissipation (1 a 3, une par type) : la 1re garde ses anciens noms (dispelEdge / dispelIcon / dispelLbl)
	f.bigE, f.bigI, f.bigL = {}, {}, {}
	f.bigKT, f.bigKX, f.bigOn = { 0, 0, 0 }, { false, false, false }, { false, false, false }
	for k = 1, E.BIGMAX do
		local ed = f.ov:CreateTexture(nil, "OVERLAY")
		ed:SetTexture(T.tex.white)
		ed:Hide()
		f.bigE[k] = ed
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.bigI[k] = ic
		local lb = T.Text(f.ov, 8, T.c.text, "CENTER", true)
		lb:Hide()
		f.bigL[k] = lb
	end
	f.dispelEdge, f.dispelIcon, f.dispelLbl = f.bigE[1], f.bigI[1], f.bigL[1]
	-- types de debuff presents (ordre de priorite) : f.oI indice de type, f.oT nom, f.oX texture ; f.tp / f.tx = lecture brute par type
	f.oN = 0
	f.oI, f.oT, f.oX = { 0, 0, 0, 0 }, { false, false, false, false }, { false, false, false, false }
	f.tp, f.tx = { false, false, false, false }, { false, false, false, false }
	-- contour decoupe (4 bords en segments de la couleur de chaque type)
	f.splitTx, f.splitR, f.splitN = {}, {}, 0
	for k = 1, E.SPLITMAX do
		local sx = f.ov:CreateTexture(nil, "OVERLAY")
		sx:SetTexture(T.tex.white)
		sx:Hide()
		f.splitTx[k] = sx
		f.splitR[k] = { k = 0, x = 0, y = 0, w = 0, h = 0 }
	end
	-- petites icones de dissipation en ligne (dans un coin) et petites icones a cote du pseudo
	f.smE, f.smP, f.smI, f.smX, f.smOn = {}, {}, { 0, 0, 0, 0 }, { false, false, false, false }, { false, false, false, false }
	for k = 1, 4 do
		local e = f.ov:CreateTexture(nil, "ARTWORK")
		e:SetTexture(T.tex.white)
		e:Hide()
		f.smE[k] = e
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.smP[k] = ic
	end
	f.nicI, f.nicKey, f.nicN, f.nicPlaced = {}, { false, false, false }, 0, false
	for k = 1, 3 do
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexture(T.tex.white)
		ic:Hide()
		f.nicI[k] = ic
	end
	-- effets de boss et aggro (SUI.GroupFx) : couche au-dessus des icones de dissipation
	f.ov2 = CreateFrame("Frame", nil, f)
	f.ov2:SetFrameLevel(f:GetFrameLevel() + 8)
	f.ov2:SetAllPoints(f)
	f.fxHl = f.ov2:CreateTexture(nil, "BACKGROUND")
	f.fxHl:SetTexture(T.tex.white)
	f.fxHl:SetAllPoints(f)
	f.fxHl:Hide()
	f.fxE, f.fxI, f.fxT = {}, {}, {}
	f.fxTex, f.fxKey, f.fxOn, f.fxSec, f.fxWarn = { false, false, false }, { false, false, false }, { false, false, false }, { -2, -2, -2 }, { false, false, false }
	f.fxN, f.fxTick, f.fxTintOn, f.fxTintKey, f.fxPlaced = 0, false, false, false, 0
	for k = 1, E.FXMAX do
		local ed = f.ov2:CreateTexture(nil, "ARTWORK")
		ed:SetTexture(T.tex.white)
		ed:Hide()
		f.fxE[k] = ed
		local ic = f.ov2:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.fxI[k] = ic
		local tt = T.Text(f.ov2, 10, T.c.text, "CENTER", true)
		tt:Hide()
		f.fxT[k] = tt
	end
	f.agFrame, f.agIcOn, f.agBarOn, f.agPaint = false, false, false, false
	f.agIc = f.ov2:CreateTexture(nil, "ARTWORK")
	f.agIc:SetTexture(T.tex.white)
	f.agIc:Hide()
	f.agTx = T.Text(f.ov2, 10, T.c.text, "CENTER", true)
	f.agTx:SetText("!")
	f.agTx:Hide()
	f.agBar = f.ov2:CreateTexture(nil, "OVERLAY")
	f.agBar:SetTexture(T.tex.white)
	f.agBar:Hide()
	f.alertIcon = f.ov:CreateTexture(nil, "OVERLAY")
	f.alertIcon:Hide()
	f.mark = f.ov:CreateTexture(nil, "OVERLAY")
	f.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	f.mark:Hide()
	for k = 1, g.maxDeb do
		local e = f.ov:CreateTexture(nil, "ARTWORK")
		e:SetTexture(T.tex.white)
		e:Hide()
		f.dEdge[k] = e
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.dIcon[k] = ic
	end
	for k = 1, g.maxBuf do
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.bIcon[k] = ic
	end
	for k = 1, g.maxHot do
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.hIcon[k] = ic
		local tt = T.Text(f.ov, 8, T.c.text, "CENTER", true)
		tt:Hide()
		f.hTime[k] = tt
	end
	f.nameText = T.Text(f.ov, 10, T.c.text, "LEFT", true)
	f.hpText = T.Text(f.ov, 10, T.c.text, "RIGHT", true)
	f.statusText = T.Text(f.ov, 10, T.c.warn, "CENTER", true)
	f.tagText = T.Text(f.ov, 9, T.c.warn, "RIGHT", true)
	f.pwText = T.Text(f.ov, 8, T.c.text, "CENTER", true)
	f.pwText:Hide()
	local Look = SUI.Look
	if Look then
		-- texture des barres et police des textes principaux : <module>.bartex / <module>.font / <module>.fontsize (menu Aspect du module)
		Look.ApplyBar(f.hp, g.look, {})
		Look.ApplyBar(f.heal, g.look, {})
		Look.ApplyBar(f.pw, g.look, {})
		Look.ApplyText(f.nameText, g.look, 10, true)
		Look.ApplyText(f.hpText, g.look, 10, true)
		Look.ApplyText(f.statusText, g.look, 10, true)
	end
	f:SetScript("OnClick", onClick)
	f:SetScript("OnEnter", onEnter)
	f:SetScript("OnLeave", onLeave)
	f:SetScript("OnMouseWheel", onWheel)
	f:Hide()
	return f
end

local anchorBar
function E.Resize(g, f)
	local hpH = E.HpHeight(g, f)
	anchorBar(f.hp, f, hpH)
	anchorBar(f.heal, f, hpH)
end

function anchorBar(b, f, hpH)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	b:SetHeight(hpH)
end

-- Declenchement des clics sur les cadres : a l'appui (clickheal.clickon = down, module Soins au clic actif) ou au relachement (par defaut).
function E.SyncClicks()
	local ch = SUI.ClickHeal
	local down = (ch and ch.on and C.Get("clickheal.clickon") == "down") and true or false
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		for k = 1, getn(g.frames) do
			local f = g.frames[k]
			if f.clickDown ~= down then
				f.clickDown = down
				if down then
					f:RegisterForClicks("LeftButtonDown", "RightButtonDown", "MiddleButtonDown")
				else
					f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
				end
			end
		end
	end
end

-- Roues de souris : seulement si les liaisons de clic en utilisent (voir Mod_ClickHeal.lua).
function E.SyncWheel()
	local ch = SUI.ClickHeal
	local on = (ch and ch.on and ch.hasWheel) and true or false
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		for k = 1, getn(g.frames) do g.frames[k]:EnableMouseWheel(on) end
	end
end

-- Tailles et ancrages internes (reappliques quand un reglage de taille change).
function E.ApplyGeometry(g)
	local cfg = g.cfg
	local w, h, ph, isz = cfg.width, cfg.height, cfg.powerheight, cfg.iconsize
	local nhot = cfg.hotany
	if nhot > g.maxHot then nhot = g.maxHot end
	local dsz, dpos = cfg.dispelsize, cfg.dispelpos
	local ssz, spos = cfg.dispelsmallsize, cfg.dispelsmallpos
	local tagres = ((cfg.roletag or cfg.leader) and cfg.tagpos == "topright") and 12 or 0   -- place du role / chef en haut a droite
	local agres = cfg.aggroframes and 14 or 0                             -- place de l'icone d'aggro, a gauche du role
	local resL = (cfg.dispelsmall and spos == "bottomleft") and 2 * (ssz + 3) or 0    -- petites icones : place reservee dans la rangee
	local resR = (cfg.dispelsmall and spos == "bottomright") and 2 * (ssz + 3) or 0
	local sig = w .. "|" .. h .. "|" .. ph .. "|" .. isz .. "|" .. nhot .. "|" .. dsz .. "|" .. dpos .. "|" .. cfg.nameanchor .. "|" ..
		cfg.dispelthick .. "|" .. ssz .. "|" .. spos .. "|" .. tostring(cfg.dispelsmall) .. "|" .. tagres .. "|" .. agres .. "|" ..
		cfg.fxsize .. "|" .. cfg.fxpos .. "|" .. tostring(cfg.marks) .. "|" .. cfg.hppos .. "|" .. cfg.manapos .. "|" .. cfg.manacontent .. "|" ..
		cfg.markpos .. "|" .. cfg.marksize .. "|" .. cfg.tagpos .. "|" .. cfg.tagsize
	if sig == g.sig then return end
	g.sig = sig
	for i = 1, getn(g.frames) do
		local f = g.frames[i]
		f:SetWidth(w)
		f:SetHeight(h)
		f.px, f.py = nil, nil
		f.pwShown = nil
		E.Resize(g, f)
		f.pw:ClearAllPoints()
		f.pw:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
		f.pw:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		f.pw:SetHeight(ph > 0 and ph or 1)
		f.pwText:SetWidth(floor(w * 0.5))
		f.pwText:SetHeight(10)
		E.PlacePwText(g, f)
		f.pwTxt = nil
		f.pwKey = nil
		f.nameText:SetWidth(floor(w * 0.62))
		f.nameText:SetHeight(12)
		f.namePt = nil
		E.PlaceName(g, f)
		f.hpText:SetHeight(12)
		E.PlaceHpText(g, f)
		f.statusText:ClearAllPoints()
		f.statusText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
		E.PlaceTag(g, f)
		E.PlaceMark(g, f)
		f.dispelTx:ClearAllPoints()
		f.dispelTx:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		f.dispelTx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
		f.dispelTx:SetWidth(3)
		-- grosses icones de dissipation : jamais plus hautes que le cadre (E.PlaceBig), recalees selon leur nombre au dessin suivant
		E.PlaceBig(g, f, 1)
		local bd = f.dispelBd
		bd[1]:ClearAllPoints()
		bd[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		bd[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
		bd[1]:SetHeight(2)
		bd[2]:ClearAllPoints()
		bd[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
		bd[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
		bd[2]:SetHeight(2)
		bd[3]:ClearAllPoints()
		bd[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
		bd[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
		bd[3]:SetWidth(2)
		bd[4]:ClearAllPoints()
		bd[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
		bd[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 2)
		bd[4]:SetWidth(2)
		f.bigPaint = nil
		local asz = h - 6
		if asz > 28 then asz = 28 end
		f.alertIcon:ClearAllPoints()
		f.alertIcon:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.alertIcon:SetWidth(asz)
		f.alertIcon:SetHeight(asz)
		local base = 2 + ((ph > 0) and (ph + 1) or 0)
		-- aggro (SUI.GroupFx) : icone "!" en haut a droite, barre fine du tank en haut
		f.agIc:ClearAllPoints()
		f.agIc:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(2 + tagres), -2)
		f.agIc:SetWidth(12)
		f.agIc:SetHeight(12)
		f.agTx:ClearAllPoints()
		f.agTx:SetPoint("CENTER", f.agIc, "CENTER", 0, 0)
		f.agTx:SetWidth(12)
		f.agTx:SetHeight(12)
		f.agBar:ClearAllPoints()
		f.agBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.agBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		f.agBar:SetHeight(2)
		-- petites icones de dissipation en ligne : coin choisi (bas gauche / bas droite / haut droite)
		for k = 1, 4 do
			local e, ic = f.smE[k], f.smP[k]
			e:ClearAllPoints()
			if spos == "bottomright" then
				e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - (k - 1) * (ssz + 3), base - 1)
			elseif spos == "topright" then
				e:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(2 + tagres + agres) - (k - 1) * (ssz + 3), -2)
			else
				e:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2 + (k - 1) * (ssz + 3), base - 1)
			end
			e:SetWidth(ssz + 2)
			e:SetHeight(ssz + 2)
			ic:ClearAllPoints()
			ic:SetPoint("CENTER", e, "CENTER", 0, 0)
			ic:SetWidth(ssz)
			ic:SetHeight(ssz)
		end
		f.fxPlaced = 0
		f.splitSig = nil
		f.nicPlaced = false
		for k = 1, g.maxDeb do
			local ic, e = f.dIcon[k], f.dEdge[k]
			e:ClearAllPoints()
			e:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2 + resL + (k - 1) * (isz + 3), base - 1)
			e:SetWidth(isz + 2)
			e:SetHeight(isz + 2)
			ic:ClearAllPoints()
			ic:SetPoint("CENTER", e, "CENTER", 0, 0)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
		end
		for k = 1, g.maxBuf do
			local ic = f.bIcon[k]
			ic:ClearAllPoints()
			ic:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - resR - (nhot + k - 1) * (isz + 1), base)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
		end
		for k = 1, g.maxHot do
			local ic, tt = f.hIcon[k], f.hTime[k]
			ic:ClearAllPoints()
			ic:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - resR - (k - 1) * (isz + 1), base)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
			tt:ClearAllPoints()
			tt:SetPoint("CENTER", ic, "CENTER", 0, 0)
			tt:SetWidth(isz + 6)
			tt:SetHeight(10)
		end
	end
	g.arrangeDirty = true
end

local function handleStart()
	local h = this
	if C.Get("ui.locked") then return end
	h.container:StartMoving()
	h.moving = true
end

local function handleStop()
	local h = this
	if not h.moving then return end
	h.moving = false
	local c = h.container
	c:StopMovingOrSizing()
	local l, b = c:GetLeft(), c:GetBottom()
	if c.layoutKey and l and b then
		local sc = c:GetScale() or 1
		C.SetPos(c.layoutKey, l * sc, b * sc)
		SUI.Layout.Apply(c.layoutKey)
	end
end

-- Ancienne poignee "::" : remplacee par la poignee nommee du service Mover (Mover.lua), donc toujours cachee.
function E.SyncLock(g)
	if not g.handle then return end
	g.handle:Hide()
end

function E.Build(g)
	if g.built then return end
	g.built = true
	local c = CreateFrame("Frame", "ShikiUI_" .. g.title .. "_Container", UIParent)
	c:SetFrameStrata("LOW")
	c:SetWidth(g.cfg.width)
	c:SetHeight(1)
	g.container = c
	g.handle = T.Button(c, "::", 22, 12, nil)
	g.handle:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 2)
	g.handle.container = c
	g.handle:RegisterForDrag("LeftButton")
	g.handle:SetScript("OnDragStart", handleStart)
	g.handle:SetScript("OnDragStop", handleStop)
	for i = 1, g.max do g.frames[i] = E.CreateUnitFrame(g, i) end
	if g.kind == "raid" then                       -- titres de groupe (reglage grouptitle) : huit textes, jamais crees en combat
		for s = 1, 8 do
			local t = T.Text(c, 9, T.c.dim, "LEFT", true)
			t:SetHeight(E.TITLEH)
			t:Hide()
			g.titles[s] = t
		end
	end
	SUI.Layout.Register(c, g.layoutKey, "TOPLEFT", g.defX, g.defY)
	T.OnAccent(function()
		if g.active then
			E.PaintFixed(g)
			E.MarkAll(g, "dH")
			E.MarkAll(g, "dB")
			E.MarkAll(g, "dA")
			E.MarkAll(g, "dF")
		end
	end)
	E.PaintFixed(g)
	E.ApplyGeometry(g)
	E.SyncLock(g)
	E.SyncWheel()
	E.SyncClicks()
	if not g.active then c:Hide() end
end

-- ---------------------------------------------------------------- evenements
local UNIT_EV = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE",
	"UNIT_MAXRAGE", "UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_FOCUS", "UNIT_MAXFOCUS", "UNIT_DISPLAYPOWER", "UNIT_AURA",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE" }
local POWER_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_RAGE = true, UNIT_MAXRAGE = true, UNIT_ENERGY = true,
	UNIT_MAXENERGY = true, UNIT_FOCUS = true, UNIT_MAXFOCUS = true, UNIT_DISPLAYPOWER = true }
local MANA_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_DISPLAYPOWER = true }
local ROSTER_EV = { "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET" }

local function want(g, ev)
	local cfg = g.cfg
	if g.kind == "pins" then return false end
	if POWER_EV[ev] then
		if cfg.powerheight <= 0 or cfg.manabar == "none" then return false end
		return cfg.manabar == "all" or MANA_EV[ev] == true     -- hors "all" : la rage / l'energie ne servent a rien
	end
	if ev == "UNIT_AURA" then
		return cfg.debuffs > 0 or cfg.buffs > 0 or cfg.dispelmode ~= "off" or (cfg.alerts and g.nAlerts > 0) or cfg.hotany > 0
	end
	if ev == "UNIT_PET" then return g.kind == "party" and cfg.pets end
	return true
end

local function setEv(g, ev, handler, on)
	if on and not g.evOn[ev] then
		g.evOn[ev] = true
		SUI.On(ev, handler)
	elseif not on and g.evOn[ev] then
		g.evOn[ev] = false
		SUI.Off(ev, handler)
	end
end

function E.SyncEvents(g)
	local cfg = g.cfg
	for i = 1, getn(UNIT_EV) do
		local ev = UNIT_EV[i]
		setEv(g, ev, (ev == "PARTY_MEMBER_ENABLE" or ev == "PARTY_MEMBER_DISABLE") and g.hMember or g.hUnit, g.active and want(g, ev))
	end
	for i = 1, getn(ROSTER_EV) do
		local ev = ROSTER_EV[i]
		setEv(g, ev, g.hRoster, g.active and want(g, ev) and g.kind ~= "pins")
	end
	setEv(g, "PLAYER_TARGET_CHANGED", g.hTarget, g.active and (cfg.target or cfg.aggro))
	setEv(g, "RAID_TARGET_UPDATE", g.hMarks, g.active and cfg.marks and g.kind ~= "pins")
	setEv(g, "SPELLS_CHANGED", g.hSpells, g.active and g.kind ~= "pins")
end

function E.Activate(g)
	if g.active then return end
	g.active = true
	E.ReadConfig(g)
	E.ScanCures()
	E.SyncEvents(g)
	g.tFlush = SUI.Every(FLUSH, g.fnFlush, g.title .. ".flush", true)
	g.tSlow = SUI.Every(g.slowInterval, g.fnSlow, g.title .. ".slow", true)
	E.SyncHots(g)
	E.SyncCast()
	if g.kind ~= "pins" and SUI.GroupFx then SUI.GroupFx.OnChange(g.hFx) end
	E.WatchFx()
	g.rosterDirty = true
	if g.built then
		g.container:Show()
		E.ApplyGeometry(g)
		E.SyncLock(g)
		E.Flush(g)
	end
end

function E.Deactivate(g)
	if not g.active then return end
	g.active = false
	E.SyncEvents(g)
	SUI.Cancel(g.tFlush)
	SUI.Cancel(g.tSlow)
	g.tFlush, g.tSlow = nil, nil
	E.SyncHots(g)
	E.SyncCast()
	if g.kind ~= "pins" and SUI.GroupFx then SUI.GroupFx.OffChange(g.hFx) end
	if g.built then
		for i = 1, getn(g.frames) do setVisible(g, g.frames[i], false) end
		for i = 1, g.cap do g.q[i] = false end
		g.qh, g.qt, g.qn = 1, 1, 0
		g.nOrder = 0
		g.container:Hide()
		g.handle:Hide()
	end
end

-- Les reglages d'affichage de SUI.GroupFx (groupfx.fx.icon / tint / timer, groupfx.aggro.frame...) ne produisent aucun evenement d'unite :
-- chaque instance active est marquee, et le prochain tour lent redessine ses cadres (apres que GroupFx ait relu ses propres reglages).
function E.OnFxKey()
	for i = 1, getn(E.instances) do E.instances[i].fxDirty = true end
end

function E.WatchFx()
	if E.fxWatching then return end
	E.fxWatching = true
	C.Watch("groupfx.", E.OnFxKey)
end

-- Reglage modifie : relire, retailler, reorganiser, tout redessiner.
function E.OnKey(g, key)
	if not g.active then return end
	E.ReadConfig(g)
	if g.built then E.ApplyGeometry(g) end
	E.SyncEvents(g)
	E.SyncHots(g)
	E.SyncCast()
	g.rosterDirty = true
	g.arrangeDirty = true
	-- ce qui ne se recalcule pas tout seul : opacite hors portee, aggro, soins entrants (sinon repris au tour lent suivant)
	local cfg = g.cfg
	if not cfg.aggro then
		g.aggroFrame = nil
		for i = 1, g.nOrder do g.order[i].aggro = false end
	end
	if g.built and (key == nil or sfind(key, "color$") or sfind(key, "custom$")) then E.PaintFixed(g) end   -- couleurs personnalisees relues
	for i = 1, g.nOrder do
		local f = g.order[i]
		if not cfg.range then f.inRange = nil end
		if not cfg.los then f.noSight = false end
		f.cr = nil
		if not cfg.incoming then
			f.inc = 0
			f.incMine = 0
		end
		if not cfg.resinfo then f.res = false end
		if f.state ~= nil then E.ApplyAlpha(g, f) end
		f.dI = true
		E.Push(g, f)
	end
	if g.built then E.SyncLock(g) end
end

-- ---------------------------------------------------------------- commandes communes (alertes, roles)
local function words(rest)
	local out = {}
	for w in string.gfind(rest or "", "%S+") do tinsert(out, w) end
	return out
end
E.Words = words

local function setList(g, key, list)
	local s = table.concat(list, ";")
	if slen(s) > 400 then
		SUI.Print(L("msg." .. g.name .. ".toolong"))
		return false
	end
	C.Set(g.prefix .. key, s)
	return true
end

-- /sui <module> alert add <fragment> | del <fragment> | list | scan
function E.CmdAlert(g, w)
	local sub = w[2]
	local tmp = {}
	local n = E.ParseList(C.Get(g.prefix .. "alertlist"), tmp)
	if sub == "add" and w[3] then
		for i = 1, n do
			if tmp[i] == w[3] then
				SUI.Print(L("msg." .. g.name .. ".alertdup", w[3]))
				return
			end
		end
		tinsert(tmp, w[3])
		if setList(g, "alertlist", tmp) then SUI.Print(L("msg." .. g.name .. ".alertadded", w[3])) end
	elseif sub == "del" and w[3] then
		local found = false
		for i = n, 1, -1 do
			if tmp[i] == w[3] then
				table.remove(tmp, i)
				found = true
			end
		end
		if found then
			setList(g, "alertlist", tmp)
			SUI.Print(L("msg." .. g.name .. ".alertdeleted", w[3]))
		else
			SUI.Print(L("msg." .. g.name .. ".alertmissing", w[3]))
		end
	elseif sub == "scan" then
		local k = 0
		for _, unit in ipairs({ "player", "target" }) do
			if UnitExists(unit) then
				for i = 1, MAXAUR do
					local tex = UnitDebuff(unit, i)
					if not tex then break end
					local _, _, seg = sfind(tex, "([^\\]+)$")
					k = k + 1
					SUI.Print(L("msg." .. g.name .. ".alertscan", unit, seg or tex))
				end
			end
		end
		if k == 0 then SUI.Print(L("msg." .. g.name .. ".alertscan0")) end
	else
		if n == 0 then
			SUI.Print(L("msg." .. g.name .. ".alertnone"))
		else
			SUI.Print(L("msg." .. g.name .. ".alertlist", table.concat(tmp, ", ")))
		end
	end
end

-- /sui <module> role <nom> <t|h|d|none>
function E.CmdRole(g, w)
	local name, r = w[2], w[3]
	if not name or not r then
		SUI.Print(L("msg." .. g.name .. ".roleusage"))
		return
	end
	local tmp = {}
	local n = E.ParseList(C.Get(g.prefix .. "roles"), tmp)
	for i = n, 1, -1 do
		local _, _, nm = sfind(tmp[i], "^(.-):")
		if nm == name then table.remove(tmp, i) end
	end
	r = string.upper(r)
	if r == "T" or r == "H" or r == "D" then
		tinsert(tmp, name .. ":" .. r)
	elseif r ~= "NONE" then
		SUI.Print(L("msg." .. g.name .. ".roleusage"))
		return
	end
	if setList(g, "roles", tmp) then SUI.Print(L("msg." .. g.name .. ".roleset", name, r)) end
end

-- ---------------------------------------------------------------- preset "Soigneur"
-- Valeurs lisibles pour soigner : HoT et cooldowns sur tous (3) et sur les tanks, gros debuffs a dissiper, barre de mana des soigneurs,
-- soins entrants, aggro, role repere, rez, vie critique en rouge. 'dispelonly' depend de la classe : vrai si le grimoire contient une
-- dissipation. Une valeur DEJA modifiee par le joueur (couche courante) n'est jamais ecrasee, sauf force. Meme jeu pour group.* et raid.*.
E.HEAL_PRESET = { hots = 3, tankhots = 3, hotwarn = 3, debuffs = 3, iconsize = 16, dispelbig = true, dispelsize = 22, dispelmode = "known",
	dispelstyle = "both", manabar = "healers", powerheight = 4, incoming = true, incsrc = "all", aggro = true, roletag = true,
	resinfo = true, range = true, lowhp = 35 }
E.HEAL_PREFIXES = { "group.", "raid." }

-- Applique le preset ; renvoie (nombre de cles ecrites, nombre de cles conservees car deja choisies par le joueur).
function E.HealPreset(force)
	local done, kept = 0, 0
	local canCure = false
	E.ScanCures()
	for _ in pairs(E.cure) do canCure = true end
	for i = 1, getn(E.HEAL_PREFIXES) do
		local pre = E.HEAL_PREFIXES[i]
		for k, v in pairs(E.HEAL_PRESET) do
			local key = pre .. k
			if C.meta[key] then
				if not force and C.IsModified(key) then
					kept = kept + 1
				elseif C.Set(key, v) then
					done = done + 1
				end
			end
		end
		local key = pre .. "dispelonly"
		if C.meta[key] then
			if not force and C.IsModified(key) then kept = kept + 1 elseif C.Set(key, canCure) then done = done + 1 end
		end
	end
	return done, kept
end

-- Retire les ecarts du joueur sur les cles du preset (retour aux defauts / presets de mode).
function E.HealPresetReset()
	local n = 0
	for i = 1, getn(E.HEAL_PREFIXES) do
		local pre = E.HEAL_PREFIXES[i]
		for k in pairs(E.HEAL_PRESET) do
			if C.meta[pre .. k] and C.Reset(pre .. k) then n = n + 1 end
		end
		if C.meta[pre .. "dispelonly"] and C.Reset(pre .. "dispelonly") then n = n + 1 end
	end
	return n
end

-- Marque (ou demarque) un joueur comme tank dans le groupe ET le raid ; sans nom : la cible amie.
function E.HealTank(name, on)
	if not name or name == "" then
		if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") then name = UnitName("target") end
	end
	if not name or name == "" then
		SUI.Print(L("msg.group.heal.tankusage"))
		return false
	end
	local r = on and "t" or "none"
	E.CmdRole(M.party, { "role", name, r })
	local R = SUI.Raid
	local rg = R and R.Instance and R.Instance()
	if rg then E.CmdRole(rg, { "role", name, r }) end
	return true
end

-- ================================================================ module "group"
M.on = false
M.party = nil
M.enemies = nil

M.party = E.New({ name = "group", title = "Group", prefix = "group.", kind = "party", max = 10, maxDeb = 4, maxBuf = 6, maxHot = 4,
	layoutKey = "group", defX = 20, defY = -260 })
M.party.units = PU

-- Ennemis epingles : memes cadres, leurs propres dimensions (group.enemywidth / enemyheight) ; unite = GUID SuperWoW.
M.enemies = E.New({ name = "group", title = "GroupEnemies", prefix = "group.", kind = "pins", max = 4, maxDeb = 4, maxBuf = 1,
	layoutKey = "group.enemies", defX = 300, defY = -260, slowInterval = 0.25,
	after = function(g)
		g.cfg.width = C.Get("group.enemywidth")
		g.cfg.height = C.Get("group.enemyheight")
		g.cfg.powerheight = 0
		g.cfg.sort = "none"
		g.cfg.orient = "vertical"
		g.cfg.debuffs = 0
		g.cfg.buffs = 0
		g.cfg.range = false
		g.cfg.aggro = false
		g.cfg.incoming = false
		g.cfg.marks = false
		g.cfg.dispelmode = "off"
		g.cfg.hots = 0
		g.cfg.tankhots = 0
		g.cfg.dispelbig = false
		g.cfg.lowhp = 0
		g.cfg.hotwarn = 0
		g.cfg.resinfo = false
		g.cfg.alerts = false
		g.cfg.roletag = false
		g.cfg.nameanchor = "left"       -- les ennemis epingles gardent leur mise en page d'origine
		g.cfg.nameicons = "off"
		g.cfg.dispelsmall = false
		g.cfg.fxframes = false
		g.cfg.aggroframes = false
	end })

local BLIZZ_PARTY = { "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }

function M.HideBlizzard()
	for i = 1, getn(BLIZZ_PARTY) do
		local fr = getglobal(BLIZZ_PARTY[i])
		if fr then
			fr:UnregisterAllEvents()
			fr:Hide()
		end
	end
	M.blizzHidden = true
end

-- ---------------------------------------------------------------- ennemis epingles
function M.Pin(guid)
	local g = M.enemies
	if not guid then return false, "noguid" end
	local cap = C.Get("group.enemies")
	if cap <= 0 then return false, "off" end
	for i = 1, g.nPins do
		if g.pins[i] == guid then return false, "dup" end
	end
	if g.nPins >= cap or g.nPins >= g.max then return false, "full" end
	g.nPins = g.nPins + 1
	g.pins[g.nPins] = guid
	if g.built then g.frames[g.nPins].unit = guid end
	g.rosterDirty = true
	return true
end

function M.Unpin(guid)
	local g = M.enemies
	for i = 1, g.nPins do
		if g.pins[i] == guid then
			for j = i, g.nPins - 1 do g.pins[j] = g.pins[j + 1] end
			g.pins[g.nPins] = nil
			g.nPins = g.nPins - 1
			if g.built then
				for j = 1, g.max do g.frames[j].unit = g.pins[j] end
			end
			g.rosterDirty = true
			return true
		end
	end
	return false
end

function M.ClearPins()
	local g = M.enemies
	for i = 1, g.nPins do g.pins[i] = nil end
	g.nPins = 0
	if g.built then
		for j = 1, g.max do g.frames[j].unit = nil end
	end
	g.rosterDirty = true
end

local function targetGuid()
	if not UnitExists("target") then return nil end
	return SUI.Target.GUID("target")
end

function M.OnTargetAuto()
	local g = M.enemies
	if not M.on or C.Get("group.enemyauto") ~= "boss" then return end
	if not (SUI.Api.superwow and UnitExists("target")) then return end
	if UnitClassification("target") == "worldboss" and UnitCanAttack("player", "target") then M.Pin(targetGuid()) end
end

function M.OnClearPins()
	local g = M.enemies
	for i = g.nPins, 1, -1 do
		local guid = g.pins[i]
		if not UnitExists(guid) or UnitIsDeadOrGhost(guid) then M.Unpin(guid) end
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	if not M.on then return end
	-- nombre d'ennemis epingles abaisse (ou a zero) : les cadres en trop disparaissent tout de suite
	if key == nil or key == "group.enemies" then
		local cap = C.Get("group.enemies")
		while M.enemies.nPins > cap do M.Unpin(M.enemies.pins[M.enemies.nPins]) end
	end
	E.OnKey(M.party, key)
	E.OnKey(M.enemies, key)
	if key == "group.hideblizz" then
		if value then
			M.HideBlizzard()
		elseif M.blizzHidden then
			SUI.Print(L("msg.reload"))
		end
	end
	if key == nil or key == "ui.locked" then
		E.SyncLock(M.party)
		E.SyncLock(M.enemies)
	end
end

function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("", function(key, value)
			if key == nil or key == "ui.locked" or key == "ui.locale" or sfind(key, "^group%.") then M.OnKey(key, value) end
		end)
	end
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTargetAuto)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnClearPins)
	SUI.On("PLAYER_ENTERING_WORLD", M.ClearPins)
	SUI.WhenSafe(function()
		if not M.on then return end
		E.ReadConfig(M.party)
		E.ReadConfig(M.enemies)
		E.Build(M.party)
		E.Build(M.enemies)
		E.Activate(M.party)
		E.Activate(M.enemies)
		if C.Get("group.hideblizz") then M.HideBlizzard() end
	end)
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTargetAuto)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnClearPins)
	SUI.Off("PLAYER_ENTERING_WORLD", M.ClearPins)
	E.Deactivate(M.party)
	E.Deactivate(M.enemies)
	-- les cadres de groupe du jeu ont perdu leurs evenements : seul un /reload les rend (dit une seule fois)
	if M.blizzHidden and not M.blizzNotified then
		M.blizzNotified = true
		SUI.Print(L("msg.reload"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("group", 27)

local function opt(key, typ, order, def, extra)
	local o = { key = "group." .. key, type = typ, cat = "group", label = "opt.group." .. key, tip = "tip.group." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local GROUP_OPTIONS = {
		opt("solo", "bool", 10, false, { simple = true }),
		opt("hideinraid", "bool", 20, true),
		opt("pets", "bool", 30, false),
		opt("width", "number", 40, 100, { min = 50, max = 220, step = 2, simple = true }),
		opt("height", "number", 50, 34, { min = 16, max = 80, step = 2, simple = true }),
		opt("powerheight", "number", 60, 4, { min = 0, max = 12, step = 1 }),
		opt("manabar", "choice", 61, "all", { choices = { "none", "healers", "casters", "all" } }),
		opt("manahunter", "bool", 62, false),
		opt("manatext", "bool", 63, false),
		opt("spacing", "number", 70, 2, { min = 0, max = 20, step = 1 }),
		opt("sort", "choice", 80, "none", { choices = { "none", "role", "class", "name" } }),
		opt("orient", "choice", 90, "vertical", { choices = { "vertical", "horizontal" } }),
		opt("hpcolor", "choice", 100, "class", { choices = { "class", "health", "style", "custom" }, simple = true }),
		opt("hptext", "choice", 110, "percent", { choices = { "none", "percent", "value", "deficit", "deficitpct", "both" }, simple = true }),
		opt("namelen", "number", 120, 10, { min = 4, max = 16, step = 1 }),
		opt("nameanchor", "choice", 121, "topleft", { choices = { "topleft", "topcenter", "topright", "left", "center", "right", "bottomleft", "bottomcenter", "bottomright" }, simple = true }),
		opt("nameicons", "choice", 122, "dispel", { choices = { "off", "dispel", "fx", "both" } }),
		opt("range", "bool", 130, true, { simple = true }),
		opt("rangeyd", "number", 140, 40, { min = 10, max = 60, step = 5 }),
		opt("outalpha", "number", 150, 0.45, { min = 0.2, max = 1, step = 0.05 }),
		opt("debuffs", "number", 160, 3, { min = 0, max = 4, step = 1, simple = true }),
		opt("buffs", "number", 170, 0, { min = 0, max = 6, step = 1 }),
		opt("hots", "number", 172, 2, { min = 0, max = 4, step = 1, simple = true }),
		opt("hotall", "bool", 174, false),
		opt("iconsize", "number", 180, 12, { min = 8, max = 20, step = 1 }),
		opt("dispelmode", "choice", 190, "known", { choices = { "known", "all", "off" }, simple = true }),
		opt("dispelonly", "bool", 200, false),
		opt("dispelstyle", "choice", 202, "both", { choices = { "split", "stripe", "frame", "both", "none" }, simple = true }),
		opt("dispelprio", "choice", 204, "magic", { choices = { "magic", "curse", "poison", "disease" } }),
		opt("dispelbig", "bool", 205, true, { simple = true }),
		opt("dispelsize", "number", 206, 20, { min = 10, max = 32, step = 1 }),
		opt("dispelpos", "choice", 207, "center", { choices = { "center", "right", "left" } }),
		opt("dispelbigmax", "number", 207.1, 1, { min = 1, max = 3, step = 1 }),
		opt("dispelsmall", "bool", 207.2, false, { simple = true }),
		opt("dispelsmallpos", "choice", 207.3, "bottomleft", { choices = { "bottomleft", "bottomright", "topright" } }),
		opt("dispelsmallsize", "number", 207.4, 9, { min = 6, max = 14, step = 1 }),
		opt("dispelthick", "number", 207.5, 2, { min = 1, max = 4, step = 1 }),
		opt("fxframes", "bool", 211, true, { simple = true }),
		opt("fxsize", "number", 212, 22, { min = 12, max = 32, step = 1 }),
		opt("fxpos", "choice", 213, "left", { choices = { "left", "center", "right" } }),
		opt("fxmax", "number", 214, 2, { min = 1, max = 3, step = 1 }),
		opt("aggroframes", "bool", 215, true, { simple = true }),
		opt("tankhots", "number", 173, 0, { min = 0, max = 4, step = 1 }),
		opt("hotwarn", "number", 175, 3, { min = 0, max = 10, step = 1 }),
		opt("lowhp", "number", 112, 0, { min = 0, max = 80, step = 5 }),
		opt("healpreset", "choice", 5, "off", { choices = { "off", "apply" }, simple = true }),
		opt("aggro", "bool", 210, true),
		opt("incoming", "bool", 220, true),
		opt("incsrc", "choice", 221, "all", { choices = { "me", "all" } }),
		opt("resinfo", "bool", 225, true),
		opt("roletag", "bool", 230, true),
		opt("leader", "bool", 240, true),
		opt("marks", "bool", 250, true),
		opt("target", "bool", 260, true),
		opt("tooltip", "bool", 270, true),
		opt("alerts", "bool", 280, true),
		opt("alertsound", "choice", 290, "none", { choices = { "none", "self", "any" } }),
		opt("alertlist", "string", 300, ""),
		opt("roles", "string", 310, ""),
		opt("roleguess", "choice", 320, "none", { choices = { "none", "class" } }),
		opt("budget", "number", 330, 10, { min = 1, max = 40, step = 1 }),
		opt("slowstep", "number", 340, 10, { min = 1, max = 40, step = 1 }),
		opt("hideblizz", "bool", 350, true, { reload = true }),
		opt("enemies", "number", 360, 0, { min = 0, max = 4, step = 1 }),
		opt("enemyauto", "choice", 370, "off", { choices = { "off", "boss" } }),
		opt("enemywidth", "number", 380, 160, { min = 100, max = 300, step = 5 }),
		opt("enemyheight", "number", 390, 22, { min = 14, max = 50, step = 2 }),
		-- 5e passe (soigneur) : disposition, textes, transparences, ligne de vue, couleurs, listes de HoT
		opt("fill", "choice", 91, "tl", { choices = { "tl", "tr", "bl", "br" } }),
		opt("hpcustom", "color", 101, ""),
		opt("deadcolor", "color", 102, ""),
		opt("inccolor", "color", 103, ""),
		opt("hppos", "choice", 111, "right", { choices = { "topleft", "topcenter", "topright", "left", "center", "right", "bottomleft", "bottomcenter", "bottomright" }, simple = true }),
		opt("manapos", "choice", 64, "center", { choices = { "left", "center", "right" } }),
		opt("manacontent", "choice", 65, "percent", { choices = { "percent", "value", "deficit" } }),
		opt("deadalpha", "number", 151, 0, { min = 0, max = 1, step = 0.05 }),
		opt("offalpha", "number", 152, 0, { min = 0, max = 1, step = 0.05 }),
		opt("los", "bool", 153, false),
		opt("losalpha", "number", 154, 0.6, { min = 0.1, max = 1, step = 0.05 }),
		opt("markpos", "choice", 251, "topleft", { choices = { "topleft", "topcenter", "center" } }),
		opt("marksize", "number", 252, 0, { min = 0, max = 24, step = 1 }),
		opt("hotlist", "string", 176, ""),
		opt("hotoff", "string", 177, ""),
		-- 6e passe : role / chef place et dimensionne
		opt("tagpos", "choice", 231, "topright", { choices = { "topright", "topleft", "bottomright", "bottomleft" } }),
		opt("tagsize", "number", 232, 9, { min = 7, max = 16, step = 1 }),
}
-- Aspect : texture des barres, police et taille des textes (group.bartex / group.font / group.fontsize), meme systeme que les autres modules.
if SUI.Look then
	local lk = SUI.Look.Options("group", { bar = true, font = true, cat = "group", order = 820 })
	for i = 1, getn(lk) do tinsert(GROUP_OPTIONS, lk[i]) end
end

SUI.RegisterModule("group", {
	default = false,
	cost = "medium",
	options = GROUP_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : le module "group" (cadres de groupe).
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.group then SUI.Migrate.MAP.group = { "group" } end

-- Mode Raid (groupe de 5 dans un raid / donjon difficile) : plus compact, pas de buffs, debuffs a dissiper seulement.
SUI.Config.AddPreset("raid", "*", { ["group.buffs"] = 0, ["group.debuffs"] = 2, ["group.dispelonly"] = true, ["group.width"] = 90,
	["group.height"] = 30, ["group.budget"] = 12 })

-- Reglage "Appliquer le preset Soigneur" du menu : une valeur "apply" declenche le preset puis revient seule a "off".
C.Watch("group.healpreset", function(key, value)
	if value ~= "apply" then return end
	local n, kept = E.HealPreset(false)
	SUI.Print(L("msg.group.heal.applied", n, kept))
	C.Set("group.healpreset", "off")
end)

-- /sui heal [force|reset|tank [Nom]|untank [Nom]]
SUI.RegisterCommand("heal", function(rest)
	local w = words(rest)
	local sub = w[1]
	if sub == "reset" then
		SUI.Print(L("msg.group.heal.reset", E.HealPresetReset()))
	elseif sub == "tank" then
		E.HealTank(w[2], true)
	elseif sub == "untank" then
		E.HealTank(w[2], false)
	elseif sub == nil or sub == "" or sub == "force" or sub == "apply" then
		local n, kept = E.HealPreset(sub == "force")
		SUI.Print(L("msg.group.heal.applied", n, kept))
	else
		SUI.Print(L("msg.group.heal.usage"))
	end
end, "help.group.heal")

SUI.RegisterCommand("group", function(rest)
	local w = words(rest)
	local sub = w[1]
	if sub == "alert" then
		E.CmdAlert(M.party, w)
	elseif sub == "role" then
		E.CmdRole(M.party, { "role", w[2], w[3] })
	elseif sub == "pin" then
		if not SUI.Api.superwow then
			SUI.Print(L("msg.group.needsw"))
			return
		end
		local ok, why = M.Pin(targetGuid())
		SUI.Print(L(ok and "msg.group.pinned" or ("msg.group.pin." .. tostring(why))))
	elseif sub == "unpin" then
		local guid = targetGuid()
		SUI.Print(L(guid and M.Unpin(guid) and "msg.group.unpinned" or "msg.group.pin.none"))
	elseif sub == "clearpins" then
		M.ClearPins()
		SUI.Print(L("msg.group.pinscleared"))
	else
		local g = M.party
		SUI.Print(L("msg.group.info", g.nOrder, M.enemies.nPins, g.qn, g.nAlerts))
	end
end, "help.group")
