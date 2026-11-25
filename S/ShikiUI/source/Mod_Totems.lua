-- ShikiUI Totems : gestionnaire de totems du chaman (v0.4, module "totems"), dans l'esprit de CallOfElements (aucun code copie) :
-- une barre terre / feu / eau / air, un bouton "tous", des jeux (presets), la duree restante de chaque totem pose.
-- Donnees : noms de sorts et durees relevees dans ShamanRotation_Totems.lua (Spell.dbc du serveur, addon du joueur) pour 14 totems, et dans
--   pfUI libs/libtotem.lua (MIT, durees par rang de sort) pour Earthbind 45, Stoneclaw 15, Grounding 45, Mana Tide 12, totems de resistance
--   120, Windwall 120. Sentry : AUCUNE duree relevee (pas de minuteur). Conflit connu : Windfury 90 (ShamanRotation) contre 120 (pfUI) ->
--   90 retenu (addon du joueur, donnee du serveur). Les jeux (caster, melee, aoe, nova, fear, poison, disease) reprennent ShamanRotation.
--   Les noms de sorts sont ceux du client ANGLAIS : un client francais ne trouvera pas les totems (limite assumee).
-- Pose reperee par : Nampower SPELL_GO_SELF(objet, sort, lanceur, ...) ; SuperWoW UNIT_CASTEVENT(lanceur, cible, "CAST", sort) ; sinon le
--   message de combat CHAT_MSG_SPELL_SELF_BUFF (nom du totem dans le texte, repere dans CallOfElements). "Totemic Recall" efface tout.
--   Aucune API 1.12 ne dit si un totem est detruit ou hors de portee : le suivi est un MINUTEUR remis a zero a la mort et au changement de zone.
-- Cout declare : LIGHT. Une minuterie partagee (0,25 s) qui ne fait rien tant qu'aucun totem n'est pose, cadres construits hors combat,
--   aucune creation en combat, texte reecrit seulement quand la seconde change.
-- NON VERIFIE en jeu : les noms des evenements ci-dessus, le texte du message de pose, CastSpellByName sur les totems, les durees ci-dessus.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Totems = M

local getn = table.getn
local floor = math.floor
local strformat = string.format
local EMPTY = ""

M.ELEMENTS = { "earth", "fire", "water", "air" }
-- { cle, element, nom du sort (client anglais), duree en secondes ou nil }
M.DATA = {
	{ "earthbind", "earth", "Earthbind Totem", 45, "Totem Liens terrestres" }, { "stoneclaw", "earth", "Stoneclaw Totem", 15, "Totem Griffe de pierre" },
	{ "stoneskin", "earth", "Stoneskin Totem", 120, "Totem Peau de pierre" }, { "strengthofearth", "earth", "Strength of Earth Totem", 120, "Totem Force de la terre" },
	{ "tremor", "earth", "Tremor Totem", 120, "Totem Secousses" },
	{ "firenova", "fire", "Fire Nova Totem", 5, "Totem Nova de feu" }, { "flametongue", "fire", "Flametongue Totem", 120, "Totem Langue de feu" },
	{ "frostresistance", "fire", "Frost Resistance Totem", 120, "Totem de resistance au givre" }, { "magma", "fire", "Magma Totem", 20, "Totem Magma" },
	{ "searing", "fire", "Searing Totem", 55, "Totem Ardent" },
	{ "diseasecleansing", "water", "Disease Cleansing Totem", 120, "Totem Purificateur de maladie" }, { "fireresistance", "water", "Fire Resistance Totem", 120, "Totem de resistance au feu" },
	{ "healingstream", "water", "Healing Stream Totem", 60, "Totem Flux de soins" }, { "manaspring", "water", "Mana Spring Totem", 60, "Totem Source de mana" },
	{ "manatide", "water", "Mana Tide Totem", 12, "Totem Maree de mana" }, { "poisoncleansing", "water", "Poison Cleansing Totem", 120, "Totem Purificateur de poison" },
	{ "graceofair", "air", "Grace of Air Totem", 120, "Totem Grace de l'air" }, { "grounding", "air", "Grounding Totem", 45, "Totem Terre-a-terre" },
	{ "natureresistance", "air", "Nature Resistance Totem", 120, "Totem de resistance a la nature" }, { "sentry", "air", "Sentry Totem", nil, "Totem Sentinelle" },
	{ "tranquilair", "air", "Tranquil Air Totem", 120, "Totem d'air paisible" }, { "windfury", "air", "Windfury Totem", 90, "Totem Furie-des-vents" },
	{ "windwall", "air", "Windwall Totem", 120, "Totem Mur de vent" },
}
M.PRESETS = {
	caster = { fire = "searing", water = "manaspring", air = "tranquilair" },
	melee = { fire = "flametongue", air = "windfury", earth = "strengthofearth", water = "manaspring" },
	aoe = { fire = "magma", water = "manaspring", air = "tranquilair" },
	nova = { fire = "firenova", water = "manaspring", air = "tranquilair" },
	fear = { fire = "searing", water = "manaspring", air = "tranquilair", earth = "tremor" },
	poison = { fire = "searing", water = "poisoncleansing", air = "tranquilair" },
	disease = { fire = "searing", water = "diseasecleansing", air = "tranquilair" },
}
M.PRESET_LIST = { "custom", "caster", "melee", "aoe", "nova", "fear", "poison", "disease" }
M.byKey, M.byName = {}, {}
-- pliage d'accents (client frFR) : les comparaisons de noms totems ignorent les accents.
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
M.list = { earth = {}, fire = {}, water = {}, air = {} }   -- element -> { cles } (ordre du tableau)
M.byFold = {}
for i = 1, getn(M.DATA) do
	local d = M.DATA[i]
	local rec = { key = d[1], el = d[2], name = d[3], dur = d[4], fr = d[5] }
	M.byKey[rec.key] = rec
	M.byName[rec.name] = rec
	if rec.fr then M.byName[rec.fr] = rec end
	M.byFold[fold(rec.name)] = rec
	if rec.fr then M.byFold[fold(rec.fr)] = rec end
	table.insert(M.list[rec.el], rec.key)
end

M.on = false
M.built = false
M.btn = {}
M.cur, M.at = {}, {}      -- element -> totem pose (fiche), instant de pose
M.known = {}              -- nom -> texture (grimoire)
M.applying = false
M.sicon = {}
M.cfg = { preset = "caster", earth = "none", fire = "searing", water = "manaspring", air = "tranquilair", size = 34, spacing = 3,
	timer = true, warn = 10, vertical = false, allbutton = true, autoreset = true, alpha = 1, tick = 0.25, announce = false }

function M.ReadConfig()
	local cfg = M.cfg
	cfg.preset = C.Get("totems.preset")
	for i = 1, 4 do cfg[M.ELEMENTS[i]] = C.Get("totems." .. M.ELEMENTS[i]) end
	cfg.size = C.Get("totems.size")
	cfg.spacing = C.Get("totems.spacing")
	cfg.timer = C.Get("totems.timer")
	cfg.warn = C.Get("totems.warn")
	cfg.vertical = C.Get("totems.vertical")
	cfg.allbutton = C.Get("totems.allbutton")
	cfg.autoreset = C.Get("totems.autoreset")
	cfg.alpha = C.Get("totems.alpha")
	cfg.tick = C.Get("totems.tick")
	cfg.announce = C.Get("totems.announce")
	cfg.bg = C.Get("totems.bg")
	cfg.color = C.Get("totems.color")
	cfg.coloron = C.Get("totems.coloron")
	cfg.colorwarn = C.Get("totems.colorwarn")
end

-- Design par jetons du style (aucune couleur en dur) : totems.bg = fond des boutons (style | panel | bg | inset | none), totems.color =
-- couleur des temps (style = texte clair), totems.coloron = bordure d'un totem en place (style = accent), totems.colorwarn = bordure d'un
-- totem bientot fini (style = orange d'avertissement).
M.BGS = { "style", "panel", "bg", "inset", "none" }
M.COLORS = { "style", "good", "warn", "bad", "dim", "text" }
M.nobg = {}

function M.TokenRGB(name, default)
	local c = (name and name ~= "style") and T.c[name] or nil
	if not c then c = T.c[default] end
	return c[1], c[2], c[3]
end

-- Fond d'un bouton selon totems.bg ("none" = teinte du fond, opacite nulle) et couleur des temps / etiquettes.
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
		b.lastState = nil          -- le fond repeint remet la bordure neutre : on la redessine
	end
	local r, g, bl = M.TokenRGB(M.cfg.color, "text")
	b.timer:SetTextColor(r, g, bl, 1)
	b.label:SetTextColor(r, g, bl, 1)
end

-- ---------------------------------------------------------------- grimoire
function M.ScanBook()
	if SUI.InCombat() then M.bookPending = true return end
	M.bookPending = false
	local known = {}
	local i = 1
	while true do
		local name = GetSpellName(i, "spell")
		if not name then break end
		local rec = M.byName[name] or M.byFold[fold(name)]
		if rec then
			rec.cname = name   -- nom reel du grimoire (frFR chez OctoWow) : utilise pour l'incantation
			known[rec.cname] = GetSpellTexture(i, "spell") or false
		end
		i = i + 1
	end
	M.known = known
	M.Paint()
end

function M.Selected(el)
	local k = M.cfg[el]
	if not k or k == "none" then return nil end
	return M.byKey[k]
end

-- ---------------------------------------------------------------- pose et suivi
function M.Place(name, now)
	if name == "Totemic Recall" then M.Clear() return end
	local d = M.byName[name]
	if not d then return end
	local el = d.el
	if M.cur[el] == d and M.at[el] and now - M.at[el] < 0.5 then return end
	M.cur[el] = d
	M.at[el] = now
	M.lastState = nil
	M.Paint()
end

function M.Clear()
	for i = 1, 4 do
		local el = M.ELEMENTS[i]
		M.cur[el] = nil
		M.at[el] = nil
	end
	M.Paint()
end

function M.NameOf(spell)
	local t = M.sicon[spell]
	if t ~= nil then return t or nil end
	local info = getglobal("SpellInfo")
	if info then
		local n = info(spell)
		M.sicon[spell] = n or false
		return n
	end
	return nil
end

function M.OnGo(ev, a1, a2)
	-- SPELL_GO_SELF(objet, sort, ...)
	local n = M.NameOf(a2)
	if n then M.Place(n, GetTime()) end
end

function M.OnCastEvent(ev, a1, a2, a3, a4)
	-- UNIT_CASTEVENT(lanceur, cible, type, sort, duree)
	if a3 ~= "CAST" or not M.playerGuid or a1 ~= M.playerGuid then return end
	local n = M.NameOf(a4)
	if n then M.Place(n, GetTime()) end
end

function M.OnChat(ev, a1)
	if not a1 then return end
	local low = fold(a1)   -- plie : le texte FR accentue du client est compare aux noms plies
	local now = GetTime()
	for i = 1, getn(M.DATA) do
		local en, fr = M.DATA[i][3], M.DATA[i][5]
		if (en and string.find(low, fold(en), 1, true)) or (fr and string.find(low, fold(fr), 1, true)) then M.Place(en, now) return end
	end
	if string.find(low, "totemic recall", 1, true) or string.find(low, "rappel totemique", 1, true) then M.Clear() end
end

function M.OnReset()
	if M.cfg.autoreset then M.Clear() end
end

function M.Cast(el)
	local d = M.Selected(el)
	if not d then SUI.Print(L("msg.totems.none")) return false end
	if not (d.cname and M.known[d.cname]) then SUI.Print(L("msg.totems.unknown", d.cname or d.name)) return false end
	CastSpellByName(d.cname or d.name)
	return true
end

-- Pose tous les totems du jeu qui manquent (ou finissent). Les elements ont chacun leur GCD : tout part dans le meme appui.
function M.CastAll()
	local now = GetTime()
	local n = 0
	for i = 1, 4 do
		local el = M.ELEMENTS[i]
		local d = M.Selected(el)
		if d and d.cname and M.known[d.cname] ~= nil then
			local left = M.Left(el, now)
			if M.cur[el] ~= d or not left or left < 3 then
				CastSpellByName(d.cname or d.name)
				n = n + 1
			end
		end
	end
	if n == 0 then SUI.Print(L("msg.totems.allset")) end
	return n
end

-- Secondes restantes du totem de l'element (nil si rien, 9999 si sans duree connue).
function M.Left(el, now)
	local d = M.cur[el]
	if not d or not M.at[el] then return nil end
	if not d.dur then return 9999 end
	local left = M.at[el] + d.dur - now
	if left <= 0 then return nil end
	return left
end

function M.ApplyPreset(name)
	local p = M.PRESETS[name]
	if not p then return end
	M.applying = true
	for i = 1, 4 do
		local el = M.ELEMENTS[i]
		C.Set("totems." .. el, p[el] or "none")
	end
	M.applying = false
	M.ReadConfig()
	M.Paint()
end

-- Clic droit : totem suivant de l'element (parmi ceux du grimoire), puis "aucun".
function M.Cycle(el)
	local cur = M.cfg[el]
	local list = M.list[el]
	local idx = 0
	for i = 1, getn(list) do if list[i] == cur then idx = i end end
	for step = 1, getn(list) + 1 do
		local j = idx + step
		if j > getn(list) + 1 then j = j - getn(list) - 1 end
		if j == getn(list) + 1 then C.Set("totems." .. el, "none") return end
		local d = M.byKey[list[j]]
		if d.cname and M.known[d.cname] ~= nil then C.Set("totems." .. el, list[j]) return end
	end
end

-- ---------------------------------------------------------------- affichage
local function timeKey(left)
	if left >= 9999 then return -2 end
	return floor(left)
end

local function timeText(k)
	if k < 0 then return EMPTY end
	if k >= 60 then
		local m = floor(k / 60)
		return strformat("%d:%02d", m, k - m * 60)
	end
	return strformat("%d", k)
end

local function setBorder(b, c)
	b:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
end

-- Etat visuel d'un bouton : 0 = rien de choisi / inconnu, 1 = manque, 2 = en place, 3 = bientot fini.
function M.PaintButton(el, now)
	local b = M.btn[el]
	if not b then return end
	local d = M.Selected(el)
	local shown = d
	local tex = nil
	if d and d.cname then tex = M.known[d.cname] end
	local active = M.cur[el]
	local left = M.Left(el, now)
	if active and left and (not d or active ~= d) then shown = active tex = (active.cname and M.known[active.cname]) or nil end
	local state = 0
	if d and d.cname and M.known[d.cname] ~= nil then state = 1 end
	if left then state = (left < M.cfg.warn) and 3 or 2 end
	if tex ~= b.lastTex then
		b.lastTex = tex
		if tex then b.icon:SetTexture(tex) b.icon:Show() else b.icon:Hide() end
	end
	if state ~= b.lastState then
		b.lastState = state
		if state == 3 then
			local r, g, bl = M.TokenRGB(M.cfg.colorwarn, "warn")
			b:SetBackdropBorderColor(r, g, bl, 1)
		elseif state == 2 then
			local r, g, bl
			if M.cfg.coloron and M.cfg.coloron ~= "style" then r, g, bl = M.TokenRGB(M.cfg.coloron, "good") else r, g, bl = T.Accent() end
			b:SetBackdropBorderColor(r, g, bl, 1)
		else setBorder(b, T.c.border) end
		b.icon:SetAlpha(state == 0 and 0.35 or (state == 1 and 0.6 or 1))
	end
	local key = -1
	if M.cfg.timer and left then key = timeKey(left) end
	if key ~= b.lastKey then
		b.lastKey = key
		b.timer:SetText(timeText(key))
	end
end

function M.Paint()
	if not M.built then return end
	local now = GetTime()
	for i = 1, 4 do M.PaintButton(M.ELEMENTS[i], now) end
end

function M.Tick()
	if not M.built then return end
	local now = GetTime()
	local any = false
	for i = 1, 4 do
		local el = M.ELEMENTS[i]
		if M.cur[el] then
			any = true
			if not M.Left(el, now) then
				if M.cfg.announce then SUI.Print(L("msg.totems.expired", M.cur[el].name)) end
				M.cur[el] = nil
				M.at[el] = nil
			end
		end
	end
	if any or M.dirty then
		M.dirty = false
		M.Paint()
	end
end

-- ---------------------------------------------------------------- construction (hors combat)
local function clickButton()
	local b = this
	if not b.el then return end
	if b.el == "all" then
		M.CastAll()
	elseif arg1 == "RightButton" then
		M.Cycle(b.el)
	else
		M.Cast(b.el)
	end
end

local function enterButton()
	local b = this
	GameTooltip:SetOwner(b, "ANCHOR_TOP")
	if b.el == "all" then
		GameTooltip:AddLine(L("msg.totems.alltip"))
	else
		local d = M.Selected(b.el)
		GameTooltip:AddLine(d and d.name or L("msg.totems.none"))
		GameTooltip:AddLine(L("msg.totems.hint"))
	end
	GameTooltip:Show()
end

local function leaveButton()
	GameTooltip:Hide()
end

function M.BuildButton(parent, el)
	local b = CreateFrame("Button", nil, parent)
	b.el = el
	T.Backdrop(b, T.c.bg, T.c.border)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:Hide()
	b.timer = T.Text(b, 11, T.c.text, "CENTER", true)
	b.timer:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label = T.Text(b, 10, T.c.text, "CENTER", true)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	if SUI.Look then
		SUI.Look.ApplyText(b.timer, "totems", 11, true)    -- police et taille des temps : totems.font / .fontsize
		SUI.Look.ApplyText(b.label, "totems", 10, true)
	end
	M.StyleButton(b, true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", clickButton)
	b:SetScript("OnEnter", enterButton)
	b:SetScript("OnLeave", leaveButton)
	b.lastKey = -1
	return b
end

function M.Build()
	if M.built then return end
	local h = CreateFrame("Frame", "ShikiUI_Totems", UIParent)
	h:SetWidth(160)
	h:SetHeight(34)
	M.holder = h
	for i = 1, 4 do M.btn[M.ELEMENTS[i]] = M.BuildButton(h, M.ELEMENTS[i]) end
	M.btn.all = M.BuildButton(h, "all")
	M.btn.all.label:SetText(L("msg.totems.alllabel"))
	h.hint = h:CreateTexture(nil, "BACKGROUND")
	h.hint:SetAllPoints(h)
	h.hint:SetTexture(T.tex.white)
	h.hint:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 0.3)
	SUI.Layout.Register(h, "totems.bar", "CENTER", 0, -160)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("totems.bar", h, { label = "mod.mover.n.totems.bar", scale = true, always = true })
	end
	T.GearButton(h, "totems", { size = 12, point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", x = 0, y = 1, title = L("msg.totems.gear"),
		onCreate = function(g) M.gear = g end })
	T.OnAccent(M.OnStyle)
	M.built = true
	M.ApplyOptions()
end

-- Changement de style / d'accent : le repeint du theme remet la bordure neutre, on redessine l'etat de chaque bouton.
function M.OnStyle()
	if not M.built then return end
	for i = 1, 5 do
		local b = M.btn[i <= 4 and M.ELEMENTS[i] or "all"]
		b.lastState = nil
		M.StyleButton(b, true)
	end
	M.Paint()
end

function M.ApplyLock()
	if not M.built then return end
	M.holder.hint:Hide()      -- la poignee nommee est dessinee par le service Mover (Mover.lua)
end

function M.ApplyOptions()
	if not M.built then return end
	local c = M.cfg
	local sz, sp = c.size, c.spacing
	local order = { "earth", "fire", "water", "air", "all" }
	local n = c.allbutton and 5 or 4
	for i = 1, 5 do
		local b = M.btn[order[i]]
		b:SetWidth(sz)
		b:SetHeight(sz)
		b:ClearAllPoints()
		if i <= n then
			if c.vertical then b:SetPoint("TOPLEFT", M.holder, "TOPLEFT", 0, -(i - 1) * (sz + sp))
			else b:SetPoint("TOPLEFT", M.holder, "TOPLEFT", (i - 1) * (sz + sp), 0) end
			b:Show()
		else
			b:Hide()
		end
	end
	if c.vertical then
		M.holder:SetWidth(sz)
		M.holder:SetHeight(n * sz + (n - 1) * sp)
	else
		M.holder:SetWidth(n * sz + (n - 1) * sp)
		M.holder:SetHeight(sz)
	end
	local V = SUI.Visibility
	if V and V.byFrame[M.holder] then V.SetBase(M.holder, c.alpha) else M.holder:SetAlpha(c.alpha) end
	for i = 1, 5 do
		local b = M.btn[order[i]]
		b.lastKey, b.lastState, b.lastTex = -1, nil, nil
		M.StyleButton(b)
		b.timer:SetText(EMPTY)
	end
	if M.active then
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(c.tick, M.Tick, "totems.tick", true)
	end
	M.dirty = true
	M.Paint()
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	M.ReadConfig()
	if key == "totems.preset" then
		if M.cfg.preset ~= "custom" and not M.applying then M.ApplyPreset(M.cfg.preset) end
	elseif not M.applying and (key == "totems.earth" or key == "totems.fire" or key == "totems.water" or key == "totems.air") then
		if M.cfg.preset ~= "custom" then
			M.applying = true
			C.Set("totems.preset", "custom")
			M.applying = false
			M.ReadConfig()
		end
	end
	M.ApplyOptions()
end

function M.IsShaman()
	local _, cls = UnitClass("player")
	return cls == "SHAMAN"
end

-- Visibilite conditionnelle (totems.vis / .fade, SUI.Visibility, mode "show") : le service fond puis cache la barre.
function M.VisAdd()
	local V = SUI.Visibility
	if not V or not M.built then return end
	if V.byFrame[M.holder] then return end
	V.Add(M.holder, "totems", { mode = "show", module = "totems", alpha = M.cfg.alpha, cat = "totems" })
end

-- Retire la barre du service quand le module est coupe (differe : Remove detache un observateur, jamais pendant une notification).
function M.VisDrop()
	local V = SUI.Visibility
	if M.active or not V or not M.built then return end
	V.Remove(M.holder)
end

function M.Activate()
	if M.active then return end
	M.active = true
	M.playerGuid = SUI.Api.GUID("player")
	SUI.On("CHAT_MSG_SPELL_SELF_BUFF", M.OnChat)
	SUI.On("LEARNED_SPELL_IN_TAB", M.ScanBook)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.On("PLAYER_DEAD", M.OnReset)
	SUI.On("ZONE_CHANGED_NEW_AREA", M.OnReset)
	if SUI.Api.nampower then SUI.On("SPELL_GO_SELF", M.OnGo) end
	if SUI.Api.superwow then SUI.On("UNIT_CASTEVENT", M.OnCastEvent) end
	M.task = SUI.Every(M.cfg.tick, M.Tick, "totems.tick", true)
	M.VisAdd()
end

function M.OnRegen()
	if M.bookPending then M.ScanBook() end
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Off("CHAT_MSG_SPELL_SELF_BUFF", M.OnChat)
	SUI.Off("LEARNED_SPELL_IN_TAB", M.ScanBook)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.Off("PLAYER_DEAD", M.OnReset)
	SUI.Off("ZONE_CHANGED_NEW_AREA", M.OnReset)
	SUI.Off("SPELL_GO_SELF", M.OnGo)
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Cancel(M.task)
	M.task = nil
	if SUI.Visibility and M.built then SUI.After(0.05, M.VisDrop, "totems.visdrop") end
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	if not M.watching then
		M.watching = true
		C.Watch("totems.", M.OnKey)
		C.Watch("ui.locked", M.ApplyLock)
	end
	if not M.IsShaman() then
		SUI.Print(L("msg.totems.notshaman"))
		return
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.ScanBook()
		M.Activate()
		local V = SUI.Visibility
		if not V or V.Allowed(M.holder) then M.holder:Show() end
		M.ApplyOptions()
		M.ApplyLock()
	end)
end

function M.Disable()
	M.on = false
	M.Deactivate()
	if M.built then
		M.holder:Hide()
		M.Clear()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("totems", 39)

local function opt(key, typ, order, def, extra)
	local o = { key = "totems." .. key, type = typ, cat = "totems", label = "opt.totems." .. key, tip = "tip.totems." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function elementChoices(el)
	local c = { "none" }
	for i = 1, getn(M.list[el]) do table.insert(c, M.list[el][i]) end
	return c
end

-- Options communes du socle : visibilite conditionnelle (totems.vis / .fade) et police des temps et etiquettes (totems.font / .fontsize).
local function addAll(list)
	local d = SUI.Visibility.Options("totems", { cat = "totems", order = 800 })
	for i = 1, getn(d) do table.insert(list, d[i]) end
	d = SUI.Look.Options("totems", { font = true, cat = "totems", order = 820 })
	for i = 1, getn(d) do table.insert(list, d[i]) end
	table.insert(list, opt("bg", "choice", 830, "style", { choices = M.BGS, choiceText = function(o, v) return L("choice.totems.bg." .. v) end }))
	table.insert(list, opt("color", "choice", 831, "style", { choices = M.COLORS, choiceText = function(o, v) return L("choice.totems.color." .. v) end }))
	table.insert(list, opt("coloron", "choice", 832, "style", { choices = M.COLORS, choiceText = function(o, v) return L("choice.totems.coloron." .. v) end }))
	table.insert(list, opt("colorwarn", "choice", 833, "style", { choices = M.COLORS, choiceText = function(o, v) return L("choice.totems.colorwarn." .. v) end }))
	return list
end

SUI.RegisterModule("totems", {
	default = false,
	cost = "light",
	options = addAll({
		opt("preset", "choice", 10, "caster", { choices = M.PRESET_LIST, simple = true }),
		opt("earth", "choice", 20, "none", { choices = elementChoices("earth"), simple = true }),
		opt("fire", "choice", 30, "searing", { choices = elementChoices("fire"), simple = true }),
		opt("water", "choice", 40, "manaspring", { choices = elementChoices("water"), simple = true }),
		opt("air", "choice", 50, "tranquilair", { choices = elementChoices("air"), simple = true }),
		opt("size", "number", 60, 34, { min = 20, max = 60, step = 2, simple = true }),
		opt("spacing", "number", 70, 3, { min = 0, max = 12, step = 1 }),
		opt("timer", "bool", 80, true, { simple = true }),
		opt("warn", "number", 90, 10, { min = 0, max = 30, step = 1 }),
		opt("vertical", "bool", 100, false),
		opt("allbutton", "bool", 110, true),
		opt("autoreset", "bool", 120, true),
		opt("announce", "bool", 130, false),
		opt("alpha", "number", 140, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("tick", "number", 150, 0.25, { min = 0.1, max = 1, step = 0.05 }),
	}),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : aucun module de barre de totems releve (la correspondance est a confirmer).
-- Mode Raid : relecture plus lente.
SUI.Config.AddPreset("raid", "*", { ["totems.tick"] = 0.5 })

SUI.RegisterCommand("totems", function(rest)
	local word, arg = rest, nil
	local sp = string.find(rest or "", " ", 1, true)
	if sp then word = string.sub(rest, 1, sp - 1) arg = string.sub(rest, sp + 1) end
	if word == "cast" and arg then
		M.Cast(arg)
	elseif word == "all" then
		M.CastAll()
	elseif word == "set" and arg then
		if M.PRESETS[arg] then C.Set("totems.preset", arg) else SUI.Print(L("msg.totems.badpreset", arg)) end
	elseif word == "recall" then
		CastSpellByName("Totemic Recall")
	else
		local n = 0
		for i = 1, 4 do if M.cur[M.ELEMENTS[i]] then n = n + 1 end end
		SUI.Print(L("msg.totems.info", n, M.cfg.preset))
	end
end, "help.totems")
