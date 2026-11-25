-- ShikiUI Mail : courrier en masse (equivalent configurable de TurtleMail ; reecrit, aucune ligne copiee).
-- Cout declare : LIGHT. Aucun evenement hors de la boite aux lettres : MAIL_SHOW / MAIL_CLOSED seulement ; le reste (MAIL_INBOX_UPDATE,
-- MAIL_SEND_SUCCESS, UI_ERROR_MESSAGE) n'est ecoute que boite ouverte. Une seule minuterie partagee (SUI.Every, 0,3 s), allumee a l'ouverture de
-- la boite et rendue a la fermeture. Aucune table creee en combat : 50 lignes de journal et la file d'envoi (tampons paralleles) preallouees une
-- fois (SUI.WhenSafe). Le module est coupe par le mode Raid (raid = "off") : personne ne ramasse son courrier en raid.
-- RAMASSAGE : /sui mail take ou le bouton "Tout prendre" parcourt la boite, un geste par tour (argent puis objet puis, si demande, suppression
--  du courrier vide) et attend MAIL_INBOX_UPDATE (2 s au plus, 3 essais) avant de continuer. JAMAIS un courrier contre remboursement (COD) ni un
--  courrier de MJ ; arret des qu'il reste moins de mail.keepfree places libres ou que le jeu refuse (inventaire plein). Filtre : tout, hotel des
--  ventes seulement, tout sauf l'hotel des ventes, argent seulement. La suppression (mail.deleteempty, coupee) ne touche qu'un courrier VIDE, sans
--  texte ecrit par un joueur.
-- ENVOI EN MASSE : liste d'objets a envoyer (mail.sendlist, donnee du profil, /sui mail add|remove|clear) ; /sui mail send <nom> (ou le bouton)
--  envoie un courrier par pile, un a la fois, en attendant MAIL_SEND_SUCCESS ; confirmation obligatoire (mail.confirmsend) : une premiere demande
--  arme l'envoi 10 s, la seconde l'execute. Aucun argent, aucun COD.
-- DESTINATAIRES : memorise les derniers destinataires (mail.recent) et les propose en boutons.
-- JOURNAL : les 50 derniers objets / sommes ramasses (/sui mail log).
-- SOURCES (relevees dans TurtleMail installe, jamais executees ici) : GetInboxNumItems, GetInboxHeaderInfo (retours 3 expediteur, 5 argent,
--  6 COD, 8 objet, 11 texte, 13 MJ), GetInboxItem, TakeInboxMoney / TakeInboxItem / DeleteInboxItem(index), CheckInbox, ClickSendMailItemButton,
--  GetSendMailItem, SendMail(destinataire, sujet, texte), SendMailNameEditBox, MAIL_SHOW / MAIL_CLOSED / MAIL_INBOX_UPDATE / MAIL_SEND_SUCCESS,
--  hotels des ventes reconnus par "Auction House" dans le nom de l'expediteur (liste de TurtleMail).
-- ENVOI MULTIPLE (panneau, grille des sacs, Maj-clic / clic droit, file avec progression et annulation) : voir le bloc du meme nom plus bas.
--  NON VERIFIE EN JEU en plus : texte exact des erreurs du courrier (M.MailErr), noms des addons / cadres de courrier tiers (M.OTHERADDONS,
--  M.OTHERFRAMES), SetSendMailMoney, retour de la piece jointe par ClickSendMailItemButton, ContainerFrameItemButton_OnClick (Maj-clic).
-- NON VERIFIE EN JEU : tout ;la position du panneau a cote de MailFrame ; le texte exact de l'erreur d'inventaire plein ; le 2e retour de
--  GetContainerNumFreeSlots ; le delai reel du serveur entre un geste et MAIL_INBOX_UPDATE ; ClearCursor avant le depot d'une piece jointe.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind, ssub, slower, sformat = string.find, string.sub, string.lower, string.format

local M = {}
SUI.Mail = M

local MAXLOG = 50
local MAXSEND = 100
local TICK = 0.3

M.on = false
M.open = false         -- boite aux lettres ouverte
M.active = false       -- ramassage en cours
M.idx = 1
M.fail = 0
M.waitUpd = false
M.waitSince = 0
M.gold, M.items, M.mails = 0, 0, 0
M.pSender, M.pName, M.pCount, M.pMoney = nil, nil, 0, 0   -- geste en attente de la reponse du serveur
M.log = {}             -- anneau { t, sender, name, count, money }
M.lcount, M.lhead = 0, 0
M.sendList = {}        -- id d'objet -> true
M.nlist = 0
M.sb, M.ss = {}, {}    -- file d'envoi : sac, case
M.ns, M.si = 0, 1
M.sending = false
M.sent = 0
M.to = nil
M.waitSend = false
M.armed = nil          -- { to, until } : envoi arme en attente de confirmation
M.armTo, M.armUntil = nil, 0
M.dirty = true
M.lastTo = nil
M.info = { mails = 0, items = 0, money = 0 }

-- ---------------------------------------------------------------- utilitaires
local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

function M.Money(c)
	c = c or 0
	local g = math.floor(c / 10000)
	local s = math.floor((c - g * 10000) / 100)
	return sformat("%dg %ds %dc", g, s, c - g * 10000 - s * 100)
end

-- Cases libres d un sac (API 1.12 : pas de GetContainerNumFreeSlots, on compte les cases vides).
function M.BagFree(bag)
	local n = 0
	local slots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
	for s = 1, slots do
		if not GetContainerItemInfo(bag, s) then n = n + 1 end
	end
	return n
end

function M.Free()
	local n = 0
	for bag = 0, 4 do
		n = n + (M.BagFree(bag) or 0)
	end
	return n
end

function M.IsAH(sender)
	return sender ~= nil and sfind(sender, "Auction House", 1, true) ~= nil
end

local function header(i)
	local _, _, sender, _, money, cod, _, hasItem, _, _, text, _, gm = GetInboxHeaderInfo(i)
	return sender, money or 0, cod or 0, hasItem, text, gm
end

-- ---------------------------------------------------------------- journal
function M.LogAdd(sender, name, count, money)
	local e = M.log[1]
	if not e then return end
	local size = C.Get("mail.logsize")
	local h = M.lhead + 1
	if h > size then h = 1 end
	M.lhead = h
	e = M.log[h]
	e.t, e.sender, e.name, e.count, e.money = GetTime(), sender or "?", name, count or 0, money or 0
	if M.lcount < size then M.lcount = M.lcount + 1 end
end

function M.LogGet(i)
	if i < 1 or i > M.lcount then return nil end
	local size = C.Get("mail.logsize")
	local idx = M.lhead - (i - 1)
	if idx < 1 then idx = idx + size end
	return M.log[idx]
end

-- ---------------------------------------------------------------- ramassage
function M.StartCollect()
	if not M.open then SUI.Print(L("msg.mail.closed")) return false end
	if M.active then return false end
	M.active = true
	M.idx = 1
	M.fail = 0
	M.waitUpd = false
	M.gold, M.items, M.mails = 0, 0, 0
	M.Refresh()
	return true
end

function M.StopCollect(done, why)
	if not M.active then return end
	M.active = false
	M.waitUpd = false
	M.Forget()
	if why then
		SUI.Print(L("msg.mail.stopped", L("msg.mail.why." .. why)))
	end
	SUI.Print(L("msg.mail.collected", M.items, M.Money(M.gold)))
	M.dirty = true
	M.Refresh()
end

function M.Wait()
	M.waitUpd = true
	M.waitSince = GetTime()
end

-- Le serveur a repondu : le geste en attente est acquis (totaux et journal).
function M.Commit()
	if M.pSender then
		M.gold = M.gold + M.pMoney
		M.items = M.items + M.pCount
		M.LogAdd(M.pSender, M.pName, M.pCount, M.pMoney)
		M.pSender, M.pName, M.pCount, M.pMoney = nil, nil, 0, 0
	end
end

function M.Forget()
	M.pSender, M.pName, M.pCount, M.pMoney = nil, nil, 0, 0
end

-- Un geste de ramassage : retourne sans rien faire s'il faut attendre le serveur.
function M.Step()
	if M.waitUpd then
		if GetTime() - M.waitSince < 2 then return end
		M.waitUpd = false
		M.Forget()
		M.fail = M.fail + 1
		if M.fail >= 3 then
			M.fail = 0
			M.idx = M.idx + 1
		end
	end
	if M.idx > GetInboxNumItems() then
		M.StopCollect(true)
		return
	end
	local i = M.idx
	local sender, money, cod, hasItem, text, gm = header(i)
	if cod > 0 or gm then
		M.idx = i + 1
		return
	end
	local filt = C.Get("mail.filter")
	local ah = M.IsAH(sender)
	local skip = (filt == "ah" and not ah) or (filt == "noah" and ah)
	local canMoney = (not skip) and money > 0 and C.Get("mail.takemoney")
	local canItem = (not skip) and hasItem and filt ~= "money" and C.Get("mail.takeitems")
	if canMoney then
		TakeInboxMoney(i)
		M.pSender, M.pName, M.pCount, M.pMoney = sender, nil, 0, money
		M.Wait()
		return
	end
	if canItem then
		if M.Free() <= C.Get("mail.keepfree") then
			M.StopCollect(false, "full")
			return
		end
		local name, _, count = GetInboxItem(i)
		TakeInboxItem(i)
		if not M.active then return end   -- le jeu a refuse (inventaire plein) : OnError a deja tout arrete
		M.pSender, M.pName, M.pCount, M.pMoney = sender, name, count or 1, 0
		M.Wait()
		return
	end
	if (not skip) and C.Get("mail.deleteempty") and money == 0 and not hasItem and not text and filt ~= "money" then
		DeleteInboxItem(i)
		M.Wait()
		return
	end
	M.idx = i + 1
end

function M.OnInbox()
	if M.waitUpd then M.Commit() end
	M.waitUpd = false
	M.fail = 0
	M.dirty = true
end

function M.OnError(ev, msg)
	if not msg then return end
	if M.MultiOnError(msg) then return end
	if M.sending then
		M.StopSend(msg)
	elseif M.active and (sfind(slower(msg), "inventory is full", 1, true) or (getglobal("ERR_INV_FULL") and msg == getglobal("ERR_INV_FULL"))) then
		-- le texte traduit OU la globale du client (un client non-US n'ecrit pas "inventory is full")
		M.StopCollect(false, "full")
	end
end

-- ---------------------------------------------------------------- liste d'envoi et destinataires
local function listString()
	local s = ""
	for id, _ in pairs(M.sendList) do
		if s ~= "" then s = s .. "," end
		s = s .. id
	end
	return s
end

function M.ReadList()
	for k, _ in pairs(M.sendList) do M.sendList[k] = nil end
	M.nlist = 0
	local s = C.Get("mail.sendlist") or ""
	for id in string.gfind(s, "(%d+)") do
		local n = tonumber(id)
		if n and not M.sendList[n] and M.nlist < 100 then
			M.sendList[n] = true
			M.nlist = M.nlist + 1
		end
	end
end

local function idOf(ref)
	local _, _, id = sfind(ref or "", "item:(%d+)")
	if not id then _, _, id = sfind(ref or "", "^%s*(%d+)%s*$") end
	return tonumber(id)
end

function M.ListAdd(ref)
	local id = idOf(ref)
	if not id then return false end
	if not M.sendList[id] then
		if M.nlist >= 100 then return false end
		M.sendList[id] = true
		M.nlist = M.nlist + 1
	end
	C.SetBase("mail.sendlist", listString())
	return true
end

function M.ListRemove(ref)
	local id = idOf(ref)
	if not id or not M.sendList[id] then return false end
	M.sendList[id] = nil
	M.nlist = M.nlist - 1
	C.SetBase("mail.sendlist", listString())
	return true
end

function M.ListClear()
	C.SetBase("mail.sendlist", "")
end

function M.Recent()
	local out = {}
	local s = C.Get("mail.recent") or ""
	for name in string.gfind(s, "([^,]+)") do tinsert(out, name) end
	return out
end

function M.Remember(name)
	if not C.Get("mail.remember") or type(name) ~= "string" then return end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" or sfind(name, "[,|]") or string.len(name) > 24 then return end
	local list = M.Recent()
	local low = slower(name)
	local s = name
	local n = 1
	local max = C.Get("mail.maxrecent")
	for i = 1, getn(list) do
		if slower(list[i]) ~= low and n < max then
			s = s .. "," .. list[i]
			n = n + 1
		end
	end
	C.SetBase("mail.recent", s)
	M.dirty = true
end

-- ---------------------------------------------------------------- envoi en masse
function M.BuildSendQueue()
	local n = 0
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag)
		for slot = 1, size do
			local link = GetContainerItemLink(bag, slot)
			if link and n < MAXSEND then
				local id = idOf(link)
				if id and M.sendList[id] then
					n = n + 1
					M.sb[n], M.ss[n] = bag, slot
				end
			end
		end
	end
	M.ns = n
	return n
end

-- Demande d'envoi : arme (confirmation) ou execute.
function M.RequestSend(to, confirmed)
	if not M.open then SUI.Print(L("msg.mail.closed")) return false end
	if M.sending then return false end
	if type(to) ~= "string" or to == "" then SUI.Print(L("msg.mail.noto")) return false end
	if slower(to) == slower(UnitName("player") or "") then SUI.Print(L("msg.mail.self")) return false end
	local n = M.BuildSendQueue()
	if n == 0 then SUI.Print(L("msg.mail.nothing")) return false end
	if C.Get("mail.confirmsend") and not (confirmed and M.armTo == to and GetTime() < M.armUntil) then
		M.armTo = to
		M.armUntil = GetTime() + 10
		SUI.Print(L("msg.mail.arm", n, to))
		M.Refresh()
		return false
	end
	M.armTo = nil
	M.sending = true
	M.to = to
	M.si = 1
	M.sent = 0
	M.waitSend = false
	M.Refresh()
	return true
end

function M.StopSend(why)
	if not M.sending then return end
	M.sending = false
	M.waitSend = false
	ClearCursor()
	if why then SUI.Print(L("msg.mail.sendstopped", why)) end
	SUI.Print(L("msg.mail.sentdone", M.sent, M.to or "?"))
	M.Refresh()
end

function M.SendStep()
	if M.waitSend then
		if GetTime() - M.waitSince < 4 then return end
		M.waitSend = false
		M.si = M.si + 1
	end
	if M.si > M.ns then
		M.StopSend(nil)
		return
	end
	local bag, slot = M.sb[M.si], M.ss[M.si]
	ClearCursor()
	PickupContainerItem(bag, slot)
	ClickSendMailItemButton()
	local name = GetSendMailItem()
	if not name then
		ClearCursor()
		M.si = M.si + 1
		return
	end
	SendMail(M.to, name, "")
	if not M.sending then return end
	M.waitSend = true
	M.waitSince = GetTime()
end

function M.OnSendSuccess()
	if M.MultiOnSuccess() then return end
	if M.sending and M.waitSend then
		M.waitSend = false
		M.sent = M.sent + 1
		M.si = M.si + 1
		M.Remember(M.to)
	elseif M.lastTo then
		M.Remember(M.lastTo)
	end
end

-- ---------------------------------------------------------------- champs de saisie du courrier (destinataire, objet, texte, argent)
-- Le panneau ne cree AUCUN champ de saisie : on ecrit dans ceux du jeu (SendMailNameEditBox...). Ce qui pouvait les rendre inutilisables :
--  1. un cadre captant la souris AU-DESSUS d'eux (niveau perime apres la construction, comme dans Menu.SyncLevel ; ou le panneau lui-meme
--     pose a cote / sur la fenetre) : le clic n'atteint plus le champ ;
--  2. la zone vide du texte (SendMailScrollFrame) qui ne donne pas le focus au champ du texte ;
--  3. des scripts Tab / Entree / Echap absents.
-- M.SyncFields rehausse tout champ recouvert (meme strate seulement), M.WireFields pose clic-zone et scripts manquants, M.SinkPanel descend le
-- panneau sous la fenetre du courrier quand ils se recouvrent. Le tout est refait a l'ouverture, au passage sur l'onglet Envoyer, puis toutes
-- les 3 s boite ouverte ; jamais en combat. /sui maildiag montre l'etat, /sui maildiag fix force la reparation.
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local STRATA_BELOW = { BACKGROUND = "BACKGROUND", LOW = "LOW", MEDIUM = "LOW", HIGH = "MEDIUM", DIALOG = "HIGH", FULLSCREEN = "DIALOG",
	FULLSCREEN_DIALOG = "FULLSCREEN", TOOLTIP = "FULLSCREEN_DIALOG" }
M.FIELDS = { "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailBodyEditBox", "SendMailMoneyGold", "SendMailMoneySilver",
	"SendMailMoneyCopper" }
M.NEXT = { SendMailNameEditBox = "SendMailSubjectEditBox", SendMailSubjectEditBox = "SendMailBodyEditBox" }
M.fixes = 0

local function live(fr)
	return type(fr) == "table" and type(fr.GetFrameLevel) == "function" and type(fr.GetChildren) == "function"
end

local function strataOf(fr)
	local s = fr.GetFrameStrata and fr:GetFrameStrata()
	if type(s) ~= "string" or not STRATA_RANK[s] then s = "MEDIUM" end
	return s
end

local function rankOf(fr)
	return STRATA_RANK[strataOf(fr)] * 100000 + (fr:GetFrameLevel() or 0)
end

local function rectOf(fr)
	local l, b, r, t = fr:GetLeft(), fr:GetBottom(), fr:GetRight(), fr:GetTop()
	if not (l and b and r and t) then return nil end
	local s = fr:GetEffectiveScale() or 1
	return l * s, b * s, r * s, t * s
end

local function overlap(a, b)
	local al, ab, ar, at = rectOf(a)
	local bl, bb, br, bt = rectOf(b)
	if not al or not bl then return false end
	return al < br and bl < ar and ab < bt and bb < at
end

local function describe(fr)
	return tostring(fr:GetName() or "?") .. "(" .. strataOf(fr) .. " L" .. tostring(fr:GetFrameLevel()) ..
		(fr:IsMouseEnabled() and " souris" or "") .. ")"
end

-- Cadres visibles, captant la souris, plus hauts que "eb" et qui le recouvrent en son centre.
function M.Overlays(eb)
	local out = {}
	local l, b, r, t = rectOf(eb)
	if not l then return out end
	local cx, cy = (l + r) / 2, (b + t) / 2
	local mine = rankOf(eb)
	local function add(k)
		if k == eb or not live(k) then return end
		if not (k:IsShown() and k:IsMouseEnabled() and rankOf(k) > mine) then return end
		local kl, kb, kr, kt = rectOf(k)
		if not kl or cx < kl or cx > kr or cy < kb or cy > kt then return end
		for i = 1, getn(out) do
			if out[i] == k then return end
		end
		tinsert(out, k)
	end
	local function scan(parent)
		local kids = { parent:GetChildren() }
		for i = 1, getn(kids) do
			if type(kids[i]) == "table" then add(kids[i]) end
		end
	end
	scan(UIParent)
	local p = eb:GetParent()
	local depth = 0
	while live(p) and p ~= UIParent and depth < 8 do
		add(p)
		scan(p)
		p = p:GetParent()
		depth = depth + 1
	end
	return out
end

-- Vrai si fr est root ou un de ses descendants.
local function isUnder(fr, root)
	local p, depth = fr, 0
	while type(p) == "table" and depth < 12 do
		if p == root then return true end
		p = p.GetParent and p:GetParent() or nil
		depth = depth + 1
	end
	return false
end

-- Rehausse chaque champ recouvert au-dessus de ce qui le recouvre, MAIS seulement si le cadre fautif fait partie de la fenetre du courrier
-- (MailFrame et ses enfants : niveau perime) ou du panneau ShikiUI ; une autre fenetre legitimement au-dessus (assistant, autre addon) n'est
-- pas traversee : elle est seulement signalee par /sui maildiag. Meme strate uniquement. Retourne le nombre de champs corriges.
function M.SyncFields()
	local fixed = 0
	local mf = getglobal("MailFrame")
	for i = 1, getn(M.FIELDS) do
		local eb = getglobal(M.FIELDS[i])
		if live(eb) and eb:IsVisible() then
			local list = M.Overlays(eb)
			local want
			local es = strataOf(eb)
			for k = 1, getn(list) do
				if strataOf(list[k]) == es and (isUnder(list[k], mf) or isUnder(list[k], M.frame) or isUnder(eb, list[k])) then
					local lv = (list[k]:GetFrameLevel() or 0) + 1
					if not want or lv > want then want = lv end
				end
			end
			if want then
				eb:SetFrameLevel(want)
				fixed = fixed + 1
			end
		end
	end
	M.fixes = M.fixes + fixed
	return fixed
end

local function focusNext(to)
	return function()
		local e = getglobal(to)
		if e and e.SetFocus then e:SetFocus() end
	end
end

local function leaveField()
	this:ClearFocus()
end

function M.FocusBody()
	local eb = getglobal("SendMailBodyEditBox")
	if live(eb) and eb.SetFocus then
		eb:SetFocus()
		return true
	end
	return false
end

-- Marque de saisie : un cadre fin a la couleur d'accent entoure le champ qui a le clavier (le curseur du jeu disparait sur le fond du style).
local function focusMark(eb, name)
	if eb.suiMark then return end
	local host = eb
	if name == "SendMailBodyEditBox" then
		local sf = getglobal("SendMailScrollFrame")
		if live(sf) then host = sf end
	end
	local hl = CreateFrame("Frame", nil, host)
	hl:SetPoint("TOPLEFT", host, "TOPLEFT", -3, 3)
	hl:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 3, -3)
	hl:EnableMouse(false)
	hl:SetFrameLevel(host:GetFrameLevel() + 3)
	hl:Hide()
	eb.suiMark = hl
	local function paint()
		local r, g, b = SUI.Theme.Accent()
		SUI.Theme.Backdrop(hl, { 0, 0, 0, 0 }, { r, g, b, 1 })
	end
	local oldIn, oldOut = eb:GetScript("OnEditFocusGained"), eb:GetScript("OnEditFocusLost")
	eb:SetScript("OnEditFocusGained", function()
		if oldIn then oldIn() end
		paint()
		hl:Show()
	end)
	eb:SetScript("OnEditFocusLost", function()
		if oldOut then oldOut() end
		hl:Hide()
	end)
end

-- Une seule fois par champ : souris et clavier actifs, Tab / Entree vers le champ suivant, Echap quitte la saisie (seulement si le jeu n'a pas
-- deja pose le script) ; un clic dans la zone vide du texte donne le focus au champ du texte.
function M.WireFields()
	for i = 1, 3 do
		local name = M.FIELDS[i]
		local eb = getglobal(name)
		if live(eb) and not eb.suiMailWired then
			eb.suiMailWired = true
			eb:EnableMouse(true)
			eb:EnableKeyboard(true)
			focusMark(eb, name)
			local nxt = M.NEXT[name]
			if nxt then
				if not eb:GetScript("OnTabPressed") then eb:SetScript("OnTabPressed", focusNext(nxt)) end
				if not eb:GetScript("OnEnterPressed") then eb:SetScript("OnEnterPressed", focusNext(nxt)) end
			end
			if not eb:GetScript("OnEscapePressed") then eb:SetScript("OnEscapePressed", leaveField) end
		end
	end
	local sf = getglobal("SendMailScrollFrame")
	if live(sf) and not sf.suiMailWired then
		sf.suiMailWired = true
		local old = sf:GetScript("OnMouseDown")
		sf:EnableMouse(true)
		sf:SetScript("OnMouseDown", function()
			if old then old() end
			M.FocusBody()
		end)
	end
end

local function setStrata(fr, strata, seen)
	if seen[fr] then return end
	seen[fr] = true
	fr:SetFrameStrata(strata)
	local kids = { fr:GetChildren() }
	for i = 1, getn(kids) do
		if type(kids[i]) == "table" and kids[i] ~= fr then setStrata(kids[i], strata, seen) end
	end
end

-- Le panneau passe sous la fenetre du courrier quand ils se recouvrent (jamais de clic vole) ; il retrouve sa strate sinon.
function M.SinkPanel()
	if M.frame and live(getglobal("MailFrame")) and M.frame:GetParent() == getglobal("MailFrame") then return false end
	local f, mf = M.frame, getglobal("MailFrame")
	if not live(f) or not live(mf) then return false end
	local want = "MEDIUM"
	if f:IsShown() and mf:IsShown() and overlap(f, mf) then want = STRATA_BELOW[strataOf(mf)] end
	if strataOf(f) == want then return false end
	if SUI.InCombat() then return false end
	setStrata(f, want, {})
	return true
end

-- Tout reparer d'un coup (ouverture, bouton du panneau, /sui maildiag fix). Retourne le nombre de champs rehausses.
function M.RepairInput()
	if SUI.InCombat() then return 0 end
	M.WireFields()
	M.SinkPanel()
	return M.SyncFields()
end

function M.FieldsTick()
	local sf = getglobal("SendMailFrame")
	if not live(sf) then return end
	local vis = sf:IsVisible() and true or false
	M.fieldTick = (M.fieldTick or 0) + 1
	if vis and (vis ~= M.sendVis or M.fieldTick >= 10) then
		M.fieldTick = 0
		M.RepairInput()
	end
	M.sendVis = vis
end

-- Bouton du panneau : repare puis place le curseur dans le destinataire.
function M.OnRepair()
	if not M.open then SUI.Print(L("msg.mail.closed")) return false end
	local sf = getglobal("SendMailFrame")
	if not (live(sf) and sf:IsVisible()) then SUI.Print(L("msg.mail.opensend")) return false end
	local n = M.RepairInput()
	local eb = getglobal("SendMailNameEditBox")
	if live(eb) and eb.SetFocus then eb:SetFocus() end
	SUI.Print(L("msg.mail.repaired", n))
	return true
end

-- /sui maildiag : etat des fenetres du courrier et de chaque champ (qui le recouvre ?). "fix" force la reparation avant le releve.
function M.Diag(fix)
	local out = {}
	local function add(s)
		tinsert(out, s)
		SUI.Print(s)
		SUI.LogError("maildiag", s)
	end
	if fix then add(L("msg.mail.diag.fixed", M.RepairInput())) end
	add(L("msg.mail.diag.head", M.open and 1 or 0, M.on and 1 or 0, M.fixes))
	local gk = getglobal("GetCurrentKeyBoardFocus")
	local kf = type(gk) == "function" and gk() or nil
	add("saisie clavier : " .. ((kf and kf.GetName and kf:GetName()) or (kf and "cadre sans nom") or "aucun champ"))
	add("TurtleMail=" .. (getglobal("TurtleMail_To") ~= nil and "charge" or "non") .. " WIM=" .. (getglobal("WIM_Windows") ~= nil and "charge" or "non") .. " pfUI=" .. (getglobal("pfUI") ~= nil and "charge" or "non"))
	local f = M.frame
	if live(f) then add("panneau " .. describe(f) .. " visible=" .. (f:IsShown() and "1" or "0")) end
	local names = { "MailFrame", "SendMailFrame", "SendMailScrollFrame" }
	for i = 1, getn(names) do
		local fr = getglobal(names[i])
		if live(fr) then
			add(names[i] .. " " .. describe(fr) .. " visible=" .. (fr:IsVisible() and "1" or "0") .. ((fr.suiMailWired and " clic-zone") or ""))
		else
			add(names[i] .. " : absent")
		end
	end
	for i = 1, getn(M.FIELDS) do
		local eb = getglobal(M.FIELDS[i])
		if live(eb) then
			local line = M.FIELDS[i] .. " " .. describe(eb) .. " visible=" .. (eb:IsVisible() and "1" or "0")
			if eb.HasFocus then line = line .. " focus=" .. (eb:HasFocus() and "1" or "0") end
			add(line)
			local list = M.Overlays(eb)
			for k = 1, getn(list) do
				if k <= 4 then add("  AU-DESSUS : " .. describe(list[k])) end
			end
			if getn(list) == 0 then add("  " .. L("msg.mail.diag.clear")) end
		end
	end
	M.lastDiag = out
	return out
end

-- ---------------------------------------------------------------- panneau
-- Infobulle d'un bouton du panneau (garde l'effet de survol du Theme).
function M.Tip(b, key)
	local oldIn, oldOut = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oldIn then oldIn() end
		local g = getglobal("GameTooltip")
		if g then
			g:SetOwner(this, "ANCHOR_RIGHT")
			g:SetText(L(key), nil, nil, nil, nil, 1)
			g:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		if oldOut then oldOut() end
		local g = getglobal("GameTooltip")
		if g then g:Hide() end
	end)
end

function M.Count()
	local info = M.info
	info.mails, info.items, info.money = GetInboxNumItems(), 0, 0
	local n = info.mails
	if n > 50 then n = 50 end
	for i = 1, n do
		local _, money, cod, hasItem = header(i)
		if cod == 0 then
			info.money = info.money + money
			if hasItem then info.items = info.items + 1 end
		end
	end
end

function M.Refresh()
	local f = M.frame
	if not f then return end
	if M.open then M.Count() end
	local info = M.info
	if M.active then
		setText(f.status, L("msg.mail.working", M.idx, info.mails))
	elseif M.sending then
		setText(f.status, L("msg.mail.sending", M.si, M.ns))
	else
		setText(f.status, L("msg.mail.status", info.mails, info.items, M.Money(info.money)))
	end
	T.SetButtonText(f.take, M.active and L("msg.mail.btn.stop") or L("msg.mail.btn.take"))
	local arming = M.armTo and GetTime() < M.armUntil
	T.SetButtonText(f.send, arming and L("msg.mail.btn.confirm") or L("msg.mail.btn.send"))
	local recent = M.Recent()
	local max = C.Get("mail.maxrecent")
	if max > 8 then max = 8 end
	local rb = M.mp and M.mp.recent or {}
	for i = 1, 8 do
		local b = rb[i]
		if not b then
			-- panneau pas encore cree
		elseif i <= max and recent[i] then
			setText(b.label, recent[i])
			b.name = recent[i]
			b:Show()
		else
			b:Hide()
		end
	end
	M.dirty = false
end

function M.Tick()
	if not M.open then return end
	if M.armTo and GetTime() >= M.armUntil then
		M.armTo = nil
		M.dirty = true
	end
	local box = getglobal("SendMailNameEditBox")
	if box then
		local txt = box:GetText()
		if txt and txt ~= "" then
			if txt ~= M.lastTo then M.mdirty = true end     -- le destinataire affiche dans le panneau multiple suit le champ du jeu
			M.lastTo = txt
		end
	end
	if C.Get("mail.fixfields") then
		M.FieldsTick()
		if M.frame and M.frame:IsShown() and not SUI.InCombat() then M.SinkPanel() end
	end
	M.SyncBar()
	if M.active then M.Step() end
	if M.sending then M.SendStep() end
	M.Sync()
	if M.mrun then M.MultiStep() end
	if M.dirty or M.active or M.sending then M.Refresh() end
end

function M.ApplyOptions()
	local f = M.frame
	if not f then return end
	M.SyncBar()
end

-- Deplacement : Maj + glisser sur le fond du panneau (hors boutons), en plus de la poignee du mode "Deplacer l'interface".
-- Meme enregistrement que le Mover (position par mode, remise a zero), effet immediat.
function M.DragStart(f)
	if type(IsShiftKeyDown) ~= "function" or not IsShiftKeyDown() or SUI.InCombat() then return false end
	if arg1 ~= nil and arg1 ~= "LeftButton" then return false end
	f:StartMoving()
	M.dragging = true
	return true
end

function M.DragStop(f)
	if not M.dragging then return false end
	M.dragging = false
	f:StopMovingOrSizing()
	local l, b = f:GetLeft(), f:GetBottom()
	local rec = SUI.Mover and SUI.Mover.items and SUI.Mover.items["mail"]
	if l and b and rec and SUI.Mover.Commit then
		local sc = f:GetScale() or 1
		SUI.Mover.Commit(rec, l * sc, b * sc)
	elseif l and b and SUI.Layout then      -- sans Mover : memoriser quand meme (sinon Layout.Apply ramenerait le cadre en arriere)
		local sc = f:GetScale() or 1
		local _, _, s = C.GetPos(SUI.Layout.ReadKey("mail"))
		C.SetPos(SUI.Layout.WriteKey("mail"), l * sc, b * sc, s)
		SUI.Layout.Apply("mail")
	elseif SUI.Layout then
		SUI.Layout.Apply("mail")
	end
	return true
end

function M.Place(f)
	local reg = SUI.Mover and SUI.Mover.Register
	if not (reg and reg("mail", f, { label = "mod.mover.n.mail", point = "LEFT", x = 420, y = 40, scale = true })) then
		SUI.Layout.Register(f, "mail", "LEFT", 420, 40)
	end
	f:SetScript("OnMouseDown", function() M.DragStart(f) end)
	f:SetScript("OnMouseUp", function() M.DragStop(f) end)
	f:SetScript("OnHide", function() M.DragStop(f) end)
end

-- Dans la fenetre du courrier (aucune fenetre en plus) : une barre sous le titre de l'onglet Reception (etat, Tout prendre, Envoyer la liste) ;
-- l'envoi multiple est un 3e onglet "Multiple" a cote de Reception / Envoi (voir M.BuildMulti et M.BuildTab).
M.EW, M.EX, M.EY = 330, 12, -30

function M.Build()
	if M.frame then return end
	local mf = getglobal("MailFrame")
	local emb = live(mf)
	local f = CreateFrame("Frame", "ShikiUI_MailBar", emb and mf or UIParent)
	f:SetWidth(M.EW)
	f:SetHeight(42)
	f:SetFrameLevel(((emb and mf:GetFrameLevel()) or 0) + 20)
	f:Hide()
	if emb then f:SetPoint("TOPLEFT", mf, "TOPLEFT", M.EX, M.EY) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 200) end
	f.status = T.Text(f, 11, T.c.text, "LEFT")
	f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.status:SetWidth(M.EW - 24)
	f.take = T.Button(f, L("msg.mail.btn.take"), (M.EW - 6) / 2, 20, function()
		if M.active then M.StopCollect(false) else M.StartCollect() end
	end)
	f.take:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
	f.send = T.Button(f, L("msg.mail.btn.send"), (M.EW - 6) / 2, 20, function()
		local box = getglobal("SendMailNameEditBox")
		local to = box and box:GetText() or ""
		if to == "" then to = M.Recent()[1] or "" end
		M.RequestSend(to, true)
	end)
	f.send:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -18)
	-- engrenage : ouvre les reglages du module
	T.GearButton(f, "mail", { size = 16, point = "TOPRIGHT", x = 0, y = 2, title = L("msg.mail.gear") })
	M.Tip(f.take, "tip.mail.btn.take")
	M.Tip(f.send, "tip.mail.btn.send")
	M.frame = f
	for i = 1, MAXLOG do M.log[i] = { t = 0, sender = "", name = nil, count = 0, money = 0 } end
	M.ApplyOptions()
end

-- La fenetre du courrier n'existe pas toujours quand le module se construit : la barre s'y accroche a l'ouverture
function M.Embed()
	local f, mf = M.frame, getglobal("MailFrame")
	if not f or not live(mf) or f:GetParent() == mf then return end
	f:SetParent(mf)
	f:SetFrameLevel((mf:GetFrameLevel() or 0) + 20)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", mf, "TOPLEFT", M.EX, M.EY)
end

-- Vrai quand l'onglet Reception est celui qui est affiche
function M.InboxTabVisible()
	local inf = getglobal("InboxFrame")
	if live(inf) and inf.IsVisible then return inf:IsVisible() and true or false end
	return true
end

-- Montre la barre de la reception seulement boite ouverte, option allumee, onglet Reception
function M.SyncBar()
	local f = M.frame
	if not f then return end
	local want = M.open and C.Get("mail.panel") and M.InboxTabVisible() and not M.mmode
	if want and not f:IsShown() then
		f:Show()
		M.dirty = true
	elseif not want and f:IsShown() then
		f:Hide()
	end
end

-- Corps du message cache pendant l'onglet Multiple (le panneau le recouvre), rendu apres
function M.RestoreBody()
	local sf = getglobal("SendMailScrollFrame")
	if M.bodyHidden and live(sf) then sf:Show() end
	M.bodyHidden = false
end

-- Onglet "Multiple" : l'onglet Envoi reste celui du jeu (destinataire, argent), le panneau d'envoi multiple prend la place du corps du message
function M.SetMulti(on)
	if on and (not M.open or not C.Get("mail.multi") or M.OtherMail()) then return false end
	if on and not M.SendTabVisible() then
		local t2 = getglobal("MailFrameTab2")
		if live(t2) and t2.Click then t2:Click() end
	end
	M.mmode = on and true or false
	M.mdirty = true
	M.Sync()
	M.SyncBar()
	return true
end

function M.BuildTab()
	if M.tab then return M.tab end
	local mf = getglobal("MailFrame")
	if not live(mf) then return nil end
	local t2 = getglobal("MailFrameTab2")
	local b = T.Button(mf, L("msg.mail.m.tab"), 84, 24, function() M.SetMulti(not M.mmode) end)
	if live(t2) then b:SetPoint("LEFT", t2, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 180, -28) end
	-- choisir Reception ou Envoi quitte l'onglet Multiple
	for i = 1, 2 do
		local t = getglobal("MailFrameTab" .. i)
		if live(t) and not t.suiMailTab then
			t.suiMailTab = true
			local old = t:GetScript("OnClick")
			t:SetScript("OnClick", function()
				M.mmode = false
				M.Sync()
				M.SyncBar()
				if old then old() end
			end)
		end
	end
	M.tab = b
	return b
end

-- ---------------------------------------------------------------- ENVOI MULTIPLE (panneau, grille des sacs, file d'attente)
-- Un panneau a cote du panneau du module (ou de MailFrame) sur la page Envoyer : liste visuelle des objets a envoyer (icone, quantite ; un clic
-- retire), destinataire (champ du jeu SendMailNameEditBox + liste deroulante des 8 derniers), or optionnel par courrier, sujet par defaut
-- (mail.subject, sinon nom de l'objet), bouton Envoyer tout (un courrier par pile : on attend MAIL_SEND_SUCCESS ou l'erreur avant le suivant,
-- delai mail.multidelay), barre de progression, Annuler, confirmation avec recapitulatif. Un objet refuse (lie, destinataire inconnu, boite
-- pleine...) est saute et liste a la fin ; 3 erreurs de destinataire de suite arretent tout. Le panneau ne cree aucun champ de saisie.
-- AJOUT depuis les sacs : Maj-clic ou clic droit (enveloppe de ContainerFrameItemButton_OnClick, posee a l'ouverture du courrier et rendue a la
-- fermeture ; coupee si un autre addon de courrier est charge) et grille cliquable (bouton Sacs). Une seule piece jointe par courrier en 1.12.
-- Couts : rien tant que la boite est fermee (panneau cache, pas d'enveloppe, pas de minuterie propre : M.Tick l'appelle).
M.ml = {}              -- objets a envoyer : { bag, slot, id, name, tex, count, done }
M.nml = 0
M.mrun, M.mstop = false, false
M.mi, M.mtotal, M.mdone, M.msent = 1, 0, 0, 0
M.mwait, M.msince, M.mnext, M.mcons = false, 0, 0, 0
M.mto = nil
M.mskip = {}           -- lignes "nom : raison"
M.nskip = 0
M.mpage = 0
M.mdirty = true
M.mhide = false        -- ferme a la main (/sui mail multi) pour cette ouverture
M.marmTo, M.marmUntil = nil, 0
M.mreport = ""
M.hooked, M.chain = false, false
M.MAXML = 100
M.PAGE = 24
M.GOLDS = { 0, 1, 5, 10, 50, 100, 500 }
M.OTHERADDONS = { "TurtleMail", "MailManager", "SendMailPlus" }
M.OTHERFRAMES = { "TurtleMailFrame", "TurtleMailSendFrame", "TurtleMail_Frame" }

-- Objet d'une case : id, nom, icone, quantite (nil si case vide).
function M.ItemAt(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if not link then return nil end
	local id = idOf(link)
	if not id then return nil end
	local _, _, name = sfind(link, "%[(.-)%]")
	local tex, count = GetContainerItemInfo(bag, slot)
	return id, name or "?", tex, count or 1
end

function M.OtherMail()
	if M.forceHook then return false end
	local ial = getglobal("IsAddOnLoaded")
	if type(ial) == "function" then
		for i = 1, getn(M.OTHERADDONS) do
			if ial(M.OTHERADDONS[i]) then return true end
		end
	end
	return false
end

function M.MultiFind(bag, slot)
	for i = 1, M.nml do
		local e = M.ml[i]
		if not e then
			M.MultiHeal()          -- entree manquante : la liste est reparee puis la recherche reprend
			return M.MultiFind(bag, slot)
		end
		if e.bag == bag and e.slot == slot then return i end
	end
	return nil
end

-- Retire l'entree i en decalant les suivantes (compte tenu de M.nml seul : table.remove se fie a table.getn, qui se trompe si le tableau a un trou).
local function dropEntry(i)
	for j = i, M.nml - 1 do M.ml[j] = M.ml[j + 1] end
	M.ml[M.nml] = nil
	M.nml = M.nml - 1
end

-- Reconstruit la liste sans trou (securite : M.nml doit toujours designer des entrees existantes).
function M.MultiHeal()
	local k = 0
	local n = M.nml
	for i = 1, n do
		local e = M.ml[i]
		M.ml[i] = nil
		if e then k = k + 1 M.ml[k] = e end
	end
	M.nml = k
end

function M.MultiAdd(bag, slot)
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return false end
	if M.MultiFind(bag, slot) then return false end
	local id, name, tex, count = M.ItemAt(bag, slot)
	if not id then return false end
	if M.nml >= M.MAXML then SUI.Print(L("msg.mail.m.full", M.MAXML)) return false end
	M.nml = M.nml + 1
	M.ml[M.nml] = { bag = bag, slot = slot, id = id, name = name, tex = tex, count = count }
	M.marmTo = nil
	M.mdirty = true
	return true
end

function M.MultiRemove(i)
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return false end
	if i < 1 or i > M.nml then return false end
	dropEntry(i)
	M.marmTo = nil
	local last = math.floor((M.nml - 1) / M.PAGE)
	if last < 0 then last = 0 end
	if M.mpage > last then M.mpage = last end
	M.mdirty = true
	return true
end

function M.MultiToggle(bag, slot)
	local i = M.MultiFind(bag, slot)
	if i then return M.MultiRemove(i) end
	return M.MultiAdd(bag, slot)
end

function M.MultiClear()
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return false end
	for i = M.nml, 1, -1 do M.ml[i] = nil end
	M.nml = 0
	M.mpage = 0
	M.marmTo = nil
	M.mdirty = true
	return true
end

-- Ajoute (ou, si tout y est deja, retire) tous les objets d'un sac.
function M.MultiBag(bag)
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return end
	local size = GetContainerNumSlots(bag) or 0
	local all, any = true, false
	for s = 1, size do
		if M.ItemAt(bag, s) then
			any = true
			if not M.MultiFind(bag, s) then all = false end
		end
	end
	if not any then return end
	for s = 1, size do
		if M.ItemAt(bag, s) then
			local i = M.MultiFind(bag, s)
			if all then
				if i then M.MultiRemove(i) end
			elseif not i then
				M.MultiAdd(bag, s)
			end
		end
	end
end

function M.MultiGold()
	local g = C.Get("mail.multigold") or 0
	if g < 0 then g = 0 end
	return g
end

function M.MultiTo()
	local box = getglobal("SendMailNameEditBox")
	local t = (box and box.GetText and box:GetText()) or ""
	t = string.gsub(t, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	return t
end

function M.MultiSubject()
	local s = C.Get("mail.subject") or ""
	if s == "" then return nil end
	return s
end

-- Classe un message d'erreur du serveur : "player" (destinataire), "full" (boite pleine), "bound" (objet lie), "other", ou nil (sans rapport).
function M.MailErr(msg)
	if type(msg) ~= "string" then return nil end
	local m = slower(msg)
	if sfind(m, "not found", 1, true) or sfind(m, "no such", 1, true) or sfind(m, "cannot find", 1, true) or sfind(m, "unknown", 1, true)
		or sfind(m, "introuvable", 1, true) or sfind(m, "inconnu", 1, true) or sfind(m, "doesn't exist", 1, true) then
		return "player"
	end
	if sfind(m, "inventory", 1, true) or sfind(m, "inventaire", 1, true) then return nil end
	if sfind(m, "enough money", 1, true) or sfind(m, "enough gold", 1, true) or sfind(m, "pas assez", 1, true) then return "money" end
	if sfind(m, "full", 1, true) or sfind(m, "plein", 1, true) then return "full" end
	if sfind(m, "bound", 1, true) or sfind(m, "cannot mail", 1, true) or sfind(m, "can't mail", 1, true) or sfind(m, "li\195\169", 1, true) then
		return "bound"
	end
	if sfind(m, "mail", 1, true) or sfind(m, "courrier", 1, true) then return "other" end
	return nil
end

-- Retrouve l'objet d'une entree : meme case, sinon une autre case portant le meme objet et la meme quantite (les sacs ont pu bouger).
function M.MultiResolve(e)
	local id, _, _, count = M.ItemAt(e.bag, e.slot)
	if id == e.id and count == e.count then return true end
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag) or 0
		for s = 1, size do
			local id2, _, _, c2 = M.ItemAt(bag, s)
			if id2 == e.id and c2 == e.count then
				local taken = false
				for j = 1, M.nml do
					local o = M.ml[j]
					if o and o ~= e and not o.done and o.bag == bag and o.slot == s then taken = true end
				end
				if not taken then
					e.bag, e.slot = bag, s
					return true
				end
			end
		end
	end
	return false
end

-- Reprend la piece jointe restee dans le courrier (apres une erreur) et la rend au sac.
function M.MultiRelease()
	ClearCursor()
	if GetSendMailItem and GetSendMailItem() then
		ClickSendMailItemButton()
		ClearCursor()
	end
end

function M.MultiSkip(e, why)
	M.nskip = M.nskip + 1
	M.mskip[M.nskip] = L("msg.mail.m.skipline", e.name or "?", L("msg.mail.m.why." .. why))
	e.res = why
	M.mdone = M.mdone + 1
	M.mdirty = true
end

function M.MultiRecap(to)
	local names = ""
	local n = M.nml
	for i = 1, n do
		if i > 4 then
			names = names .. ", ..."
			break
		end
		local e = M.ml[i] or {}
		names = names .. (i > 1 and ", " or "") .. (e.name or "?") .. ((e.count or 1) > 1 and ("x" .. e.count) or "")
	end
	local g = M.MultiGold()
	return L("msg.mail.m.recap", n, to, g > 0 and L("msg.mail.m.recap.gold", g) or "", names)
end

-- Demande d'envoi : arme (recapitulatif) ou execute. Retourne true quand la file demarre.
function M.MultiStart(to, confirmed)
	if not M.open then SUI.Print(L("msg.mail.closed")) return false end
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return false end
	if type(to) ~= "string" or to == "" then to = M.MultiTo() end
	if to == "" then to = M.Recent()[1] or "" end
	if to == "" then SUI.Print(L("msg.mail.noto")) return false end
	if slower(to) == slower(UnitName("player") or "") then SUI.Print(L("msg.mail.self")) return false end
	if M.nml == 0 then SUI.Print(L("msg.mail.nothing")) return false end
	if C.Get("mail.confirmsend") and not (confirmed and M.marmTo == to and GetTime() < M.marmUntil) then
		M.marmTo = to
		M.marmUntil = GetTime() + 10
		M.mreport = M.MultiRecap(to)
		SUI.Print(M.mreport)
		M.mdirty = true
		return false
	end
	M.marmTo = nil
	M.mrun, M.mstop = true, false
	M.mto = to
	M.mi, M.mdone, M.msent, M.mcons = 1, 0, 0, 0
	M.mtotal = M.nml
	M.mwait = false
	M.mnext = 0
	for i = M.nskip, 1, -1 do M.mskip[i] = nil end
	M.nskip = 0
	for i = 1, M.nml do
		M.ml[i].done, M.ml[i].res = nil, nil
	end
	M.mreport = ""
	M.mdirty = true
	return true
end

-- Fin de file : retire les objets envoyes de la liste, resume dans le chat (objets sautes en dernier).
function M.MultiFinish(why)
	if not M.mrun then return end
	M.mrun, M.mwait = false, false
	M.MultiRelease()
	local setm = getglobal("SetSendMailMoney")
	if type(setm) == "function" then setm(0) end     -- l'or par courrier ne doit pas rester dans le champ du jeu
	for i = M.nml, 1, -1 do
		if M.ml[i] and M.ml[i].done then dropEntry(i) end
	end
	local last = math.floor((M.nml - 1) / M.PAGE)
	if last < 0 then last = 0 end
	if M.mpage > last then M.mpage = last end
	if why == "cancel" then
		M.mreport = L("msg.mail.m.cancelled", M.msent, M.mtotal)
	elseif why then
		M.mreport = L("msg.mail.m.aborted", L("msg.mail.m.why." .. why))
	else
		M.mreport = L("msg.mail.m.done", M.msent, M.mto or "?")
	end
	SUI.Print(M.mreport)
	if M.nskip > 0 then
		SUI.Print(L("msg.mail.m.skipped", M.nskip))
		for i = 1, M.nskip do SUI.Print(M.mskip[i]) end
	end
	M.mdirty = true
end

-- Annuler : le courrier deja parti est attendu (sa reponse arrive), puis la file s'arrete.
function M.MultiCancel()
	if not M.mrun then return end
	M.mstop = true
	if not M.mwait then M.MultiFinish("cancel") end
	M.mdirty = true
end

function M.MultiFail(e, why)
	M.mwait = false
	M.MultiRelease()
	M.MultiSkip(e, why)
	M.mi = M.mi + 1
	M.mnext = GetTime() + (C.Get("mail.multidelay") or 1)
	if why == "player" or why == "full" or why == "money" then M.mcons = M.mcons + 1 else M.mcons = 0 end
end

function M.MultiStep()
	if M.mwait then
		if GetTime() - M.msince < 8 then return end
		M.MultiFail(M.ml[M.mi], "timeout")
	end
	if M.mstop then M.MultiFinish("cancel") return end
	if M.mcons >= 3 then M.MultiFinish("errors") return end
	if GetTime() < M.mnext then return end
	while M.mi <= M.nml and M.ml[M.mi] and M.ml[M.mi].done do M.mi = M.mi + 1 end
	if M.mi > M.nml then M.MultiFinish(nil) return end
	local e = M.ml[M.mi]
	if not e then M.MultiHeal() M.MultiFinish(nil) return end
	if not M.MultiResolve(e) then
		M.MultiSkip(e, "missing")
		M.mi = M.mi + 1
		return
	end
	ClearCursor()
	PickupContainerItem(e.bag, e.slot)
	ClickSendMailItemButton()
	local name = GetSendMailItem()
	if not name then
		ClearCursor()
		M.MultiSkip(e, "locked")
		M.mi = M.mi + 1
		return
	end
	local g = M.MultiGold()
	local setm = getglobal("SetSendMailMoney")
	if type(setm) == "function" then setm(g * 10000) end   -- toujours : ne jamais joindre un montant reste dans le champ
	M.mwait = true             -- avant SendMail : une erreur peut arriver pendant l'appel
	M.msince = GetTime()
	SendMail(M.mto, M.MultiSubject() or name, "")
end

function M.MultiOnSuccess()
	if not (M.mrun and M.mwait) then return false end
	local e = M.ml[M.mi]
	M.mwait = false
	if e then e.done = true end
	M.msent = M.msent + 1
	M.mdone = M.mdone + 1
	M.mi = M.mi + 1
	M.mcons = 0
	M.mnext = GetTime() + (C.Get("mail.multidelay") or 1)
	M.Remember(M.mto)
	M.mdirty = true
	return true
end

function M.MultiOnError(msg)
	if not (M.mrun and M.mwait) then return false end
	local kind = M.MailErr(msg)
	if not kind then return false end
	M.MultiFail(M.ml[M.mi], kind)
	return true
end

-- ---------------------------------------------------------------- ajout depuis les sacs (Maj-clic / clic droit)
function M.CaptureOK()
	if not (M.open and M.mp and M.mp:IsShown() and not M.mrun) then return false end
	if not C.Get("mail.multihook") or M.OtherMail() then return false end
	return not (CursorHasItem and CursorHasItem())
end

function M.BagClick(button, ignoreShift)
	if M.hooked and M.CaptureOK() and not ignoreShift then
		local b = this
		local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
		if b and b.GetParent and b:GetParent() and (button == "RightButton" or (button == "LeftButton" and shift)) then
			M.MultiToggle(b:GetParent():GetID(), b:GetID())
			M.MultiPickRefresh()
			M.MultiRefresh()
			return
		end
	end
	return M.origClick(button, ignoreShift)
end

function M.HookOn()
	if M.hooked then return end
	M.hooked = true
	if M.chain or type(getglobal("ContainerFrameItemButton_OnClick")) ~= "function" then return end
	M.origClick = getglobal("ContainerFrameItemButton_OnClick")
	setglobal("ContainerFrameItemButton_OnClick", M.BagClick)
	M.chain = true
end

-- Rend la fonction du jeu si personne ne l'a enveloppee depuis ; sinon l'enveloppe reste en place mais ne fait que transmettre.
function M.HookOff()
	if not M.hooked then return end
	M.hooked = false
	if M.chain and getglobal("ContainerFrameItemButton_OnClick") == M.BagClick then
		setglobal("ContainerFrameItemButton_OnClick", M.origClick)
		M.chain = false
	end
end

-- ---------------------------------------------------------------- panneau et grille
function M.SendTabVisible()
	local sf = getglobal("SendMailFrame")
	if sf and sf.IsVisible then return sf:IsVisible() and true or false end
	return true
end

function M.MultiAnchorTarget()
	for i = 1, getn(M.OTHERFRAMES) do
		local o = getglobal(M.OTHERFRAMES[i])
		if type(o) == "table" and o.IsVisible and o:IsVisible() then return o, "right" end
	end
	if M.frame and M.frame:IsShown() then return M.frame, "below" end
	local mf = getglobal("MailFrame")
	if mf then return mf, "right" end
	return UIParent, "center"
end

function M.MultiPlace()
	local f = M.mp
	if not f then return end
	local mf = getglobal("MailFrame")
	local ref, how = mf, "embed"
	if not live(mf) then ref, how = UIParent, "center" end
	if M.manchor == ref and M.mhow == how and (how ~= "embed" or f:GetParent() == ref) then return end
	M.manchor, M.mhow = ref, how
	f:ClearAllPoints()
	if how == "embed" then
		if f:GetParent() ~= ref then
			f:SetParent(ref)
			f:SetFrameLevel((ref:GetFrameLevel() or 0) + 30)
		end
		f:SetPoint("TOPLEFT", ref, "TOPLEFT", 12, -95)
	else
		f:SetPoint("CENTER", ref, "CENTER", 0, 0)
	end
end

local function cellTip(b)
	local g = getglobal("GameTooltip")
	if g and b.tipText then
		g:SetOwner(b, "ANCHOR_RIGHT")
		-- vraie infobulle de l'objet (stats, effets, prix...) quand il est encore dans cette case du sac ; sinon son nom seul
		if b.tipBag and b.tipSlot and g.SetBagItem and GetContainerItemLink(b.tipBag, b.tipSlot) then
			g:SetBagItem(b.tipBag, b.tipSlot)
		else
			g:SetText(b.tipText, nil, nil, nil, nil, 1)
		end
		g:Show()
	end
end

local function cellOut()
	local g = getglobal("GameTooltip")
	if g then g:Hide() end
end

local function makeCell(parent, size)
	local b = T.Button(parent, "", size, size, nil)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	if b.icon.SetTexCoord then b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	b.cnt = T.Text(b, 9, T.c.text, "RIGHT", true)
	b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b:SetScript("OnEnter", function() cellTip(this) end)
	b:SetScript("OnLeave", function() cellOut() end)
	return b
end

-- ---------------------------------------------------------------- grille des sacs : categories
-- Les objets de la grille sont classes (ressources, consommables, equipement, quete, autres), regroupes par sous-type du client
-- (Herbes, Metal et pierre, Tissu, Potions...), un titre par groupe ; un clic sur un titre ajoute / retire tout le groupe.
M.PKGROUPS = { "res", "consum", "equip", "quest", "other" }
M.PKORDER = { res = 1, consum = 2, equip = 3, quest = 4, other = 5 }
M.PKCOLS, M.PKCS, M.PKTOP, M.PKH, M.PKHEAD = 10, 24, 50, 400, 18
M.pkFilter = "all"
local PKTRADE = { "trade", "marchandise", "reagent", "composant", "recipe", "recette", "gem" }

-- Groupe et sous-groupe d'un objet d'apres GetItemInfo (type / sous-type du client, FR ou EN). Mis en cache une fois l'objet connu.
function M.PickGroup(id)
	M.pkInfo = M.pkInfo or {}
	local c = M.pkInfo[id]
	if c then return c[1], c[2] end
	local gi = getglobal("GetItemInfo")
	if type(gi) ~= "function" then return "other", "" end
	local nm, _, q, _, tyo, st, _, eq = gi(id)
	if not nm then return "other", "" end
	local ty = slower(tyo or "")
	local g, sub = "other", tyo or ""
	if ty == "quest" or sfind(ty, "^qu.-te$") then
		g, sub = "quest", ""
	elseif q == 0 then
		g, sub = "other", "@junk"
	elseif ty == "consumable" or ty == "consommable" then
		g, sub = "consum", st or ""
	else
		local trade = sfind(ty, "^r.-actif$") and true or false
		for i = 1, getn(PKTRADE) do
			if sfind(ty, PKTRADE[i], 1, true) then trade = true end
		end
		if trade then
			g = "res"
			if sfind(ty, "trade", 1, true) or sfind(ty, "marchandise", 1, true) then sub = st or "" end
		elseif (eq and eq ~= "" and eq ~= "INVTYPE_BAG" and eq ~= "INVTYPE_AMMO" and eq ~= "INVTYPE_QUIVER")
			or ty == "weapon" or ty == "armor" or ty == "arme" or ty == "armure" then
			g = "equip"
		end
	end
	M.pkInfo[id] = { g, sub }
	return g, sub
end

function M.PickCmp(a, b)
	if a.gi ~= b.gi then return a.gi < b.gi end
	if a.sub ~= b.sub then return a.sub < b.sub end
	if a.name ~= b.name then return a.name < b.name end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

-- Objets des sacs 0 a 4 passant le filtre, tries par groupe / sous-groupe / nom.
function M.PickList()
	local out, n = {}, 0
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag) or 0
		for s = 1, size do
			local id, name, tex, count = M.ItemAt(bag, s)
			if id then
				local g, sub = M.PickGroup(id)
				if M.pkFilter == "all" or M.pkFilter == g then
					n = n + 1
					out[n] = { bag = bag, slot = s, id = id, name = name, tex = tex, count = count, g = g, sub = sub, gi = M.PKORDER[g] or 9 }
				end
			end
		end
	end
	table.sort(out, M.PickCmp)
	return out, n
end

-- Clic sur un titre : tout le groupe est ajoute, ou retire s'il y est deja en entier.
function M.PickGroupToggle(list, i1, i2)
	if M.mrun then SUI.Print(L("msg.mail.m.busy")) return end
	local all = true
	for k = i1, i2 do
		if not M.MultiFind(list[k].bag, list[k].slot) then all = false end
	end
	for k = i1, i2 do
		local e = list[k]
		local ix = M.MultiFind(e.bag, e.slot)
		if all then
			if ix then M.MultiRemove(ix) end
		elseif not ix then
			M.MultiAdd(e.bag, e.slot)
		end
	end
end

function M.PickHeadText(g, sub, n)
	local t = L("msg.mail.pk." .. g)
	if sub == "@junk" then t = t .. " : " .. L("msg.mail.pk.junk")
	elseif sub ~= "" then t = t .. " : " .. sub end
	return t .. " (" .. n .. ")"
end

function M.MultiPickRefresh()
	local f = M.pk
	if not f or not f:IsShown() then return end
	for i = 1, getn(M.PKGROUPS) + 1 do
		local fb = f.filters[i]
		if fb then T.SetSelected(fb, fb.fkey == M.pkFilter) end
	end
	local list, total = M.PickList()
	local COLS, CS, TOP, MAXH = M.PKCOLS, M.PKCS, M.PKTOP, M.PKH
	local used, col, hn, cn, over = 0, 0, 0, 0, 0
	local i = 1
	local stop = false
	while i <= total and not stop do
		local e = list[i]
		local j = i
		while j < total and list[j + 1].g == e.g and list[j + 1].sub == e.sub do j = j + 1 end
		if col > 0 then used = used + CS + 2 col = 0 end
		local h = f.heads[hn + 1]
		if not h or used + M.PKHEAD + CS + 2 > MAXH then
			over = total - i + 1
			break
		end
		hn = hn + 1
		h.list, h.i1, h.i2 = list, i, j
		setText(h.label, M.PickHeadText(e.g, e.sub, j - i + 1))
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(TOP + used))
		local allsel = true
		for k = i, j do
			if not M.MultiFind(list[k].bag, list[k].slot) then allsel = false end
		end
		T.SetSelected(h, allsel)
		h:Show()
		used = used + M.PKHEAD
		local k = i
		while k <= j do
			if col == 0 and used + CS + 2 > MAXH then
				over = total - k + 1
				stop = true
				break
			end
			cn = cn + 1
			local b = f.cells[cn]
			if not b then over = total - k + 1 stop = true cn = cn - 1 break end
			local c = list[k]
			b.bag, b.slot = c.bag, c.slot
			b.icon:SetTexture(c.tex)
			setText(b.cnt, c.count > 1 and tostring(c.count) or "")
			b.tipText = c.name
			b.tipBag, b.tipSlot = c.bag, c.slot
			T.SetSelected(b, M.MultiFind(c.bag, c.slot) ~= nil)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + col * (CS + 2), -(TOP + used))
			b:Show()
			col = col + 1
			if col == COLS then used = used + CS + 2 col = 0 end
			k = k + 1
		end
		i = j + 1
	end
	for k = cn + 1, getn(f.cells) do f.cells[k]:Hide() end
	for k = hn + 1, getn(f.heads) do f.heads[k]:Hide() end
	setText(f.more, over > 0 and L("msg.mail.pk.more", over) or "")
end

function M.BuildPicker()
	if M.pk then return M.pk end
	local COLS, CS, TOP, MAXH = M.PKCOLS, M.PKCS, M.PKTOP, M.PKH
	local f = T.Panel(M.mp, COLS * (CS + 2) + 14, TOP + MAXH + 22)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:SetPoint("TOPLEFT", M.mp, "TOPRIGHT", 4, 0)
	f:Hide()
	f.cells = {}
	f.bags = {}
	f.filters = {}
	f.heads = {}
	for i = 0, 4 do
		local b = T.Button(f, "B" .. i, 36, 18, function(btn)
			M.MultiBag(btn.bagIdx)
			M.MultiPickRefresh()
		end)
		b.bagIdx = i
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + i * 38, -6)
		f.bags[i + 1] = b
	end
	-- filtres par categorie
	local keys = { "all", "res", "consum", "equip", "quest", "other" }
	for i = 1, getn(keys) do
		local b = T.Button(f, L("msg.mail.pk.f." .. keys[i]), 42, 18, function(btn)
			M.pkFilter = btn.fkey
			M.MultiPickRefresh()
		end)
		b.fkey = keys[i]
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (i - 1) * 43, -28)
		f.filters[i] = b
	end
	-- titres de groupe (cliquables)
	for i = 1, 16 do
		local h = T.Button(f, "", COLS * (CS + 2) - 2, 16, function(btn)
			if btn.list then
				M.PickGroupToggle(btn.list, btn.i1, btn.i2)
				M.MultiPickRefresh()
			end
		end)
		h.label:ClearAllPoints()
		h.label:SetPoint("LEFT", h, "LEFT", 4, 0)
		h.label:SetJustifyH("LEFT")
		h:Hide()
		f.heads[i] = h
	end
	for i = 1, COLS * math.floor(MAXH / (CS + 2)) do
		local b = makeCell(f, CS)
		b.onclick = function(btn)
			if btn.bag then
				M.MultiToggle(btn.bag, btn.slot)
				M.MultiPickRefresh()
			end
		end
		b:Hide()
		f.cells[i] = b
	end
	f.hint = T.Text(f, 9, T.c.dim, "LEFT")
	f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
	setText(f.hint, L("msg.mail.pk.hint"))
	f.more = T.Text(f, 9, T.c.dim, "RIGHT")
	f.more:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
	M.pk = f
	return f
end

function M.MultiPick()
	if not M.mp then return end
	-- par defaut : ce sont TES sacs (Maj-clic / clic droit), pas une seconde grille ; la grille reste en option
	if not C.Get("mail.multigrid") then
		if M.pk and M.pk:IsShown() then M.pk:Hide() end
		local ib, oa = getglobal("IsBagOpen"), getglobal("OpenAllBags")
		if type(oa) == "function" and not (type(ib) == "function" and ib(0)) then pcall(oa, true) end
		return
	end
	local f = M.BuildPicker()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
		M.MultiPickRefresh()
	end
end

function M.MultiDrop()
	local d = M.mp and M.mp.drop
	if not d then return end
	if d:IsShown() then d:Hide() return end
	local list = M.Recent()
	local n = 0
	for i = 1, 8 do
		local b = d.items[i]
		if list[i] then
			n = n + 1
			setText(b.label, list[i])
			b.name = list[i]
			b:Show()
		else
			b:Hide()
		end
	end
	if n == 0 then return end
	d:SetHeight(n * 18 + 6)
	d:Show()
end

function M.MultiPickName(name)
	local box = getglobal("SendMailNameEditBox")
	if box and box.SetText and name then box:SetText(name) end
	if M.mp and M.mp.drop then M.mp.drop:Hide() end
	M.mdirty = true
end

function M.MultiCycleGold()
	local cur = M.MultiGold()
	local nxt = M.GOLDS[1]
	for i = 1, getn(M.GOLDS) do
		if M.GOLDS[i] > cur then
			nxt = M.GOLDS[i]
			break
		end
	end
	C.Set("mail.multigold", nxt)
	M.marmTo = nil
	M.mdirty = true
end

function M.MultiSendClick()
	local to = M.MultiTo()
	M.MultiStart(to, true)
	M.MultiRefresh()
end

function M.BuildMulti()
	if M.mp then return M.mp end
	local W0, H0, CS = 330, 272, 24
	local mf = getglobal("MailFrame")
	local emb = live(mf)
	local f = T.Panel(emb and mf or UIParent, W0, H0)
	if emb then f:SetFrameLevel((mf:GetFrameLevel() or 0) + 30) else f:SetFrameStrata("MEDIUM") end
	f:EnableMouse(true)
	f:Hide()
	f.title = T.Text(f, 11, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
	f.title:SetWidth(250)
	f.prev = T.Button(f, "<", 20, 16, function() if M.mpage > 0 then M.mpage = M.mpage - 1 M.mdirty = true end end)
	f.prev:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
	f.next = T.Button(f, ">", 20, 16, function()
		if (M.mpage + 1) * M.PAGE < M.nml then M.mpage = M.mpage + 1 M.mdirty = true end
	end)
	f.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
	f.cells = {}
	for i = 1, M.PAGE do
		local r = math.floor((i - 1) / 12)
		local c = i - 1 - r * 12
		local b = makeCell(f, CS)
		b.idx = i
		b.onclick = function(btn)
			local ix = M.mpage * M.PAGE + btn.idx
			if ix <= M.nml then M.MultiRemove(ix) M.MultiRefresh() M.MultiPickRefresh() end
		end
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + c * (CS + 2), -26 - r * (CS + 2))
		f.cells[i] = b
	end
	f.empty = T.Text(f, 10, T.c.dim or T.c.text, "CENTER")
	f.empty:SetPoint("TOP", f, "TOP", 0, -50)
	f.empty:SetWidth(300)
	-- destinataire : le champ du jeu reste la source ; ce bouton lui donne le focus, la fleche ouvre les derniers destinataires
	f.to = T.Button(f, "", 282, 18, function()
		local box = getglobal("SendMailNameEditBox")
		if box and box.SetFocus then box:SetFocus() end
	end)
	f.to.label:SetWidth(275)
	f.to:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -92)
	f.dropb = T.Button(f, "v", 28, 18, function() M.MultiDrop() end)
	f.dropb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -92)
	f.drop = T.Panel(f, 130, 150)
	f.drop:SetFrameStrata("HIGH")
	f.drop:SetPoint("TOPLEFT", f.dropb, "BOTTOMRIGHT", -130, -2)
	f.drop:Hide()
	f.drop.items = {}
	for i = 1, 8 do
		local b = T.Button(f.drop, "", 122, 16, function(btn) M.MultiPickName(btn.name) end)
		b.label:SetWidth(116)
		b:SetPoint("TOPLEFT", f.drop, "TOPLEFT", 4, -3 - (i - 1) * 18)
		f.drop.items[i] = b
	end
	-- derniers destinataires : un clic pose le nom dans le champ du jeu
	f.recent = {}
	for i = 1, 8 do
		local b = T.Button(f, "", 72, 16, function(btn)
			local box = getglobal("SendMailNameEditBox")
			if box and btn.name then box:SetText(btn.name) end
			M.mdirty = true
			local sj = getglobal("SendMailSubjectEditBox")
			if not M.mmode and live(sj) and sj.SetFocus then sj:SetFocus() end      -- destinataire pose : on passe a l'objet
		end)
		b.label:SetWidth(68)
		local r = math.floor((i - 1) / 4)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1 - r * 4) * 74, -116 - r * 18)
		f.recent[i] = b
	end
	f.gold = T.Button(f, "", 150, 20, function() M.MultiCycleGold() M.MultiRefresh() end)
	f.gold:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -158)
	f.pick = T.Button(f, L("msg.mail.m.pick"), 150, 20, function() M.MultiPick() end)
	f.pick:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -158)
	f.clear = T.Button(f, L("msg.mail.m.clear"), 90, 20, function() M.MultiClear() M.MultiRefresh() M.MultiPickRefresh() end)
	f.clear:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -184)
	f.cancel = T.Button(f, L("msg.mail.m.cancel"), 90, 20, function() M.MultiCancel() M.MultiRefresh() end)
	f.cancel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -184)
	f.all = T.Button(f, L("msg.mail.m.sendall"), 189, 20, function() M.MultiSendClick() end)
	f.all:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -184)
	f.bar = T.Bar(f)
	f.bar:SetWidth(314)
	f.bar:SetHeight(12)
	f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -212)
	f.bar:SetMinMaxValues(0, 1)
	f.bar:SetValue(0)
	f.prog = T.Text(f.bar, 10, T.c.text, "CENTER")
	f.prog:SetPoint("CENTER", f.bar, "CENTER", 0, 0)
	f.report = T.Text(f, 10, T.c.text, "LEFT")
	f.report:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -230)
	f.report:SetWidth(314)
	-- Aide a la saisie : repare les champs du courrier (voir M.RepairInput) et place le curseur dans le destinataire.
	f.fix = T.Button(f, L("msg.mail.btn.fix"), 314, 18, function() M.OnRepair() end)
	f.fix:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	M.Tip(f.fix, "tip.mail.btn.fix")
	M.Tip(f.pick, "tip.mail.m.pick")
	M.Tip(f.dropb, "tip.mail.m.drop")
	M.Tip(f.gold, "tip.mail.m.gold")
	M.Tip(f.all, "tip.mail.m.sendall")
	M.Tip(f.cancel, "tip.mail.m.cancel")
	f:SetScript("OnHide", function()
		if M.pk then M.pk:Hide() end
		f.drop:Hide()
	end)
	M.mp = f
	M.manchor = nil
	return f
end

function M.MultiRefresh()
	local f = M.mp
	if not f or not f:IsShown() then return end
	local n = M.nml
	setText(f.title, L("msg.mail.m.title") .. "  " .. L("msg.mail.m.count", n))
	local base = M.mpage * M.PAGE
	for i = 1, M.PAGE do
		local b = f.cells[i]
		local e = M.ml[base + i]
		if e then
			b.icon:SetTexture(e.tex)
			setText(b.cnt, e.count > 1 and tostring(e.count) or "")
			b.tipText = e.name
			b.tipBag, b.tipSlot = nil, nil
			if not e.done and e.bag and e.slot and M.ItemAt(e.bag, e.slot) == e.id then b.tipBag, b.tipSlot = e.bag, e.slot end
			b:SetAlpha(e.done and 0.4 or 1)
			b:Show()
		else
			b:Hide()
		end
	end
	if n > M.PAGE then
		f.prev:Show()
		f.next:Show()
	else
		f.prev:Hide()
		f.next:Hide()
	end
	if n == 0 then
		setText(f.empty, M.OtherMail() and L("msg.mail.m.nohook") or L("msg.mail.m.empty"))
		f.empty:Show()
	else
		f.empty:Hide()
	end
	local to = M.MultiTo()
	setText(f.to.label, to ~= "" and L("msg.mail.m.to", to) or L("msg.mail.m.to.none"))
	local g = M.MultiGold()
	setText(f.gold.label, g > 0 and L("msg.mail.m.gold", g) or L("msg.mail.m.gold.off"))
	local arming = M.marmTo and GetTime() < M.marmUntil
	setText(f.all.label, arming and L("msg.mail.m.confirm") or L("msg.mail.m.sendall"))
	f.all.disabled = M.mrun and true or false
	if M.mrun then
		f.clear:Hide()
		f.cancel:Show()
		setText(f.cancel.label, M.mstop and L("msg.mail.m.canceling") or L("msg.mail.m.cancel"))
		f.bar:SetValue(M.mtotal > 0 and (M.mdone / M.mtotal) or 0)
		setText(f.prog, L("msg.mail.m.progress", M.mdone, M.mtotal))
	else
		f.clear:Show()
		f.cancel:Hide()
		f.bar:SetValue(0)
		setText(f.prog, "")
	end
	local rep = M.mreport
	if not M.mrun and M.nskip > 0 and not arming then rep = rep .. " " .. L("msg.mail.m.skipped", M.nskip) end
	setText(f.report, rep)
	M.mdirty = false
end

-- Appelee par M.Tick (boite ouverte seulement) : montre / cache le panneau, le remet a cote, rafraichit.
function M.Sync()
	local want = M.open and C.Get("mail.multi") and M.mmode and (M.mrun or M.SendTabVisible()) and true or false
	-- le corps du message est cache tant que l'onglet Multiple est affiche
	local sf = getglobal("SendMailScrollFrame")
	if want and M.SendTabVisible() and live(sf) and not M.bodyHidden then
		M.bodyHidden = true
		sf:Hide()
	elseif not want and M.bodyHidden then
		M.RestoreBody()
	end
	if M.tab then
		T.SetSelected(M.tab, want)
		if M.open and C.Get("mail.multi") and not M.OtherMail() then M.tab:Show() else M.tab:Hide() end
	end
	local f = M.mp
	if want and not f and not SUI.InCombat() then f = M.BuildMulti() end
	if not f then return end
	if want then
		M.MultiPlace()
		if not f:IsShown() then
			f:Show()
			M.mdirty = true
		end
		if not M.mfilled then
			M.mfilled = true
			local box = getglobal("SendMailNameEditBox")
			if box and box.GetText and box:GetText() == "" and M.Recent()[1] then box:SetText(M.Recent()[1]) end
		end
		if M.marmTo and GetTime() >= M.marmUntil then
			M.marmTo = nil
			M.mdirty = true
		end
		if M.mdirty or M.mrun then M.MultiRefresh() end
	elseif f:IsShown() then
		f:Hide()
	end
end

-- ---------------------------------------------------------------- evenements et cycle de vie
function M.OnShow()
	M.open = true
	M.dirty = true
	M.lastTo = nil
	M.armTo = nil
	SUI.On("MAIL_INBOX_UPDATE", M.OnInbox)
	SUI.On("MAIL_SEND_SUCCESS", M.OnSendSuccess)
	SUI.On("UI_ERROR_MESSAGE", M.OnError)
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(TICK, M.Tick, "mail.tick")
	M.sendVis, M.fieldTick = nil, 10
	M.mhide, M.mfilled, M.marmTo = false, false, nil
	M.mmode = false
	M.mpage = 0
	M.Embed()
	if not SUI.InCombat() then M.BuildTab() end
	M.HookOn()
	M.ApplyOptions()
	M.Refresh()
	if C.Get("mail.fixfields") then
		-- les fenetres du courrier prennent leur niveau definitif apres MAIL_SHOW : on repare juste apres, hors combat
		SUI.After(0.3, function()
			if M.open and M.on and not SUI.InCombat() then M.RepairInput() end
		end, "mail.fix")
	end
	if C.Get("mail.autotake") then
		SUI.After(1, function()
			if M.open and M.on then M.StartCollect() end
		end, "mail.auto")
	end
end

function M.OnClose()
	M.open = false
	M.Release()
	if M.frame then M.frame:Hide() end
end

-- Rend minuterie et evenements ecoutes boite ouverte ; arrete tout travail en cours.
function M.Release()
	if M.mrun then
		M.mstop, M.mwait = true, false
		M.MultiFinish("cancel")
	end
	M.HookOff()
	M.marmTo = nil
	M.mmode = false
	M.RestoreBody()
	if M.tab then M.tab:Hide() end
	if M.mp then M.mp:Hide() end
	M.active = false
	M.sending = false
	M.waitSend = false
	M.waitUpd = false
	M.armTo = nil
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("MAIL_INBOX_UPDATE", M.OnInbox)
	SUI.Off("MAIL_SEND_SUCCESS", M.OnSendSuccess)
	SUI.Off("UI_ERROR_MESSAGE", M.OnError)
end

function M.OnKey(key, value)
	if key == nil or key == "mail.sendlist" then M.ReadList() end
	if key == nil or key == "mail.logsize" then
		local size = C.Get("mail.logsize")
		if M.lcount > size then M.lcount = size end
		if M.lhead > size then
			M.lhead = 0
			M.lcount = 0
		end
	end
	M.ApplyOptions()
	M.dirty = true
end

function M.Enable()
	M.on = true
	M.ReadList()
	SUI.WhenSafe(M.Build)
	SUI.On("MAIL_SHOW", M.OnShow)
	SUI.On("MAIL_CLOSED", M.OnClose)
	if not M.watching then
		M.watching = true
		C.Watch("mail.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("MAIL_SHOW", M.OnShow)
	SUI.Off("MAIL_CLOSED", M.OnClose)
	M.open = false
	M.Release()
	if M.frame then M.frame:Hide() end
end

-- /sui mail multi [clear|send <nom> [ok]|ok|cancel|hook] : ouvre / ferme le panneau ; clear vide la liste ; send arme (puis ok confirme) l'envoi.
function M.MultiCommand(arg)
	local w, rest = arg, ""
	local sp = sfind(arg, " ", 1, true)
	if sp then
		w = ssub(arg, 1, sp - 1)
		rest = ssub(arg, sp + 1)
	end
	w = slower(w)
	if w == "clear" then
		M.MultiClear()
	elseif w == "send" then
		local to, confirmed = rest, false
		local _, _, a, b = sfind(rest, "^(%S+)%s+(%S+)$")
		if a and slower(b) == "ok" then to, confirmed = a, true end
		M.MultiStart(to, confirmed)
	elseif w == "ok" then
		M.MultiStart(M.marmTo or "", true)
	elseif w == "cancel" then
		M.MultiCancel()
	elseif w == "hook" then
		M.forceHook = not M.forceHook
	else
		if not M.open then SUI.Print(L("msg.mail.closed")) return end
		M.SetMulti(not M.mmode)
		SUI.Print(L("msg.mail.m.shown", M.mmode and L("msg.mail.m.on") or L("msg.mail.m.off")))
	end
end

-- ---------------------------------------------------------------- commandes
function M.Command(rest)
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = ssub(rest, sp + 1)
	end
	word = slower(word)
	if word == "take" then
		M.StartCollect()
	elseif word == "diag" then
		M.Diag(slower(arg) == "fix")
	elseif word == "stop" then
		M.StopCollect(false)
		M.StopSend(nil)
		M.MultiCancel()
	elseif word == "multi" then
		M.MultiCommand(arg)
	elseif word == "subject" then
		local t = string.gsub(arg, "^%s+", "")
		t = string.gsub(t, "%s+$", "")
		if string.len(t) > 64 then t = ssub(t, 1, 64) end
		C.SetBase("mail.subject", t)
		SUI.Print(L("msg.mail.m.subject", t ~= "" and t or L("msg.mail.m.subject.none")))
	elseif word == "add" then
		if M.ListAdd(arg) then SUI.Print(L("msg.mail.added", M.nlist)) else SUI.Print(L("msg.mail.badref")) end
	elseif word == "remove" then
		if M.ListRemove(arg) then SUI.Print(L("msg.mail.removed", M.nlist)) else SUI.Print(L("msg.mail.badref")) end
	elseif word == "clear" then
		M.ListClear()
		SUI.Print(L("msg.mail.cleared"))
	elseif word == "list" then
		if M.nlist == 0 then SUI.Print(L("msg.mail.list.none")) end
		for id, _ in pairs(M.sendList) do SUI.Print(L("msg.mail.list.line", id)) end
	elseif word == "send" then
		local to, confirmed = arg, false
		local _, _, a, b = sfind(arg, "^(%S+)%s+(%S+)$")
		if a and slower(b) == "ok" then to, confirmed = a, true end
		M.RequestSend(to, confirmed)
	elseif word == "log" then
		local n = tonumber(arg) or 10
		if M.lcount == 0 then SUI.Print(L("msg.mail.log.none")) end
		for i = 1, n do
			local e = M.LogGet(i)
			if not e then break end
			if e.money > 0 then
				SUI.Print(L("msg.mail.log.money", e.sender, M.Money(e.money)))
			else
				SUI.Print(L("msg.mail.log.item", e.sender, e.name or "?", e.count))
			end
		end
	else
		SUI.Print(L("msg.mail.help", M.open and 1 or 0, M.nlist))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("mail", 33)

local function opt(key, typ, order, def, extra)
	local o = { key = "mail." .. key, type = typ, cat = "mail", label = "opt.mail." .. key, tip = "tip.mail." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("mail", {
	default = false,
	cost = "light",
	raid = "off",
	options = {
		opt("panel", "bool", 10, true, { simple = true }),
		opt("fixfields", "bool", 15, true, { simple = true }),
		opt("takemoney", "bool", 20, true, { simple = true }),
		opt("takeitems", "bool", 30, true, { simple = true }),
		opt("filter", "choice", 40, "all", { choices = { "all", "ah", "noah", "money" }, simple = true }),
		opt("autotake", "bool", 50, false, { simple = true }),
		opt("keepfree", "number", 60, 0, { min = 0, max = 20, step = 1 }),
		opt("deleteempty", "bool", 70, false),
		opt("confirmsend", "bool", 80, true, { simple = true }),
		opt("remember", "bool", 90, true),
		opt("maxrecent", "number", 100, 4, { min = 1, max = 8, step = 1 }),
		opt("multi", "bool", 105, true, { simple = true }),
		opt("multihook", "bool", 106, true),
		opt("multigrid", "bool", 107, false),
		opt("multigold", "number", 107, 0, { min = 0, max = 1000, step = 1 }),
		opt("multidelay", "number", 108, 1, { min = 1, max = 5, step = 1 }),
		opt("logsize", "number", 110, 30, { min = 10, max = 50, step = 10 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : liste d'envoi "id,id" et derniers destinataires "Nom,Nom".
SUI.Config.Register({ ["mail.sendlist"] = "", ["mail.recent"] = "", ["mail.subject"] = "" })

-- Equivalent pfUI : aucun module de courrier releve dans pfUI\modules (pas de ligne Migrate.MAP).

SUI.RegisterCommand("mail", function(rest) M.Command(rest or "") end, "help.mail")

-- /sui maildiag [fix] : pourquoi on ne peut pas ecrire dans le courrier (qui recouvre chaque champ) ; "fix" repare tout de suite.
SUI.RegisterCommand("maildiag", function(rest)
	local _, _, w = sfind(rest or "", "^%s*(%S*)")
	M.Diag(slower(w or "") == "fix")
end, "help.mail.diag")
