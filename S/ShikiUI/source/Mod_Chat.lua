-- ShikiUI Chat : onglets maison, filtres, copie, horodatage, couleurs de classe, liens web (v0.3, module "chat").
-- Principe (relu dans le pfUI installe, MIT, jamais execute par ce projet) : chaque ChatFrameN recoit un enrobage de sa methode
-- AddMessage (le texte est deja mis en forme par le client : |Hplayer:Nom|h[Nom]|h ; le nom n est jamais perdu : au moindre doute le lien est laisse intact), SetItemRef est enrobe pour les liens "url:",
-- aucun hooksecurefunc. Cout : un traitement de chaine par ligne (une seule passe, rien si l'option correspondante est coupee),
-- une minuterie partagee a 0,5 s (barre d'onglets, roster), aucune frame creee en combat.
-- NON VERIFIE en jeu : format exact des liens de canal, mouvement des onglets Blizzard (FCF_*), roulette sur ChatFrameN,
-- tables LOCALIZED_CLASS_NAMES_* (absentes = pas de couleur pour amis / guilde / qui).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Chat = M

local getn, tinsert = table.getn, table.insert
local strfind, strsub, strlower, strgsub, strformat, strlen = string.find, string.sub, string.lower, string.gsub, string.format, string.len
local floor = math.floor
local strbyte, strchar = string.byte, string.char

local TICK = 0.5
local HIST_MAX = 500
local CLASS_MAX = 400
local DEDUPE_N = 10

M.on = false
M.frames = {}          -- index -> ChatFrameN
M.num = 0
M.orig = {}
M.class = {}           -- nom -> jeton de classe (anglais, majuscules)
M.nclass = 0
M.hex = {}             -- jeton de classe -> "rrggbb"
M.loc2tok = nil        -- classe localisee -> jeton (si le client donne LOCALIZED_CLASS_NAMES_*)
M.unread = {}
M.hist = {}
M.hpos = {}
M.hcnt = {}
M.skip = {}            -- index -> true : fenetre non traitee (journal de combat)
M.dedupeText = {}
M.dedupeTime = {}
M.dedupeFrame = {}
M.dedupeAt = 0
M.dirty = false
M.rosterDirty = false
M.lastSel = nil
M.stampHex = "888888"
M.dropped = 0
M.seq = {}
M.seqSeen = {}
M.orderList = nil
M.cfg = { stamp = true, stampfmt = "hm", url = true, classcolor = true, shortchan = false, dedupe = 0, nourl = false, quiet = false,
	history = 200, wheel = 3, tabs = true, tabs2 = true, background = false, bgalpha = 0.6, hidebuttons = true, fontsize = 0, maxlines = 128, unread = true,
	kwn = 0, kwcolor = "warn", kwsound = "none", kwchannels = "all", kwflash = true }
M.TAB2_DEF = { [2] = true }        -- affectation par defaut de la barre 2 : la fenetre 2 (journal de combat)
M.kw = {}              -- mots-cles compiles : { s = texte replie, pre = joker au debut, suf = joker a la fin }
M.kwFlash = {}         -- index de fenetre -> true : mot-cle recu dans une fenetre non regardee
M.kwAny = false
M.kwPhase = false
M.kwEpoch = 0
M.kwLast = -10
M.kwName = nil
M.kwOpen = "|cffe6c24a"
M.kwRGB = { 0.95, 0.76, 0.26 }
M.kwHits = 0

local STAMP = { hm = "%H:%M", hms = "%H:%M:%S", hm12 = "%I:%M %p" }

-- ---------------------------------------------------------------- reglages
function M.ReadConfig()
	local cfg = M.cfg
	cfg.stamp = C.Get("chat.stamp")
	cfg.stampfmt = STAMP[C.Get("chat.stampfmt")] or STAMP.hm
	cfg.url = C.Get("chat.url")
	cfg.classcolor = C.Get("chat.classcolor")
	cfg.shortchan = C.Get("chat.shortchan")
	cfg.dedupe = C.Get("chat.dedupe")
	cfg.nourl = C.Get("chat.nourl")
	cfg.quiet = C.Get("chat.quiet")
	cfg.history = C.Get("chat.history")
	cfg.wheel = C.Get("chat.wheel")
	cfg.tabs = C.Get("chat.tabs")
	cfg.tabs2 = C.Get("chat.tabs2")
	cfg.tab2set = C.Get("chat.tab2set")
	cfg.cw = C.Get("chat.width") or 0
	cfg.ch = C.Get("chat.height") or 0
	cfg.background = C.Get("chat.background")
	cfg.bgalpha = C.Get("chat.bgalpha")
	cfg.hidebuttons = C.Get("chat.hidebuttons")
	cfg.fontsize = C.Get("chat.fontsize")
	cfg.maxlines = C.Get("chat.maxlines")
	cfg.unread = C.Get("chat.unread")
	local kc, ks, kh = C.Get("chat.kwcolor"), C.Get("chat.kwsound"), C.Get("chat.kwchannels")
	cfg.kwcolor = M.KW_COLORS[kc] and kc or "warn"
	if M.KW_SOUNDS[ks] ~= nil then cfg.kwsound = ks else cfg.kwsound = "none" end
	if kh == "private" or kh == "public" then cfg.kwchannels = kh else cfg.kwchannels = "all" end
	cfg.kwflash = C.Get("chat.kwflash")
	M.KwRebuild()
end

local function hexOf(c)
	return strformat("%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

-- couleur de l'horodatage = jeton 'dim' du style (relue au changement de style)
function M.RefreshColors()
	M.stampHex = hexOf(T.c.dim)
	M.accentHex = hexOf({ T.Accent() })
	M.KwColor()
end

-- ---------------------------------------------------------------- classes des joueurs
function M.Learn(name, class)
	if type(name) ~= "string" or type(class) ~= "string" or name == "" then return end
	local c = M.class
	if c[name] == nil then
		if M.nclass >= CLASS_MAX then
			for k, _ in pairs(c) do c[k] = nil end
			M.nclass = 0
		end
		M.nclass = M.nclass + 1
	end
	c[name] = class
end

function M.LearnUnit(unit)
	if UnitExists(unit) and UnitIsPlayer(unit) then
		local _, cls = UnitClass(unit)
		M.Learn(UnitName(unit), cls)
	end
end

local function localized(name)
	if not M.loc2tok then
		local map = {}
		local m, f = getglobal("LOCALIZED_CLASS_NAMES_MALE"), getglobal("LOCALIZED_CLASS_NAMES_FEMALE")
		if type(m) == "table" then for tok, txt in pairs(m) do map[txt] = tok end end
		if type(f) == "table" then for tok, txt in pairs(f) do map[txt] = tok end end
		M.loc2tok = map
	end
	return M.loc2tok[name]
end

function M.ScanRoster()
	M.rosterDirty = false
	for i = 1, 4 do M.LearnUnit(M.partyIds[i]) end
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do M.LearnUnit(M.raidIds[i]) end
	end
	if GetNumFriends then
		for i = 1, GetNumFriends() do
			local name, _, cls = GetFriendInfo(i)
			if name and cls then M.Learn(name, localized(cls)) end
		end
	end
	M.guildPending = false
	if GetNumGuildMembers and SUI.InCombat() then
		M.guildPending = true                  -- relu des la fin du combat (la liste de guilde n'est pas lue en combat)
	elseif GetNumGuildMembers then
		for i = 1, GetNumGuildMembers() do
			local name, _, _, _, cls = GetGuildRosterInfo(i)
			if name and cls then M.Learn(name, localized(cls)) end
		end
	end
	M.LearnUnit("player")
end

-- Le client ne remplit la liste de guilde que s'il la demande : sans cela les membres connectes apres l'ouverture du jeu n'ont pas de couleur.
-- Au plus une demande toutes les 30 s ; GUILD_ROSTER_UPDATE relance ensuite la lecture.
function M.RequestGuild()
	local now = GetTime()
	if M.guildAsked and now - M.guildAsked < 30 then return end
	M.guildAsked = now
	M.unknownSeen = false
	local ig, gr = getglobal("IsInGuild"), getglobal("GuildRoster")
	if type(ig) == "function" and ig() and type(gr) == "function" then gr() end
end

function M.OnWho()
	if not GetNumWhoResults then return end
	for i = 1, GetNumWhoResults() do
		local name, _, _, _, cls = GetWhoInfo(i)
		if name and cls then M.Learn(name, localized(cls)) end
	end
end

local function classHex(token)
	local h = M.hex[token]
	if h == nil then
		local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
		if col then h = strformat("%02x%02x%02x", floor(col.r * 255 + 0.5), floor(col.g * 255 + 0.5), floor(col.b * 255 + 0.5)) else h = false end    -- style:ok couleur de classe (donnee de jeu)
		M.hex[token] = h
	end
	return h
end

-- Colore le nom d'un lien joueur. Rappel : whole = le lien entier "|Hplayer:donnees|hTEXTE|h", data = tout ce qui suit "|Hplayer:" jusqu'a
-- "|h" (nom, puis eventuellement ":ligne:canal"), shown = TEXTE (avec ou sans crochets, accents et chiffres admis). Le NOM n'est jamais
-- perdu : au moindre doute (texte deja colore, nom vide, classe inconnue, texte louche ou trop long) on rend le lien ENTIER, intact.
-- On renvoie toujours une chaine (jamais nil) : le comportement de gsub sur un retour nil n'est pas le meme d'une version de Lua a l'autre.
local function colorName(whole, data, shown)
	if type(whole) ~= "string" or type(data) ~= "string" or type(shown) ~= "string" then return whole end
	local n = strlen(shown)
	if n == 0 or n > 64 or strfind(shown, "|", 1, true) then return whole end      -- deja colore (|c), autre lien (|H), texte coupe
	local name = data
	local colon = strfind(data, ":", 1, true)
	if colon then name = strsub(data, 1, colon - 1) end
	if name == "" then return whole end
	local tok = M.class[name]
	if not tok then
		local dash = strfind(name, "-", 1, true)       -- "Nom-Royaume" : la classe est connue sous le nom court
		if dash and dash > 1 then tok = M.class[strsub(name, 1, dash - 1)] end
	end
	local h = tok and classHex(tok)
	if not h then
		M.unknownSeen = true                   -- joueur inconnu : la liste de guilde sera redemandee (limitee) pour la prochaine fois
		return whole
	end
	local open, inner, close = "", shown, ""
	if n >= 2 and strsub(shown, 1, 1) == "[" and strsub(shown, n, n) == "]" then
		open, inner, close = "[", strsub(shown, 2, n - 1), "]"
		if inner == "" then return whole end
	end
	return "|Hplayer:" .. data .. "|h" .. open .. "|cff" .. h .. inner .. "|r" .. close .. "|h"
end

-- ---------------------------------------------------------------- mots-cles
-- Syntaxe : mots separes par des virgules, sans tenir compte des majuscules (accents compris : E = e). "$me" = le nom du personnage et son
-- surnom (option chat.nick). Mot entier par defaut ; "*" au debut ou a la fin = n'importe quelles lettres a cet endroit (heal* : healer).
-- Le mot surligne est entoure de |cff..|r ; JAMAIS touche : liens |H..|h..|h (donc le nom de l'auteur) et textes deja colores |c..|r.
-- Cout : rien du tout quand la liste est vide ; sinon une recherche simple par mot sur la ligne, la mise en forme n'a lieu qu'en cas de mot trouve.
M.KW_MAX = 16
M.KW_COLORS = { warn = true, accent = true, good = true, bad = true, text = true }
M.KW_SOUNDS = { none = false, tell = "TellMessage", ping = "MapPing", raid = "RaidWarning", quest = "QUESTADDED", level = "LEVELUP" }

local function foldPair(c)
	return "\195" .. strchar(strbyte(c) + 32)
end

-- Minuscules, y compris les lettres accentuees en UTF-8 (deux octets "\195" + 128..158 -> +32, sauf le signe multiplier). Longueur inchangee.
local function fold(s)
	s = strlower(s)
	if strfind(s, "\195", 1, true) then s = strgsub(s, "\195([\128-\150\152-\158])", foldPair) end
	return s
end
M.Fold = fold

local function isWord(ch)
	return ch ~= "" and strfind(ch, "^[%w_\128-\255]") ~= nil
end

function M.KwColor()
	local cfg = M.cfg
	local r, g, b
	if cfg.kwcolor == "accent" then
		r, g, b = T.Accent()
	else
		local c = T.c[cfg.kwcolor] or T.c.warn
		r, g, b = c[1], c[2], c[3]
	end
	M.kwRGB[1], M.kwRGB[2], M.kwRGB[3] = r, g, b
	M.kwOpen = "|cff" .. hexOf({ r, g, b })
	M.kwEpoch = M.kwEpoch + 1
end

local function trim(w)
	w = strgsub(w, "^%s+", "")
	return (strgsub(w, "%s+$", ""))
end

-- Liste compilee a partir du texte du reglage ; renvoie la liste et le nombre de mots retenus.
function M.KwParse(raw, me, nick)
	local list, seen, n = {}, {}, 0
	if type(raw) ~= "string" then return list, 0 end
	local from = 1
	local len = strlen(raw)
	while from <= len + 1 and n < M.KW_MAX do
		local comma = strfind(raw, ",", from, true)
		local word
		if comma then word = strsub(raw, from, comma - 1) else word = strsub(raw, from) end
		if comma then from = comma + 1 else from = len + 2 end
		word = trim(word)
		local words = { word }
		if word == "$me" then words = { me or "", nick or "" } end
		for i = 1, 2 do
			local w = words[i]
			if type(w) == "string" and w ~= "" then
				local pre, suf = false, false
				if strsub(w, 1, 1) == "*" then pre = true; w = strsub(w, 2) end
				if strsub(w, -1) == "*" then suf = true; w = strsub(w, 1, -2) end
				w = trim(w)
				if strlen(w) >= 2 and not strfind(w, "|", 1, true) then
					local f = fold(w)
					local key = f .. (pre and "<" or "") .. (suf and ">" or "")
					if not seen[key] and n < M.KW_MAX then
						seen[key] = true
						n = n + 1
						list[n] = { s = f, pre = pre, suf = suf }
					end
				end
			end
		end
	end
	return list, n
end

function M.KwRebuild()
	local cfg = M.cfg
	local me = UnitName("player")
	M.kwName = me
	M.kw, cfg.kwn = M.KwParse(C.Get("chat.keywords"), me, C.Get("chat.nick"))
	if cfg.kwn == 0 then
		M.kwFlash = {}
		M.kwAny = false
	end
	M.KwColor()
end

-- Premier mot-cle (le plus a gauche, puis le plus long) dans low[p..b] ; positions dans low, mots entiers sauf jokers.
local function kwFind(low, p, a, b)
	local bs, be
	local kws = M.kw
	for i = 1, M.cfg.kwn do
		local k = kws[i]
		local from = p
		while true do
			local s, e = strfind(low, k.s, from, true)
			if not s or e > b then break end
			if (k.pre or s == a or not isWord(strsub(low, s - 1, s - 1))) and (k.suf or e == b or not isWord(strsub(low, e + 1, e + 1))) then
				-- jokers : le mot surligne s'etend jusqu'aux limites du mot
				if k.pre then
					while s > p and isWord(strsub(low, s - 1, s - 1)) do s = s - 1 end
				end
				if k.suf then
					while e < b and isWord(strsub(low, e + 1, e + 1)) do e = e + 1 end
				end
				if not bs or s < bs or (s == bs and e > be) then bs, be = s, e end
				break
			end
			from = s + 1
		end
	end
	return bs, be
end

local function kwRange(text, low, a, b, out, n)
	local p = a
	while p <= b do
		local s, e = kwFind(low, p, a, b)
		if not s then break end
		if s > p then out[getn(out) + 1] = strsub(text, p, s - 1) end
		out[getn(out) + 1] = M.kwOpen .. strsub(text, s, e) .. "|r"
		n = n + 1
		p = e + 1
	end
	if p <= b then out[getn(out) + 1] = strsub(text, p, b) end
	return n
end

-- Surligne les mots-cles hors liens et hors textes colores. Renvoie le texte et le nombre de mots surlignes (0 = texte rendu tel quel).
function M.Highlight(text)
	local cfg = M.cfg
	if cfg.kwn == 0 or type(text) ~= "string" then return text, 0 end
	local low = fold(text)
	local any = false
	for i = 1, cfg.kwn do
		if strfind(low, M.kw[i].s, 1, true) then any = true; break end
	end
	if not any then return text, 0 end
	local out, n = {}, 0
	local len = strlen(text)
	local seg = 1
	while seg <= len do
		local q = strfind(text, "|", seg, true)
		if not q then
			n = kwRange(text, low, seg, len, out, n)
			break
		end
		if q > seg then n = kwRange(text, low, seg, q - 1, out, n) end
		local c2 = strsub(text, q + 1, q + 1)
		local stop = q + 1
		if c2 == "H" then
			local e1 = strfind(text, "|h", q + 2, true)
			local e2 = e1 and strfind(text, "|h", e1 + 2, true)
			stop = e2 and (e2 + 1) or len
		elseif c2 == "c" then
			local r = strfind(text, "|r", q + 2, true)
			stop = r and (r + 1) or len
		end
		if stop > len then stop = len end
		out[getn(out) + 1] = strsub(text, q, stop)
		seg = stop + 1
	end
	if n == 0 then return text, 0 end
	return table.concat(out), n
end

-- "private" (guilde, groupe, raid, chuchotements, dire) ou "public" (canaux numerotes) d'apres le lien de canal de la ligne.
function M.KwKind(text)
	local c = strfind(text, "|Hchannel:", 1, true)
	if not c then return "private" end
	local ch = strsub(text, c + 10, c + 18)
	if strfind(ch, "^channel:") or strfind(ch, "^%d") then return "public" end
	return "private"
end

function M.KwSound()
	local name = M.KW_SOUNDS[M.cfg.kwsound]
	if not name then return end
	local now = GetTime()
	if now - M.kwLast < 1 then return end
	M.kwLast = now
	local f = getglobal("PlaySound")
	if type(f) == "function" then
		local ok, err = pcall(f, name)
		if not ok then SUI.Report("chat sound", err) end
	end
end

-- Alerte sur l'onglet de la fenetre : clignotement de la barre ShikiUI, puis appel facultatif au gestionnaire d'onglets.
function M.KwAlert(id)
	if not (M.cfg.kwflash and id) then return end
	if M.selected and M.selected:GetID() == id then return end
	M.kwFlash[id] = true
	M.kwAny = true
	M.dirty = true
	local ct = SUI.ChatTabs
	if ct and type(ct.Flash) == "function" then
		local ok, err = pcall(ct.Flash, id)
		if not ok then SUI.Report("chat flash", err) end
	end
end

-- Appele par Process : surligne, puis son et alerte si un mot a ete trouve. Ses propres messages ne declenchent rien.
function M.Keywords(frame, text)
	local cfg = M.cfg
	if cfg.kwchannels ~= "all" and M.KwKind(text) ~= cfg.kwchannels then return text end
	local me = M.kwName
	if me and strfind(text, "|Hplayer:" .. me .. "|h", 1, true) then return text end
	local out, n = M.Highlight(text)
	if n > 0 then
		M.kwHits = M.kwHits + 1
		M.KwSound()
		M.KwAlert(frame:GetID())
	end
	return out
end

function M.KwTick()
	local left = false
	if M.selected and M.selected.GetID then M.kwFlash[M.selected:GetID()] = nil end
	for i = 1, M.num do
		if M.kwFlash[i] then left = true end
	end
	M.kwAny = left
	M.kwPhase = left and not M.kwPhase
	M.dirty = true
end

-- ---------------------------------------------------------------- liens web
local function wrapUrl(url)
	return "|cff" .. (M.accentHex or "4dc4e8") .. "|Hurl:" .. url .. "|h[" .. url .. "]|h|r"
end

local function wrapWww(pos, url)
	local before = strsub(M.curText, pos - 1, pos - 1)
	if before == "/" or before == "[" or before == ":" then return nil end
	return wrapUrl(url)
end

function M.HasUrl(text)
	return strfind(text, "://", 1, true) or strfind(text, "www.", 1, true)
end

function M.LinkUrls(text)
	if strfind(text, "|Hurl:", 1, true) then return text end
	text = strgsub(text, "(%a[%w+.-]*://[%w%-%._~:/%?#@!%$&'%*%+,;=%%]+)", wrapUrl)
	if strfind(text, "www.", 1, true) then
		M.curText = text
		text = strgsub(text, "()(www%.[%w%-%.]+%.%a%a+[%w/%?%-_=&#%.%%]*)", wrapWww)
	end
	return text
end

-- ---------------------------------------------------------------- traitement d'une ligne
function M.Process(frame, text)
	if type(text) ~= "string" or frame.suiSkip then return text end
	local cfg = M.cfg
	local isChannel = strfind(text, "|Hchannel:", 1, true)
	local isPlayer = strfind(text, "|Hplayer:", 1, true)
	if isChannel or isPlayer then
		if isChannel and cfg.quiet and SUI.InCombat() then
			M.dropped = M.dropped + 1
			return false
		end
		if isChannel and cfg.nourl and M.HasUrl(text) then
			M.dropped = M.dropped + 1
			return false
		end
		if cfg.dedupe > 0 then
			local now = GetTime()
			for i = 1, DEDUPE_N do
				if M.dedupeText[i] == text and M.dedupeFrame[i] == frame and now - M.dedupeTime[i] < cfg.dedupe then
					M.dropped = M.dropped + 1
					return false
				end
			end
			local k = M.dedupeAt + 1
			if k > DEDUPE_N then k = 1 end
			M.dedupeAt = k
			M.dedupeText[k] = text
			M.dedupeFrame[k] = frame
			M.dedupeTime[k] = now
		end
	end
	if isPlayer and cfg.classcolor then
		text = strgsub(text, "(|Hplayer:([^|]*)|h(.-)|h)", colorName)
	end
	if isChannel and cfg.shortchan then
		text = strgsub(text, "|h%[(%d+)%. [^%]]+%]|h", "|h[%1]|h")
	end
	if cfg.url and M.HasUrl(text) then
		text = M.LinkUrls(text)
	end
	if cfg.kwn > 0 and (isChannel or isPlayer) then
		text = M.Keywords(frame, text)
	end
	if cfg.stamp then
		text = "|cff" .. M.stampHex .. "[" .. date(cfg.stampfmt) .. "]|r " .. text
	end
	-- historique (anneau de taille fixe, rien n'est alloue)
	local id = frame:GetID()
	local ring = M.hist[id]
	if ring then
		local p = M.hpos[id] + 1
		if p > HIST_MAX then p = 1 end
		M.hpos[id] = p
		ring[p] = text
		if M.hcnt[id] < HIST_MAX then M.hcnt[id] = M.hcnt[id] + 1 end
	end
	if M.selected and frame ~= M.selected and cfg.unread then
		if id then
			M.unread[id] = (M.unread[id] or 0) + 1
			M.dirty = true
		end
	end
	return text
end

function M.Wrapped(self, text, a1, a2, a3, a4, a5, a6)
	local o = self.suiOrig
	if M.on then
		local ok, res = pcall(M.Process, self, text)
		if ok then
			if res == false then return end
			text = res
		else
			SUI.Report("chat", res)
		end
	end
	return o(self, text, a1, a2, a3, a4, a5, a6)
end

function M.WrapFrame(f)
	if f.suiOrig then return end
	f.suiOrig = f.AddMessage
	f.AddMessage = M.Wrapped
end

-- ---------------------------------------------------------------- copie
-- Texte de l'historique d'une fenetre, du plus ancien au plus recent, sans codes de couleur ni de lien.
function M.HistoryText(id)
	local ring, n = M.hist[id], M.hcnt[id]
	if not ring or not n or n == 0 then return "" end
	local limit = M.cfg.history
	if n > limit then n = limit end
	local out = {}
	local p = M.hpos[id] - n
	for i = 1, n do
		p = p + 1
		if p < 1 then p = p + HIST_MAX elseif p > HIST_MAX then p = p - HIST_MAX end
		local s = ring[p]
		if s then
			s = strgsub(s, "|c%x%x%x%x%x%x%x%x", "")
			s = strgsub(s, "|r", "")
			s = strgsub(s, "|H[^|]*|h(.-)|h", "%1")
			tinsert(out, s)
		end
	end
	return table.concat(out, "\n")
end

function M.ShowCopy(text, title)
	if not M.copy then return false end
	M.copy.title:SetText(title or L("msg.chat.copytitle"))
	M.copy.edit:SetText(text or "")
	-- hauteur du texte (14 px par ligne, lignes longues repliees) : sans elle les longs historiques seraient coupes et inatteignables
	local body = text or ""
	local lines = 2 + floor(strlen(body) / 90)
	local pos = strfind(body, "\n", 1, true)
	while pos do
		lines = lines + 1
		pos = strfind(body, "\n", pos + 1, true)
	end
	if lines * 14 < 400 then lines = 29 end
	M.copy.edit:SetHeight(lines * 14)
	if M.copy.scroll.UpdateScrollChildRect then M.copy.scroll:UpdateScrollChildRect() end
	M.copy.scroll:SetVerticalScroll(0)
	M.copy:Show()
	M.copy.edit:SetFocus()
	M.copy.edit:HighlightText()
	return true
end

function M.CopyFrame(id)
	id = id or (M.selected and M.selected:GetID()) or 1
	return M.ShowCopy(M.HistoryText(id), L("msg.chat.copytitle"))
end

function M.OnItemRef(link, text, button)
	if M.on and type(link) == "string" and strsub(link, 1, 4) == "url:" then
		M.ShowCopy(strsub(link, 5), L("msg.chat.urltitle"))
		return
	end
	if M.on and type(link) == "string" and strsub(link, 1, 8) == "channel:" and not IsShiftKeyDown() then
		local r = M.origItemRef(link, text, button)
		local ok, err = pcall(M.OnChannelLink, link)
		if not ok then SUI.Report("chat channel link", err) end
		return r
	end
	return M.origItemRef(link, text, button)
end

-- Clic sur un nom de canal ([2. World]) : la zone de saisie vise CE canal et la fenetre qui le montre est selectionnee
-- (le client laissait la saisie sur le canal precedent et la fenetre sur General).
function M.OnChannelLink(link)
	local arg = strsub(link, 9)
	local gcn = getglobal("GetChannelName")
	if arg == "" or type(gcn) ~= "function" then return end
	local idx, name = gcn(tonumber(arg) or arg)
	if type(idx) ~= "number" or idx <= 0 then return end
	M.FocusChannel(idx, name)
end

function M.FocusChannel(idx, name)
	local frame
	if SUI.ChatTabs and SUI.ChatTabs.FrameForChannel then frame = SUI.ChatTabs.FrameForChannel(name) end
	if frame then
		FCF_SelectDockFrame(frame)
		M.selected = getglobal("SELECTED_CHAT_FRAME") or frame
		local id = frame.GetID and frame:GetID()
		if id and M.unread then M.unread[id] = 0 end
		M.dirty = true
	end
	local eb = getglobal("ChatFrameEditBox")
	if eb then
		eb.chatType = "CHANNEL"
		eb.channelTarget = idx
		eb.stickyType = "CHANNEL"
		if frame then eb.chatFrame = frame end
		local upd = getglobal("ChatEdit_UpdateHeader")
		if type(upd) == "function" then upd(eb) end
	end
end

function M.HookItemRef()
	if M.origItemRef then return end
	local orig = getglobal("SetItemRef")
	if type(orig) ~= "function" then return end
	M.origItemRef = orig
	setglobal("SetItemRef", M.OnItemRef)
end

-- ---------------------------------------------------------------- roulette
function M.OnWheel()
	local f = this
	if not M.on then return end
	local n = M.cfg.wheel
	if arg1 > 0 then
		if IsShiftKeyDown() then f:PageUp() elseif IsControlKeyDown() then f:ScrollToTop() else for _ = 1, n do f:ScrollUp() end end
	else
		if IsShiftKeyDown() then f:PageDown() elseif IsControlKeyDown() then f:ScrollToBottom() else for _ = 1, n do f:ScrollDown() end end
	end
end

-- ---------------------------------------------------------------- barre d'onglets
-- Une fenetre existe si le client la dit visible OU si elle est attachee a la barre : le client ne marque "visible" que l'onglet
-- selectionne (releve dans les variables sauvegardees : isDocked=1 pour tous les onglets, shown=nil sauf pour un). Le journal de
-- combat (suiSkip) reste cache.
local function windowShown(i)
	local name, _, _, _, _, _, shown = GetChatWindowInfo(i)
	local f = M.frames and M.frames[i]
	if not shown and f and f.isDocked and not f.suiSkip then shown = 1 end
	return name, shown
end

-- Fenetre reellement affichee : le client laisse parfois SELECTED_CHAT_FRAME sur General alors que l'onglet clique (Raid...) est visible -> l'encadre bleu
-- suit la fenetre qui est a l'ecran, pas la variable.
function M.TrueSel(pref)
	local sel = getglobal("SELECTED_CHAT_FRAME")
	if pref and pref.IsShown and pref:IsShown() then return pref end
	if sel and sel.IsShown and sel:IsShown() then return sel end
	if M.frames then
		for i = 1, 12 do
			local f = M.frames[i]
			if f and not f.suiSkip and f.IsShown and f:IsShown() and f.isDocked then return f end
		end
	end
	return sel or pref
end

function M.OnTabClick(b, btn)
	local f = M.frames[b.idx]
	if not f then return end
	if btn == "RightButton" and M.tabMenu and M.tabMenu(b.idx, b) then return end
	FCF_SelectDockFrame(f)
	M.selected = M.TrueSel(f)
	M.unread[b.idx] = 0
	M.dirty = true
	M.RefreshBar()
end

-- Ordre d'affichage des onglets (liste de numeros de fenetres, posee par le module chattabs ; nil = ordre naturel).
function M.SetOrder(list)
	M.orderList = list
	M.dirty = true
end

function M.Sequence()
	local seq, seen, n = M.seq, M.seqSeen, 0
	for k, _ in pairs(seen) do seen[k] = nil end
	local order = M.orderList
	if order then
		for k = 1, getn(order) do
			local id = order[k]
			if M.frames[id] and not seen[id] then
				n = n + 1
				seq[n] = id
				seen[id] = true
			end
		end
	end
	for i = 1, M.num do
		if not seen[i] then
			n = n + 1
			seq[n] = i
		end
	end
end

-- Les onglets Blizzard doivent rester invisibles et sans souris (le client les reaffiche : fondu, nouvelle fenetre) sinon ils se
-- superposent a la barre ShikiUI et captent les clics.
function M.KeepTabsHidden()
	if not (M.on and M.cfg.tabs) then return end
	for i = 1, M.num do
		local tab = getglobal("ChatFrame" .. i .. "Tab")
		if tab and tab:GetAlpha() ~= 0 then
			tab:SetAlpha(0)
			tab:EnableMouse(false)
			M.tabHidden[i] = true
		end
	end
end

function M.RefreshBar()
	M.dirty = false
	local bar = M.bar
	if not bar then return end
	M.KeepTabsHidden()
	M.Sequence()
	-- Barre 2 active seulement si le reglage est on, la fenetre 2 existe, est visible et N'EST PAS dockee
	-- (GetChatWindowInfo renvoie son etat de dock, comme le reste de l'addon le lit). Sinon, tous les onglets
	-- retournent dans la barre principale.
	local f2 = M.frames[2]
	local two = false
	if M.bar2 and M.cfg.tabs2 and f2 and f2:IsShown() then
		local _, _, _, _, _, _, shown2, docked2 = GetChatWindowInfo(2)
		two = (shown2 and not docked2) or false
	end
	local b2set = (type(M.cfg.tab2set) == "table") and M.cfg.tab2set or M.TAB2_DEF
	local n1, n2 = 0, 0
	for s = 1, M.num do
		local i = M.seq[s]
		local name, shown = windowShown(i)
		local b = M.tabs[i]
		if shown and name and name ~= "" and M.cfg.tabs then
			if two and b2set[i] then
				n2 = n2 + 1
				b.slot, b.onBar = n2, 2
			else
				n1 = n1 + 1
				b.slot, b.onBar = n1, 1
			end
			b.winName = name
			b:Show()
		else
			b.slot = nil
			b.onBar = nil
			b:Hide()
			if M.bar2 and b:GetParent() == M.bar2 then b:SetParent(bar) end
		end
	end
	if M.bar2 then
		if two and n2 > 0 and M.cfg.tabs then
			M.bar2:Show()
		else
			M.bar2:Hide()
		end
	end
	if n1 == 0 and n2 == 0 then return end
	-- largeur reelle de chaque fenetre exprimee dans l'echelle de sa barre (la barre n'a pas l'echelle de la fenetre)
	local f1 = M.frames[1]
	local fw = (f1:GetWidth() or 0) * (f1:GetScale() or 1) / (bar:GetScale() or 1)
	if fw <= 0 then fw = bar:GetWidth() or 400 end
	if M.barRelay and M.barRelay.moved and bar:GetWidth() ~= fw then bar:SetWidth(fw) end
	local avail = fw - 24 - 58      -- 58 px reserves aux boutons copier et bulle (ils se placent dans la barre, a droite des onglets)
	local w = (n1 > 0) and floor(avail / n1) or 110
	if w > 110 then w = 110 end
	if w < 36 then w = 36 end
	local w2 = 110
	if two and n2 > 0 then
		local fw2 = (f2:GetWidth() or 0) * (f2:GetScale() or 1) / (M.bar2:GetScale() or 1)
		if fw2 <= 0 then fw2 = M.bar2:GetWidth() or 400 end
		if M.bar2Relay and M.bar2Relay.moved and M.bar2:GetWidth() ~= fw2 then M.bar2:SetWidth(fw2) end
		w2 = floor(fw2 / n2)
		if w2 > 110 then w2 = 110 end
		if w2 < 36 then w2 = 36 end
	end
	for i = 1, M.num do
		local b = M.tabs[i]
		if b.slot then
			local bb = (b.onBar == 2) and M.bar2 or bar
			local bw = (b.onBar == 2) and w2 or w
			if b:GetParent() ~= bb then b:SetParent(bb) end
			if b.curW ~= bw or b.curSlot ~= b.slot or b.curBar ~= b.onBar then
				b:SetWidth(bw)
				b:ClearAllPoints()
				b:SetPoint("LEFT", bb, "LEFT", 2 + (b.slot - 1) * (bw + 2), 0)
				b.curW, b.curSlot, b.curBar = bw, b.slot, b.onBar
			end
			local n = M.unread[i] or 0
			local txt = b.winName
			if n > 0 then txt = txt .. " (" .. n .. ")" end
			if b.curText ~= txt then
				T.SetButtonText(b, txt)
				b.curText = txt
			end
			local sel = (M.selected == M.frames[i])
			if b.curSel ~= sel then
				T.SetSelected(b, sel)
				b.curSel = sel
			end
			local key = (n > 0) and 1 or 0
			if M.kwFlash[i] and not sel then key = M.kwPhase and 2 or 3 end
			if b.curFlag ~= key or b.curEp ~= M.kwEpoch then
				b.curFlag, b.curEp = key, M.kwEpoch
				local c = (n > 0 or key == 3) and T.c.warn or T.c.text
				if key == 2 then c = M.kwRGB end
				if not sel then b.label:SetTextColor(c[1], c[2], c[3], 1) end
			end
		end
	end
end

-- Affecte (on) ou retire (off) la fenetre idx de la barre d'onglets 2. Retourne true si applique (contrat du menu chattabs).
function M.SetBar(idx, on)
	if not M.frames[idx] then return false end
	local set = C.Get("chat.tab2set")
	if type(set) ~= "table" then set = { [2] = true } end
	if on then set[idx] = true else set[idx] = nil end
	C.Set("chat.tab2set", set)
	M.cfg.tab2set = set
	M.dirty = true
	M.RefreshBar()
	return true
end

-- La fenetre idx est-elle affectee a la barre 2 ? (sans config : la fenetre 2)
function M.InBar2(idx)
	local set = M.cfg.tab2set
	if type(set) ~= "table" then set = M.TAB2_DEF end
	return set[idx] == true
end

-- ---------------------------------------------------------------- application des reglages sur les frames
function M.ApplyOptions()
	if not M.built then return end
	local cfg = M.cfg
	if M.bar then
		if M.on and cfg.tabs then M.bar:Show() else M.bar:Hide() end
		if M.copyBtn then if M.on and cfg.tabs then M.copyBtn:Show() else M.copyBtn:Hide() end end
	end
	if M.bar2 then
		if not (M.on and cfg.tabs and cfg.tabs2) then M.bar2:Hide() end
		M.dirty = true               -- le prochain refresh redecoupe les onglets (detachee ? onglets affectes ?)
	end
	for i = 1, M.num do
		local f = M.frames[i]
		local tab = getglobal("ChatFrame" .. i .. "Tab")
		if tab then
			if M.on and cfg.tabs then
				tab:SetAlpha(0)
				tab:EnableMouse(false)
				M.tabHidden[i] = true
			elseif M.tabHidden[i] then
				tab:SetAlpha(1)
				tab:EnableMouse(true)
				M.tabHidden[i] = nil
			end
		end
		for _, nm in ipairs(M.btnNames) do
			local b = getglobal("ChatFrame" .. i .. nm)
			if b then
				if M.on and cfg.hidebuttons then
					b:SetAlpha(0)
					b:EnableMouse(false)
					M.btnHidden[i .. nm] = true
				elseif M.btnHidden[i .. nm] then
					b:SetAlpha(1)
					b:EnableMouse(true)
					M.btnHidden[i .. nm] = nil
				end
			end
		end
		if M.on and cfg.wheel > 0 and not f:GetScript("OnMouseWheel") then
			f:EnableMouseWheel(true)
			f:SetScript("OnMouseWheel", M.OnWheel)
			M.wheelSet[i] = true
		elseif M.wheelSet[i] and not (M.on and cfg.wheel > 0) then
			f:SetScript("OnMouseWheel", nil)
			M.wheelSet[i] = nil
		end
		-- taille de la fenetre principale : 0 = celle du client (le Mover garde le reste)
		if i == 1 and M.on and (cfg.cw > 0 or cfg.ch > 0) then
			if cfg.cw > 0 then f:SetWidth(cfg.cw) end
			if cfg.ch > 0 then f:SetHeight(cfg.ch) end
			local save = getglobal("FCF_SavePositionAndDimensions")
			if type(save) == "function" then pcall(save, f) end
			if M.SyncRelays then SUI.After(0.1, M.SyncRelays, "chat.size") end
		end
		-- lignes gardees : valeur du reglage ; retour a 128 (defaut du client) quand le module est coupe ou la valeur remise a 128
		local ml = 128
		if M.on then ml = cfg.maxlines end
		if (f.suiMax or 128) ~= ml then
			f:SetMaxLines(ml)
			f.suiMax = ml
		end
		-- taille du texte : 0 = celle du client (relue avant le premier changement, remise quand le reglage revient a 0 ou le module est coupe)
		local setFont = getglobal("FCF_SetChatWindowFontSize")
		if type(setFont) == "function" then
			if M.on and cfg.fontsize > 0 then
				if f.suiFont ~= cfg.fontsize then
					if not f.suiFontOrig then
						local gi = getglobal("GetChatWindowInfo")
						local _, sz
						if type(gi) == "function" then _, sz = gi(i) end
						f.suiFontOrig = sz or 14
					end
					local ok, err = pcall(setFont, f, cfg.fontsize)
					if not ok then SUI.Report("chat font", err) end
					f.suiFont = cfg.fontsize
				end
			elseif f.suiFont then
				local ok, err = pcall(setFont, f, f.suiFontOrig or 14)
				if not ok then SUI.Report("chat font", err) end
				f.suiFont = nil
			end
		end
	end
	if not (M.on and cfg.unread) then
		for i = 1, M.num do M.unread[i] = 0 end
	end
	if M.back then
		if M.on and cfg.background then
			M.back:SetAlpha(cfg.bgalpha)
			M.back:Show()
		else
			M.back:Hide()
		end
	end
	M.dirty = true
	-- la barre cachee (reglage "tabs") n'a plus de poignee ; une poignee deja affichee est mise a jour
	if getn(M.relays) > 0 then
		M.SyncRelays()
		local mv = SUI.Mover
		if mv and mv.active and mv.Sync then mv.Sync() end
	end
end

-- ---------------------------------------------------------------- cadres deplacables (poignees du Mover)
-- Trois elements se deplacent SEPAREMENT : la fenetre principale (chat.main), la barre d'onglets ShikiUI (chat.tabs) et la zone de saisie
-- (chat.edit). Pour chacun, un cadre-relais invisible (enfant d'UIParent, a l'echelle du Layout : ui.scale x echelle du Mover) porte la poignee ;
-- la poignee est ancree sur le relais et dimensionnee d'apres lui. Tant qu'aucune position n'est enregistree, le relais SUIT l'element (rien n'est
-- touche) ; une fois enregistree, l'element est ancre a l'ecran sur le relais. Toutes les conversions d'echelle passent par scales() : une taille
-- ou une position lue sur l'element (echelle ts) s'exprime dans le relais (echelle ps) par * ts / ps. Position remise a zero (ou module coupe) :
-- les ancrages d'origine, releves avant le premier deplacement, sont rejoues.
-- NON VERIFIE EN JEU : FCF_SavePositionAndDimensions, le comportement du dock apres deplacement.
M.relays = {}

local function relaySaved(key)
	return SUI.Layout and SUI.Layout.ReadKey and C.GetPos(SUI.Layout.ReadKey(key)) and true or false
end

function M.MoverSaved()
	return relaySaved("chat.main")
end

local function scales(r, t)
	local ps, ts = r.p:GetScale() or 1, t:GetScale() or 1
	if ps <= 0 then ps = 1 end
	if ts <= 0 then ts = 1 end
	return ps, ts
end

local function savePoints(f)
	local out = {}
	local n = f.GetNumPoints and f:GetNumPoints() or 0
	for i = 1, n do
		local pt, rel, rp, x, y = f:GetPoint(i)
		if pt then tinsert(out, { pt, rel, rp, x, y }) end
	end
	return out
end

local function restorePoints(f, pts)
	if getn(pts) == 0 then return false end
	f:ClearAllPoints()
	for i = 1, getn(pts) do
		local p = pts[i]
		f:SetPoint(p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
	end
	return true
end

-- Taille et position du relais d'apres l'element reel (echelles comprises).
local function syncOne(r)
	local t = r.get()
	if not t or not r.p then return end
	local ps, ts = scales(r, t)
	local w, h = t:GetWidth(), t:GetHeight()
	if w and w > 0 then r.p:SetWidth(w * ts / ps) end
	if h and h > 0 then r.p:SetHeight(h * ts / ps) end
	if M.on and (not r.visible or r.visible()) then r.p:Show() else r.p:Hide() end
	if not relaySaved(r.key) and not SUI.InCombat() and t:GetLeft() and t:GetBottom() then
		r.p:ClearAllPoints()
		r.p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", t:GetLeft() * ts / ps, t:GetBottom() * ts / ps)
	end
end

local function restoreOne(r)
	local t = r.get()
	if not t or not r.orig or not r.moved then return end
	r.moved = false
	if restorePoints(t, r.orig) and r.after then r.after(t, true) end
	M.dirty = true
end

-- Pose l'element reel sur son relais (position enregistree) ou lui rend ses ancrages d'origine (position effacee).
local function applyOne(r)
	if not M.on or SUI.InCombat() then return end
	local t = r.get()
	if not t or not r.p then return end
	if relaySaved(r.key) then
		local l, b = r.p:GetLeft(), r.p:GetBottom()
		if not l or not b then return end
		local ps, ts = scales(r, t)
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * ps / ts, b * ps / ts)
		r.moved = true
		if r.after then r.after(t, false) end
		M.dirty = true
	elseif r.moved then
		restoreOne(r)
	end
end

function M.SyncRelays()
	for i = 1, getn(M.relays) do syncOne(M.relays[i]) end
end

function M.ApplyRelays()
	for i = 1, getn(M.relays) do applyOne(M.relays[i]) end
end

M.SyncMover = M.SyncRelays
M.ApplyMover = M.ApplyRelays

-- Module coupe : tout ce qui a ete deplace retrouve sa place d'origine (le deplacement se refait a la remise en marche).
function M.RestoreRelays()
	if SUI.InCombat() then return end
	for i = 1, getn(M.relays) do
		local r = M.relays[i]
		if r.moved then restoreOne(r) end
	end
end

function M.OnPos(key)
	if key == nil or key == "pos" or key == "mode" or key == "layout" or key == "ui.scale" then
		if key == "ui.scale" and SUI.Layout and SUI.Layout.Apply then
			for i = 1, getn(M.relays) do SUI.Layout.Apply(M.relays[i].key) end     -- l'echelle des relais doit etre a jour avant de convertir
		end
		M.ApplyRelays()
		M.SyncRelays()
	end
end

local function relayHook()
	M.ApplyRelays()
	M.SyncRelays()
end

function M.AddRelay(key, name, get, after)
	local t = get()
	if not t or not SUI.Mover or not SUI.Mover.Register then return nil end
	local p = CreateFrame("Frame", name, UIParent)
	p:SetWidth(t:GetWidth() or 300)
	p:SetHeight(t:GetHeight() or 22)
	p:Show()
	local r = { key = key, p = p, get = get, after = after, orig = savePoints(t), moved = false }
	tinsert(M.relays, r)
	SUI.Mover.Register(key, p, { point = "BOTTOMLEFT", x = t:GetLeft() or 40, y = t:GetBottom() or 200, scale = false, sync = M.SyncRelays,
		apply = relayHook })
	return r
end

function M.BuildMover()
	local f1 = M.frames[1]
	if M.mover or not f1 or not SUI.Mover or not SUI.Mover.Register then return end
	local rm = M.AddRelay("chat.main", "ShikiUI_ChatMover", function() return M.frames[1] end, function(f, reset)
		if not reset and f.SetUserPlaced then f:SetUserPlaced(true) end
		local save = getglobal("FCF_SavePositionAndDimensions")
		if type(save) == "function" then
			local ok, err = pcall(save, f)
			if not ok then SUI.Report("chat mover", err) end
		end
	end)
	if not rm then return end
	M.mover = rm.p
	M.barRelay = M.AddRelay("chat.tabs", "ShikiUI_ChatTabsMover", function() return M.bar end, function(bar, reset)
		local f1x = M.frames[1]
		if not reset and f1x and f1x:GetWidth() then bar:SetWidth(f1x:GetWidth() * (f1x:GetScale() or 1) / (bar:GetScale() or 1)) end
	end)
	if M.barRelay then M.barRelay.visible = function() return M.cfg.tabs end end
	M.bar2Relay = M.AddRelay("chat.tabs2", "ShikiUI_ChatTabs2Mover", function() return M.bar2 end, function(bar, reset)
		local f2x = M.frames[2]
		if not reset and f2x and f2x:GetWidth() then bar:SetWidth(f2x:GetWidth() * (f2x:GetScale() or 1) / (bar:GetScale() or 1)) end
	end)
	if M.bar2Relay then M.bar2Relay.visible = function() return M.cfg.tabs and M.cfg.tabs2 end end
	-- Une fois ancree par un seul point, la zone de saisie perd la largeur que lui donnaient ses deux ancres d'origine : on la remet a la
	-- largeur du chat (sinon le cadre se deforme et le texte "Say:" deborde).
	M.AddRelay("chat.edit", "ShikiUI_ChatEditMover", function() return getglobal("ChatFrameEditBox") end, function(eb, reset)
		local f1x = M.frames[1]
		local w = f1x and f1x:GetWidth()
		if not reset and w and w > 100 then eb:SetWidth(w * (f1x:GetScale() or 1) / (eb:GetScale() or 1)) end
	end)
	local eb = getglobal("ChatFrameEditBox")
	if eb and not M.editHooked and eb.GetScript and eb.SetScript then
		M.editHooked = true
		local old = eb:GetScript("OnShow")
		eb:SetScript("OnShow", function()
			if old then old() end
			M.ApplyRelays()
		end)
	end
	C.Watch("", M.OnPos)
	M.SyncRelays()
	M.ApplyRelays()
	M.SyncRelays()
	SUI.After(4, function() M.ApplyRelays() M.SyncRelays() end, "chat.mover")
end

-- ---------------------------------------------------------------- construction (une seule fois, hors combat)
function M.Build()
	if M.built then return end
	if not getglobal("ChatFrame1") then return end        -- pas d'interface Blizzard (hors jeu) : le module reste inactif
	M.num = getglobal("NUM_CHAT_WINDOWS") or 7
	M.partyIds = { "party1", "party2", "party3", "party4" }
	M.raidIds = {}
	for i = 1, 40 do M.raidIds[i] = "raid" .. i end
	M.tabs = {}
	M.tabHidden = {}
	M.btnHidden = {}
	M.wheelSet = {}
	M.btnNames = { "UpButton", "DownButton", "BottomButton" }
	for i = 1, M.num do
		local f = getglobal("ChatFrame" .. i)
		M.frames[i] = f
		local ring = {}
		for k = 1, HIST_MAX do ring[k] = false end
		M.hist[i] = ring
		M.hpos[i] = 0
		M.hcnt[i] = 0
		M.unread[i] = 0
	end
	local f1 = M.frames[1]
	-- fond
	local back = CreateFrame("Frame", "ShikiUI_ChatBack", UIParent)
	back:SetFrameStrata("BACKGROUND")
	T.Backdrop(back, T.c.bg, T.c.border)
	back:SetPoint("TOPLEFT", f1, "TOPLEFT", -4, 4)
	back:SetPoint("BOTTOMRIGHT", f1, "BOTTOMRIGHT", 4, -6)
	M.back = back
	-- barre d'onglets
	local bar = CreateFrame("Frame", "ShikiUI_ChatBar", UIParent)
	bar:SetHeight(22)
	bar:SetWidth(f1:GetWidth())
	T.Backdrop(bar, T.c.bg, T.c.border)
	bar:SetPoint("BOTTOMLEFT", f1, "TOPLEFT", 0, 8)
	bar:SetPoint("BOTTOMRIGHT", f1, "TOPRIGHT", 0, 8)
	M.bar = bar
	for i = 1, M.num do
		local b = T.Button(bar, "", 60, 18, M.OnTabClick)
		b.idx = i
		b:Hide()
		M.tabs[i] = b
	end
	-- Barre d'onglets 2 : ancree au-dessus de la fenetre 2 (ex. journal de combat detache a droite). Les fenetres
	-- affectees a cette barre (config chat.tab2set, defaut : la fenetre 2) y posent leurs onglets au lieu de la barre
	-- principale. Elle suit la fenetre 2 comme la barre principale suit la fenetre 1, et se cache tant que la fenetre
	-- 2 est dockee (dans le dock, les fenetres se superposent : la barre 2 empilerait sur la barre 1).
	local f2 = M.frames[2]
	if f2 then
		local bar2 = CreateFrame("Frame", "ShikiUI_ChatBar2", UIParent)
		bar2:SetHeight(22)
		bar2:SetWidth(f2:GetWidth())
		T.Backdrop(bar2, T.c.bg, T.c.border)
		bar2:SetPoint("BOTTOMLEFT", f2, "TOPLEFT", 0, 8)
		bar2:SetPoint("BOTTOMRIGHT", f2, "TOPRIGHT", 0, 8)
		bar2:Hide()
		M.bar2 = bar2
	end
	-- Bouton "copier" : une ACTION, pas un onglet. Petit carre a part, a droite, separe des onglets par un filet, dessine comme deux feuilles
	-- superposees (icone "copier") et non comme un onglet de canal ; l'infobulle dit ce qu'il fait.
	local cb = T.Button(bar, "", 22, 18, function() M.CopyFrame() end)
	cb:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
	cb.glyph = {}
	for k = 1, 2 do
		local g = cb:CreateTexture(nil, "OVERLAY")
		g:SetTexture(T.tex.white)
		g:SetWidth(8)
		g:SetHeight(9)
		g:SetPoint("CENTER", cb, "CENTER", k == 1 and -2 or 2, k == 1 and 2 or -2)
		cb.glyph[k] = g
	end
	cb.glyph[1]:SetVertexColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	cb.glyph[2]:SetVertexColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
	cb.sep = bar:CreateTexture(nil, "ARTWORK")
	cb.sep:SetTexture(T.tex.white)
	cb.sep:SetWidth(1)
	cb.sep:SetHeight(14)
	cb.sep:SetPoint("RIGHT", cb, "LEFT", -4, 0)
	cb.sep:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	local oe, ol = cb:GetScript("OnEnter"), cb:GetScript("OnLeave")
	cb:SetScript("OnEnter", function()
		if oe then oe() end
		if GameTooltip and GameTooltip.SetOwner then
			GameTooltip:SetOwner(cb, "ANCHOR_TOPRIGHT")
			GameTooltip:SetText(L("msg.chat.copytip"))
			GameTooltip:Show()
		end
	end)
	cb:SetScript("OnLeave", function()
		if ol then ol() end
		if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
	end)
	M.copyBtn = cb
	-- le bouton devient un cadre a part (deplacable, "chat.copybtn") ; il suit la visibilite de la barre d onglets
	cb:SetParent(UIParent)
	cb:SetFrameStrata(bar:GetFrameStrata())
	cb:SetFrameLevel((bar:GetFrameLevel() or 1) + 3)
	cb.sep:Hide()
	cb:ClearAllPoints()
	SUI.Layout.Register(cb, "chat.copybtn", "BOTTOMLEFT", 600, 40)
	if bar:IsVisible() then cb:Show() else cb:Hide() end
	-- bulle du menu de chat (emotes, langues...) : cadre Blizzard rendu deplacable ("chat.menubtn")
	local mb = getglobal("ChatFrameMenuButton")
	if mb and not M.menuBtn then
		M.menuBtn = mb
		local okm, errm = pcall(function()
			mb:SetParent(UIParent)
			mb:SetFrameStrata(bar:GetFrameStrata())
			mb:SetFrameLevel((bar:GetFrameLevel() or 1) + 3)
			mb:SetWidth(22)
			mb:SetHeight(18)
			mb:ClearAllPoints()
			SUI.Layout.Register(mb, "chat.menubtn", "BOTTOMLEFT", 630, 40)
			-- les menus deroulants (canaux, emotes, langues) s ouvrent AU-DESSUS des cadres d unites
			local oc = mb:GetScript("OnClick")
			mb:SetScript("OnClick", function()
				if oc then oc() end
				local nm = { "ChatMenu", "EmoteMenu", "LanguageMenu", "VoiceMacroMenu" }
				for i = 1, 4 do
					local m = getglobal(nm[i])
					if m and m.SetFrameStrata then m:SetFrameStrata("FULLSCREEN_DIALOG") end
				end
			end)
		end)
		if not okm then SUI.Report("chat menubtn", errm) end
	end
	-- fenetre de copie (texte de l'historique ou adresse web)
	local cp = T.Panel(UIParent, 520, 300)
	cp:SetFrameStrata("DIALOG")
	cp:Hide()
	M.copy = cp
	cp.title = T.Text(cp, 12, T.c.text, "LEFT")
	cp.title:SetPoint("TOPLEFT", cp, "TOPLEFT", 10, -8)
	local sf = CreateFrame("ScrollFrame", "ShikiUI_ChatCopyScroll", cp)
	sf:SetPoint("TOPLEFT", cp, "TOPLEFT", 8, -30)
	sf:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -8, 34)
	local ed = T.Edit(sf, 490, 400)
	ed:SetMultiLine(true)
	ed:SetMaxLetters(0)
	sf:SetScrollChild(ed)
	-- roulette : fait defiler le texte copie (sans elle, seule la fin du texte etait atteignable au clavier)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function()
		local s = this
		local cur, mx = s:GetVerticalScroll() or 0, s:GetVerticalScrollRange() or 0
		local nv = cur - arg1 * 42
		if nv < 0 then nv = 0 elseif nv > mx then nv = mx end
		s:SetVerticalScroll(nv)
	end)
	cp.edit = ed
	cp.scroll = sf
	local all = T.Button(cp, L("msg.chat.selectall"), 100, 20, function() M.copy.edit:SetFocus() M.copy.edit:HighlightText() end)
	all:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 8, 8)
	local close = T.Button(cp, L("msg.chat.close"), 80, 20, function() M.copy:Hide() end)
	close:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -8, 8)
	cp:SetScript("OnHide", function() M.copy.edit:ClearFocus() end)
	SUI.Layout.Register(cp, "chat.copy", "CENTER", 0, 80)
	cp:SetFrameStrata("DIALOG")
	tinsert(UISpecialFrames, "ShikiUI_ChatCopy")
	setglobal("ShikiUI_ChatCopy", cp)
	M.built = true
	M.BuildMover()
	M.RefreshColors()
	M.ReadConfig()
	local combatLog = getglobal("COMBAT_LOG")
	for i = 1, M.num do
		local name = GetChatWindowInfo(i)
		if name and combatLog and name == combatLog then M.frames[i].suiSkip = true end
	end
	if not M.watching then
		M.watching = true
		C.Watch("chat.", M.OnKey)
		T.OnAccent(M.OnStyle)
	end
	if M.on then M.Activate() end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- minuterie partagee
function M.Tick()
	if M.rosterDirty or (M.guildPending and not SUI.InCombat()) then M.ScanRoster() end
	if M.unknownSeen or not M.guildAsked then M.RequestGuild() end
	local sel = M.TrueSel(nil)
	if sel ~= M.selected then
		M.selected = sel
		if sel and sel.GetID then
			M.unread[sel:GetID()] = 0
			M.kwFlash[sel:GetID()] = nil
		end
		M.dirty = true
	end
	if M.kwAny then M.KwTick() end
	if M.cfg.kwn > 0 and M.kwName ~= UnitName("player") then M.KwRebuild() end
	M.KeepTabsHidden()
	if M.dirty then M.RefreshBar() end
end

function M.MarkRoster()
	M.rosterDirty = true
end

function M.OnTarget()
	if M.cfg.classcolor then M.LearnUnit("target") end
end

function M.OnMouseover()
	if M.cfg.classcolor then M.LearnUnit("mouseover") end
end

function M.OnKey(key, value)
	M.ReadConfig()
	M.ApplyOptions()
end

function M.OnStyle()
	M.RefreshColors()
end

-- ---------------------------------------------------------------- cycle de vie
function M.Activate()
	if M.active or not M.built then return end
	M.active = true
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("UPDATE_MOUSEOVER_UNIT", M.OnMouseover)
	SUI.On("PARTY_MEMBERS_CHANGED", M.MarkRoster)
	SUI.On("RAID_ROSTER_UPDATE", M.MarkRoster)
	SUI.On("FRIENDLIST_UPDATE", M.MarkRoster)
	SUI.On("GUILD_ROSTER_UPDATE", M.MarkRoster)
	SUI.On("WHO_LIST_UPDATE", M.OnWho)
	SUI.On("PLAYER_ENTERING_WORLD", M.MarkRoster)
	M.task = SUI.Every(TICK, M.Tick, "chat.tick", true)
	M.rosterDirty = true
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	M.num = getglobal("NUM_CHAT_WINDOWS") or 7
	for i = 1, M.num do
		local f = getglobal("ChatFrame" .. i)
		if f then M.WrapFrame(f) end
	end
	M.HookItemRef()
	SUI.WhenSafe(M.Build)
	M.Activate()
	M.ApplyOptions()
	if M.built and M.mover then
		M.ApplyRelays()
		M.SyncRelays()
	end
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("UPDATE_MOUSEOVER_UNIT", M.OnMouseover)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.MarkRoster)
	SUI.Off("RAID_ROSTER_UPDATE", M.MarkRoster)
	SUI.Off("FRIENDLIST_UPDATE", M.MarkRoster)
	SUI.Off("GUILD_ROSTER_UPDATE", M.MarkRoster)
	SUI.Off("WHO_LIST_UPDATE", M.OnWho)
	SUI.Off("PLAYER_ENTERING_WORLD", M.MarkRoster)
end

function M.Disable()
	M.on = false
	M.Deactivate()
	M.RestoreRelays()
	M.SyncRelays()
	M.ApplyOptions()
	if M.copy then M.copy:Hide() end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("chat", 22)

local function opt(key, typ, order, def, extra)
	local o = { key = "chat." .. key, type = typ, cat = "chat", label = "opt.chat." .. key, tip = "tip.chat." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("chat", {
	default = true,
	cost = "medium",
	options = {
		opt("tabs", "bool", 10, true, { simple = true }),
		opt("tabs2", "bool", 11, true, { simple = true }),
		opt("stamp", "bool", 20, true, { simple = true }),
		opt("stampfmt", "choice", 21, "hm", { choices = { "hm", "hms", "hm12" } }),
		opt("classcolor", "bool", 30, true, { simple = true }),
		opt("url", "bool", 40, true, { simple = true }),
		opt("shortchan", "bool", 50, false),
		opt("unread", "bool", 60, true),
		opt("dedupe", "number", 70, 0, { min = 0, max = 30, step = 1 }),
		opt("nourl", "bool", 71, false),
		opt("quiet", "bool", 72, false),
		opt("history", "number", 80, 200, { min = 50, max = 500, step = 50 }),
		opt("wheel", "number", 90, 3, { min = 0, max = 10, step = 1 }),
		opt("hidebuttons", "bool", 100, true),
		opt("background", "bool", 110, false),
		opt("bgalpha", "number", 111, 0.6, { min = 0.1, max = 1, step = 0.1 }),
		opt("fontsize", "number", 120, 0, { min = 0, max = 20, step = 1 }),
		opt("width", "number", 125, 0, { min = 0, max = 800, step = 10 }),
		opt("height", "number", 126, 0, { min = 0, max = 600, step = 10 }),
		opt("maxlines", "number", 130, 128, { min = 128, max = 1024, step = 64 }),
		opt("keywords", "text", 140, "$me"),
		opt("nick", "text", 141, ""),
		opt("kwcolor", "choice", 142, "warn", { choices = { "warn", "accent", "good", "bad", "text" } }),
		opt("kwsound", "choice", 143, "none", { choices = { "none", "tell", "ping", "raid", "quest", "level" } }),
		opt("kwchannels", "choice", 144, "all", { choices = { "all", "private", "public" } }),
		opt("kwflash", "bool", 145, true),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalents pfUI relevees (modules enregistres par pfUI:RegisterModule) : ce module attend tant que pfUI les fait tourner.
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.chat then SUI.Migrate.MAP.chat = { "chat", "chatcopy" } end

-- Mode Raid : moins de bruit, historique plus court, aucun canal public pendant les combats.
SUI.Config.AddPreset("raid", "*", { ["chat.history"] = 100, ["chat.dedupe"] = 5, ["chat.quiet"] = true, ["chat.shortchan"] = true })

SUI.RegisterCommand("chat", function(rest)
	if rest == "clear" then
		for i = 1, M.num do
			if M.hist[i] then
				for k = 1, HIST_MAX do M.hist[i][k] = false end
				M.hpos[i], M.hcnt[i], M.unread[i] = 0, 0, 0
			end
		end
		M.dirty = true
		SUI.Print(L("msg.chat.cleared"))
	elseif rest == "kw" or rest == "words" then
		SUI.Print(L("msg.chat.kwhelp"))
		SUI.Print(L("msg.chat.kwstate", M.cfg.kwn, M.kwHits))
	elseif rest == "stats" then
		SUI.Print(L("msg.chat.stats", M.nclass, M.dropped))
	elseif not M.built or not M.CopyFrame() then
		SUI.Print(L("msg.chat.notready"))
	end
end, "help.chat")
