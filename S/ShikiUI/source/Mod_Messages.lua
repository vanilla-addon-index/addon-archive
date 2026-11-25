-- ShikiUI Messages : fenetres de conversation par interlocuteur, notifications, historique persistant (equivalent configurable de WIM ;
-- reecrit, aucune ligne copiee). Module "messages". Cout declare : MEDIUM (frames preconstruites, une minuterie partagee allumee
-- seulement quand une notification ou un non-lu existe).
-- NOTIFICATION : un chuchotement (CHAT_MSG_WHISPER) cree une pastille (toast) cliquable par interlocuteur (nom, debut du message, compteur),
--  son optionnel, clignotement de bordure, compteur de non-lus (badge). Les pastilles s'empilent (5 visibles, le reste en file) ; un clic
--  ouvre la conversation, un clic droit ferme la pastille. Invitations de groupe / guilde, demandes d'echange et de duel : pastilles
--  d'information (aucune acceptation automatique). Mots-cles surveilles dans les canaux (CHAT_MSG_CHANNEL) : pastille + historique.
-- FENETRES : une par personne (mode "windows") ou une seule a onglets (mode "tabs") ; historique, saisie directe (SendChatMessage
--  "WHISPER"), couleur de classe, horodatage, liens d'objets (SetItemRef / infobulle), fermer, reduire, redimensionner. Toutes les
--  frames sont creees UNE fois, hors combat (pools) ; positions via SUI.Mover / SUI.Layout. DEPLACEMENT LIBRE : fenetres, pastilles (par
--  leur ancre), compteur et historique se glissent a la souris (StartMoving du moteur, pas d'OnUpdate) avec la touche choisie (option
--  dragmod : Maj / Ctrl / Alt / aucune / desactive) ; a la fin du glisser la position est ecrite dans le Layout (une cle par fenetre,
--  par mode) et appliquee tout de suite ; le clic qui suit un glisser n'ouvre / ne ferme rien.
-- CHAT NORMAL : option "suppress" : ChatFrame_OnEvent est enrobe (une fois) et ignore les evenements de chuchotement quand une fenetre
--  les montre ; coupee, le chat garde ses chuchotements. Mod_Chat n'est pas touche (il enrobe AddMessage, pas l'evenement).
-- HISTORIQUE : ShikiUIDB.global.msghist[Nom-Royaume][contact] = { name, "<ts><sens><texte>", ... } ; sens i (recu) o (envoye) a (absence)
--  k (mot-cle) e (invitation). Limite par contact, limite globale, purge par anciennete, fenetre de recherche par nom ou par mot.
-- ABSENCE : si /afk ou /dnd est actif (UnitIsAFK / UnitIsDND), reponse automatique une seule fois par contact (option, coupee par defaut :
--  le serveur peut deja repondre lui-meme).
-- COMBAT : option combatqueue : les evenements recus en combat vont dans un anneau PREALLOUE (32 entrees) et ne sont traites (fenetres,
--  pastilles, son, historique) qu'a PLAYER_REGEN_ENABLED ; en combat seul le badge compte. Les mots-cles de canal sont ignores en combat.
-- SOURCES (relevees dans WIM et pfUI installes, jamais executees ici) : CHAT_MSG_WHISPER (arg1 texte, arg2 nom), CHAT_MSG_WHISPER_INFORM
--  (arg1 texte, arg2 destinataire), CHAT_MSG_AFK / CHAT_MSG_DND (arg1 message, arg2 nom), CHAT_MSG_CHANNEL (arg1 texte, arg2 auteur, arg4
--  "N. canal"), SendChatMessage(texte, "WHISPER", nil, nom), ChatFrame_OnEvent(event), ChatFrame_ReplyTell, ChatEdit_SetLastTellTarget /
--  GetLastTellTarget, ChatFrameEditBox, OnHyperlinkClick -> SetItemRef, UnitIsAFK, PARTY_INVITE_REQUEST / DUEL_REQUESTED /
--  GUILD_INVITE_REQUEST (arg1 = nom ; arg2 = guilde), ScrollingMessageFrame.
-- NON VERIFIE EN JEU : tout ; TRADE_REQUEST (arg1 nom), UnitIsDND, ChatFrame_SendTell, PlaySound("TellMessage"), StartSizing("TOPRIGHT")
--  depuis une ancre BOTTOMLEFT, hauteur de ligne des pastilles, ScrollToBottom apres Clear, la suppression du chuchotement dans le chat
--  (ChatFrame_OnEvent peut etre enrobe par d'autres addons), le format reel de arg4 du canal. Non fait : shift-clic d'un lien dans la
--  saisie des fenetres (le jeu insere dans la saisie du chat), commandes / dans la saisie des fenetres (refusees).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local sfind, ssub, slower, supper, sformat, slen, sgsub = string.find, string.sub, string.lower, string.upper, string.format, string.len, string.gsub
local floor, abs = math.floor, math.abs

local M = {}
SUI.Messages = M

local NWIN = 8            -- fenetres preconstruites (maxwin <= NWIN)
local NTAB = 8            -- onglets
local NTOAST = 5          -- pastilles visibles
local PN = 32             -- anneau des evenements recus en combat
local MAXLINES = 80       -- lignes gardees en memoire par conversation
local MAXCONV = 40        -- conversations gardees en memoire
local MAXCONTACTS = 150   -- contacts gardes dans l'historique
local TICK = 0.5
local TH, TW = 36, 230    -- pastille : hauteur de pas, largeur
local HMAX = 200          -- lignes affichees par la recherche

M.on = false
M.convs = {}          -- cle (nom en minuscules) -> conversation { key, name, lines, unread, lastT, open, slot, class }
M.nconv = 0
M.win = {}
M.tf = {}             -- pastilles (frames)
M.toasts = {}         -- file des notifications { key, kind, name, text, count, born, blinkUntil }
M.pk, M.pnm, M.ptx, M.ptm = {}, {}, {}, {}
for i = 1, PN do M.pk[i], M.pnm[i], M.ptx[i], M.ptm[i] = false, false, false, 0 end
M.phead, M.pcount, M.dropped = 1, 0, 0
M.replied = {}        -- cle -> true : reponse d'absence deja envoyee
M.nreplied = 0
M.kw = {}             -- mots surveilles (minuscules)
M.kwSeen = {}
M.nseen = 0
M.htotal, M.hcontacts = 0, 0
M.hres = {}
M.blinkOn = false
M.armUntil = 0
M.dimHex, M.accentHex = "888888", "4dc4e8"
M.watching = false

-- ---------------------------------------------------------------- utilitaires
local function hexOf(c)
	return sformat("%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

function M.RefreshColors()
	M.dimHex = hexOf(T.c.dim)
	M.accentHex = hexOf({ T.Accent() })
end

local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

function M.Now()
	local f = getglobal("time")
	if f then return f() end
	return 0
end

function M.Date(fmt, ts)
	local f = getglobal("date")
	if f then return f(fmt, ts) end
	return ""
end

local function trim(s)
	s = sgsub(s, "^%s+", "")
	return (sgsub(s, "%s+$", ""))
end

function M.Key(name)
	return slower(name)
end

-- Nom saisi par l'utilisateur : Majuscule puis minuscules ; nil si ce n'est pas un nom plausible.
function M.CleanName(name)
	if type(name) ~= "string" then return nil end
	name = trim(name)
	if name == "" or slen(name) > 24 or sfind(name, "[%s|:,]") then return nil end
	return supper(ssub(name, 1, 1)) .. slower(ssub(name, 2))
end

local function clip(s, n)
	if slen(s) > n then return ssub(s, 1, n - 3) .. "..." end
	return s
end

-- Decoupe "a,b c" en mots minuscules dans le tableau out.
local function words(s, out)
	for i = getn(out), 1, -1 do out[i] = nil end
	local pos = 1
	s = slower(s or "")
	while pos <= slen(s) do
		local a, b = sfind(s, "[^,;]+", pos)
		if not a then break end
		local w = trim(ssub(s, a, b))
		if w ~= "" then tinsert(out, w) end
		pos = b + 1
	end
	return out
end

-- ---------------------------------------------------------------- classes
local CLASSUNITS = nil

function M.ClassOf(name)
	local ch = SUI.Chat
	local tok = ch and ch.class and ch.class[name]
	if tok then return tok end
	if UnitName("player") == name then
		local _, c = UnitClass("player")
		return c
	end
	if not CLASSUNITS then
		CLASSUNITS = { "target", "mouseover" }
		for i = 1, 4 do tinsert(CLASSUNITS, "party" .. i) end
		for i = 1, 40 do tinsert(CLASSUNITS, "raid" .. i) end
	end
	for i = 1, getn(CLASSUNITS) do
		local u = CLASSUNITS[i]
		if UnitExists(u) and UnitName(u) == name and UnitIsPlayer(u) then
			local _, c = UnitClass(u)
			if c then return c end
		end
	end
	return nil
end

local function classRGB(tok)
	local col = tok and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok]
	if col then return col.r, col.g, col.b end
	return nil
end

local function classHex(tok)
	local r, g, b = classRGB(tok)
	if r then return hexOf({ r, g, b }) end    -- style:ok couleur de classe (donnee de jeu)
	return nil
end

local function paintName(fs, tok)
	local r, g, b = classRGB(tok)
	if r then
		fs:SetTextColor(r, g, b, 1)    -- style:ok couleur de classe (donnee de jeu)
	else
		local c = T.c.text
		fs:SetTextColor(c[1], c[2], c[3], 1)
	end
end

-- ---------------------------------------------------------------- historique persistant
function M.Store()
	local g = C.GetGlobal("msghist")
	if type(g) ~= "table" then
		g = {}
		C.SetGlobal("msghist", g)
		if C.GetGlobal("msghist") ~= g then return nil end
	end
	local ck = C.CharKey()
	local st = g[ck]
	if type(st) ~= "table" then
		st = {}
		g[ck] = st
	end
	return st
end

local function entryTs(e)
	local _, _, ts = sfind(e, "^(%d+)")
	return tonumber(ts) or 0
end

function M.HistCount()
	local st = M.Store()
	M.htotal, M.hcontacts = 0, 0
	if not st then return end
	for key, rec in pairs(st) do
		if type(rec) == "table" then
			M.htotal = M.htotal + getn(rec)
			M.hcontacts = M.hcontacts + 1
		end
	end
end

local function dropOldestContact(st)
	local oldest, okey = nil, nil
	for key, rec in pairs(st) do
		local last = getn(rec) > 0 and entryTs(rec[getn(rec)]) or 0
		if not oldest or last < oldest then oldest, okey = last, key end
	end
	if okey then
		M.htotal = M.htotal - getn(st[okey])
		st[okey] = nil
		M.hcontacts = M.hcontacts - 1
	end
end

-- Retire les plus anciennes lignes (tous contacts confondus) jusqu'a 90 % de la limite globale.
function M.HistTrimGlobal()
	local st = M.Store()
	if not st then return end
	local target = floor(C.Get("messages.histtotal") * 0.9)
	local guard = 0
	while M.htotal > target and guard < 5000 do
		guard = guard + 1
		local best, bkey = nil, nil
		for key, rec in pairs(st) do
			if getn(rec) > 0 then
				local ts = entryTs(rec[1])
				if not best or ts < best then best, bkey = ts, key end
			end
		end
		if not bkey then break end
		local rec = st[bkey]
		tremove(rec, 1)
		M.htotal = M.htotal - 1
		if getn(rec) == 0 then
			st[bkey] = nil
			M.hcontacts = M.hcontacts - 1
		end
	end
end

-- Purge par anciennete (jours) ; retourne le nombre de lignes retirees.
function M.HistPurge()
	local days = C.Get("messages.histdays")
	local st = M.Store()
	if days <= 0 or not st then return 0 end
	local cutoff = M.Now() - days * 86400
	local removed = 0
	for key, rec in pairs(st) do
		while getn(rec) > 0 and entryTs(rec[1]) < cutoff do
			tremove(rec, 1)
			removed = removed + 1
		end
		if getn(rec) == 0 then
			st[key] = nil
		end
	end
	if removed > 0 then M.HistCount() end
	return removed
end

-- Ajoute une ligne a l'historique du contact 'key' (nom affiche 'name').
function M.HistAdd(key, name, dir, text, ts)
	if not C.Get("messages.history") then return end
	local st = M.Store()
	if not st then return end
	local rec = st[key]
	if not rec then
		if M.hcontacts >= MAXCONTACTS then dropOldestContact(st) end
		rec = { name = name }
		st[key] = rec
		M.hcontacts = M.hcontacts + 1
	end
	tinsert(rec, sformat("%d", ts) .. dir .. clip(text, 255))
	M.htotal = M.htotal + 1
	local per = C.Get("messages.histper")
	while getn(rec) > per do
		tremove(rec, 1)
		M.htotal = M.htotal - 1
	end
	if M.htotal > C.Get("messages.histtotal") then M.HistTrimGlobal() end
end

-- Efface l'historique d'un contact (key) ou de tous (key == nil) ; retourne le nombre de lignes.
function M.HistClear(key)
	local st = M.Store()
	if not st then return 0 end
	local n = 0
	if key then
		local rec = st[key]
		if rec then
			n = getn(rec)
			st[key] = nil
		end
	else
		for k, rec in pairs(st) do
			n = n + getn(rec)
			st[k] = nil
		end
	end
	M.HistCount()
	return n
end

function M.DisplayName(key, rec)
	if key == "*watch" then return L("msg.messages.hist.watch") end
	if key == "*events" then return L("msg.messages.hist.events") end
	return rec.name or key
end

local function byTime(a, b)
	if a[1] ~= b[1] then return a[1] < b[1] end
	return a[5] < b[5]
end

-- Recherche : un mot present dans le nom du contact (toutes ses lignes) ou dans le texte d'une ligne. Resultat trie par date dans M.hres.
function M.Search(q)
	q = slower(trim(q or ""))
	local out = M.hres
	for i = getn(out), 1, -1 do out[i] = nil end
	local st = M.Store()
	if not st then return out end
	local seq = 0
	for key, rec in pairs(st) do
		local nm = M.DisplayName(key, rec)
		local byname = q ~= "" and sfind(slower(nm), q, 1, true) ~= nil
		for j = 1, getn(rec) do
			local _, _, ts, dir, text = sfind(rec[j], "^(%d+)(%a)(.*)$")
			if ts and (q == "" or byname or sfind(slower(text), q, 1, true)) then
				seq = seq + 1
				tinsert(out, { tonumber(ts), nm, dir, text, seq })
			end
		end
	end
	table.sort(out, byTime)
	return out
end

-- ---------------------------------------------------------------- conversations
local function sortedClosed()
	local best, bkey = nil, nil
	for key, c in pairs(M.convs) do
		if not c.open and (c.unread or 0) == 0 then
			if not best or c.lastT < best then best, bkey = c.lastT, key end
		end
	end
	return bkey
end

-- Ligne prete a afficher. old : ligne relue de l'historique (nom et horodatage attenues).
function M.Line(conv, dir, text, ts, old)
	local stamp = ""
	if C.Get("messages.stamp") then
		local fmt = C.Get("messages.stampfmt") == "hms" and "%H:%M:%S" or "%H:%M"
		stamp = "|cff" .. M.dimHex .. "[" .. M.Date(fmt, ts) .. "]|r "
	end
	if dir == "i" or dir == "k" then
		local hex = (not old) and classHex(conv.class) or nil
		return stamp .. "|cff" .. (hex or M.dimHex) .. conv.name .. "|r: " .. text
	elseif dir == "o" then
		local me = UnitName("player") or "?"
		return stamp .. "|cff" .. (old and M.dimHex or M.accentHex) .. me .. "|r: " .. text
	end
	return stamp .. "|cff" .. M.dimHex .. text .. "|r"
end

-- Preremplit une conversation avec les dernieres lignes de l'historique.
function M.Preload(conv)
	local n = C.Get("messages.preload")
	if n <= 0 then return end
	local st = M.Store()
	local rec = st and st[conv.key]
	if not rec then return end
	local first = getn(rec) - n + 1
	if first < 1 then first = 1 end
	for j = first, getn(rec) do
		local _, _, ts, dir, text = sfind(rec[j], "^(%d+)(%a)(.*)$")
		if ts then M.Push1(conv, M.Line(conv, dir, text, tonumber(ts), true), ts .. dir .. "1" .. text) end
	end
end

-- src : "<ts><sens><1 si relue de l'historique><texte>", garde en parallele pour refaire les lignes quand l'horodatage change (reglages stamp / stampfmt).
function M.Push1(conv, line, src)
	if getn(conv.lines) >= MAXLINES then
		tremove(conv.lines, 1)
		tremove(conv.src, 1)
	end
	tinsert(conv.lines, line)
	tinsert(conv.src, src)
end

-- Refait toutes les lignes en memoire avec les reglages d'horodatage actuels, puis redessine les fenetres ouvertes.
function M.Restamp()
	for _, c in pairs(M.convs) do
		for i = 1, getn(c.lines) do
			local _, _, ts, dir, old, text = sfind(c.src[i] or "", "^(%d+)(%a)(%d)(.*)$")
			if ts then c.lines[i] = M.Line(c, dir, text, tonumber(ts), old == "1") end
		end
	end
	for i = 1, NWIN do
		local w = M.win[i]
		if w and w.conv and w:IsShown() and not w.min then M.Render(w) end
	end
end

function M.GetConv(name, create)
	local key = M.Key(name)
	local c = M.convs[key]
	if c or not create then return c end
	if M.nconv >= MAXCONV then
		local old = sortedClosed()
		if old then
			M.convs[old] = nil
			M.nconv = M.nconv - 1
		end
	end
	c = { key = key, name = name, lines = {}, src = {}, unread = 0, lastT = GetTime(), open = false, slot = nil, class = M.ClassOf(name) }
	M.convs[key] = c
	M.nconv = M.nconv + 1
	M.Preload(c)
	return c
end

function M.Unread()
	local n = 0
	for _, c in pairs(M.convs) do n = n + (c.unread or 0) end
	return n
end

-- La conversation est-elle visible et lue (fenetre ou onglet actif, non reduit) ?
function M.Displayed(conv)
	if not conv.open or not conv.slot then return false end
	local w = M.win[conv.slot]
	return w ~= nil and w.conv == conv.key and w:IsShown() and not w.min
end

-- ---------------------------------------------------------------- fenetres
function M.Render(w)
	local conv = w.conv and M.convs[w.conv]
	w.msgs:Clear()
	if not conv then return end
	local c = T.c.text
	for i = 1, getn(conv.lines) do
		w.msgs:AddMessage(conv.lines[i], c[1], c[2], c[3])
	end
	w.msgs:ScrollToBottom()
end

function M.SetTitle(w)
	local conv = w.conv and M.convs[w.conv]
	if not conv then
		setText(w.title, "")
		return
	end
	local n = conv.unread or 0
	setText(w.title, conv.name .. (n > 0 and (" (" .. n .. ")") or ""))
	paintName(w.title, conv.class)
end

function M.C_tabs()
	return C.Get("messages.mode") == "tabs"
end

-- Place le champ de messages selon le mode (barre d'onglets en mode "tabs") et l'etat reduit.
function M.LayoutWin(w)
	local tabs = M.C_tabs()
	w.msgs:ClearAllPoints()
	w.msgs:SetPoint("TOPLEFT", w, "TOPLEFT", 8, tabs and -44 or -24)
	w.msgs:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -8, 28)
	for i = 1, NTAB do
		local b = w.tabs[i]
		if not (tabs and w.slot == 1 and not w.min and w.tabkeys[i]) then b:Hide() end
	end
	if w.min then
		w:SetHeight(22)
		w.msgs:Hide()
		w.edit:Hide()
		w.grip:Hide()
		w.hist:Hide()
	else
		w:SetWidth(C.Get("messages.winw"))
		w:SetHeight(C.Get("messages.winh"))
		w.msgs:Show()
		w.edit:Show()
		w.grip:Show()
		w.hist:Show()
	end
end

-- Barre d'onglets (fenetre 1, mode "tabs") : un bouton par conversation ouverte.
function M.LayoutTabs(w)
	local tabs = M.C_tabs() and w.slot == 1
	local n = 0
	for i = 1, NTAB do w.tabkeys[i] = nil end
	if tabs then
		local list = {}
		for key, c in pairs(M.convs) do
			if c.open and c.slot == 1 then tinsert(list, c) end
		end
		table.sort(list, function(a, b) return a.opened < b.opened end)
		for i = 1, getn(list) do
			if i <= NTAB then
				w.tabkeys[i] = list[i].key
				n = i
			end
		end
	end
	-- largeur d'un onglet : 68 au plus, reduite pour que tous tiennent dans la fenetre (jamais de bouton hors du cadre)
	local tw = 68
	if n > 0 then
		tw = floor(((w:GetWidth() or 320) - 12) / n) - 2
		if tw > 68 then tw = 68 end
		if tw < 22 then tw = 22 end
	end
	for i = 1, NTAB do
		local b = w.tabs[i]
		local c = w.tabkeys[i] and M.convs[w.tabkeys[i]]
		if c and not w.min then
			local u = c.unread or 0
			setText(b.label, clip(c.name, floor(tw / 7)) .. (u > 0 and ("*" .. u) or ""))
			b.key = c.key
			T.SetSelected(b, c.key == w.conv)
			b:SetWidth(tw)
			b.label:SetWidth(tw - 4)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", w, "TOPLEFT", 6 + (i - 1) * (tw + 2), -24)
			b:Show()
		else
			b:Hide()
		end
	end
end

function M.RefreshWin(w)
	M.LayoutWin(w)
	M.LayoutTabs(w)
	M.SetTitle(w)
end

local function sendFromWindow(w)
	local conv = w.conv and M.convs[w.conv]
	local txt = w.edit:GetText()
	if not conv or not txt or txt == "" then return end
	if ssub(txt, 1, 1) == "/" then
		SUI.Print(L("msg.messages.nocmd"))
		w.edit:SetText("")
		return
	end
	SendChatMessage(txt, "WHISPER", nil, conv.name)
	w.edit:SetText("")
end

local function winScroll()
	if arg1 and arg1 > 0 then this:ScrollUp() else this:ScrollDown() end
end

local function linkClick()
	if M.JustDragged() then return end
	local f = getglobal("SetItemRef")
	if f then f(arg1, arg2, arg3) end
end

local function linkEnter()
	local tt = getglobal("GameTooltip")
	if tt and type(arg1) == "string" and ssub(arg1, 1, 5) == "item:" then
		tt:SetOwner(this, "ANCHOR_RIGHT")
		pcall(tt.SetHyperlink, tt, arg1)   -- pcall : AtlasLoot intercepte les tooltips
		tt:Show()
	end
end

local function linkLeave()
	local tt = getglobal("GameTooltip")
	if tt then tt:Hide() end
end

-- ---------------------------------------------------------------- deplacement libre
-- Touche exigee au moment ou l'on appuie sur le bouton gauche (option messages.dragmod, relue a chaque appui : effet immediat).
function M.ModHeld()
	local m = C.Get("messages.dragmod")
	if m == "none" then return true end
	local name = nil
	if m == "shift" then name = "IsShiftKeyDown" elseif m == "ctrl" then name = "IsControlKeyDown" elseif m == "alt" then name = "IsAltKeyDown" end
	local f = name and getglobal(name)
	if type(f) ~= "function" then return false end
	return f() and true or false
end

-- src : cadre qui recoit le clic (this) ; src.dragFrame : cadre a deplacer ; src.dragId : cle de position (Layout).
function M.DragStart(src)
	if M.dframe then M.DragStop() end
	if not M.on or not src or not src.dragFrame or arg1 ~= "LeftButton" or not M.ModHeld() then return false end
	local f = src.dragFrame
	f:SetMovable(true)
	if not f:IsShown() then
		-- l'ancre des pastilles est cachee hors apercu : montree (transparente) le temps du glisser
		f.tmpShow = true
		f:SetAlpha(0)
		f:Show()
	end
	M.dframe, M.did = f, src.dragId
	M.dl, M.db = f:GetLeft(), f:GetBottom()
	f:StartMoving()
	return true
end

-- Fin du glisser : position ecrite (unites d'UIParent, comme le Mover) puis appliquee et diffusee.
function M.DragStop()
	local f = M.dframe
	if not f then return end
	M.dframe = nil
	f:StopMovingOrSizing()
	local id = M.did
	local l, b = f:GetLeft(), f:GetBottom()
	M.dragMoved = false
	if l and b and M.dl and M.db and (abs(l - M.dl) > 2 or abs(b - M.db) > 2) then
		M.dragMoved = true
		M.dragEnd = GetTime()
		local sc = f:GetScale() or 1
		local _, _, s = C.GetPos(SUI.Layout.ReadKey(id))
		C.SetPos(SUI.Layout.WriteKey(id), l * sc, b * sc, s)
	end
	if f.tmpShow then
		f.tmpShow = false
		f:SetAlpha(1)
		f:Hide()
	end
	SUI.Layout.Apply(id)
	if M.dragMoved then C.Notify("pos", nil) end
end

-- Vrai juste apres un glisser reel : le clic qui suit ne doit rien declencher.
function M.JustDragged()
	return M.dragMoved and M.dragEnd and GetTime() - M.dragEnd < 0.25 and true or false
end

local function dragDown()
	M.DragStart(this)
end

local function dragUp()
	M.DragStop()
end

local function dragSrc(src, frame, id)
	src.dragFrame, src.dragId = frame, id
	src:SetScript("OnMouseDown", dragDown)
	src:SetScript("OnMouseUp", dragUp)
end

function M.BuildWindow(i)
	if M.win[i] then return M.win[i] end
	local f = T.Panel(UIParent, C.Get("messages.winw"), C.Get("messages.winh"))
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	f:SetResizable(true)
	f:SetMinResize(220, 120)
	f:SetClampedToScreen(true)
	f:Hide()
	f.slot = i
	f.min = false
	f.tabkeys = {}
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	f.title:SetWidth(120)
	f.tbar = CreateFrame("Button", nil, f)
	f.tbar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.tbar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -94, 0)
	f.tbar:SetHeight(22)
	f.tbar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.tbar:SetScript("OnClick", function() M.TitleClick(i, arg1) end)
	dragSrc(f.tbar, f, "messages.win" .. i)
	dragSrc(f, f, "messages.win" .. i)
	f.close = T.Button(f, "x", 16, 16, function() M.CloseSlot(i) end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -3)
	f.mini = T.Button(f, "-", 16, 16, function() M.ToggleMin(i) end)
	f.mini:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
	f.hist = T.Button(f, L("msg.messages.btn.hist"), 16, 16, function()
		local conv = f.conv and M.convs[f.conv]
		if conv then M.ShowHistory(conv.name) end
	end)
	f.hist:SetPoint("RIGHT", f.mini, "LEFT", -2, 0)
	-- engrenage : ouvre les reglages du module (a gauche du bouton Historique)
	T.GearButton(f, "messages", { size = 16, point = "TOPRIGHT", x = -92, y = -3, title = L("msg.messages.gear"),
		onCreate = function(g)
			g:ClearAllPoints()
			g:SetPoint("RIGHT", f.hist, "LEFT", -2, 0)
		end })
	f.tabs = {}
	for k = 1, NTAB do
		local b = T.Button(f, "", 68, 16, function(btn)
			if btn.key then M.Open(btn.key, true) end
		end)
		b.label:SetWidth(64)
		b:Hide()
		f.tabs[k] = b
	end
	local m = CreateFrame("ScrollingMessageFrame", nil, f)
	m:SetFont(T.font, 11)
	m:SetJustifyH("LEFT")
	m:SetMaxLines(120)
	m:SetFading(false)
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", winScroll)
	m:SetScript("OnHyperlinkClick", linkClick)
	m:SetScript("OnHyperlinkEnter", linkEnter)
	m:SetScript("OnHyperlinkLeave", linkLeave)
	f.msgs = m
	dragSrc(m, f, "messages.win" .. i)
	local e = T.Edit(f, 100, 18)
	e:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
	e:SetMaxLetters(255)
	e:SetScript("OnEnterPressed", function() sendFromWindow(f) end)
	f.edit = e
	local g = CreateFrame("Button", nil, f)
	g:SetWidth(14)
	g:SetHeight(14)
	g:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	g:SetScript("OnMouseDown", function() f:StartSizing("TOPRIGHT") end)
	g:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		M.SizeDone(f)
	end)
	f.grip = g
	M.win[i] = f
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("messages.win" .. i, f, { label = L("msg.messages.mover.win", i), point = "BOTTOMLEFT",
			x = 30 + (i - 1) * 36, y = 200 + (i - 1) * 28, scale = false })
	else
		SUI.Layout.Register(f, "messages.win" .. i, "BOTTOMLEFT", 30 + (i - 1) * 36, 200 + (i - 1) * 28)
	end
	return f
end

-- Fin d'un redimensionnement a la souris : la taille devient un reglage commun a toutes les fenetres.
function M.SizeDone(f)
	local w, h = f:GetWidth(), f:GetHeight()
	if f.min then return end
	C.SetBase("messages.winw", w)
	C.SetBase("messages.winh", h)
end

function M.ToggleMin(i)
	local w = M.win[i]
	if not w then return end
	w.min = not w.min
	if not w.min then
		local conv = w.conv and M.convs[w.conv]
		if conv then conv.unread = 0 end
		M.RefreshWin(w)
		M.Render(w)
		M.UpdateBadge()
	else
		M.RefreshWin(w)
	end
end

-- Actions sur l'interlocuteur : clic droit sur le titre = menu du jeu (inviter, /who, ami, ignorer...), Maj + clic gauche = /who
-- (niveau, race, zone dans le chat), comme un clic sur un nom dans le chat.
function M.PlayerMenu(name)
	local f = getglobal("FriendsFrame_ShowDropdown")
	if type(f) == "function" then
		local ok, err = pcall(f, name, 1)
		if not ok then SUI.Report("messages menu", err) end
		return true
	end
	return false
end

function M.WhoName(name)
	local f = getglobal("SendWho")
	if type(f) ~= "function" or not name then return false end
	f("n-" .. name)
	return true
end

function M.TitleClick(i, button)
	if M.JustDragged() then return end
	local w = M.win[i]
	local conv = w and w.conv and M.convs[w.conv]
	if conv and button == "RightButton" then
		M.PlayerMenu(conv.name)
		return
	end
	if conv and IsShiftKeyDown and IsShiftKeyDown() then
		M.WhoName(conv.name)
		return
	end
	if w and w.min then M.ToggleMin(i) elseif w then w.edit:SetFocus() end
end

-- Attribue une fenetre (ou l'onglet) a la conversation ; retourne le numero de fenetre.
function M.Attach(conv)
	if M.C_tabs() then
		conv.slot = 1
		M.win[1].conv = conv.key
		return 1
	end
	local max = C.Get("messages.maxwin")
	if conv.slot and conv.slot <= max and M.win[conv.slot].conv == conv.key then return conv.slot end
	local free = nil
	for s = 1, max do
		if not M.win[s].conv then
			free = s
			break
		end
	end
	if not free then
		local oldest, ok = nil, nil
		for s = 1, max do
			local c = M.convs[M.win[s].conv]
			if c and (not oldest or c.lastT < oldest) then oldest, ok = c.lastT, s end
		end
		free = ok or 1
		local victim = M.convs[M.win[free].conv]
		if victim then
			victim.open = false
			victim.slot = nil
		end
	end
	M.win[free].conv = conv.key
	conv.slot = free
	return free
end

-- Ouvre (ou ramene au premier plan) la conversation. focus : place le curseur dans la saisie.
function M.Open(key, focus)
	local conv = M.convs[key]
	if not conv or not M.on or not M.win[1] then return false end
	if not conv.open then
		conv.open = true
		conv.opened = GetTime()
	end
	if M.C_tabs() then
		local count = 0
		for _, c in pairs(M.convs) do
			if c.open and c.slot == 1 then count = count + 1 end
		end
		if count > NTAB then
			local oldest, ok = nil, nil
			for k, c in pairs(M.convs) do
				if c.open and c.slot == 1 and k ~= key and (not oldest or c.lastT < oldest) then oldest, ok = c.lastT, k end
			end
			if ok then
				M.convs[ok].open = false
				M.convs[ok].slot = nil
			end
		end
	end
	local s = M.Attach(conv)
	local w = M.win[s]
	w.conv = key
	w.min = false
	conv.unread = 0
	w:Show()
	M.RefreshWin(w)
	M.Render(w)
	M.RemoveToast(key)
	M.UpdateBadge()
	if focus and C.Get("messages.focus") then w.edit:SetFocus() end
	return true
end

function M.CloseSlot(i)
	local w = M.win[i]
	if not w or not w.conv then
		if w then w:Hide() end
		return
	end
	local conv = M.convs[w.conv]
	if conv then
		conv.open = false
		conv.slot = nil
	end
	w.conv = nil
	w.edit:ClearFocus()
	if M.C_tabs() and i == 1 then
		local pick = nil
		for _, c in pairs(M.convs) do
			if c.open and c.slot == 1 and (not pick or c.lastT > pick.lastT) then pick = c end
		end
		if pick then
			w.conv = pick.key
			pick.unread = 0
			M.RefreshWin(w)
			M.Render(w)
			M.UpdateBadge()
			return
		end
	end
	w.min = false
	w:Hide()
	M.UpdateBadge()
end

-- Mode ou nombre de fenetres change : tout re-attribuer.
function M.Reflow()
	local open = {}
	for _, c in pairs(M.convs) do
		if c.open then tinsert(open, c) end
	end
	table.sort(open, function(a, b) return a.lastT < b.lastT end)
	for i = 1, NWIN do
		local w = M.win[i]
		if w then
			w.conv = nil
			w.min = false
			w:Hide()
		end
	end
	for _, c in pairs(M.convs) do
		c.open = false
		c.slot = nil
	end
	for i = 1, getn(open) do M.Open(open[i].key, false) end
end

function M.OpenByName(name, focus)
	local nm = M.CleanName(name)
	if not nm then return false end
	local conv = M.GetConv(nm, true)
	return M.Open(conv.key, focus)
end

-- ---------------------------------------------------------------- pastilles et badge
function M.BuildToast(i)
	local b = T.Button(UIParent, "", TW, TH - 2, function(btn, button)
		M.ToastClick(i, button)
	end)
	b:SetFrameStrata("HIGH")
	b.label:ClearAllPoints()
	b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -4)
	b.label:SetWidth(TW - 50)
	b.label:SetJustifyH("LEFT")
	b.sub = T.Text(b, 10, T.c.dim, "LEFT")
	b.sub:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -18)
	b.sub:SetWidth(TW - 12)
	b.cnt = T.Text(b, 11, T.c.text, "RIGHT")
	b.cnt:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -4)
	b.hold = false
	dragSrc(b, M.anchor, "messages.toasts")
	b:SetScript("OnEnter", function()
		this.hold = true
	end)
	b:SetScript("OnLeave", function()
		this.hold = false
	end)
	b:Hide()
	M.tf[i] = b
	return b
end

function M.ToastClick(i, button)
	if M.JustDragged() then return end
	local e = M.toasts[i]
	if not e then return end
	if button == "RightButton" then
		M.DismissToast(i)
		return
	end
	local key = e.key
	local author = e.kind == "k" and e.name or nil
	M.DismissToast(i)
	if key then
		M.Open(key, true)
	elseif author then
		M.OpenByName(author, true)
	end
end

function M.DismissToast(i)
	if M.toasts[i] then
		tremove(M.toasts, i)
		M.ToastLayout()
	end
end

function M.RemoveToast(key)
	for i = getn(M.toasts), 1, -1 do
		if M.toasts[i].key == key then tremove(M.toasts, i) end
	end
	M.ToastLayout()
end

function M.ClearToasts()
	for i = getn(M.toasts), 1, -1 do M.toasts[i] = nil end
	M.ToastLayout()
end

function M.ToastLayout()
	if not M.anchor then return end
	local n = getn(M.toasts)
	for i = 1, NTOAST do
		local f = M.tf[i]
		local e = M.toasts[i]
		if f then
			if e and M.on then
				local conv = e.key and M.convs[e.key]
				setText(f.label, e.name)
				paintName(f.label, conv and conv.class or e.class)
				setText(f.sub, clip(e.text, 40))
				local cnt = e.count > 1 and ("x" .. e.count) or ""
				if i == NTOAST and n > NTOAST then cnt = cnt .. " +" .. (n - NTOAST) end
				setText(f.cnt, cnt)
				-- meme echelle que le cadre-ancre (ui.scale x Mover) : sa poignee a la taille reelle des pastilles et elles restent alignees dessous
				f:SetScale(M.anchor:GetScale() or 1)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", M.anchor, "BOTTOMLEFT", 0, -(i - 1) * TH)
				f:Show()
			else
				f:Hide()
			end
		end
	end
end

-- Ajoute ou met a jour une pastille. kind : i (chuchotement) e (evenement) k (mot-cle).
function M.Toast(kind, key, name, text, class)
	if not M.on or not C.Get("messages.toast") then return end
	local now = GetTime()
	local e = nil
	if key then
		for i = 1, getn(M.toasts) do
			if M.toasts[i].key == key then e = M.toasts[i] end
		end
	end
	if e then
		e.count = e.count + 1
		e.text = text
		e.born = now
	else
		e = { key = key, kind = kind, name = name, text = text, count = 1, born = now, class = class }
		tinsert(M.toasts, e)
	end
	e.blinkUntil = now + 4
	M.ToastLayout()
	M.EnsureTick()
end

local function border(f, hot)
	if hot then
		local r, g, b = T.Accent()
		f:SetBackdropBorderColor(r, g, b, 1)
	else
		local c = T.c.border
		f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

function M.BuildBadge()
	local f = T.Panel(UIParent, 46, 22)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f.txt = T.Text(f, 12, T.c.text, "CENTER")
	f.txt:SetPoint("CENTER", f, "CENTER", 0, 0)
	dragSrc(f, f, "messages.badge")
	f:SetScript("OnMouseUp", function()
		M.DragStop()
		M.BadgeClick()
	end)
	f:Hide()
	M.badge = f
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("messages.badge", f, { label = L("msg.messages.mover.badge"), point = "TOPRIGHT", x = -20, y = -170, scale = false,
			preview = function(on) M.previewBadge = on; M.UpdateBadge() end })
	else
		SUI.Layout.Register(f, "messages.badge", "TOPRIGHT", -20, -170)
	end
end

function M.UpdateBadge()
	local f = M.badge
	if not f then return end
	local n = M.Unread() + M.pcount
	if (M.on and C.Get("messages.badge") and n > 0) or (M.on and M.previewBadge) then
		setText(f.txt, n > 0 and sformat("%d", n) or "0")
		f:Show()
		if n > 0 and not M.task then M.EnsureTick() end
	else
		f:Hide()
	end
end

function M.BadgeClick()
	if M.JustDragged() then return end
	local pick = nil
	for _, c in pairs(M.convs) do
		if (c.unread or 0) > 0 and (not pick or c.lastT > pick.lastT) then pick = c end
	end
	if pick then M.Open(pick.key, true) else M.ShowHistory("") end
end

-- ---------------------------------------------------------------- minuterie (allumee seulement si besoin)
function M.EnsureTick()
	if not M.task then M.task = SUI.Every(TICK, M.Tick, "messages.tick") end
end

function M.Tick()
	local now = GetTime()
	M.blinkOn = not M.blinkOn
	local secs = C.Get("messages.toastsecs")
	local blink = C.Get("messages.blink")
	local changed = false
	local i = 1
	while i <= getn(M.toasts) do
		local e = M.toasts[i]
		local f = i <= NTOAST and M.tf[i] or nil
		if f and f.hold then e.born = now end
		if secs > 0 and now - e.born > secs then
			tremove(M.toasts, i)
			changed = true
		else
			i = i + 1
		end
	end
	if changed then M.ToastLayout() end
	for k = 1, NTOAST do
		local f = M.tf[k]
		local e = M.toasts[k]
		if f and e then
			border(f, blink and now < e.blinkUntil and M.blinkOn)
		end
	end
	local unread = M.Unread()
	if M.badge and M.badge:IsShown() then border(M.badge, blink and (unread > 0 or M.pcount > 0) and M.blinkOn) end
	for k = 1, NWIN do
		local w = M.win[k]
		if w and w:IsShown() then
			local u = 0
			for _, c in pairs(M.convs) do
				if c.open and c.slot == k then u = u + (c.unread or 0) end
			end
			border(w, blink and u > 0 and M.blinkOn)
		end
	end
	if getn(M.toasts) == 0 and unread == 0 and M.pcount == 0 then
		SUI.Cancel(M.task)
		M.task = nil
		if M.badge then border(M.badge, false) end
		for k = 1, NWIN do
			if M.win[k] then border(M.win[k], false) end
		end
	end
end

-- ---------------------------------------------------------------- traitement des messages
function M.Sound()
	if not C.Get("messages.sound") then return end
	local f = getglobal("PlaySound")
	if f then f("TellMessage") end
end

function M.LastTell(name)
	local set, eb = getglobal("ChatEdit_SetLastTellTarget"), getglobal("ChatFrameEditBox")
	if set and eb then set(eb, name) end
end

function M.Suppressing()
	return M.on and C.Get("messages.suppress") and not (SUI.InCombat() and C.Get("messages.combatqueue"))
end

function M.AutoReply(conv)
	if not C.Get("messages.autoreply") then return end
	local fa, fd = getglobal("UnitIsAFK"), getglobal("UnitIsDND")
	local away = (fa and fa("player")) or (fd and fd("player"))
	if not away then
		if M.nreplied > 0 then
			for k, _ in pairs(M.replied) do M.replied[k] = nil end
			M.nreplied = 0
		end
		return
	end
	if M.replied[conv.key] then return end
	M.replied[conv.key] = true
	M.nreplied = M.nreplied + 1
	local txt = C.Get("messages.replytext")
	if not txt or txt == "" then txt = L("msg.messages.autoreply.default") end
	SendChatMessage(txt, "WHISPER", nil, conv.name)
end

-- Ajoute une ligne a la conversation (memoire + fenetre visible) et gere le compteur de non-lus.
function M.AddLine(conv, dir, text, ts)
	local line = M.Line(conv, dir, text, ts, false)
	M.Push1(conv, line, sformat("%d", ts) .. dir .. "0" .. text)
	conv.lastT = GetTime()
	if M.Displayed(conv) then
		local c = T.c.text
		M.win[conv.slot].msgs:AddMessage(line, c[1], c[2], c[3])
	elseif dir == "i" then
		conv.unread = (conv.unread or 0) + 1
		if conv.open and conv.slot then M.RefreshWin(M.win[conv.slot]) end
	end
end

function M.Process(kind, name, text, ts)
	if not M.on then return end
	if kind == "i" or kind == "o" or kind == "a" or kind == "d" then
		local conv = M.GetConv(name, kind == "i" or kind == "o")
		if not conv then return end
		if not conv.class then conv.class = M.ClassOf(name) end
		if kind == "i" then
			M.AddLine(conv, "i", text, ts)
			M.HistAdd(conv.key, conv.name, "i", text, ts)
			M.LastTell(name)
			local shown = M.Displayed(conv)
			if C.Get("messages.autoopen") and not conv.open then M.Open(conv.key, false) end
			if not M.Displayed(conv) then
				M.Toast("i", conv.key, conv.name, text, conv.class)
			end
			if not shown then M.Sound() end   -- son des qu'un message arrive hors conversation affichee (suppress ou non)
			M.AutoReply(conv)
		elseif kind == "o" then
			M.AddLine(conv, "o", text, ts)
			M.HistAdd(conv.key, conv.name, "o", text, ts)
			if C.Get("messages.openonsend") and not conv.open then M.Open(conv.key, false) end
		else
			local tag = kind == "a" and "<AFK> " or "<DND> "
			M.AddLine(conv, "a", tag .. text, ts)
			M.HistAdd(conv.key, conv.name, "a", tag .. text, ts)
		end
	elseif kind == "e" then
		if C.Get("messages.invites") then
			M.Toast("e", nil, name, text, M.ClassOf(name))
			M.Sound()
			if C.Get("messages.histinvites") then M.HistAdd("*events", "*events", "e", name .. ": " .. text, ts) end
		end
	elseif kind == "k" then
		M.Toast("k", nil, name, text, M.ClassOf(name))
		M.Sound()
		if C.Get("messages.histwatch") then M.HistAdd("*watch", "*watch", "k", name .. ": " .. text, ts) end
	end
	M.UpdateBadge()
end

-- Anneau d'attente (combat) : aucune table creee.
function M.Push(kind, name, text)
	if M.pcount >= PN then
		M.phead = SUI.Mod(M.phead, PN) + 1
		M.pcount = PN - 1
		M.dropped = M.dropped + 1
	end
	local idx = SUI.Mod(M.phead + M.pcount - 1, PN) + 1
	M.pk[idx], M.pnm[idx], M.ptx[idx], M.ptm[idx] = kind, name, text, M.Now()
	M.pcount = M.pcount + 1
	M.UpdateBadge()
end

function M.Flush()
	if M.pcount == 0 then return end
	local n, lost = M.pcount, M.dropped
	M.dropped = 0
	local head = M.phead
	M.phead, M.pcount = 1, 0
	for k = 1, n do
		local idx = SUI.Mod(head + k - 2, PN) + 1
		local kind, name, text, ts = M.pk[idx], M.pnm[idx], M.ptx[idx], M.ptm[idx]
		M.pk[idx], M.pnm[idx], M.ptx[idx] = false, false, false
		if kind then M.Process(kind, name, text, ts) end
	end
	SUI.Print(L("msg.messages.flushed", n))
	if lost > 0 then SUI.Print(L("msg.messages.lost", lost)) end
	M.UpdateBadge()
end

local function incoming(kind, name, text)
	if not M.on or type(name) ~= "string" or name == "" or type(text) ~= "string" then return end
	if SUI.InCombat() and C.Get("messages.combatqueue") then
		M.Push(kind, name, text)
	else
		M.Process(kind, name, text, M.Now())
	end
end

function M.OnWhisper(ev, text, name) incoming("i", name, text) end
function M.OnInform(ev, text, name) incoming("o", name, text) end
function M.OnAway(ev, text, name)
	if not M.GetConv(name, false) then return end
	incoming(ev == "CHAT_MSG_AFK" and "a" or "d", name, text)
end

function M.OnPartyInvite(ev, who) incoming("e", who, L("msg.messages.ev.party")) end
function M.OnGuildInvite(ev, who, guild) incoming("e", who, L("msg.messages.ev.guild", guild or "?")) end
function M.OnTrade(ev, who) incoming("e", who, L("msg.messages.ev.trade")) end
function M.OnDuel(ev, who) incoming("e", who, L("msg.messages.ev.duel")) end

-- Mot-cle dans un canal (jamais en combat ; un auteur au plus une fois par minute).
function M.OnChannel(ev, text, author, _, chan)
	if not M.on or type(text) ~= "string" or type(author) ~= "string" or SUI.InCombat() then return end
	if author == UnitName("player") then return end
	local low = slower(text)
	local hit = false
	for i = 1, getn(M.kw) do
		if sfind(low, M.kw[i], 1, true) then hit = true end
	end
	if not hit then return end
	local now = GetTime()
	local seen = M.kwSeen[author]
	if seen and now - seen < 60 then return end
	if M.nseen > 60 then
		for k, _ in pairs(M.kwSeen) do M.kwSeen[k] = nil end
		M.nseen = 0
	end
	if not seen then M.nseen = M.nseen + 1 end
	M.kwSeen[author] = now
	local c = (type(chan) == "string" and chan ~= "") and ("[" .. chan .. "] ") or ""
	M.Process("k", author, clip(c .. text, 200), M.Now())
end

function M.OnRegen()
	M.Flush()
end

-- ---------------------------------------------------------------- crochets du chat Blizzard
local SUPPRESSED = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_AFK = true, CHAT_MSG_DND = true }

function M.ChatHook(ev)
	local e = ev or event
	if SUPPRESSED[e] and M.Suppressing() and type(arg2) == "string" then
		if e == "CHAT_MSG_WHISPER" or e == "CHAT_MSG_WHISPER_INFORM" or M.GetConv(arg2, false) then return end
	end
	return M.origChat(ev)
end

function M.ReplyHook(chatFrame)
	if M.on and C.Get("messages.hooksend") then
		local get = getglobal("ChatEdit_GetLastTellTarget")
		local eb = (chatFrame and chatFrame.editBox) or getglobal("ChatFrameEditBox")
		local who = get and eb and get(eb)
		if type(who) == "string" and who ~= "" and M.OpenByName(who, true) then return end
	end
	return M.origReply(chatFrame)
end

function M.SendTellHook(name)
	if M.on and C.Get("messages.hooksend") and type(name) == "string" and M.OpenByName(name, true) then return end
	return M.origSendTell(name)
end

function M.Hook()
	if not M.origChat then
		local f = getglobal("ChatFrame_OnEvent")
		if type(f) == "function" then
			M.origChat = f
			setglobal("ChatFrame_OnEvent", M.ChatHook)
		end
	end
	if not M.origReply then
		local f = getglobal("ChatFrame_ReplyTell")
		if type(f) == "function" then
			M.origReply = f
			setglobal("ChatFrame_ReplyTell", M.ReplyHook)
		end
	end
	if not M.origSendTell then
		local f = getglobal("ChatFrame_SendTell")
		if type(f) == "function" then
			M.origSendTell = f
			setglobal("ChatFrame_SendTell", M.SendTellHook)
		end
	end
end

-- ---------------------------------------------------------------- fenetre d'historique
function M.RenderHistory()
	local h = M.hwin
	if not h then return end
	local q = h.edit:GetText() or ""
	local res = M.Search(q)
	h.msgs:Clear()
	local n = getn(res)
	local first = n - HMAX + 1
	if first < 1 then first = 1 end
	local c = T.c.text
	for i = first, n do
		local r = res[i]
		local mark = r[3] == "o" and ">" or (r[3] == "i" and "<" or "*")
		h.msgs:AddMessage("|cff" .. M.dimHex .. "[" .. M.Date("%d/%m %H:%M", r[1]) .. "]|r |cff" .. M.accentHex .. r[2] .. "|r " .. mark .. " " .. r[4],
			c[1], c[2], c[3])
	end
	h.msgs:ScrollToBottom()
	setText(h.info, L("msg.messages.hist.count", n, M.hcontacts))
	M.hshown = n
end

function M.ShowHistory(q)
	if not M.on or not M.hwin then return end
	local h = M.hwin
	h.edit:SetText(q or "")
	h:Show()
	M.RenderHistory()
end

function M.BuildHistory()
	local f = T.Panel(UIParent, 440, 300)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	f.title:SetText(L("msg.messages.hist.title"))
	f.close = T.Button(f, "x", 16, 16, function() f:Hide() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	f.clear = T.Button(f, L("msg.messages.hist.clear"), 90, 16, function() M.ClearAllRequest() end)
	f.clear:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
	T.GearButton(f, "messages", { size = 16, point = "TOPRIGHT", x = -100, y = -4, title = L("msg.messages.gear"),
		onCreate = function(g)
			g:ClearAllPoints()
			g:SetPoint("RIGHT", f.clear, "LEFT", -4, 0)
		end })
	f.edit = T.Edit(f, 200, 18)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
	f.edit:SetScript("OnTextChanged", function() M.RenderHistory() end)
	f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	f.info = T.Text(f, 10, T.c.dim, "LEFT")
	f.info:SetPoint("LEFT", f.edit, "RIGHT", 8, 0)
	f.info:SetWidth(200)
	local m = CreateFrame("ScrollingMessageFrame", nil, f)
	m:SetFont(T.font, 11)
	m:SetJustifyH("LEFT")
	m:SetMaxLines(250)
	m:SetFading(false)
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", winScroll)
	m:SetScript("OnHyperlinkClick", linkClick)
	dragSrc(m, f, "messages.hist")
	dragSrc(f, f, "messages.hist")
	m:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -50)
	m:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
	f.msgs = m
	M.hwin = f
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("messages.hist", f, { label = L("msg.messages.mover.hist"), point = "CENTER", x = 0, y = 0, scale = false })
	else
		SUI.Layout.Register(f, "messages.hist", "CENTER", 0, 0)
	end
end

-- Effacement total : une premiere demande arme (10 s), la seconde dans le delai execute.
function M.ClearAllRequest()
	local now = GetTime()
	if now < M.armUntil then
		M.armUntil = 0
		local n = M.HistClear(nil)
		if M.hwin then
			T.SetButtonText(M.hwin.clear, L("msg.messages.hist.clear"))
			M.RenderHistory()
		end
		SUI.Print(L("msg.messages.cleared.all", n))
		return true
	end
	M.armUntil = now + 10
	if M.hwin then T.SetButtonText(M.hwin.clear, L("msg.messages.hist.confirm")) end
	SUI.Print(L("msg.messages.armed"))
	return false
end

-- ---------------------------------------------------------------- construction, reglages, cycle de vie
function M.Build()
	if M.anchor then return end
	M.RefreshColors()
	local a = T.Panel(UIParent, TW, 22)
	a:Hide()
	a.txt = T.Text(a, 11, T.c.dim, "CENTER")
	a.txt:SetPoint("CENTER", a, "CENTER", 0, 0)
	a.txt:SetText(L("msg.messages.mover.toasts"))
	M.anchor = a
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("messages.toasts", a, { label = L("msg.messages.mover.toasts"), point = "TOPRIGHT", x = -20, y = -200, scale = false,
			preview = function(on) if on then a:Show() else a:Hide() end end })
	else
		SUI.Layout.Register(a, "messages.toasts", "TOPRIGHT", -20, -200)
	end
	for i = 1, NTOAST do M.BuildToast(i) end
	for i = 1, NWIN do M.BuildWindow(i) end
	M.BuildBadge()
	M.BuildHistory()
	T.OnAccent(M.RefreshColors)
	M.ApplyOptions()
end

local function want(ev, cond, fn)
	if cond then SUI.On(ev, fn) else SUI.Off(ev, fn) end
end

function M.ReadWatch()
	words(C.Get("messages.keywords") or "", M.kw)
end

function M.UpdateEvents()
	local on = M.on
	want("CHAT_MSG_WHISPER", on, M.OnWhisper)
	want("CHAT_MSG_WHISPER_INFORM", on, M.OnInform)
	want("CHAT_MSG_AFK", on, M.OnAway)
	want("CHAT_MSG_DND", on, M.OnAway)
	want("PLAYER_REGEN_ENABLED", on, M.OnRegen)
	local inv = on and C.Get("messages.invites")
	want("PARTY_INVITE_REQUEST", inv, M.OnPartyInvite)
	want("GUILD_INVITE_REQUEST", inv, M.OnGuildInvite)
	want("TRADE_REQUEST", inv, M.OnTrade)
	want("DUEL_REQUESTED", inv, M.OnDuel)
	want("CHAT_MSG_CHANNEL", on and C.Get("messages.watch") and getn(M.kw) > 0, M.OnChannel)
end

function M.ApplyOptions()
	M.ReadWatch()
	M.UpdateEvents()
	if not M.anchor then return end
	if not M.on then
		M.DragStop()
		for i = 1, NWIN do
			if M.win[i] then
				M.win[i]:Hide()
				M.win[i].conv = nil
				M.win[i].min = false
			end
		end
		for _, c in pairs(M.convs) do
			c.open = false
			c.slot = nil
		end
		for i = 1, NTOAST do M.tf[i]:Hide() end
		M.badge:Hide()
		M.hwin:Hide()
		return
	end
	local max = C.Get("messages.maxwin")
	local tabs = M.C_tabs()
	if M.lastTabs ~= nil and (M.lastTabs ~= tabs or M.lastMax ~= max) then
		M.lastTabs, M.lastMax = tabs, max
		M.Reflow()
	end
	M.lastTabs, M.lastMax = tabs, max
	for i = 1, NWIN do
		local w = M.win[i]
		if w and w:IsShown() then M.RefreshWin(w) end
	end
	M.ToastLayout()
	M.UpdateBadge()
end

function M.OnKey(key, value)
	if key == nil or key == "messages.keywords" or key == "messages.watch" or key == "messages.invites" or key == "messages.mode"
		or key == "messages.maxwin" or key == "messages.badge" or key == "messages.winw" or key == "messages.winh" then
		M.ApplyOptions()
	elseif key == "messages.stamp" or key == "messages.stampfmt" then
		M.Restamp()
	elseif key == "messages.histper" or key == "messages.histtotal" or key == "messages.histdays" then
		M.HistPurge()
		M.HistTrimGlobal()
	end
	if key == "messages.toast" and not value then M.ClearToasts() end
end

-- Echelle de l'interface changee : les pastilles (hors de l'ancre) reprennent l'echelle de l'ancre tout de suite.
function M.OnScale()
	if M.anchor and SUI.Layout and SUI.Layout.Apply then SUI.Layout.Apply("messages.toasts") end
	M.ToastLayout()
end

function M.Enable()
	M.on = true
	M.Hook()
	M.HistCount()
	M.HistPurge()
	SUI.WhenSafe(M.Build)
	if not M.watching then
		M.watching = true
		C.Watch("messages.", M.OnKey)
		C.Watch("ui.scale", M.OnScale)
	end
	M.ApplyOptions()
end

function M.Disable()
	M.on = false
	M.UpdateEvents()
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	M.ClearToasts()
	if M.anchor then M.ApplyOptions() end
end

-- ---------------------------------------------------------------- commandes
function M.Command(rest)
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = trim(ssub(rest, sp + 1))
	end
	word = slower(word)
	if word == "list" then
		local n = 0
		for _, c in pairs(M.convs) do
			n = n + 1
			SUI.Print(L("msg.messages.list.line", c.name, c.unread or 0, getn(c.lines)))
		end
		if n == 0 then SUI.Print(L("msg.messages.list.none")) end
	elseif word == "open" then
		if not M.OpenByName(arg, true) then SUI.Print(L("msg.messages.open.usage")) end
	elseif word == "history" then
		M.ShowHistory(arg)
	elseif word == "clear" then
		if arg == "" then
			M.ClearToasts()
			for _, c in pairs(M.convs) do c.unread = 0 end
			M.UpdateBadge()
			SUI.Print(L("msg.messages.cleared.notif"))
		elseif slower(arg) == "all" then
			M.ClearAllRequest()
		else
			local nm = M.CleanName(arg)
			local key = nm and M.Key(nm)
			local n = key and M.HistClear(key) or 0
			local c = key and M.convs[key]
			if c then
				for i = getn(c.lines), 1, -1 do
						c.lines[i] = nil
						c.src[i] = nil
					end
				if c.open and c.slot then M.Render(M.win[c.slot]) end
			end
			SUI.Print(L("msg.messages.cleared.one", nm or arg, n))
		end
	elseif word == "watch" then
		if arg == "" then
			SUI.Print(L("msg.messages.watch.show", C.Get("messages.keywords") or ""))
		else
			if slower(arg) == "off" then arg = "" end
			C.SetBase("messages.keywords", arg)
			SUI.Print(L("msg.messages.watch.show", arg))
		end
	elseif word == "reply" then
		C.SetBase("messages.replytext", arg)
		SUI.Print(L("msg.messages.reply.set", arg))
	elseif word == "purge" then
		SUI.Print(L("msg.messages.purged", M.HistPurge()))
	else
		SUI.Print(L("msg.messages.help"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("messages", 55)

local function opt(key, typ, order, def, extra)
	local o = { key = "messages." .. key, type = typ, cat = "messages", label = "opt.messages." .. key, tip = "tip.messages." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("messages", {
	default = false,
	cost = "medium",
	options = {
		opt("toast", "bool", 10, true, { simple = true }),
		opt("sound", "bool", 20, true, { simple = true }),
		opt("badge", "bool", 30, true, { simple = true }),
		opt("autoopen", "bool", 40, true, { simple = true }),
		opt("mode", "choice", 50, "windows", { choices = { "windows", "tabs" }, simple = true }),
		opt("suppress", "bool", 60, true, { simple = true }),
		opt("combatqueue", "bool", 70, true, { simple = true }),
		opt("history", "bool", 80, true, { simple = true }),
		opt("blink", "bool", 90, true),
		opt("toastsecs", "number", 100, 10, { min = 0, max = 60, step = 1 }),
		opt("maxwin", "number", 110, 4, { min = 1, max = 8, step = 1 }),
		opt("winw", "number", 120, 320, { min = 220, max = 600, step = 10 }),
		opt("winh", "number", 130, 200, { min = 120, max = 500, step = 10 }),
		opt("focus", "bool", 140, true),
		opt("hooksend", "bool", 150, true),
		opt("openonsend", "bool", 160, true),
		opt("dragmod", "choice", 165, "shift", { choices = { "shift", "ctrl", "alt", "none", "off" }, simple = true }),
		opt("stamp", "bool", 170, true),
		opt("stampfmt", "choice", 180, "hm", { choices = { "hm", "hms" } }),
		opt("preload", "number", 190, 8, { min = 0, max = 30, step = 1 }),
		opt("histper", "number", 200, 100, { min = 20, max = 500, step = 20 }),
		opt("histtotal", "number", 210, 1500, { min = 200, max = 5000, step = 100 }),
		opt("histdays", "number", 220, 30, { min = 0, max = 365, step = 5 }),
		opt("invites", "bool", 230, true, { simple = true }),
		opt("histinvites", "bool", 240, true),
		opt("watch", "bool", 250, false),
		opt("histwatch", "bool", 260, false),
		opt("autoreply", "bool", 270, false),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : mots surveilles "a,b" et texte de la reponse d'absence.
SUI.Config.Register({ ["messages.keywords"] = "", ["messages.replytext"] = "" })

-- Equivalent pfUI : aucun module de messages prives releve dans pfUI\modules (pas de ligne Migrate.MAP).

SUI.RegisterCommand("msg", function(rest) M.Command(rest or "") end, "help.messages")
