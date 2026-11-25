-- ShikiUI TankTools : alertes de tank (v0.9, module "tanktools"), dans l'esprit de Tankalyze et de TankSuite. Code reecrit, rien de copie.
-- SOURCES CONSULTEES (signatures et noms seulement ; TankSuite est a l'utilisateur, Tankalyze annonce un credit TauntBuddy et n'a pas de licence
--   dans son dossier) : Tankalyze (AddOns\Tankalyze, Core.lua / Localization.lua) liste les provocations Taunt, Growl, Mocking Blow, Hand of
--   Reckoning et Earthshaker Slam (ces deux derniers : ajouts du serveur Turtle WoW) et lit CHAT_MSG_SPELL_SELF_DAMAGE avec les chaines
--   SPELLRESISTSELFOTHER, SPELLMISSSELFOTHER, SPELLIMMUNESELFOTHER, SPELLEVADEDSELFOTHER, SPELLDODGEDSELFOTHER, SPELLPARRIEDSELFOTHER.
-- Ce que fait le module :
--   1. perte d'aggro : la cible n'a plus le joueur pour cible (unite "targettarget") -> alerte ; la provocation prete est signalee par un "!".
--   2. provocation ratee : message du journal de combat (resistee, ratee, immunisee, esquivee, parade) -> alerte, annonce au groupe en option.
--   3. barre des temps de recharge defensifs (GetSpellCooldown sur le grimoire, 1.12) avec temps restant.
--   4. vie basse du tank -> alerte qui nomme la premiere defense prete.
-- NON VERIFIE EN JEU : les noms de sorts (anglais) des jeux par classe, les noms des chaines du client (relevees dans Tankalyze), le son
--   (relevee dans DebuffAlert / Mod_Group), UIErrorsFrame:AddMessage, l'unite "targettarget". Pas fait : retrait automatique de Salvation.
-- Cout : "light". Une seule minuterie, cadres prepares une fois (hors combat), aucune table creee en combat.
-- Lua 5.0 : pas de #, de %, de select ni de ... ; au plus 32 valeurs externes par fonction.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.TankTools = M

local getn, tinsert = table.getn, table.insert
local floor, ceil, mmax = math.floor, math.ceil, math.max
local strfind, strformat = string.find, string.format
local EMPTY = ""

-- Pliage d'accents (le grimoire FR porte des accents : "Regeneration frenetique").
-- Les cles sont les sequences UTF-8 FR en decimales : \195\169 = e accentue, etc.
local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\146"] = "a", ["\195\149"] = "o", ["\195\154"] = "u", ["\195\161"] = "a", ["\195\163"] = "a",
	["\195\165"] = "a", ["\195\166"] = "a", ["\195\173"] = "i", ["\195\176"] = "o", ["\195\178"] = "o",
	["\195\177"] = "n", ["\195\145"] = "n", ["\195\152"] = "o", ["\195\151"] = "o",
}
local function fold(s)
	local out = string.lower(s)
	out = string.gsub(out, "\195[\128-\191]", PLAIN)
	return out
end
M.fold = fold

M.SOUND = "Sound\\Interface\\RaidWarning.wav"
M.MAXBTN = 8
M.GCD = 1.5           -- secondes : un recharge plus court est le delai global, pas un vrai temps de recharge
M.EVENTS = { "CHAT_MSG_SPELL_SELF_DAMAGE" }
M.ANNOUNCE = { "off", "auto" }

-- Provocations (noms anglais) : un echec sur l'une d'elles declenche l'alerte.
-- Client frFR (OctoWow) : les memes provocations sous leurs noms FR (journal et grimoire localises).
-- Candidats doubles pour les noms FR incertains : seul celui du grimoire / journal est retenu.
M.TAUNTS = { ["Taunt"] = true, ["Growl"] = true, ["Mocking Blow"] = true, ["Hand of Reckoning"] = true, ["Earthshaker Slam"] = true,
	["Challenging Shout"] = true, ["Challenging Roar"] = true,
	["Provocation"] = true, ["Grondement"] = true, ["Coup moqueur"] = true,
	["Cri d'affrontement"] = true, ["Rugissement d'affrontement"] = true,
	["Cri de defi"] = true, ["Rugissement de defi"] = true }
-- Resolution FR -> EN pour le grimoire (M.want est indexe par les noms EN).
M.FRBOOK = {
	["provocation"] = "Taunt", ["grondement"] = "Growl", ["coup moqueur"] = "Mocking Blow",
	["cri d'affrontement"] = "Challenging Shout", ["cri de defi"] = "Challenging Shout",
	["rugissement d'affrontement"] = "Challenging Roar", ["rugissement de defi"] = "Challenging Roar",
	["blocage"] = "Shield Block", ["mur protecteur"] = "Shield Wall", ["dernier rempart"] = "Last Stand",
	["frappe"] = "Bash", ["peau d'ecorce"] = "Barkskin", ["regeneration frenetique"] = "Frenzied Regeneration",
	["bouclier saint"] = "Holy Shield", ["protection divine"] = "Divine Protection",
	["marteau de la justice"] = "Hammer of Justice", ["imposition des mains"] = "Lay on Hands",
	["secousse terrestre"] = "Earth Shock",
}

-- Echecs : { chaine globale du client, code }. Les deux arguments du format sont (sort, cible) dans l'ordre du format.
M.FAILS = {
	{ "SPELLRESISTSELFOTHER", "resist" },
	{ "SPELLMISSSELFOTHER", "miss" },
	{ "SPELLIMMUNESELFOTHER", "immune" },
	{ "SPELLEVADEDSELFOTHER", "evade" },
	{ "SPELLDODGEDSELFOTHER", "dodge" },
	{ "SPELLPARRIEDSELFOTHER", "parry" },
}

-- Jeux par classe : { sort, genre } ; genre taunt (provocation), defense (defensif d'urgence), utility.
M.SETS = {
	WARRIOR = { { "Taunt", "taunt" }, { "Mocking Blow", "taunt" }, { "Challenging Shout", "taunt" }, { "Shield Block", "defense" },
		{ "Shield Wall", "defense" }, { "Last Stand", "defense" } },
	DRUID = { { "Growl", "taunt" }, { "Challenging Roar", "taunt" }, { "Bash", "utility" }, { "Barkskin", "defense" },
		{ "Frenzied Regeneration", "defense" } },
	PALADIN = { { "Hand of Reckoning", "taunt" }, { "Holy Shield", "defense" }, { "Divine Protection", "defense" },
		{ "Hammer of Justice", "utility" }, { "Lay on Hands", "defense" } },
	SHAMAN = { { "Earthshaker Slam", "taunt" }, { "Earth Shock", "utility" } },
}

M.cfg = { show = true, size = 32, spacing = 3, vertical = false, timer = true, alpha = 1, aggro = true, taunt = true, lowhp = 35,
	sound = true, flash = true, announce = "off", cooldown = 3, always = false, tick = 0.5, hideooc = false }
M.fails, M.nfails, M.nmissing = {}, 0, 0
M.last = {}
M.want, M.book, M.slots, M.slotn = {}, {}, {}, 0
M.btn = {}
M.holding = nil
M.lowFlag = false
M.nalert = 0
M.lastText = nil

-- ---------------------------------------------------------------- motifs du journal
function M.BuildPatterns()
	M.nfails, M.nmissing = 0, 0
	for i = getn(M.fails), 1, -1 do M.fails[i] = nil end
	local cmp = SUI.Meter and SUI.Meter.Compile
	for i = 1, getn(M.FAILS) do
		local fmt = getglobal(M.FAILS[i][1])
		if cmp and type(fmt) == "string" and fmt ~= EMPTY then
			local pat, order, n = cmp(fmt)
			if n == 2 then
				M.nfails = M.nfails + 1
				M.fails[M.nfails] = { pat = pat, first = order[1] == 1, why = M.FAILS[i][2] }
			else
				M.nmissing = M.nmissing + 1
			end
		else
			M.nmissing = M.nmissing + 1
		end
	end
	return M.nfails
end

-- ---------------------------------------------------------------- alertes
function M.Alert(kind, text, now)
	local last = M.last[kind]
	if last and now - last < M.cfg.cooldown then return false end
	M.last[kind] = now
	M.nalert = M.nalert + 1
	M.lastText = text
	local c = M.cfg
	if c.sound then PlaySoundFile(M.SOUND) end
	local f = getglobal("UIErrorsFrame")
	if c.flash and f and f.AddMessage then
		local col = T.c.bad
		f:AddMessage(text, col[1], col[2], col[3], 1, 2)
	end
	if not c.sound and not c.flash then SUI.Print(text) end
	return true
end

function M.TauntFailed(spell, target, why)
	local now = GetTime()
	local th = SUI.Threat
	if th and th.OnTauntFail then th.OnTauntFail(spell) end    -- la fenetre Menace retire sa ligne provisoire de provocation
	local reason = L("msg.tanktools.why." .. why)
	local shown = M.Alert("taunt", L("msg.tanktools.tauntfail", spell, reason, target), now)
	if shown and M.cfg.announce == "auto" then
		local chan = nil
		if GetNumRaidMembers() > 0 then chan = "RAID" elseif GetNumPartyMembers() > 0 then chan = "PARTY" end
		if chan then SendChatMessage(L("msg.tanktools.chat", spell, target, reason), chan) end
	end
	return shown
end

function M.OnLog(ev, a1)
	if not M.on or not M.active or not M.cfg.taunt or not a1 then return end
	for i = 1, M.nfails do
		local r = M.fails[i]
		local _, _, c1, c2 = strfind(a1, r.pat)
		if c1 then
			local spell, target = c2, c1
			if r.first then spell, target = c1, c2 end
			if M.TAUNTS[spell] then M.TauntFailed(spell, target, r.why) end
			return
		end
	end
end

-- Perte d'aggro : la cible avait le joueur pour cible, plus maintenant.
function M.CheckAggro(now, combat)
	local c = M.cfg
	if combat and UnitExists("target") and UnitCanAttack("player", "target") and UnitExists("targettarget") then
		local holder = UnitName("targettarget")
		local mine = (holder == M.player)
		if M.holding == true and not mine and c.aggro then
			M.Alert("aggro", L("msg.tanktools.lost", UnitName("target") or EMPTY, holder or EMPTY), now)
		end
		M.holding = mine
	else
		M.holding = nil
	end
end

-- Aggro pris par un allie : un monstre cible par un membre du groupe/raid vise un autre joueur que moi (meme si ce n'est pas ma cible).
function M.CheckAllies(now, combat)
	if not combat or not M.cfg.aggro then return end
	local n, pre = GetNumRaidMembers(), "raid"
	if n == 0 then n, pre = GetNumPartyMembers(), "party" end
	for i = 1, n do
		local u = pre .. i
		local mob = u .. "target"
		if UnitExists(mob) and UnitCanAttack("player", mob) and not UnitIsDead(mob) and UnitExists(mob .. "target") then
			local h = mob .. "target"
			if UnitIsPlayer(h) and not UnitIsUnit(h, "player") and UnitAffectingCombat(mob) then
				M.Alert("aggro2", L("msg.tanktools.lost", UnitName(mob) or EMPTY, UnitName(h) or EMPTY), now)
				return
			end
		end
	end
end

-- Premiere defense d'urgence prete (nom) ou nil.
function M.ReadyDefense()
	for i = 1, M.slotn do
		local s = M.slots[i]
		if s.kind == "defense" then
			local start, dur = GetSpellCooldown(s.idx, BOOKTYPE_SPELL)
			if not start or start == 0 or (dur or 0) <= M.GCD then return s.name end
		end
	end
	return nil
end

function M.CheckHealth(now, combat)
	local lim = M.cfg.lowhp
	if lim <= 0 or not combat then
		M.lowFlag = false
		return
	end
	local hp, mx = UnitHealth("player"), UnitHealthMax("player")
	if not mx or mx <= 0 or hp <= 0 then return end
	local pct = floor(hp * 100 / mx)
	if pct >= lim + 10 then
		M.lowFlag = false
	elseif pct < lim and not M.lowFlag then
		M.lowFlag = true
		local name = M.ReadyDefense()
		if name then
			M.Alert("low", L("msg.tanktools.lowcd", pct, name), now)
		else
			M.Alert("low", L("msg.tanktools.low", pct), now)
		end
	end
end

-- ---------------------------------------------------------------- grimoire et barre
function M.SelectSet()
	local _, cls = UnitClass("player")
	M.class = cls
	M.set = M.SETS[cls]
	M.active = (M.set ~= nil) or M.cfg.always
	for k in pairs(M.want) do M.want[k] = nil end
	if M.set then
		for i = 1, getn(M.set) do M.want[M.set[i][1]] = M.set[i][2] end
	end
end

function M.ScanBook()
	M.dirty = false
	for k in pairs(M.book) do M.book[k] = nil end
	local i = 1
	while i <= 400 do
		local name = GetSpellName(i, BOOKTYPE_SPELL)
		if not name then break end
		local en = M.FRBOOK[string.lower(name)] or name   -- grimoire FR : nom reel resol vers la cle EN
		if M.want[en] then M.book[en] = i end
		i = i + 1
	end
	local n = 0
	if M.set then
		for j = 1, getn(M.set) do
			local idx = M.book[M.set[j][1]]
			if idx and n < M.MAXBTN then
				n = n + 1
				local s = M.slots[n]
				if not s then s = {} M.slots[n] = s end
				s.name, s.kind, s.idx = M.set[j][1], M.set[j][2], idx
			end
		end
	end
	M.slotn = n
	M.barDirty = true
end

-- Design par jetons du style (aucune couleur en dur) : tanktools.bg = fond des icones (style | panel | bg | inset | none), tanktools.color =
-- couleur des temps (style = texte clair), tanktools.markcolor = couleur de la marque "!" (style = orange d'avertissement).
M.BGS = { "style", "panel", "bg", "inset", "none" }
M.COLORS = { "style", "good", "warn", "bad", "dim", "text" }
M.nobg = {}

function M.TokenRGB(name, default)
	local c = (name and name ~= "style") and T.c[name] or nil
	if not c then c = T.c[default] end
	return c[1], c[2], c[3]
end

-- Fond d'une icone selon tanktools.bg ; "none" = teinte du fond, opacite nulle. Les couleurs des textes suivent le meme chemin.
function M.StyleButton(b, force)
	local tok = M.cfg.bg or "style"
	if b.mbTok ~= tok or force then
		b.mbTok = tok
		if tok == "none" then
			local c = T.c.bg
			local z = M.nobg
			z[1], z[2], z[3], z[4] = c[1], c[2], c[3], 0
			T.Backdrop(b, z, T.c.border)
		elseif tok ~= "style" and T.c[tok] then
			T.Backdrop(b, T.c[tok], T.c.border)
		else
			T.Backdrop(b, T.c.bg, T.c.border)
		end
	end
	local r, g, bl = M.TokenRGB(M.cfg.color, "text")
	b.timer:SetTextColor(r, g, bl, 1)
	r, g, bl = M.TokenRGB(M.cfg.markcolor, "warn")
	b.mark:SetTextColor(r, g, bl, 1)
end

-- Changement de style / d'accent : le repeint du theme remet fonds et couleurs du style, on repose le choix de l'utilisateur.
function M.OnStyle()
	if not M.built then return end
	for i = 1, M.MAXBTN do M.StyleButton(M.btn[i], true) end
end

function M.BuildButton(parent)
	local b = CreateFrame("Frame", nil, parent)
	T.Backdrop(b, T.c.bg, T.c.border)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.timer = T.Text(b, 12, T.c.text, "CENTER", true)
	b.timer:SetPoint("CENTER", b, "CENTER", 0, 0)
	if SUI.Look then SUI.Look.ApplyText(b.timer, "tanktools", 12, true) end    -- police et taille des temps : tanktools.font / .fontsize
	b.mark = T.Text(b, 14, T.c.warn, "CENTER", true)
	b.mark:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
	M.StyleButton(b, true)
	b.key = -1
	b:Hide()
	return b
end

function M.Build()
	if M.built then return end
	local h = CreateFrame("Frame", "ShikiUI_TankTools", UIParent)
	h:SetWidth(100)
	h:SetHeight(32)
	M.holder = h
	for i = 1, M.MAXBTN do M.btn[i] = M.BuildButton(h) end
	SUI.Layout.Register(h, "tanktools.bar", "CENTER", 0, -220)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("tanktools.bar", h, { label = "mod.mover.n.tanktools.bar", scale = true, always = true })
	end
	T.GearButton(h, "tanktools", { size = 12, point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", x = 0, y = 1, title = L("msg.tanktools.gear"),
		onCreate = function(g) M.gear = g end })
	T.OnAccent(M.OnStyle)
	M.built = true
	M.barDirty = true
	M.VisAdd()
end

-- Visibilite conditionnelle (tanktools.vis / .fade, SUI.Visibility, mode "show") : le service fond puis cache la barre.
function M.VisAdd()
	local V = SUI.Visibility
	if not V or not M.on or not M.built then return end
	if V.byFrame[M.holder] then return end
	V.Add(M.holder, "tanktools", { mode = "show", module = "tanktools", alpha = M.cfg.alpha, cat = "tanktools" })
end

-- Retire la barre du service quand le module est coupe (differe : Remove detache un observateur, jamais pendant une notification).
function M.VisDrop()
	local V = SUI.Visibility
	if M.on or not V or not M.built then return end
	V.Remove(M.holder)
end

function M.Layout()
	if not M.built then return end
	local c = M.cfg
	local sz, sp = c.size, c.spacing
	for i = 1, M.MAXBTN do
		local b = M.btn[i]
		b:SetWidth(sz)
		b:SetHeight(sz)
		b:ClearAllPoints()
		if i <= M.slotn then
			local s = M.slots[i]
			b.icon:SetTexture(GetSpellTexture(s.idx, BOOKTYPE_SPELL))
			if c.vertical then b:SetPoint("TOPLEFT", M.holder, "TOPLEFT", 0, -(i - 1) * (sz + sp))
			else b:SetPoint("TOPLEFT", M.holder, "TOPLEFT", (i - 1) * (sz + sp), 0) end
			b:Show()
		else
			b:Hide()
		end
		b.key = -1
		b.mk = nil
		M.StyleButton(b)
	end
	local n = mmax(M.slotn, 1)
	if c.vertical then
		M.holder:SetWidth(sz)
		M.holder:SetHeight(n * sz + (n - 1) * sp)
	else
		M.holder:SetWidth(n * sz + (n - 1) * sp)
		M.holder:SetHeight(sz)
	end
	local V = SUI.Visibility
	if V and V.byFrame[M.holder] then V.SetBase(M.holder, c.alpha) else M.holder:SetAlpha(c.alpha) end
	M.barDirty = false
end

function M.UpdateBar(now)
	if not M.built then return end
	if M.barDirty then M.Layout() end
	local c = M.cfg
	local V = SUI.Visibility
	local want = M.on and c.show and M.slotn > 0
	if want and not M.holder:IsShown() and (not V or V.Allowed(M.holder)) then M.holder:Show()
	elseif not want and M.holder:IsShown() then M.holder:Hide() end
	if not want then return end
	for i = 1, M.slotn do
		local s = M.slots[i]
		local b = M.btn[i]
		local start, dur = GetSpellCooldown(s.idx, BOOKTYPE_SPELL)
		local left = nil
		if start and start > 0 and dur and dur > M.GCD then left = start + dur - now end
		if left and left <= 0 then left = nil end
		local key = 0
		if left and c.timer then
			if left >= 60 then key = 100000 + floor(left / 60) else key = ceil(left) end
		end
		if b.key ~= key then
			b.key = key
			if key == 0 then b.timer:SetText(EMPTY)
			elseif key >= 100000 then b.timer:SetText(strformat("%dm", key - 100000))
			else b.timer:SetText(strformat("%d", key)) end
		end
		local alpha = left and 0.45 or 1
		if b.al ~= alpha then
			b.al = alpha
			b.icon:SetAlpha(alpha)
		end
		local mk = (s.kind == "taunt" and M.holding == false and not left) and "!" or EMPTY
		if b.mk ~= mk then
			b.mk = mk
			b.mark:SetText(mk)
		end
	end
end

-- ---------------------------------------------------------------- minuterie et reglages
function M.Tick()
	if not M.on then return end
	local now = GetTime()
	local combat = UnitAffectingCombat("player") and true or false
	M.inCombat = combat
	if M.dirty then M.ScanBook() end
	if M.active then
		M.CheckAggro(now, combat)
		M.CheckAllies(now, combat)
		M.CheckHealth(now, combat)
	end
	M.UpdateBar(now)
end

function M.OnBook()
	M.dirty = true
end

function M.OnTarget()
	M.holding = nil
end

function M.ReadConfig()
	local c = M.cfg
	c.show = C.Get("tanktools.show")
	c.size = C.Get("tanktools.size")
	c.spacing = C.Get("tanktools.spacing")
	c.vertical = C.Get("tanktools.vertical")
	c.timer = C.Get("tanktools.timer")
	c.bg = C.Get("tanktools.bg")
	c.color = C.Get("tanktools.color")
	c.markcolor = C.Get("tanktools.markcolor")
	c.alpha = C.Get("tanktools.alpha")
	c.aggro = C.Get("tanktools.aggro")
	c.taunt = C.Get("tanktools.taunt")
	c.lowhp = C.Get("tanktools.lowhp")
	c.sound = C.Get("tanktools.sound")
	c.flash = C.Get("tanktools.flash")
	c.announce = C.Get("tanktools.announce")
	c.cooldown = C.Get("tanktools.cooldown")
	c.always = C.Get("tanktools.always")
	c.tick = C.Get("tanktools.tick")
	c.hideooc = C.Get("tanktools.hideooc")
end

-- Ancien reglage tanktools.hideooc (cacher hors combat) : migre vers tanktools.vis = "combat" (SUI.Visibility) et reste synchronise avec lui.
function M.SyncVis(key)
	local vis, old = C.Get("tanktools.vis"), C.Get("tanktools.hideooc")
	if key == "tanktools.hideooc" then
		if old and vis == "always" then C.Set("tanktools.vis", "combat")
		elseif not old and vis == "combat" then C.Set("tanktools.vis", "always") end
		return
	end
	if key == nil and old and vis == "always" then
		vis = "combat"
		C.Set("tanktools.vis", vis)
	end
	if old ~= (vis == "combat") then C.Set("tanktools.hideooc", vis == "combat") end
end

function M.OnKey(key, value)
	if key == nil or key == "tanktools.vis" or key == "tanktools.hideooc" then M.SyncVis(key) end
	M.ReadConfig()
	if not M.on then return end
	M.SelectSet()
	M.dirty = true
	M.barDirty = true
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(M.cfg.tick, M.Tick, "tanktools.tick", true)
	-- effet immediat (sans attendre la minuterie) : taille, espacement, sens, opacite, visibilite, temps affiches
	if M.built then
		M.VisAdd()
		M.Layout()
		M.UpdateBar(GetTime())
	end
end

function M.Enable()
	M.SyncVis(nil)
	M.on = true
	M.ReadConfig()
	M.player = UnitName("player")
	M.SelectSet()
	M.BuildPatterns()
	M.ScanBook()
	for i = 1, getn(M.EVENTS) do SUI.On(M.EVENTS[i], M.OnLog) end
	SUI.On("SPELLS_CHANGED", M.OnBook)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnBook)
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	if not M.watching then
		M.watching = true
		C.Watch("tanktools.", M.OnKey)
	end
	M.task = SUI.Every(M.cfg.tick, M.Tick, "tanktools.tick", true)
	if not M.warned then
		M.warned = true
		local isl = getglobal("IsAddOnLoaded")
		if isl then
			local others = { "Tankalyze", "TankSuite" }
			for i = 1, getn(others) do
				if isl(others[i]) then SUI.Print(L("msg.tanktools.other", others[i])) end
			end
		end
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.VisAdd()
		M.Layout()
		M.UpdateBar(GetTime())
	end)
end

function M.Disable()
	M.on = false
	for i = 1, getn(M.EVENTS) do SUI.Off(M.EVENTS[i], M.OnLog) end
	SUI.Off("SPELLS_CHANGED", M.OnBook)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnBook)
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Cancel(M.task)
	M.task = nil
	if M.built then M.holder:Hide() end
	if SUI.Visibility then SUI.After(0.05, M.VisDrop, "tanktools.visdrop") end
	M.holding = nil
	M.lowFlag = false
	for k in pairs(M.last) do M.last[k] = nil end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("tanktools", 36)

local function opt(key, typ, order, def, extra)
	local o = { key = "tanktools." .. key, type = typ, cat = "tanktools", label = "opt.tanktools." .. key, tip = "tip.tanktools." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function announceText(o, v) return L("choice.tanktools.announce." .. v) end
local function bgText(o, v) return L("choice.tanktools.bg." .. v) end
local function colText(o, v) return L("choice.tanktools.color." .. v) end
local function markText(o, v) return L("choice.tanktools.markcolor." .. v) end

-- Options communes du socle : visibilite conditionnelle (tanktools.vis / .fade) et police des temps (tanktools.font / .fontsize).
local function addAll(list)
	local d = SUI.Visibility.Options("tanktools", { cat = "tanktools", order = 800 })
	for i = 1, getn(d) do tinsert(list, d[i]) end
	d = SUI.Look.Options("tanktools", { font = true, cat = "tanktools", order = 820 })
	for i = 1, getn(d) do tinsert(list, d[i]) end
	tinsert(list, opt("bg", "choice", 830, "style", { choices = M.BGS, choiceText = bgText }))
	tinsert(list, opt("color", "choice", 831, "style", { choices = M.COLORS, choiceText = colText }))
	tinsert(list, opt("markcolor", "choice", 832, "style", { choices = M.COLORS, choiceText = markText }))
	return list
end

SUI.RegisterModule("tanktools", {
	default = false,
	cost = "light",
	options = addAll({
		opt("show", "bool", 10, true, { simple = true }),
		opt("size", "number", 20, 32, { min = 20, max = 60, step = 2, simple = true }),
		opt("aggro", "bool", 30, true, { simple = true }),
		opt("taunt", "bool", 40, true, { simple = true }),
		opt("lowhp", "number", 50, 35, { min = 0, max = 60, step = 5, simple = true }),
		opt("sound", "bool", 60, true, { simple = true }),
		opt("flash", "bool", 70, true),
		opt("announce", "choice", 80, "off", { choices = M.ANNOUNCE, choiceText = announceText }),
		opt("timer", "bool", 90, true),
		opt("vertical", "bool", 100, false),
		opt("spacing", "number", 110, 3, { min = 0, max = 12, step = 1 }),
		opt("alpha", "number", 120, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("cooldown", "number", 130, 3, { min = 1, max = 10, step = 1 }),
		opt("hideooc", "bool", 140, false),
		opt("always", "bool", 150, false),
		opt("tick", "number", 160, 0.5, { min = 0.25, max = 1, step = 0.05 }),
	}),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Aucun module pfUI equivalent (pfUI n'a pas d'outil de tank) : pas d'entree dans Migrate.MAP.
-- Mode Raid : version minimale (icones plus petites, relecture plus lente, pas de temps affiche).
SUI.Config.AddPreset("raid", "*", { ["tanktools.size"] = 28, ["tanktools.tick"] = 1, ["tanktools.timer"] = false, ["tanktools.announce"] = "off" })

SUI.RegisterCommand("tank", function(rest)
	if rest == "test" then
		M.last.test = nil
		M.Alert("test", L("msg.tanktools.test"), GetTime())
	else
		SUI.Print(L("msg.tanktools.status", M.class or EMPTY, M.slotn, M.nfails, M.nmissing))
	end
end, "help.tanktools")
