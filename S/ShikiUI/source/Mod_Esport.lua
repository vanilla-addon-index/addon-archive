-- ShikiUI Esport : suivi de combat PvP (module "esport") pour champ de bataille et arene - principes des trackers
-- modernes type Gladius (concept only, aucun code copie) :
--
--   1. ENNEMIS : jusqu'a 5 joueurs ennemis recents (cible, souris, cibles du groupe/raid) avec nom, couleur de
--      classe, barre de vie et marque de raid. Tri par vie croissante en option (le plus faible d'abord).
--   2. DR (diminishing returns) : les controles appliques a un joueur ennemi sont comptes par CATEGORIE
--      (etourdissement, peur, racine, silence, disorientation, polymorphe, camouflage) : 1er = 100 %,
--      2e = 50 %, 3e = 25 %, 4e+ = immunise, fenetre de 15 s (reglable). Affichage : categorie x comptage.
--   3. DETECTION : SuperWoW UNIT_CASTEVENT (guid de la victime -> nom via SUI.Api.GUID) avec SpellInfo pour
--      le nom de sort ; sans SuperWoW, le journal (CHAT_MSG_SPELL_PERIODIC_*) est analyse. Sorts reconnus EN
--      et FR (table d'alias, pliage d'accents - le client OctoWow est passe en FR).
--   4. Clic sur un ennemi = cibler (cible, cible de groupe/raid, souris).
-- Limites 1.12 : pas d'unite "arena1..5" - les ennemis sont suivis par NOM ; les controles sans SuperWoW ni
-- ligne de journal sont invisibles ; la liste d'ennemis se construit par ciblage (pas de scan magique).
-- Cout declare : "medium" (balayage 0,25 s quand la fenetre est ouverte ; fermee : rien).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Esport = M

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, mmin, mmax = math.floor, math.min, math.max
local sfind, slower, sgsub = string.find, string.lower, string.gsub
local strformat = string.format
local EMPTY = ""

M.on = false
M.win = nil
M.task = nil
M.enemies = {}         -- nom -> { cls, hp, hpMax, mark, seenAt, dr = { [cat] = { at, count } } }
M.order = {}           -- noms (max MAXE) pour l'affichage

M.MAXE = 5
M.REMEMBER = 30        -- secondes sans revoir un ennemi avant de l'oublier
M.DRWINDOW = 15        -- fenetre de diminishing returns (s)
M.BARH = 24
M.GAP = 3

-- Categories de controle : icones (texture du jeu) + sorts reconnus EN (plie). Les FR passent par M.FR2EN.
M.CC = {
	stun = { icon = "Interface\\Icons\\Spell_Frost_Stun",
		names = { ["hammer of justice"] = true, ["bash"] = true, ["kidney shot"] = true, ["charge"] = true,
			["intercept"] = true, ["war stomp"] = true, ["impact"] = true, ["concussion blow"] = true } },
	fear = { icon = "Interface\\Icons\\Spell_Shadow_Possession",
		names = { ["fear"] = true, ["psychic scream"] = true, ["intimidating shout"] = true, ["howl of terror"] = true } },
	root = { icon = "Interface\\Icons\\Spell_Frost_FrozenCore",
		names = { ["entangling roots"] = true, ["frost nova"] = true, ["freeze"] = true } },
	silence = { icon = "Interface\\Icons\\Spell_Troll_Silenced",
		names = { ["silence"] = true, ["garrote"] = true } },
	disorient = { icon = "Interface\\Icons\\Spell_Arcane_Missiles",
		names = { ["gouge"] = true, ["blind"] = true, ["repentance"] = true } },
	poly = { icon = "Interface\\Icons\\Spell_Magic_Polymorph",
		names = { ["polymorph"] = true, ["polymorph: pig"] = true, ["polymorph: turtle"] = true } },
	sap = { icon = "Interface\\Icons\\Ability_Sap",
		names = { ["sap"] = true } },
}
M.CC_ORDER = { "stun", "fear", "root", "silence", "disorient", "poly", "sap" }

-- Alias FR plie -> EN plie (client frFR d'OctoWow). Noms officiels FR vanilla.
M.FR2EN = {
	["marteau de la justice"] = "hammer of justice", ["fracasser"] = "bash", ["coup de pied au rein"] = "kidney shot",
	["intimidation"] = "intercept", ["piege des ancetres"] = "war stomp", ["horion de flamme"] = "impact",
	["coup de concussif"] = "concussion blow", ["cauchemar"] = "fear", ["cri psychique"] = "psychic scream",
	["cri d'intimidation"] = "intimidating shout", ["hurlement de terreur"] = "howl of terror",
	["racines entravantes"] = "entangling roots", ["nova de givre"] = "frost nova", ["geler"] = "freeze",
	["garrot"] = "garrote", ["assommer"] = "gouge", ["aveugler"] = "blind", ["repentir"] = "repentance",
	["metamorphose"] = "polymorph", ["metamorphose : porc"] = "polymorph: pig", ["metamorphose : tortue"] = "polymorph: turtle",
	["camouflage"] = "sap", ["somnifer"] = "sap", ["silence"] = "silence",
}

local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\155"] = "u", ["\195\177"] = "n", ["\195\145"] = "n",
}
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "\195[\128-\191]", function(seq) return PLAIN[seq] or seq end)
	return out
end
M.fold = fold

-- Categorie de controle pour un nom de sort (EN ou FR, plie), ou nil.
function M.CcCat(name)
	if not name or name == EMPTY then return nil end
	local low = fold(name)
	if M.FR2EN[low] then low = M.FR2EN[low] end
	local cat
	for cat, d in pairs(M.CC) do
		if d.names[low] then return cat end
	end
	return nil
end

-- ---------------------------------------------------------------- ennemis
local function touchEnemy(name, cls)
	local e = M.enemies[name]
	if not e then
		e = { cls = cls or EMPTY, dr = {}, seenAt = 0, hp = 0, hpMax = 0 }
		M.enemies[name] = e
		if getn(M.order) < M.MAXE then tinsert(M.order, name) end
	end
	if cls and cls ~= EMPTY then e.cls = cls end
	e.seenAt = GetTime()
	return e
end

function M.SeeUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsFriend("player", unit) then return end
	local nm = UnitName(unit)
	if not nm or nm == EMPTY then return end
	local _, cls = UnitClass(unit)
	local e = touchEnemy(nm, cls)
	e.hp, e.hpMax = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
	local mk = GetRaidTargetIndex(unit)
	if mk then e.mark = mk else e.mark = nil end
end

-- balayage des unites susceptibles d'etre des ennemis + oubli des absents
function M.Sweep()
	if not M.on then return end
	M.SeeUnit("target")
	M.SeeUnit("mouseover")
	local gn = getglobal("GetNumRaidMembers")
	local n = (type(gn) == "function") and (gn() or 0) or 0
	local k
	for k = 1, n do M.SeeUnit("raid" .. k .. "target") end
	local gnp = getglobal("GetNumPartyMembers")
	local np = (type(gnp) == "function") and (gnp() or 0) or 0
	for k = 1, np do M.SeeUnit("party" .. k .. "target") end
	local now = GetTime()
	local nm, e
	for nm, e in pairs(M.enemies) do
		if now - e.seenAt > M.REMEMBER then
			M.enemies[nm] = nil
			local j
			for j = getn(M.order), 1, -1 do
				if M.order[j] == nm then tremove(M.order, j) end
			end
		end
	end
	-- tri : vie croissante si l'option est active
	if C.Get("esport.lowfirst") then
		for i = 1, getn(M.order) do
			for j = i + 1, getn(M.order) do
				local a, b = M.enemies[M.order[i]], M.enemies[M.order[j]]
				local ha = a and a.hp or 999999
				local hb = b and b.hp or 999999
				if hb > 0 and hb < ha then
					local tmp = M.order[i]
					M.order[i] = M.order[j]
					M.order[j] = tmp
				end
			end
		end
	end
	if M.win and M.win:IsShown() then M.Paint() end
end

-- ---------------------------------------------------------------- DR
-- Applique un controle : cat = categorie, victim = nom du joueur ennemi VICTIME.
function M.ApplyCC(victim, cat)
	if not victim or not cat then return end
	local e = M.enemies[victim] or touchEnemy(victim, EMPTY)
	local now = GetTime()
	local win = C.Get("esport.drwindow") or M.DRWINDOW
	local d = e.dr[cat]
	if not d or now - d.at > win then
		d = { at = now, count = 0 }
		e.dr[cat] = d
	end
	d.count = mmin(4, d.count + 1)
	d.at = now
	if M.win and M.win:IsShown() then M.Paint() end
end

-- guid -> nom, via les unites connues (SUI.Api.GUID de Nampower/SuperWoW)
function M.NameOfGuid(guid)
	if not guid or not SUI.Api.GUID then return nil end
	local k, u
	local cands = { "target", "mouseover", "targettarget" }
	local gn = getglobal("GetNumRaidMembers")
	local n = (type(gn) == "function") and (gn() or 0) or 0
	for k = 1, n do cands[getn(cands) + 1] = "raid" .. k .. "target" end
	local gnp = getglobal("GetNumPartyMembers")
	local np = (type(gnp) == "function") and (gnp() or 0) or 0
	for k = 1, np do cands[getn(cands) + 1] = "party" .. k .. "target" end
	for k = 1, getn(cands) do
		u = cands[k]
		if UnitExists(u) then
			local g = SUI.Api.GUID(u)
			if g and g == guid and UnitIsPlayer(u) then return UnitName(u) end
		end
	end
	return nil
end

-- Evenement SuperWoW UNIT_CASTEVENT(caster, target, type, id, dur) : les controles portes a un JOUEUR.
function M.OnCastEvent(ev, a1, a2, a3, a4, a5)
	if not M.on or not SUI.Api.superwow then return end
	if a3 ~= "CAST" and a3 ~= "AFFECT" then return end
	local nm = M.NameOfGuid(a2)
	if not nm then return end
	local sid = tonumber(a4)
	if not sid then return end
	local si = getglobal("SpellInfo")
	if type(si) ~= "function" then return end
	local ok, sname = pcall(si, sid)
	if not ok or not sname then return end
	local cat = M.CcCat(sname)
	if cat then M.ApplyCC(nm, cat) end
end

-- journal de combat (sans SuperWoW) : "<X> is afflicted by <sort>." / FR "<X> subit <sort>." / "<X> est afflige par <sort>."
function M.OnLog(ev, msg)
	if not M.on or not msg then return end
	local victim, spell
	local _, _, v, sp
	if sfind(msg, "afflicted by", 1, true) then
		_, _, v, sp = sfind(msg, "^([^%s]+).- afflicted by (.+)%.$")
	elseif sfind(msg, "subit", 1, true) then
		_, _, v, sp = sfind(msg, "^(.-) subit (.+)%.$")
	elseif sfind(msg, "est afflige", 1, true) then
		_, _, v, sp = sfind(msg, "^(.-) est afflige par (.+)%.$")
	end
	victim, spell = v, sp
	if victim and spell then
		victim = string.gsub(victim, "^%[(.-)%]$", "%1")   -- "[Nom]" -> Nom
		local cat = M.CcCat(spell)
		if cat then M.ApplyCC(victim, cat) end
	end
end

-- ---------------------------------------------------------------- fenetre
function M.Build()
	if M.win then return end
	local f = CreateFrame("Frame", "ShikiUI_Esport", UIParent)
	f:SetWidth(210)
	f:SetHeight(M.BARH * M.MAXE + 8)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.win = f
	local i
	for i = 1, M.MAXE do
		local row = CreateFrame("Button", nil, f)
		row:SetWidth(202)
		row:SetHeight(M.BARH)
		row:Hide()
		row.hp = T.Bar(row)
		row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.hp:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.name = T.Text(row, 10, T.c.text, "LEFT", true)
		row.name:SetPoint("LEFT", row, "LEFT", 3, 0)
		row.name:SetWidth(110)
		row.dr = T.Text(row, 10, T.c.warn, "RIGHT", true)
		row.dr:SetPoint("RIGHT", row, "RIGHT", -3, 0)
		row.mark = T.Text(row, 10, T.c.text, "RIGHT", true)
		row.mark:SetPoint("RIGHT", row, "RIGHT", -48, 0)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * (M.BARH + M.GAP))
		M["row" .. i] = row
	end
	SUI.Layout.Register(f, "esport.win", "BOTTOMRIGHT", -20, 140)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("esport.win", f, { label = L("mod.esport.title"), scale = false })
	end
	T.OnAccent(function()
		if M.win and M.win:IsShown() then M.Paint() end
	end)
end

function M.Paint()
	local f = M.win
	if not f or not f:IsShown() then return end
	local now = GetTime()
	local i
	for i = 1, M.MAXE do
		local row = M["row" .. i]
		local nm = M.order[i]
		local e = nm and M.enemies[nm]
		if e then
			row:Show()
			local cc = RAID_CLASS_COLORS[e.cls]
			if cc then row.hp:SetStatusBarColor(cc.r, cc.g, cc.b, 0.55) else row.hp:SetStatusBarColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.55) end -- style:ok couleur de classe = donnee du jeu
			local pct = (e.hpMax and e.hpMax > 0) and (e.hp / e.hpMax) or 1
			row.hp:SetValue(pct)
			row.name:SetText(nm or EMPTY)
			row.mark:SetText(e.mark and (strformat("%d", e.mark)) or EMPTY)
			-- DR : dernier controle encore dans la fenetre
			local bestAt, bestCnt, bestCat = 0, 0, nil
			local catk, d
			for catk, d in pairs(e.dr or {}) do
				if now - d.at < (C.Get("esport.drwindow") or M.DRWINDOW) and d.at > bestAt then
					bestAt, bestCnt, bestCat = d.at, d.count, catk
				end
			end
			row.dr:SetText(bestCat and strformat("%s x%d", bestCat, bestCnt) or EMPTY)
			row.hit = nm
		else
			row.hit = nil
			row:Hide()
		end
	end
end

local function rowClick(row)
	local hit = row.hit
	if not hit then return end
	local un = nil
	if UnitExists("target") and UnitName("target") == hit then
		un = "target"
	else
		local gn = getglobal("GetNumRaidMembers")
		local n = (type(gn) == "function") and (gn() or 0) or 0
		local j
		for j = 1, n do
			local u = "raid" .. j .. "target"
			if UnitExists(u) and UnitName(u) == hit then un = u break end
		end
		if not un and UnitExists("mouseover") and UnitName("mouseover") == hit then un = "mouseover" end
	end
	if un then
		if SpellIsTargeting and SpellIsTargeting() then SpellTargetUnit(un) else TargetUnit(un) end
	end
end

local function wireClicks()
	local i
	for i = 1, M.MAXE do
		local row = M["row" .. i]
		row:SetScript("OnClick", function() rowClick(row) end)
	end
end

function M.Open()
	if not M.on then return end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		wireClicks()
		M.win:Show()
		M.Paint()
	end)
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.ToggleWin()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("esport.", M.OnKey)
	end
	if SUI.Api.superwow then
		SUI.On("UNIT_CASTEVENT", M.OnCastEvent)
	else
		SUI.On("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", M.OnLog)
		SUI.On("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", M.OnLog)
		SUI.On("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", M.OnLog)
	end
	M.EnsureTask()
end

function M.EnsureTask()
	if not M.task then
		M.task = SUI.Every(0.25, M.Sweep, "esport.sweep", true)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Off("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", M.OnLog)
	SUI.Off("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", M.OnLog)
	SUI.Off("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", M.OnLog)
	SUI.Cancel(M.task)
	M.task = nil
	M.Close()
end

function M.OnKey(key)
	if key == nil or string.find(key or EMPTY, "^esport%.") then
		if M.win and M.win:IsShown() then M.Paint() end
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("esport", 71)

local function opt(key, typ, order, def, extra)
	local o = { key = "esport." .. key, type = typ, cat = "esport", label = "opt.esport." .. key, tip = "tip.esport." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

SUI.RegisterModule("esport", {
	default = false,
	cost = "medium",
	options = {
		opt("lowfirst", "bool", 10, true, { simple = true }),
		opt("drwindow", "number", 20, 15, { min = 5, max = 30, step = 1 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- /sui esport [open|close] : suivi PvP (ennemis + DR).
SUI.RegisterCommand("esport", function(rest)
	if not M.on then
		C.Set("modules.esport", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	else
		M.ToggleWin()
	end
end, "help.esport")
