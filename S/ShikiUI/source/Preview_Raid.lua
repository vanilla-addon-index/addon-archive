-- ShikiUI Preview_Raid : apercu 2D des cadres de RAID (module "raid") et de GROUPE (module "group") dans le volet d'apercu du menu.
-- Un roster de FAUX joueurs deterministe (40 noms, classes, roles, vies variees, un mort, un hors ligne, des hors portee, de l'aggro, des
-- debuffs dissipables Magie / Malediction / Poison / Maladie, des HoTs, des soins entrants) est dessine selon les VRAIS reglages : taille de
-- cadre, espacement, tri, orientation, lignes, groupes visibles, noms, texte de vie, puissance, portee, icones, dissipation, marqueurs...
-- La grille suit la geometrie de SUI.GroupEngine.Arrange (Mod_Group.lua) a l'echelle (reduction uniforme) ; un cadre AGRANDI (le joueur
-- clique dans la grille, ou un exemple complet) montre chaque element : un clic sur un element saute a l'option qui le regle.
-- Aucun cadre du jeu n'est touche ; tout est cree dans build (hors combat) ; update ne cree rien (40 cadres + 4 de demonstration, prepares).
-- 4e passe : pseudo place librement (+ petites icones a cote), grosses icones de dissipation (1 a 3), petites icones en ligne, contour
-- decoupe en parts egales (meme fonction que les vrais cadres : SUI.GroupEngine.SplitLayout), effets de boss simules (SUI.GroupFx.Sample,
-- icone + minuteur + teinte) et aggro simulee (cadre rouge + icone pour un non-tank, fine barre pour un tank) : ce sont des EXEMPLES, lus
-- avec les vrais reglages group.* / raid.* et groupfx.* (le menu redessine en direct).
-- NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config
local P = SUI.Preview

local getn, tinsert = table.getn, table.insert
local floor = math.floor
local sfind = string.find

local R = {}
SUI.PreviewRaid = R

-- ---------------------------------------------------------------- donnees de test (faux joueurs)
local LINES = {
	"Thorgrim:WARRIOR:T", "Elaria:PRIEST:H", "Brannok:WARRIOR:T", "Mirelle:MAGE:D", "Zulkar:ROGUE:D",
	"Aldric:PALADIN:H", "Nyssa:HUNTER:D", "Gorrak:SHAMAN:H", "Velkhan:WARLOCK:D", "Sylvie:DRUID:H",
	"Dunmar:PALADIN:T", "Isolde:PRIEST:H", "Kaelen:MAGE:D", "Rhogar:ROGUE:D", "Tamsin:WARLOCK:D",
	"Orwin:HUNTER:D", "Lysa:DRUID:H", "Baldur:SHAMAN:H", "Fenwick:MAGE:D", "Ysolde:PRIEST:H",
	"Hadrian:WARRIOR:D", "Morwen:PALADIN:H", "Ragnor:ROGUE:D", "Selene:HUNTER:D", "Cormac:WARLOCK:D",
	"Elowen:DRUID:H", "Garrick:SHAMAN:D", "Perrin:MAGE:D", "Nimue:PRIEST:H", "Thandor:WARRIOR:D",
	"Vesper:ROGUE:D", "Alwyn:HUNTER:D", "Brynja:SHAMAN:H", "Darian:WARLOCK:D", "Eirlys:MAGE:D",
	"Falkor:PALADIN:D", "Gwynn:DRUID:D", "Hroth:WARRIOR:D", "Ilsabet:PRIEST:H", "Jorund:ROGUE:D",
}
local HPR = { 1, 0.92, 0.7, 1, 0.45, 0.85, 1, 0.62, 0.97, 0.3 }       -- vies cycliques (rapport vie / vie max)
local DEBS = {                                                         -- debuffs par joueur ("" = sans type, non dissipable)
	[2] = { "" }, [4] = { "Magic" }, [9] = { "Curse" }, [14] = { "Poison", "Magic" }, [17] = { "Magic" }, [21] = { "Disease" },
	[27] = { "Magic", "Poison", "Curse" }, [31] = { "Disease", "Curse" }, [36] = { "Poison" },
}
local MARKS = { [1] = 1, [3] = 8, [11] = 5 }                          -- marqueurs de raid (etoile, crane, lune)
local PRIO = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease" }
local TYPES = { "Magic", "Curse", "Poison", "Disease" }
local ROLERANK = { T = 1, H = 2, D = 3 }
local KEYS = { maxgroup = 8, width = 64, height = 28, powerheight = 0, spacing = 1, groupgap = 6, sort = "group", orient = "vertical",
	perline = 5, hpcolor = "class", hptext = "deficit", namelen = 6, range = true, outalpha = 0.45, debuffs = 2, buffs = 0, hots = 2,
	iconsize = 10, dispelmode = "known", dispelonly = true, dispelstyle = "both", dispelprio = "magic", aggro = true, incoming = true,
	resinfo = true, roletag = false, leader = true, marks = true, target = true, nameanchor = "topleft", nameicons = "dispel", dispelbig = true,
	dispelbigmax = 1, dispelsize = 20, dispelpos = "center", dispelsmall = false, dispelsmallpos = "bottomleft", dispelsmallsize = 9,
	dispelthick = 2, fxframes = true, fxsize = 20, fxpos = "left", fxmax = 2, aggroframes = true,
	-- 5e passe (soigneur) : memes valeurs de repli que SUI.GroupEngine.CFGKEYS
	fill = "tl", grpperline = 8, grouptitle = false, hppos = "right", manapos = "center", manacontent = "percent", manatext = false,
	deadalpha = 0, offalpha = 0, los = false, losalpha = 0.6, markpos = "topleft", marksize = 0, hpcustom = "", deadcolor = "", inccolor = "",
	autosize = false, scale20 = 0.9, scale25 = 0.8, scale40 = 0.7, tagpos = "topright", tagsize = 9,
	-- 7e passe (apercu cliquable) : barre de mana par role / classe, HoTs des tanks, vie basse
	manabar = "all", manahunter = false, tankhots = 0, lowhp = 0 }
local ZKEY = { frame = "width", hp = "hpcolor", heal = "incoming", power = "powerheight", name = "nameanchor", hptext = "hptext", tag = "roletag",
	mark = "marks", dispel = "dispelstyle", deb = "debuffs", hot = "hots", buf = "buffs", aggro = "aggro", far = "range", dead = "deadalpha",
	off = "offalpha", nic = "nameicons", big = "dispelbigmax", small = "dispelsmall", fx = "fxframes", agg = "aggroframes" }
local ZORDER = { "frame", "hp", "heal", "power", "name", "hptext", "tag", "mark", "dispel", "deb", "hot", "buf", "aggro", "nic", "big", "small",
	"fx", "agg" }
-- Reglages modifiables sur place (mini-panneau) pour chaque element de l'apercu : suffixes du module (group. / raid.), ou "@cle" absolue.
-- Les reglages absents d'un module (ex. groupgap pour le groupe) sont ignores par le panneau ; 7 lignes au plus.
local ZPANEL = {
	frame = { "width", "height", "autosize", "spacing", "groupgap", "perline" },
	hp = { "hpcolor", "bartex", "lowhp" },
	heal = { "incoming", "incsrc" },
	power = { "powerheight", "manabar", "manahunter", "manatext", "manapos", "manacontent" },
	name = { "nameanchor", "namelen", "nameicons", "fontsize" },
	hptext = { "hptext", "hppos", "lowhp", "fontsize" },
	tag = { "roletag", "leader", "tagpos", "tagsize" },
	mark = { "marks", "markpos", "marksize" },
	dispel = { "dispelmode", "dispelstyle", "dispelprio", "dispelonly", "dispelthick" },
	deb = { "debuffs", "iconsize", "dispelonly" },
	hot = { "hots", "tankhots", "hotall", "hotwarn", "iconsize" },
	buf = { "buffs", "iconsize" },
	aggro = { "aggro", "target" },
	nic = { "nameicons", "dispelsmallsize" },
	big = { "dispelbig", "dispelbigmax", "dispelsize", "dispelpos" },
	small = { "dispelsmall", "dispelsmallpos", "dispelsmallsize" },
	fx = { "fxframes", "fxsize", "fxpos", "fxmax", "@groupfx.fx.icon", "@groupfx.fx.tint", "@groupfx.fx.timer" },
	agg = { "aggroframes", "@groupfx.aggromode", "@groupfx.aggro.frame", "@groupfx.aggro.icon", "@groupfx.aggro.tank" },
	far = { "range", "outalpha", "rangeyd", "los", "losalpha" },
	dead = { "deadalpha", "deadcolor", "resinfo" },
	off = { "offalpha" },
	gap = { "spacing", "groupgap", "orient", "perline" },
	sort = { "sort", "orient", "fill", "perline", "grpperline", "grouptitle", "maxgroup" },
	gt = { "grouptitle", "sort", "grpperline" },
}
local ZALL = { "gap", "sort", "far", "dead", "off" }          -- elements hors cadre agrandi (en plus de ZORDER ; les titres "gt" a part)

R.roster = {}
for i = 1, getn(LINES) do
	local _, _, nm, cl, ro = sfind(LINES[i], "^(%a+):(%a+):(%a)$")
	local sub = floor((i - 1) / 5) + 1
	local hpr = HPR[SUI.Mod(i * 3, 10) + 1]
	local mx = (ro == "T") and 9000 or 4600
	local p = { name = nm, class = cl, role = ro, sub = sub, idx = i, hpr = hpr, hpmax = mx, state = 0, far = false, aggro = false, target = false,
		inc = 0, deb = DEBS[i] or {}, hots = SUI.Mod(i, 4), bufs = SUI.Mod(i, 3), mark = MARKS[i], rank = 0, pr = 0.35 + 0.6 * HPR[SUI.Mod(i * 7, 10) + 1],
		ptype = 0 }
	if cl == "WARRIOR" then p.ptype = 1 elseif cl == "ROGUE" then p.ptype = 3 end
	if hpr < 0.9 and SUI.Mod(i, 2) == 0 then p.inc = 0.18 end
	R.roster[i] = p
end
R.roster[1].rank = 2
R.roster[2].rank = 1
R.roster[6].rank = 1
R.roster[7].hpr, R.roster[7].state = 0, 1         -- un mort
R.roster[13].state = 2                            -- un hors ligne
R.roster[19].far, R.roster[26].far, R.roster[33].far = true, true, true     -- trois hors portee
R.roster[8].los, R.roster[15].los, R.roster[29].los = true, true, true      -- trois a portee mais hors ligne de vue (reglage los)
R.roster[3].aggro = true                          -- un en aggro
R.roster[4].target = true                         -- une cible
-- effets de boss et aggro d'exemple (indices de SUI.GroupFx.ORDER : 1 = bombe vivante, 2 = adrenaline brulante, 3 = panique) ; fxt = secondes
local NOFX = {}
for i = 1, getn(R.roster) do R.roster[i].fx, R.roster[i].fxt, R.roster[i].ag = NOFX, NOFX, nil end
R.roster[1].ag = "tank"                           -- un tank qui a l'aggro : discret
R.roster[2].fx, R.roster[2].fxt = { 1 }, { 6 }    -- un soigneur avec la bombe
R.roster[4].fx, R.roster[4].fxt = { 2 }, { 14 }
R.roster[5].ag = "off"                            -- un voleur qui a l'aggro : alerte
R.roster[10].fx, R.roster[10].fxt = { 1, 2 }, { 3, 18 }
R.roster[21].ag = "off"
R.roster[22].fx, R.roster[22].fxt = { 3 }, { 7 }

-- Joueur d'exemple complet (cadre agrandi) et ses variantes d'etat.
local function copyOf(p)
	local q = {}
	for k, v in pairs(p) do q[k] = v end
	return q
end
R.demo = { name = "Elaria", class = "PRIEST", role = "H", sub = 1, idx = 0, hpr = 0.58, hpmax = 4800, state = 0, far = false, aggro = true,
	target = false, inc = 0.2, deb = { "Magic", "Curse", "Poison", "Disease" }, hots = 4, bufs = 6, mark = 8, rank = 2, pr = 0.7, ptype = 0 }
R.demoFar = copyOf(R.demo)
R.demo.fx, R.demo.fxt, R.demo.ag = { 1, 2 }, { 8, 20 }, "off"
R.demoFar.far, R.demoFar.aggro, R.demoFar.mark, R.demoFar.deb = true, false, nil, { "Magic" }
R.demoFar.fx, R.demoFar.fxt, R.demoFar.ag = { 1 }, { 6 }, nil
R.demoDead = copyOf(R.demo)
R.demoDead.state, R.demoDead.hpr, R.demoDead.aggro, R.demoDead.deb, R.demoDead.mark = 1, 0, false, {}, nil
R.demoDead.fx, R.demoDead.fxt, R.demoDead.ag = NOFX, NOFX, nil
R.demoDead.res = true                             -- mort en cours de resurrection (reglage resinfo)
R.demoOff = copyOf(R.demo)
R.demoOff.state, R.demoOff.aggro, R.demoOff.deb, R.demoOff.mark = 2, false, {}, nil
R.demoOff.fx, R.demoOff.fxt, R.demoOff.ag = NOFX, NOFX, nil

-- ---------------------------------------------------------------- reglages reels
local function readCfg(prefix, cfg)
	for k, d in pairs(KEYS) do
		local v = C.Get(prefix .. k)
		if v == nil then v = d end
		cfg[k] = v
	end
	cfg.ns = (prefix == "raid.") and "raid" or "group"
	cfg.rw, cfg.rh, cfg.ri = cfg.width, cfg.height, cfg.iconsize          -- tailles reglees (la densite automatique en derive, voir layoutAll)
	-- couleurs personnalisees, police et texture du module (memes lectures que les vrais cadres)
	local E = SUI.GroupEngine
	if not cfg.cHp then cfg.cHp, cfg.cDead, cfg.cInc = { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } end
	cfg.colHp = E and E.ReadHex(cfg.cHp, cfg.hpcustom) or nil
	cfg.colDead = E and E.ReadHex(cfg.cDead, cfg.deadcolor) or nil
	cfg.colInc = E and E.ReadHex(cfg.cInc, cfg.inccolor) or nil
	local look = string.sub(prefix, 1, -2)
	cfg.fpath, cfg.fpx = T.Font(look)
	cfg.btex = T.BarTexture(look)
	-- reglages d'affichage de SUI.GroupFx (le module peut etre coupe : l'apercu montre quand meme ce qu'il donnerait)
	cfg.gIcon = C.Get("groupfx.fx.on") ~= false and C.Get("groupfx.fx.icon") ~= false
	cfg.gTint = C.Get("groupfx.fx.on") ~= false and C.Get("groupfx.fx.tint") ~= false
	cfg.gTimer = C.Get("groupfx.fx.on") ~= false and C.Get("groupfx.fx.timer") ~= false
	local am = C.Get("groupfx.aggromode") or "target"
	cfg.gAgFrame = am ~= "off" and C.Get("groupfx.aggro.frame") ~= false
	cfg.gAgIcon = am ~= "off" and C.Get("groupfx.aggro.icon") ~= false
	cfg.gAgTank = am ~= "off" and C.Get("groupfx.aggro.tank") == true
	return cfg
end

-- ---------------------------------------------------------------- tri et rangement (meme geometrie que SUI.GroupEngine.Arrange)
local curSort = "none"
local function less(a, b)
	if curSort == "group" then
		if a.sub ~= b.sub then return a.sub < b.sub end
	elseif curSort == "role" then
		local ra, rb = ROLERANK[a.role] or 3, ROLERANK[b.role] or 3
		if ra ~= rb then return ra < rb end
	elseif curSort == "class" then
		if a.class ~= b.class then return a.class < b.class end
	elseif curSort == "name" then
		if a.name ~= b.name then return a.name < b.name end
	end
	return a.idx < b.idx
end

-- Remplit st.ord / st.px / st.py (coordonnees logiques) pour les n premiers joueurs ; retourne le nombre affiche, largeur, hauteur totales.
function R.Arrange(st, cfg, n, kind)
	local ord = st.ord
	local cnt = 0
	for i = 1, n do
		local p = R.roster[i]
		if kind ~= "raid" or p.sub <= cfg.maxgroup then
			cnt = cnt + 1
			ord[cnt] = p
		end
	end
	curSort = cfg.sort
	for i = 2, cnt do
		local p = ord[i]
		local j = i - 1
		while j >= 1 and less(p, ord[j]) do
			ord[j + 1] = ord[j]
			j = j - 1
		end
		ord[j + 1] = p
	end
	-- meme fonction de geometrie que les vrais cadres (SUI.GroupEngine.Layout) : coin de depart, groupes par ligne, titres de groupe
	local E = SUI.GroupEngine
	if not (E and type(E.Layout) == "function") then return cnt, cfg.width, cfg.height end
	if not st.tx then st.tx, st.ty, st.tj = {}, {}, {} end
	local maxX, maxY = E.Layout(cfg, ord, cnt, st.px, st.py, st.tx, st.ty, st.tj)
	return cnt, maxX, maxY
end

-- ---------------------------------------------------------------- cadre d'un joueur
local function newCell(parent, caps, clickable)
	local c = CreateFrame(clickable and "Button" or "Frame", nil, parent)
	c.edge = P.NewTex(c, "BACKGROUND")
	c.bg = P.NewTex(c, "BACKGROUND")
	c.heal = P.NewTex(c, "BORDER")
	c.hp = P.NewTex(c, "ARTWORK")
	c.pw = P.NewTex(c, "ARTWORK")
	c.dhl = P.NewTex(c, "ARTWORK")
	c.hl = P.NewTex(c, "ARTWORK")
	c.dtx = P.NewTex(c, "OVERLAY")
	c.de, c.di, c.hi, c.bi = {}, {}, {}, {}
	for k = 1, caps[1] do
		c.de[k] = P.NewTex(c, "OVERLAY")
		c.di[k] = P.NewTex(c, "OVERLAY")
	end
	for k = 1, caps[3] do c.hi[k] = P.NewTex(c, "OVERLAY") end
	for k = 1, caps[2] do c.bi[k] = P.NewTex(c, "OVERLAY") end
	-- contour decoupe / bordure, grosses et petites icones de dissipation, icones a cote du pseudo
	c.sp, c.bge, c.bgi, c.sme, c.smi, c.nic = {}, {}, {}, {}, {}, {}
	for k = 1, 8 do c.sp[k] = P.NewTex(c, "OVERLAY") end
	for k = 1, 3 do
		c.bge[k] = P.NewTex(c, "OVERLAY")
		c.bgi[k] = P.NewTex(c, "OVERLAY")
		c.nic[k] = P.NewTex(c, "OVERLAY")
	end
	for k = 1, 4 do
		c.sme[k] = P.NewTex(c, "OVERLAY")
		c.smi[k] = P.NewTex(c, "OVERLAY")
	end
	-- effets de boss (teinte, icones, minuteurs) et aggro
	c.fxhl = P.NewTex(c, "ARTWORK")
	c.fxe, c.fxi, c.fxt = {}, {}, {}
	for k = 1, 3 do
		c.fxe[k] = P.NewTex(c, "OVERLAY")
		c.fxi[k] = c:CreateTexture(nil, "OVERLAY")
		c.fxi[k]:SetTexture(T.tex.white)
		c.fxt[k] = T.Text(c, 9, T.c.text, "CENTER", true)
	end
	c.aghl = P.NewTex(c, "ARTWORK")
	c.agbar = P.NewTex(c, "OVERLAY")
	c.agic = P.NewTex(c, "OVERLAY")
	c.agtx = T.Text(c, 10, T.c.text, "CENTER", true)
	c.mk = c:CreateTexture(nil, "OVERLAY")
	c.mk:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	c.name = T.Text(c, 10, T.c.text, "LEFT", true)
	c.hpt = T.Text(c, 10, T.c.text, "RIGHT", true)
	c.stt = T.Text(c, 10, T.c.warn, "CENTER", true)
	c.tag = T.Text(c, 9, T.c.warn, "RIGHT", true)
	c.pwt = T.Text(c, 8, T.c.text, "CENTER", true)
	c.rc = {}
	for i = 1, getn(ZORDER) do c.rc[ZORDER[i]] = { 0, 0, 0, 0 } end
	c:Hide()
	return c
end

local function rect(c, key, x, y, w, h)
	local r = c.rc[key]
	r[1], r[2], r[3], r[4] = x, y, w, h
end

-- Police du module (<module>.font) a la taille voulue ; repli : police du style.
local function pfont(fs, size, cfg)
	if size < 6 then size = 6 end
	pcall(fs.SetFont, fs, cfg.fpath or T.font, size * (cfg.fpx and 1 or (T.fontScale or 1)), T.outline)
end

local function classColor(class)
	local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if col then return col.r, col.g, col.b end         -- couleur de classe (donnee de jeu)
	return T.c.dim[1], T.c.dim[2], T.c.dim[3]
end

local function hpColor(cfg, p, ratio)
	if p.state ~= 0 then
		local d = cfg.colDead or T.c.dim
		return d[1], d[2], d[3]
	end
	if cfg.hpcolor == "class" then return classColor(p.class) end
	if cfg.hpcolor == "custom" and cfg.colHp then return cfg.colHp[1], cfg.colHp[2], cfg.colHp[3] end
	if cfg.hpcolor == "health" then
		local a, b, t
		if ratio > 0.5 then
			a, b, t = T.c.good, T.c.warn, (1 - ratio) * 2
		else
			a, b, t = T.c.warn, T.c.bad, (0.5 - ratio) * 2
		end
		return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
	end
	return T.c.good[1], T.c.good[2], T.c.good[3]
end

local function debCol(tp)
	local E = SUI.GroupEngine
	local col = E and E.DEBUFF_COL and E.DEBUFF_COL[tp]
	if col then return col[1], col[2], col[3] end
	return T.c.bad[1], T.c.bad[2], T.c.bad[3]
end

local function powerCol(pt)
	local E = SUI.GroupEngine
	local col = E and E.POWER_COL and E.POWER_COL[pt]
	if col then return col[1], col[2], col[3] end
	return T.c.dim[1], T.c.dim[2], T.c.dim[3]
end

-- Le joueur p a-t-il une barre de mana ? Meme regle que SUI.GroupEngine.ManaWanted : "all" toutes les ressources, "none" aucune, sinon
-- seulement la mana, selon le role (H force la barre, T / D la retirent en mode "healers") et la classe. Mort / hors ligne : pas de barre.
local function wantPower(cfg, p)
	if cfg.powerheight <= 0 or p.state ~= 0 then return false end
	local mode = cfg.manabar
	if mode == "all" then return true end
	if mode == "none" or p.ptype ~= 0 then return false end
	if p.role == "H" then return true end
	local E = SUI.GroupEngine
	if mode == "healers" then
		if p.role == "T" or p.role == "D" then return false end
		return not (E and E.HEALER_CLASS) or E.HEALER_CLASS[p.class] == true
	end
	if not (E and E.CASTER_CLASS) then return true end
	if E.CASTER_CLASS[p.class] then return true end
	return (p.class == "HUNTER" and cfg.manahunter) and true or false
end

local function hpString(cfg, hp, mx)
	local E = SUI.GroupEngine
	if E and type(E.HpText) == "function" then return E.HpText(cfg.hptext, hp, mx, false) end
	if cfg.hptext == "none" then return "" end
	return floor(hp / mx * 100 + 0.5) .. "%"
end

local function cutName(nm, n)
	local E = SUI.GroupEngine
	if E and type(E.Cut) == "function" then return E.Cut(nm, n) end
	return string.sub(nm, 1, n)
end

local function markCoords(t, idx)
	local col = SUI.Mod(idx - 1, 4)
	local row = floor((idx - 1) / 4)
	t:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

-- Types a dissiper presents sur p, du plus prioritaire au moins prioritaire (le type de dispelprio d'abord, puis Magie, Malediction,
-- Poison, Maladie) : remplit out[1..n] et renvoie n. Aucun type si la dissipation est coupee ou si le joueur est mort / hors ligne.
local function dispelList(cfg, p, out)
	if cfg.dispelmode == "off" or p.state ~= 0 then return 0 end
	local want = PRIO[cfg.dispelprio]
	local n = 0
	for pass = 1, 2 do
		for i = 1, getn(TYPES) do
			local tp = TYPES[i]
			if (pass == 1) == (tp == want) then
				for j = 1, getn(p.deb) do
					if p.deb[j] == tp then
						n = n + 1
						out[n] = tp
						break
					end
				end
			end
		end
	end
	return n
end

local TY = {}                 -- types du cadre en cours de dessin
local SEG = {}                -- segments du contour decoupe (tables creees une seule fois)
for i = 1, 8 do SEG[i] = { k = 0, x = 0, y = 0, w = 0, h = 0 } end
-- Place du pseudo : { ligne (1 haut, 2 milieu, 3 bas), colonne (1 gauche, 2 centre, 3 droite) } (memes noms que SUI.GroupEngine.NAME_AT).
local NAMEAT = { topleft = { 1, 1 }, topcenter = { 1, 2 }, topright = { 1, 3 }, left = { 2, 1 }, center = { 2, 2 }, right = { 2, 3 },
	bottomleft = { 3, 1 }, bottomcenter = { 3, 2 }, bottomright = { 3, 3 } }
local JUST = { "LEFT", "CENTER", "RIGHT" }

-- Effet de boss d'exemple numero k du joueur p (SUI.GroupFx.Sample) ; nil si le module d'effets est absent.
local function fxRec(p, k)
	local G = SUI.GroupFx
	local idx = p.fx[k]
	if not idx or not G or type(G.Sample) ~= "function" then return nil end
	return G.Sample(idx)
end

local function fxColor(rec)
	local G = SUI.GroupFx
	if G and type(G.Color) == "function" then return G.Color(rec) end
	return T.c.bad[1], T.c.bad[2], T.c.bad[3]
end

-- Contour decoupe (style "split") ou bordure unie (marque "cadre" avec grosse icone) : memes segments que les vrais cadres.
local function paintOutline(c, cfg, s, w, h, nt)
	local E = SUI.GroupEngine
	local m = 0
	local style = cfg.dispelstyle
	if nt > 0 and E and type(E.SplitLayout) == "function" then
		if style == "split" then
			local th = floor(cfg.dispelthick * s + 0.5)
			if th < 1 then th = 1 end
			m = E.SplitLayout(w, h, th, nt, SEG)
		elseif cfg.dispelbig and (style == "frame" or style == "both") then
			local th = floor(2 * s + 0.5)
			if th < 1 then th = 1 end
			m = E.SplitLayout(w, h, th, 1, SEG)
		end
	end
	for i = 1, 8 do
		local t = c.sp[i]
		if i <= m then
			local r = SEG[i]
			local dr, dg, db = debCol(TY[r.k])
			t:SetVertexColor(dr, dg, db, 1)
			P.Box(t, c, r.x, r.y, r.w, r.h)
		else
			t:Hide()
		end
	end
end

-- Abscisse de la k-ieme grosse icone (dissipation ou effet de boss) selon la place choisie ; cnt = nombre affiche (centrage).
local function rowX(pos, w, s, sz, gap, k, cnt, padL)
	if pos == "right" then return w - floor(2 * s + 0.5) - (sz + 2) - (k - 1) * gap end
	if pos == "left" then return floor(padL * s + 0.5) + (k - 1) * gap end
	return floor(w / 2 + (k - (cnt + 1) / 2) * gap - (sz + 2) / 2)
end

-- Grosses icones de dissipation (1 a 3), petites icones en ligne, effets de boss (icone + minuteur + teinte) et aggro d'exemple.
-- Sauve dans c : fxN (nombre d'icones d'effets montrees), pour les petites icones a cote du pseudo.
local function paintFx(c, p, cfg, s, w, h, base, nt)
	local state = p.state
	-- grosses icones de dissipation
	local nb = 0
	if cfg.dispelbig then
		nb = nt
		if nb > cfg.dispelbigmax then nb = cfg.dispelbigmax end
	end
	local bsz = floor(cfg.dispelsize * s + 0.5)
	if bsz > h - 2 then bsz = h - 2 end
	if bsz < 2 then bsz = 2 end
	local bgap = bsz + floor(3 * s + 0.5)
	local by = floor((h - (bsz + 2)) / 2)
	local bc = nb > 0 and nb or 1
	for k = 1, 3 do
		if k <= nb then
			local x = rowX(cfg.dispelpos, w, s, bsz, bgap, k, nb, 4)
			local dr, dg, db = debCol(TY[k])
			c.bge[k]:SetVertexColor(dr, dg, db, 1)
			P.Box(c.bge[k], c, x, by, bsz + 2, bsz + 2)
			P.Fill(c.bgi[k], T.c.inset, 1)
			P.Box(c.bgi[k], c, x + 1, by + 1, bsz, bsz)
		else
			c.bge[k]:Hide()
			c.bgi[k]:Hide()
		end
	end
	local bx1, bx2 = rowX(cfg.dispelpos, w, s, bsz, bgap, 1, bc, 4), rowX(cfg.dispelpos, w, s, bsz, bgap, bc, bc, 4)
	if bx2 < bx1 then bx1, bx2 = bx2, bx1 end
	rect(c, "big", bx1, by, bx2 - bx1 + bsz + 2, bsz + 2)
	-- petites icones en ligne
	local ssz = floor(cfg.dispelsmallsize * s + 0.5)
	if ssz < 2 then ssz = 2 end
	local sgap = ssz + floor(3 * s + 0.5)
	local nsm = cfg.dispelsmall and nt or 0
	local tagres = floor((((cfg.roletag or cfg.leader) and cfg.tagpos == "topright") and 12 or 0) * s + 0.5)
	local agres = floor((cfg.aggroframes and 14 or 0) * s + 0.5)
	local sx0, sy
	for k = 1, 4 do
		local x, y
		if cfg.dispelsmallpos == "bottomright" then
			x = w - floor(2 * s + 0.5) - (ssz + 2) - (k - 1) * sgap
			y = h - (base - 1) - (ssz + 2)
		elseif cfg.dispelsmallpos == "topright" then
			x = w - floor(2 * s + 0.5) - tagres - agres - (ssz + 2) - (k - 1) * sgap
			y = floor(2 * s + 0.5)
		else
			x = floor(2 * s + 0.5) + (k - 1) * sgap
			y = h - (base - 1) - (ssz + 2)
		end
		if k == 1 then sx0, sy = x, y end
		if k <= nsm then
			local dr, dg, db = debCol(TY[k])
			c.sme[k]:SetVertexColor(dr, dg, db, 1)
			P.Box(c.sme[k], c, x, y, ssz + 2, ssz + 2)
			P.Fill(c.smi[k], T.c.inset, 1)
			P.Box(c.smi[k], c, x + 1, y + 1, ssz, ssz)
		else
			c.sme[k]:Hide()
			c.smi[k]:Hide()
		end
	end
	rect(c, "small", sx0, sy, ssz + 2, ssz + 2)
	-- effets de boss
	local nf = 0
	if state == 0 and cfg.fxframes then
		nf = getn(p.fx)
		if nf > cfg.fxmax then nf = cfg.fxmax end
	end
	local nIcon = (nf > 0 and cfg.gIcon) and nf or 0
	local fsz = floor(cfg.fxsize * s + 0.5)
	if fsz > h - 2 then fsz = h - 2 end
	if fsz < 3 then fsz = 3 end
	local fgap = fsz + floor(3 * s + 0.5)
	local fy = floor((h - (fsz + 2)) / 2)
	local fc = nIcon > 0 and nIcon or 1
	c.fxN = 0
	local fs = 9 * s
	if fs > 12 then fs = 12 end
	for k = 1, 3 do
		local rec = (k <= nIcon) and fxRec(p, k) or nil
		if rec then
			c.fxN = k
			local x = rowX(cfg.fxpos, w, s, fsz, fgap, k, nIcon, 2)
			local fr, fg, fb = fxColor(rec)
			c.fxe[k]:SetVertexColor(fr, fg, fb, 1)
			P.Box(c.fxe[k], c, x, fy, fsz + 2, fsz + 2)
			c.fxi[k]:SetTexture(rec.texture)
			c.fxi[k]:SetVertexColor(1, 1, 1, 1)
			P.Box(c.fxi[k], c, x + 1, fy + 1, fsz, fsz)
			local left = p.fxt[k] or rec.left or 0
			if cfg.gTimer and left > 0 and fsz >= 9 then
				local sec = floor(left + 0.5)
				P.Font(c.fxt[k], fs)
				c.fxt[k]:SetText(sec >= 100 and (floor(sec / 60) .. "m") or tostring(sec))
				c.fxt[k]:ClearAllPoints()
				c.fxt[k]:SetPoint("CENTER", c, "TOPLEFT", x + (fsz + 2) / 2, -(fy + (fsz + 2) / 2))
				c.fxt[k]:SetWidth(fsz + 8)
				c.fxt[k]:SetHeight(fs + 2)
				c.fxt[k]:Show()
			else
				c.fxt[k]:Hide()
			end
		else
			c.fxe[k]:Hide()
			c.fxi[k]:Hide()
			c.fxt[k]:Hide()
		end
	end
	local fx1, fx2 = rowX(cfg.fxpos, w, s, fsz, fgap, 1, fc, 2), rowX(cfg.fxpos, w, s, fsz, fgap, fc, fc, 2)
	if fx2 < fx1 then fx1, fx2 = fx2, fx1 end
	rect(c, "fx", fx1, fy, fx2 - fx1 + fsz + 2, fsz + 2)
	local rec1 = (nf > 0 and cfg.gTint) and fxRec(p, 1) or nil
	if rec1 then
		local fr, fg, fb = fxColor(rec1)
		c.fxhl:SetVertexColor(fr, fg, fb, 0.30)
		P.Box(c.fxhl, c, 0, 0, w, h)
	else
		c.fxhl:Hide()
	end
	-- aggro (SUI.GroupFx.Aggro) : cadre rouge + icone pour un non-tank, fine barre pour un tank
	local ag = (state == 0 and cfg.aggroframes) and p.ag or nil
	if ag == "off" and cfg.gAgFrame then
		P.Fill(c.aghl, T.c.bad, 0.45)
		P.Box(c.aghl, c, 0, 0, w, h)
	else
		c.aghl:Hide()
	end
	local isz = floor(12 * s + 0.5)
	if isz < 3 then isz = 3 end
	local ax, ay = w - floor(2 * s + 0.5) - tagres - isz, floor(2 * s + 0.5)
	if ag == "off" and cfg.gAgIcon then
		P.Fill(c.agic, T.c.bad, 1)
		P.Box(c.agic, c, ax, ay, isz, isz)
		if isz >= 8 then
			P.Font(c.agtx, 10 * s)
			c.agtx:SetText("!")
			c.agtx:ClearAllPoints()
			c.agtx:SetPoint("CENTER", c, "TOPLEFT", ax + isz / 2, -(ay + isz / 2))
			c.agtx:SetWidth(isz)
			c.agtx:SetHeight(isz)
			c.agtx:Show()
		else
			c.agtx:Hide()
		end
	else
		c.agic:Hide()
		c.agtx:Hide()
	end
	if ag == "tank" and cfg.gAgTank then
		local ar, agg, ab = T.Accent()
		c.agbar:SetVertexColor(ar, agg, ab, 0.8)
		P.Box(c.agbar, c, 1, 1, w - 2, floor(2 * s + 0.5) < 1 and 1 or floor(2 * s + 0.5))
	else
		c.agbar:Hide()
	end
	rect(c, "agg", ax, ay, isz, isz)
end

-- Dessine le joueur p dans la cellule c a l'echelle s (reglages cfg, plafonds caps = { debuffs, buffs, hots }).
function R.Paint(c, p, cfg, s, caps)
	local w = floor(cfg.width * s + 0.5)
	local h = floor(cfg.height * s + 0.5)
	if w < 4 then w = 4 end
	if h < 3 then h = 3 end
	c:SetWidth(w)
	c:SetHeight(h)
	local ph = wantPower(cfg, p) and cfg.powerheight or 0       -- reglage manabar : pas de barre pour ce role / cette classe
	local phpx = 0
	if ph > 0 then
		phpx = floor(ph * s + 0.5)
		if phpx < 1 then phpx = 1 end
	end
	local hpH = h - 2
	if phpx > 0 then hpH = h - 3 - phpx end
	if hpH < 1 then hpH = 1 end
	local iw = w - 2
	local state = p.state
	-- fond et bordure
	if c.sel then
		local ar, ag, ab = T.Accent()
		c.edge:SetVertexColor(ar, ag, ab, 1)
	else
		P.Fill(c.edge, T.c.border, 1)
	end
	P.Box(c.edge, c, 0, 0, w, h)
	P.Fill(c.bg, T.c.bg, 1)
	P.Box(c.bg, c, 1, 1, iw, h - 2)
	rect(c, "frame", 0, 0, w, h)
	-- vie
	local ratio = p.hpr
	local fillw = iw * ratio
	if state == 2 then fillw = iw end
	local r, g, b = hpColor(cfg, p, ratio)
	c.hp:SetTexture(cfg.btex or T.tex.white)                 -- texture de barre du module (<module>.bartex)
	c.heal:SetTexture(cfg.btex or T.tex.white)
	c.pw:SetTexture(cfg.btex or T.tex.white)
	c.hp:SetVertexColor(r, g, b, 1)
	P.Box(c.hp, c, 1, 1, fillw, hpH)
	rect(c, "hp", 1, 1, iw, hpH)
	-- soins entrants
	if cfg.incoming and p.inc > 0 and state == 0 then
		local hv = ratio + p.inc
		if hv > 1 then hv = 1 end
		P.Fill(c.heal, cfg.colInc or T.c.good, 0.45)
		P.Box(c.heal, c, 1, 1, iw * hv, hpH)
		rect(c, "heal", 1 + iw * ratio, 1, iw * (hv - ratio), hpH)
	else
		c.heal:Hide()
		rect(c, "heal", 1 + iw * ratio, 1, 6, hpH)
	end
	-- puissance
	if phpx > 0 then
		local pr, pg, pb = powerCol(p.ptype)
		c.pw:SetVertexColor(pr, pg, pb, 1)
		P.Box(c.pw, c, 1, h - 1 - phpx, iw * p.pr, phpx)
		rect(c, "power", 1, h - 1 - phpx, iw, phpx)
		-- texte de mana : place (manapos) et contenu (manacontent) reels, quand la barre est assez haute pour le lire
		local E = SUI.GroupEngine
		if cfg.manatext and state == 0 and phpx >= 7 and E and type(E.PowerText) == "function" and E.PW_AT then
			local at = E.PW_AT[cfg.manapos] or E.PW_AT.center
			local mfs = phpx - 1
			if mfs > 12 then mfs = 12 end
			pfont(c.pwt, mfs, cfg)
			c.pwt:SetText(E.PowerText(cfg.manacontent, floor(p.pr * 3000), 3000))
			c.pwt:ClearAllPoints()
			c.pwt:SetPoint(at[1], c.pw, at[1], at[3], 0)
			c.pwt:SetJustifyH(at[2])
			c.pwt:SetWidth(floor(w * 0.5))
			c.pwt:SetHeight(mfs + 2)
			c.pwt:Show()
		else
			c.pwt:Hide()
		end
	else
		c.pw:Hide()
		c.pwt:Hide()
		rect(c, "power", 1, h - 3, iw, 3)
	end
	-- aggro / cible
	if state == 0 and p.aggro and cfg.aggro then
		P.Fill(c.hl, T.c.warn, 0.30)
		P.Box(c.hl, c, 0, 0, w, h)
	elseif state == 0 and p.target and cfg.target then
		local ar, ag, ab = T.Accent()
		c.hl:SetVertexColor(ar, ag, ab, 0.22)
		P.Box(c.hl, c, 0, 0, w, h)
	else
		c.hl:Hide()
	end
	rect(c, "aggro", 0, 0, w, 4)
	-- dissipation : types presents (priorite choisie d'abord), liseret a gauche et/ou voile colore (du type prioritaire), contour decoupe
	local nt = dispelList(cfg, p, TY)
	local dt = (nt > 0) and TY[1] or nil
	local sw = floor(3 * s + 0.5)
	if sw < 1 then sw = 1 end
	local dstyle = cfg.dispelstyle
	if dt then
		local dr, dg, db = debCol(dt)
		c.dtx:SetVertexColor(dr, dg, db, 1)
		c.dhl:SetVertexColor(dr, dg, db, 0.32)
		if dstyle == "stripe" or dstyle == "both" then P.Box(c.dtx, c, 0, 0, sw, h) else c.dtx:Hide() end
		if dstyle == "frame" or dstyle == "both" then P.Box(c.dhl, c, 0, 0, w, h) else c.dhl:Hide() end
	else
		c.dtx:Hide()
		c.dhl:Hide()
	end
	paintOutline(c, cfg, s, w, h, nt)
	rect(c, "dispel", 0, 0, sw + 2, h)
	-- icones : debuffs (gauche), HoTs puis buffs (droite)
	local isz = floor(cfg.iconsize * s + 0.5)
	if isz < 2 then isz = 2 end
	local base = floor((2 + ((ph > 0) and (ph + 1) or 0)) * s + 0.5)
	-- place reservee aux petites icones de dissipation dans la rangee du bas (comme les vrais cadres)
	local ssz = cfg.dispelsmallsize
	local resL = (cfg.dispelsmall and cfg.dispelsmallpos == "bottomleft") and floor(2 * (ssz + 3) * s + 0.5) or 0
	local resR = (cfg.dispelsmall and cfg.dispelsmallpos == "bottomright") and floor(2 * (ssz + 3) * s + 0.5) or 0
	local shown = 0
	local maxDeb = caps[1]
	for j = 1, getn(p.deb) do
		local tp = p.deb[j]
		if (tp ~= "" or not cfg.dispelonly or cfg.dispelmode == "off") and shown < cfg.debuffs and shown < maxDeb then
			shown = shown + 1
			local x = floor(2 * s + 0.5) + resL + (shown - 1) * (isz + floor(3 * s + 0.5))
			local y = h - base - isz - 2
			local e, ic = c.de[shown], c.di[shown]
			if tp == "" then
				P.Fill(e, T.c.bad, 1)
			else
				local dr, dg, db = debCol(tp)
				e:SetVertexColor(dr, dg, db, 1)
			end
			P.Box(e, c, x, y, isz + 2, isz + 2)
			P.Fill(ic, T.c.inset, 1)
			P.Box(ic, c, x + 1, y + 1, isz, isz)
		end
	end
	for k = shown + 1, caps[1] do
		c.de[k]:Hide()
		c.di[k]:Hide()
	end
	rect(c, "deb", floor(2 * s + 0.5), h - base - isz - 2, (isz + 2) * (shown > 0 and shown or 1), isz + 2)
	local nhot = cfg.hots
	local isTank = (p.role == "T")
	if isTank and cfg.tankhots > nhot then nhot = cfg.tankhots end         -- reglage tankhots : plus de HoTs sur les tanks
	if nhot > caps[3] then nhot = caps[3] end
	local shownH = nhot
	local hlim = p.hots
	if isTank and cfg.tankhots > hlim then hlim = cfg.tankhots end
	if shownH > hlim then shownH = hlim end
	local hx = floor(2 * s + 0.5) + resR
	for k = 1, caps[3] do
		local ic = c.hi[k]
		if k <= shownH then
			P.Fill(ic, T.c.good, 1)
			P.Box(ic, c, w - hx - k * isz - (k - 1), h - base - isz, isz, isz)
		else
			ic:Hide()
		end
	end
	rect(c, "hot", w - hx - (nhot > 0 and nhot or 1) * isz - (nhot > 1 and nhot - 1 or 0), h - base - isz, (nhot > 0 and nhot or 1) * isz, isz)
	local nb = cfg.buffs
	if nb > caps[2] then nb = caps[2] end
	local shownB = nb
	if shownB > p.bufs then shownB = p.bufs end
	for k = 1, caps[2] do
		local ic = c.bi[k]
		if k <= shownB then
			P.Fill(ic, T.c.dim, 1)
			P.Box(ic, c, w - hx - (nhot + k) * isz - (nhot + k - 1), h - base - isz, isz, isz)
		else
			ic:Hide()
		end
	end
	rect(c, "buf", w - hx - (nhot + (nb > 0 and nb or 1)) * isz - (nhot + nb), h - base - isz, (nb > 0 and nb or 1) * isz, isz)
	-- grosses / petites icones de dissipation, effets de boss et aggro d'exemple
	paintFx(c, p, cfg, s, w, h, base, nt)
	-- marqueur (place markpos, taille marksize ; 0 = taille des icones)
	local msz = (cfg.marksize > 0) and floor(cfg.marksize * s + 0.5) or isz
	if msz < 2 then msz = 2 end
	if cfg.marks and p.mark then
		markCoords(c.mk, p.mark)
		c.mk:ClearAllPoints()
		if cfg.markpos == "topcenter" then
			c.mk:SetPoint("TOP", c, "TOP", 0, -floor(2 * s + 0.5))
		elseif cfg.markpos == "center" then
			c.mk:SetPoint("CENTER", c, "CENTER", 0, 0)
		else
			c.mk:SetPoint("TOPLEFT", c, "TOPLEFT", floor(2 * s + 0.5), -floor(2 * s + 0.5))
		end
		c.mk:SetWidth(msz)
		c.mk:SetHeight(msz)
		c.mk:Show()
	else
		c.mk:Hide()
	end
	local mkx, mky = floor(2 * s + 0.5), floor(2 * s + 0.5)
	if cfg.markpos == "topcenter" then
		mkx = floor((w - msz) / 2)
	elseif cfg.markpos == "center" then
		mkx, mky = floor((w - msz) / 2), floor((h - msz) / 2)
	end
	rect(c, "mark", mkx, mky, msz, msz)
	-- textes (cachees quand le cadre est trop petit pour etre lisibles)
	local fs = (cfg.fpx or 10) * s                    -- taille du module (<module>.fontsize), 0 = taille d'origine
	if fs > 15 then fs = 15 end
	local textOk = (hpH >= 8 and fs >= 6.5)
	local ty = 1 + (hpH - fs - 2) / 2
	if ty < 1 then ty = 1 end
	local nm = cutName(p.name, cfg.namelen)
	local tx = 1 + floor(3 * s + 0.5)
	-- pseudo place librement : ligne (haut / milieu / bas) et colonne (gauche / centre / droite)
	local at = NAMEAT[cfg.nameanchor] or NAMEAT.left
	local nw = floor(w * 0.62)
	local tag = ""
	if cfg.roletag then tag = M.Tx("msg." .. cfg.ns .. ".role." .. string.lower(p.role)) end
	if cfg.leader then
		if p.rank == 2 then tag = tag .. "*" elseif p.rank == 1 then tag = tag .. "+" end
	end
	local nx, ny = tx, ty
	if at[1] == 1 then
		ny = 1 + floor(2 * s + 0.5)
	elseif at[1] == 3 then
		ny = 1 + hpH - fs - 2 - floor(2 * s + 0.5)
		if ny < 1 then ny = 1 end
	end
	if at[2] == 1 then
		if at[1] == 1 and cfg.marks and p.mark and cfg.markpos == "topleft" then nx = nx + msz + floor(2 * s + 0.5) end      -- sous le marqueur de raid
		if tag ~= "" and ((at[1] == 1 and cfg.tagpos == "topleft") or (at[1] == 3 and cfg.tagpos == "bottomleft")) then nx = nx + floor(12 * s + 0.5) end
	elseif at[2] == 2 then
		nx = floor((w - nw) / 2)
	else
		nx = w - nw - tx
		if tag ~= "" and ((at[1] == 1 and cfg.tagpos == "topright") or (at[1] == 3 and cfg.tagpos == "bottomright")) then nx = nx - floor(12 * s + 0.5) end     -- a gauche du chef / role
	end
	if textOk then
		pfont(c.name, fs, cfg)
		c.name:SetText(nm)
		c.name:SetJustifyH(JUST[at[2]])
		c.name:ClearAllPoints()
		c.name:SetPoint("TOPLEFT", c, "TOPLEFT", nx, -ny)
		c.name:SetWidth(nw)
		c.name:SetHeight(fs + 2)
		c.name:Show()
	else
		c.name:Hide()
	end
	rect(c, "name", nx, ny, nw, fs + 2)
	-- petites icones a cote du pseudo : types a dissiper (carres colores) puis effets de boss (leur icone), 3 au plus
	local kk = 0
	local nsz = floor(cfg.dispelsmallsize * s + 0.5)
	if nsz > fs + 2 then nsz = floor(fs + 2) end
	if nsz < 2 then nsz = 2 end
	local sw2 = 0
	if textOk then
		sw2 = c.name:GetStringWidth() or 0
		if sw2 > nw then sw2 = nw end
	end
	local mode = cfg.nameicons
	local ncx = nx + sw2 + floor(2 * s + 0.5)
	if textOk and mode ~= "off" then
		for pass = 1, 2 do
			local count = 0
			if pass == 1 and (mode == "dispel" or mode == "both") then count = nt end
			if pass == 2 and (mode == "fx" or mode == "both") then count = c.fxN end
			for i = 1, count do
				if kk < 3 then
					local t = c.nic[kk + 1]
					local ok = true
					if pass == 1 then
						local dr, dg, db = debCol(TY[i])
						t:SetTexture(T.tex.white)
						t:SetTexCoord(0, 1, 0, 1)
						t:SetVertexColor(dr, dg, db, 1)
					else
						local rec = fxRec(p, i)
						if rec then
							t:SetTexture(rec.texture)
							t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
							t:SetVertexColor(1, 1, 1, 1)
						else
							ok = false
						end
					end
					if ok then
						kk = kk + 1
						local off = (kk - 1) * (nsz + floor(s + 0.5))
						local x
						if at[2] == 1 then
							x = nx + sw2 + floor(2 * s + 0.5) + off
						elseif at[2] == 3 then
							x = nx + nw - sw2 - floor(2 * s + 0.5) - nsz - off
						else
							x = nx + nw / 2 + sw2 / 2 + floor(2 * s + 0.5) + off
						end
						P.Box(t, c, x, ny + (fs + 2 - nsz) / 2, nsz, nsz)
					end
				end
			end
		end
	end
	for k = kk + 1, 3 do c.nic[k]:Hide() end
	rect(c, "nic", ncx, ny + (fs + 2 - nsz) / 2, nsz * (kk > 0 and kk or 1), nsz)
	local hs = ""
	if state == 0 then hs = hpString(cfg, floor(p.hpr * p.hpmax + 0.5), p.hpmax) end
	-- texte de vie : neuf places (hppos), meme grille que le pseudo ; "right" = emplacement d'origine
	local hat = NAMEAT[cfg.hppos] or NAMEAT.right
	local hy = ty
	if hat[1] == 1 then
		hy = 1 + floor(2 * s + 0.5)
	elseif hat[1] == 3 then
		hy = 1 + hpH - fs - 2 - floor(2 * s + 0.5)
		if hy < 1 then hy = 1 end
	end
	local hw = floor(w * 0.5)
	local hx
	if hat[2] == 1 then
		hx = tx
	elseif hat[2] == 2 then
		hx = floor((w - hw) / 2)
	else
		hx = w - hw - tx - 1
	end
	if textOk and hs ~= "" and w >= 40 then
		pfont(c.hpt, fs, cfg)
		c.hpt:SetText(hs)
		-- reglage lowhp : le texte de vie passe en couleur d'alerte sous le seuil (en pourcent)
		local lc = (cfg.lowhp > 0 and p.hpr * 100 < cfg.lowhp) and T.c.bad or T.c.text
		c.hpt:SetTextColor(lc[1], lc[2], lc[3], lc[4] or 1)
		c.hpt:SetJustifyH(JUST[hat[2]])
		c.hpt:ClearAllPoints()
		c.hpt:SetPoint("TOPLEFT", c, "TOPLEFT", hx, -hy)
		c.hpt:SetWidth(hw)
		c.hpt:SetHeight(fs + 2)
		c.hpt:Show()
	else
		c.hpt:Hide()
	end
	local zw = floor(w * 0.4)
	local zx = (hat[2] == 1) and tx or ((hat[2] == 2) and floor((w - zw) / 2) or (w - zw - tx))
	rect(c, "hptext", zx, hy, zw, fs + 2)
	if textOk and state ~= 0 then
		pfont(c.stt, fs, cfg)
		-- reglage resinfo : un mort en cours de resurrection montre "Res" en vert au lieu de "Mort"
		local isRes = (state == 1 and cfg.resinfo and p.res) and true or false
		local sc = isRes and T.c.good or T.c.warn
		c.stt:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
		c.stt:SetText(isRes and L("msg." .. cfg.ns .. ".res") or (state == 2 and L("unit.offline") or L("unit.dead")))
		c.stt:ClearAllPoints()
		c.stt:SetPoint("TOP", c, "TOP", 0, -ty)
		c.stt:SetWidth(w - 4)
		c.stt:SetHeight(fs + 2)
		c.stt:Show()
	else
		c.stt:Hide()
	end
	local tfs = (cfg.tagsize or 9) * s
	if tfs > 15 then tfs = 15 end
	local tgx, tgy = floor(2 * s + 0.5), floor(2 * s + 0.5)
	local tgw = floor(w * 0.4)
	local tpos = cfg.tagpos or "topright"
	local tright = (tpos == "topright" or tpos == "bottomright")
	local tbottom = (tpos == "bottomright" or tpos == "bottomleft")
	local tcx = tright and (w - tgw - tgx) or tgx
	local tcy = tbottom and (h - tfs - 2 - tgy) or tgy
	if tcy < 1 then tcy = 1 end
	if textOk and tag ~= "" then
		P.Font(c.tag, tfs)
		c.tag:SetText(tag)
		c.tag:SetJustifyH(tright and "RIGHT" or "LEFT")
		c.tag:ClearAllPoints()
		c.tag:SetPoint("TOPLEFT", c, "TOPLEFT", tcx, -tcy)
		c.tag:SetWidth(tgw)
		c.tag:SetHeight(tfs + 2)
		c.tag:Show()
	else
		c.tag:Hide()
	end
	rect(c, "tag", tright and (w - floor(w * 0.3) - 2) or 2, floor(tcy), floor(w * 0.3), floor(tfs + 2))
	-- transparence : mort, hors ligne ou hors portee (si la portee est suivie)
	local a = 1
	if state == 1 and cfg.deadalpha > 0 then
		a = cfg.deadalpha
	elseif state == 2 and cfg.offalpha > 0 then
		a = cfg.offalpha
	elseif state ~= 0 or (cfg.range and p.far) then
		a = cfg.outalpha
	elseif cfg.los and p.los then
		a = cfg.losalpha
	end
	c:SetAlpha(a)
	c:Show()
end

-- ---------------------------------------------------------------- apercu
local function setCaption(st, cfg, prefix, cnt)
	local sortName = M.Tx("choice." .. prefix .. "sort." .. tostring(cfg.sort))
	if sortName == "" then sortName = tostring(cfg.sort) end
	st.cap:SetText(L("mod.preview.raid.count", cnt) .. "  -  " .. L("mod.preview.sort", sortName))
end

-- Positionne tout : selecteur, cadre agrandi, etats, grille. w x h = zone de l'apercu.
local function layoutAll(root, w, h)
	local st = root.st
	local cfg = st.cfg
	local caps = st.caps
	local prefix = st.prefix
	-- densite automatique (autosize) : meme facteur que les vrais cadres pour l'effectif simule (visibles seulement)
	local E = SUI.GroupEngine
	local vis = 0
	for i = 1, st.n do
		if st.kind ~= "raid" or R.roster[i].sub <= cfg.maxgroup then vis = vis + 1 end
	end
	local af = (E and type(E.AutoFactor) == "function") and E.AutoFactor(cfg, vis) or 1
	cfg.width, cfg.height, cfg.iconsize = cfg.rw, cfg.rh, cfg.ri
	if af ~= 1 then
		cfg.width, cfg.height, cfg.iconsize = floor(cfg.rw * af + 0.5), floor(cfg.rh * af + 0.5), floor(cfg.ri * af + 0.5)
		if cfg.width < 24 then cfg.width = 24 end
		if cfg.height < 10 then cfg.height = 10 end
		if cfg.iconsize < 6 then cfg.iconsize = 6 end
	end
	-- selecteur
	local x = 0
	for i = 1, getn(st.sizes) do
		local b = st.btns[i]
		P.Place(b, root, x, 0, 34, 20)
		T.SetSelected(b, b.n == st.n)
		x = x + 38
	end
	-- 92 px a droite : bouton "Ecran" du panneau, pose par dessus l'apercu
	local capw = w - x - 96
	if capw < 40 then capw = 40 end
	P.Place(st.capZone, root, x + 4, 0, capw, 20)
	st.cap:ClearAllPoints()
	st.cap:SetPoint("TOPLEFT", root, "TOPLEFT", x + 6, -4)
	st.cap:SetWidth(capw - 4)
	st.cap:SetHeight(12)
	-- zones : detail (haut ou gauche) et grille
	local wide = (w >= 520 and w >= h * 1.5)
	local dx, dy, dw, dh, gx, gy, gw, gh
	if wide then
		dw = floor(w * 0.4)
		dx, dy, dh = 0, 26, h - 26
		gx, gy, gw, gh = dw + 8, 26, w - dw - 8, h - 26
	else
		dh = floor((h - 26) * 0.4)
		if dh > 170 then dh = 170 end
		dx, dy, dw = 0, 26, w
		gx, gy, gw, gh = 0, 26 + dh + 6, w, h - 26 - dh - 6
		-- legende ancree en bas : sinon elle passe sous la grille
		local txt = L("mod.preview.raid.legend") .. " " .. L("mod.preview.raid.legend2")
		local lh = (floor(string.len(txt) * 5.4 / (w > 40 and w or 40)) + 1) * 12 + 4
		if lh > floor(gh / 2) then lh = floor(gh / 2) end
		gh = gh - lh - 4
		st.legendBottom = lh
	end
	-- cadre agrandi + 3 etats
	local cw, ch = cfg.width, cfg.height
	local sd = dw / cw
	local lim = (dh - 4) / (ch * 1.5)
	if lim < sd then sd = lim end
	if sd > 3 then sd = 3 end
	if sd < 0.5 then sd = 0.5 end
	local ss = sd * 0.5
	local lim2 = (dw - 8) / (3 * cw)
	if lim2 < ss then ss = lim2 end
	local pdet = st.pick > 0 and R.roster[st.pick] or R.demo
	R.Paint(st.det, pdet, cfg, sd, caps)
	P.Place(st.det, root, dx, dy, st.det:GetWidth(), st.det:GetHeight())
	local sy = dy + st.det:GetHeight() + 4
	local sx = dx
	local states = st.states
	for i = 1, 3 do
		local cc = states[i]
		R.Paint(cc, st.demos[i], cfg, ss, caps)
		P.Place(cc, root, sx, sy, cc:GetWidth(), cc:GetHeight())
		cc.ox, cc.oy = sx, sy
		sx = sx + cc:GetWidth() + 4
	end
	st.legend:ClearAllPoints()
	if not wide and st.legendBottom then
		st.legend:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -(h - st.legendBottom))
		st.legend:SetHeight(st.legendBottom)
	else
		st.legend:SetPoint("TOPLEFT", root, "TOPLEFT", dx, -(sy + states[1]:GetHeight() + 4))
		st.legend:SetHeight(64)
	end
	st.legend:SetWidth(dw)
	-- zones du cadre agrandi
	local det = st.det
	for i = 1, getn(ZORDER) do
		local key = ZORDER[i]
		local rc = det.rc[key]
		local z = st.zones[key]
		P.PlaceZone(z, root, dx + rc[1], dy + rc[2], rc[3], rc[4])
	end
	for i = 1, 3 do
		local cc = states[i]
		local z = st.szones[i]
		P.PlaceZone(z, root, cc.ox, cc.oy, cc:GetWidth(), cc:GetHeight())
	end
	-- grille
	local cnt, tw, th = R.Arrange(st, cfg, st.n, st.kind)
	local sg = gw / tw
	local sg2 = gh / th
	if sg2 < sg then sg = sg2 end
	if sg > 2.5 then sg = 2.5 end
	if sg < 0.2 then sg = 0.2 end
	local offx = floor((gw - tw * sg) / 2)
	for k = 1, 40 do
		local cc = st.cells[k]
		local p = st.ord[k]
		if k <= cnt then
			cc.pi = p.idx
			cc.sel = (st.pick == p.idx)
			R.Paint(cc, p, cfg, sg, caps)
			P.Place(cc, root, gx + offx + floor(st.px[k] * sg), gy + floor(st.py[k] * sg), cc:GetWidth(), cc:GetHeight())
		else
			cc:Hide()
		end
	end
	P.Place(st.gap, root, gx + offx, gy, floor(tw * sg), floor(th * sg))
	st.gap:Show()
	-- titres de groupe (grouptitle, tri par groupe) : la ou les vrais cadres les posent
	for q = 1, 8 do
		local t = st.titles[q]
		local tx0 = st.tx and st.tx[q]
		if tx0 and cfg.grouptitle and cfg.sort == "group" and sg >= 0.5 then
			pfont(t, 9 * sg, cfg)
			t:SetText(L("msg." .. cfg.ns .. ".gtitle", q))
			t:ClearAllPoints()
			if st.tj[q] then
				t:SetPoint("TOPRIGHT", root, "TOPLEFT", gx + offx + floor(tx0 * sg), -(gy + floor(st.ty[q] * sg)))
				t:SetJustifyH("RIGHT")
			else
				t:SetPoint("TOPLEFT", root, "TOPLEFT", gx + offx + floor(tx0 * sg), -(gy + floor(st.ty[q] * sg)))
				t:SetJustifyH("LEFT")
			end
			t:SetWidth(floor(cfg.width * sg))
			t:SetHeight(11 * sg)
			t:Show()
			-- zone cliquable posee sur le titre (reglage grouptitle)
			local zx = gx + offx + floor(tx0 * sg)
			if st.tj[q] then zx = zx - floor(cfg.width * sg) end
			P.PlaceZone(st.gtz[q], root, zx, gy + floor(st.ty[q] * sg), floor(cfg.width * sg), 11 * sg)
		else
			t:Hide()
			st.gtz[q]:Hide()
		end
	end
	setCaption(st, cfg, prefix, cnt)
	st.legend:SetText(L("mod.preview.raid.legend") .. " " .. L("mod.preview.raid.legend2"))
end

local function onPick()
	local c = this
	local st = c.st
	st.pick = c.pi
	st.redo()
end

-- Info-bulle d'un cadre de la grille : le nom du joueur et ce que fait le clic.
local function cellEnter()
	local p = R.roster[this.pi]
	if p then M.TipShow(this, p.name, L("mod.preview.raid.cell")) end
end

local function cellLeave()
	M.TipHide()
end

-- ---------------------------------------------------------------- elements cliquables : reglage, nom, info-bulle, mini-panneau
-- Les titres de groupe sont "gt1" a "gt8" : un seul element "gt".
local function zoneBase(zone)
	if sfind(zone, "^gt%d$") then return "gt" end
	return zone
end

local function absKey(prefix, suffix)
	if string.sub(suffix, 1, 1) == "@" then return string.sub(suffix, 2) end
	return prefix .. suffix
end

-- Cle de reglage qu'un clic sur l'element ouvre ; nil si inconnu. Le groupe n'a pas d'ecart entre groupes : l'espacement le remplace.
local function zoneOpt(prefix, zone)
	zone = zoneBase(zone)
	if zone == "gap" then
		if C.Get(prefix .. "sort") == "group" and P.FindOption(prefix .. "groupgap") then return prefix .. "groupgap" end
		return prefix .. "spacing"
	end
	if zone == "sort" then return prefix .. "sort" end
	if zone == "gt" then return prefix .. (P.FindOption(prefix .. "grouptitle") and "grouptitle" or "sort") end
	local k = ZKEY[zone]
	if k then return prefix .. k end
	return nil
end

-- Table cle de reglage -> element de l'apercu : le saut du menu (OpenAt, recherche) peut ainsi entourer l'element concerne.
-- Passe 1 : le reglage ouvert par un clic ; passe 2 : les autres reglages du mini-panneau de l'element.
local function buildKz(prefix)
	local kz = {}
	local nz, na = getn(ZORDER), getn(ZALL)
	for pass = 1, 2 do
		for i = 1, nz + na do
			local id = (i <= nz) and ZORDER[i] or ZALL[i - nz]
			if pass == 1 then
				local k = zoneOpt(prefix, id)
				if k and not kz[k] then kz[k] = id end
			else
				local l = ZPANEL[id]
				for j = 1, l and getn(l) or 0 do
					local k = absKey(prefix, l[j])
					if not kz[k] then kz[k] = id end
				end
			end
		end
	end
	return kz
end

local function zonePanel(prefix, zone)
	local l = ZPANEL[zoneBase(zone)]
	local keys = {}
	for i = 1, l and getn(l) or 0 do tinsert(keys, absKey(prefix, l[i])) end
	return { keys = keys, go = zoneOpt(prefix, zone) }
end

local function onSize(b)
	local st = b.st
	st.n = b.n
	st.redo()
end

local function makeDef(kind, prefix, sizes, defN, caps)
	local def = { title = nil, watch = { prefix, "groupfx." } }
	local catId = (prefix == "raid.") and "raid" or "group"
	def.build = function(parent, w, h)
		local root = CreateFrame("Frame", nil, parent)
		local st = { kind = kind, prefix = prefix, sizes = sizes, n = defN, pick = 0, caps = caps, cfg = {}, ord = {}, px = {}, py = {},
			cells = {}, btns = {}, zones = {}, szones = {}, states = {}, demos = { R.demoFar, R.demoDead, R.demoOff } }
		root.st = st
		st.redo = function() layoutAll(root, root.pw or w, root.ph or h) end
		-- fond cliquable : les ecarts entre cadres (espacement, ecart entre groupes)
		st.gap = P.Zone(root, "gap", 1)
		for k = 1, 40 do
			local c = newCell(root, caps, true)
			c.st = st
			c.pi = k
			c:SetFrameLevel(P.Lv(2))
			c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			c:SetScript("OnClick", onPick)
			c:SetScript("OnEnter", cellEnter)
			c:SetScript("OnLeave", cellLeave)
			st.cells[k] = c
		end
		st.det = newCell(root, caps, false)
		st.det:SetFrameLevel(P.Lv(2))
		for i = 1, 3 do
			st.states[i] = newCell(root, caps, false)
			st.states[i]:SetFrameLevel(P.Lv(2))
		end
		for i = 1, getn(sizes) do
			local b = T.Button(root, tostring(sizes[i]), 34, 20, onSize)
			b:SetFrameLevel(P.Lv(2))
			b.n = sizes[i]
			b.st = st
			st.btns[i] = b
		end
		st.titles, st.gtz = {}, {}
		for q = 1, 8 do
			st.titles[q] = T.Text(root, 9, T.c.dim, "LEFT", true)
			st.titles[q]:Hide()
			st.gtz[q] = P.Zone(root, "gt" .. q)
			st.gtz[q]:Hide()
		end
		st.tx, st.ty, st.tj = {}, {}, {}
		st.cap = T.Text(root, 10, T.c.dim, "LEFT")
		st.cap:SetHeight(12)
		st.capZone = P.Zone(root, "sort")
		st.legend = T.Text(root, 10, T.c.dim, "LEFT")
		st.legend:SetHeight(64)
		st.legend:SetJustifyV("TOP")
		for i = 1, getn(ZORDER) do st.zones[ZORDER[i]] = P.Zone(root, ZORDER[i]) end
		local sz = { "far", "dead", "off" }
		for i = 1, 3 do st.szones[i] = P.Zone(root, sz[i]) end
		return root
	end
	def.update = function(root, w, h, key, value)
		local st = root.st
		root.pw, root.ph = w, h
		readCfg(prefix, st.cfg)
		layoutAll(root, w, h)
		-- le menu a saute a un reglage (OpenAt, recherche, clic droit sur la poignee) : l'element qui le commande est entoure
		if key == nil then
			local fk = M.hl
			if type(fk) == "string" and fk ~= st.lastHl then
				st.lastHl = fk
				if not st.kz then st.kz = buildKz(prefix) end
				local zid = st.kz[fk]
				if zid then P.SelectId(catId, zid) end
			end
		end
	end
	def.click = function(zone) return zoneOpt(prefix, zone) end
	def.label = function(zone) return "mod.preview.raid.z." .. zoneBase(zone) end
	def.tip = function(zone) return "mod.preview.raid.tip." .. zoneBase(zone) end
	def.panel = function(zone) return zonePanel(prefix, zone) end
	return def
end

P.Register("raid", makeDef("raid", "raid.", { 5, 10, 20, 40 }, 40, { 3, 3, 3 }))
P.Register("group", makeDef("party", "group.", { 3, 5 }, 5, { 4, 6, 4 }))

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) la lisibilite du texte reduit (SetFont a petite taille) dans la grille a 40 joueurs ; (2) le
-- decoupage des icones de marqueurs (UI-RaidTargetingIcons) par SetTexCoord ; (3) les valeurs reelles de DebuffTypeColor (E.DEBUFF_COL de
-- Mod_Group.lua, lues au dessin) ; (4) l'ordre d'empilement des textures d'un meme calque (creation) : liseret, voile et icones.
