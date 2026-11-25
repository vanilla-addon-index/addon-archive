-- ShikiUI Tracker : verrouillages d'instances / raids (tous les personnages), limite horaire de donjons, et suivi de l'or
-- (session, jour, personnage, compte ; sources ventilees ; historique ; graphe ; objets de valeur). Module neuf, aucune ligne copiee.
-- Cout declare : LIGHT. Une seule minuterie partagee (SUI.Every, 1 s, doublee en mode urgence) ; les evenements sont ceux d'un compteur :
-- PLAYER_MONEY, CHAT_MSG_MONEY, CHAT_MSG_LOOT, MERCHANT_*, MAIL_*, AUCTION_HOUSE_*, TRADE_*, QUEST_COMPLETE / QUEST_FINISHED,
-- PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, UPDATE_INSTANCE_INFO. Un module desactive ne coute rien (tout est rendu).
-- DONNEES : ShikiUIDB.global.tracker["Nom-Royaume"] (via SUI.Config.GetGlobal / SetGlobal, jamais de fonction ni de frame) =
--  { name, seen, money, tg, tl (cumul gagne / perdu), lock = { { n = instance, id, at = heure absolue de reset } }, lockAt,
--    ent = { heures d'entree en donjon }, entz = { noms }, days = { ["AAAA-MM-JJ"] = { g, l, s = { source = net } } } }.
--  Le dernier etat vu de chaque personnage est donc conserve ; /sui tracker forget <Nom-Royaume> en oublie un. La session est en memoire.
-- SOURCES DE L'OR (net signe par source) : loot (CHAT_MSG_MONEY), vendor (marchand ouvert, gain), repair (marchand ouvert, le cout de
--  GetRepairAllCost baisse ou egale la depense), quest (QUEST_COMPLETE ... QUEST_FINISHED + 3 s), ah (hotel des ventes ouvert ; les gains de
--  vente arrivent par courrier : ils comptent sous "mail"), mail (boite ouverte, argent joint ou frais), trade (echange ouvert),
--  spent (marchand : achat ; tout autre depense), other (le reste). Un contexte ferme compte encore 1,5 s (l'argent arrive apres l'evenement).
-- VERROUS : RequestRaidInfo() puis UPDATE_INSTANCE_INFO ; GetNumSavedInstances() ; GetSavedInstanceInfo(i) -> nom, id, secondes restantes
--  (signatures relevees dans DifficultBulletinBoard\api\lockouts.lua et ChronicleCompanion\advancedlogging\core.lua, jamais executees ici).
-- LIMITE HORAIRE : une entree est inscrite quand IsInInstance() passe de faux a vrai ("party" ; "raid" si tracker.countraids) ; au login ou
--  apres /reload dans une instance, rien n'est inscrit. Au-dela de tracker.hourlimit entrees sur 3600 s, le compte a rebours donne l'heure
--  ou la plus ancienne sort de la fenetre.
-- STATUT (Perf.lua) : option tracker.hud, coupee. Perf n'offre aucun point d'extension de texte : on enveloppe la fonction publique
--  SUI.Perf.HudText a l'activation et on la rend a la desactivation ; Perf.lua n'est pas modifie.
-- NON VERIFIE EN JEU : tout. En particulier : l'unite du 3e retour de GetSavedInstanceInfo (secondes, comme DBB), les textes localises
--  de CHAT_MSG_MONEY (globales GOLD / SILVER / COPPER, repli anglais), l'ordre des evenements PLAYER_MONEY / CHAT_MSG_MONEY / QUEST_FINISHED,
--  les valeurs de retour de IsInInstance, C_Item.GetItemSellPriceByID (extension, absente = pas de prix), GetRepairAllCost apres reparation.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local sfind, ssub, slower, sformat, sgsub = string.find, string.sub, string.lower, string.format, string.gsub
local floor = math.floor

local M = {}
SUI.Tracker = M

local SRC = { "loot", "vendor", "quest", "ah", "mail", "repair", "trade", "spent", "other" }
local CTX = { "merchant", "mail", "ah", "trade" }
local HOUR = 3600
local MAXROWS = 24
local MAXVALS = 8
local MAXDAYS = 30
local GRAPH_W, GRAPH_H = 400, 200
local TABS = { "gold", "graph", "lock", "chars" }
local EVENTS = {
	{ "PLAYER_MONEY", "OnMoney" }, { "CHAT_MSG_MONEY", "OnChatMoney" }, { "CHAT_MSG_LOOT", "OnLoot" },
	{ "MERCHANT_SHOW", "OnMerchantShow" }, { "MERCHANT_UPDATE", "OnMerchantUpdate" }, { "MERCHANT_CLOSED", "OnMerchantClose" },
	{ "MAIL_SHOW", "OnMailShow" }, { "MAIL_CLOSED", "OnMailClose" },
	{ "AUCTION_HOUSE_SHOW", "OnAhShow" }, { "AUCTION_HOUSE_CLOSED", "OnAhClose" },
	{ "TRADE_SHOW", "OnTradeShow" }, { "TRADE_CLOSED", "OnTradeClose" },
	{ "QUEST_COMPLETE", "OnQuestOpen" }, { "QUEST_FINISHED", "OnQuestDone" },
	{ "PLAYER_ENTERING_WORLD", "OnWorld" }, { "ZONE_CHANGED_NEW_AREA", "OnZone" },
	{ "UPDATE_INSTANCE_INFO", "OnInfo" }, { "PLAYER_REGEN_ENABLED", "OnRegen" },
}

M.on = false
M.visOK = true            -- regle de visibilite commune (tracker.vis)
M.SRC = SRC
M.sess = nil           -- { g, l, v, t0, s = { source = net } }
M.rec = nil            -- enregistrement du personnage courant (dans la base)
M.key = nil
M.day, M.dayKey, M.dayEnd = nil, nil, 0
M.last = nil           -- derniere somme connue (cuivre)
M.ctx, M.ctxEnd = {}, {}
M.questOpen, M.questEnd = false, -100
M.pend, M.pendAt = 0, -100       -- argent de butin annonce par le chat, pas encore vu dans PLAYER_MONEY
M.oAmt, M.oAt = 0, -100          -- dernier gain non classe, que CHAT_MSG_MONEY peut encore requalifier en butin
M.repairCost = 0
M.vals = {}                      -- objets de valeur de la session { name, link, count, value } (anneau)
M.nvals, M.vhead = 0, 0
M.inInst = nil
M.mem = nil                      -- base de repli si la base sauvegardee n'existe pas
M.alerted = {}
M.limitFull = false
M.tickN = 0
M.dirty = true
M.tab = "gold"
M.rl, M.rr, M.rc, M.rh = {}, {}, {}, {}
M.rn = 0
M.gv, M.gn = {}, 0
M.armAt = -100
M.pendLocks = false
M.lootPats = {}
M.loadAt = GetTime()

-- ---------------------------------------------------------------- utilitaires
local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

local function setCol(fs, c)
	if fs.curc ~= c then
		fs.curc = c
		fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	end
end

-- Somme en cuivre -> "12g 3s 4c" (jamais de partie nulle superflue).
function M.Money(c)
	c = floor((c or 0) + 0.5)
	local neg = c < 0
	if neg then c = -c end
	local g = floor(c / 10000)
	local s = floor((c - g * 10000) / 100)
	local k = c - g * 10000 - s * 100
	local out
	if g > 0 then out = sformat("%dg %ds %dc", g, s, k)
	elseif s > 0 then out = sformat("%ds %dc", s, k)
	else out = sformat("%dc", k) end
	if neg then return "-" .. out end
	return out
end

function M.Signed(c)
	c = c or 0
	if c > 0 then return "+" .. M.Money(c) end
	return M.Money(c)
end

-- Duree en secondes -> "2j 3h", "3h 05m", "4m 09s", "12s".
function M.Dur(sec)
	sec = floor((sec or 0) + 0.5)
	if sec < 0 then sec = 0 end
	local d = floor(sec / 86400)
	local h = floor((sec - d * 86400) / HOUR)
	local m = floor((sec - d * 86400 - h * HOUR) / 60)
	local s = sec - d * 86400 - h * HOUR - m * 60
	if d > 0 then return L("msg.tracker.dur.dh", d, h) end
	if h > 0 then return sformat("%dh %02dm", h, m) end
	if m > 0 then return sformat("%dm %02ds", m, s) end
	return sformat("%ds", s)
end

-- API client gardees (une absente ne doit jamais lever d'erreur).
local function repairCost()
	local fn = getglobal("GetRepairAllCost")
	if type(fn) ~= "function" then return 0 end
	local ok, v = pcall(fn)
	if ok and type(v) == "number" then return v end
	return 0
end

local function inInstance()
	local fn = getglobal("IsInInstance")
	if type(fn) ~= "function" then return nil, nil end
	local ok, a, b = pcall(fn)
	if ok then return a, b end
	return nil, nil
end

local function srcName(src)
	return L("msg.tracker.src." .. src)
end

-- ---------------------------------------------------------------- base de donnees
function M.Data()
	local t = C.GetGlobal("tracker")
	if type(t) ~= "table" then
		t = M.mem or {}
		M.mem = t
		C.SetGlobal("tracker", t)
	end
	return t
end

function M.CharKey()
	local name = UnitName("player")
	if not name or name == "" then return nil end
	return name .. "-" .. (GetRealmName() or "?")
end

local function fixRec(r, name)
	r.name = r.name or name
	r.money = r.money or 0
	r.tg, r.tl = r.tg or 0, r.tl or 0
	if type(r.lock) ~= "table" then r.lock = {} end
	if type(r.ent) ~= "table" then r.ent = {} end
	if type(r.entz) ~= "table" then r.entz = {} end
	if type(r.days) ~= "table" then r.days = {} end
	return r
end

-- Enregistrement du personnage courant (cree si besoin) ; nil tant que le nom n'est pas connu.
function M.EnsureRec()
	local key = M.CharKey()
	if not key then return nil end
	if M.rec and M.key == key then return M.rec end
	local data = M.Data()
	local r = data[key]
	if type(r) ~= "table" then
		r = {}
		data[key] = r
	end
	fixRec(r, key)
	M.rec, M.key = r, key
	M.day, M.dayEnd = nil, 0
	return r
end

function M.NewSession()
	local s = M.sess
	if not s then
		s = { g = 0, l = 0, v = 0, t0 = 0, s = {} }
		M.sess = s
	end
	s.g, s.l, s.v, s.t0 = 0, 0, 0, GetTime()
	for i = 1, getn(SRC) do s.s[SRC[i]] = 0 end
	M.nvals, M.vhead = 0, 0
	M.dirty = true
end

-- Enregistrement du jour courant ; recree seulement au passage de minuit.
function M.EnsureDay()
	local rec = M.EnsureRec()
	if not rec then return nil end
	local now = time()
	if M.day and now < M.dayEnd then return M.day end
	local key = date("%Y-%m-%d", now)
	local d = rec.days[key]
	if type(d) ~= "table" then
		d = { g = 0, l = 0, s = {} }
		rec.days[key] = d
	end
	d.g, d.l = d.g or 0, d.l or 0
	if type(d.s) ~= "table" then d.s = {} end
	local into = tonumber(date("%H", now)) * HOUR + tonumber(date("%M", now)) * 60 + tonumber(date("%S", now))
	M.day, M.dayKey, M.dayEnd = d, key, now - into + 86400
	M.Prune()
	return d
end

-- Oublie les jours plus vieux que tracker.days.
function M.Prune()
	local rec = M.rec
	if not rec then return end
	local cut = date("%Y-%m-%d", time() - C.Get("tracker.days") * 86400)
	for k, _ in pairs(rec.days) do
		if k < cut then rec.days[k] = nil end
	end
end

-- ---------------------------------------------------------------- or : enregistrement
-- d signe (cuivre) range dans la source src : session, jour, cumul du personnage.
function M.Add(src, d)
	if d == 0 then return end
	local rec = M.EnsureRec()
	local day = M.EnsureDay()
	local s = M.sess
	if d > 0 then
		s.g = s.g + d
		if day then day.g = day.g + d end
		if rec then rec.tg = rec.tg + d end
	else
		s.l = s.l - d
		if day then day.l = day.l - d end
		if rec then rec.tl = rec.tl - d end
	end
	s.s[src] = (s.s[src] or 0) + d
	if day then day.s[src] = (day.s[src] or 0) + d end
	M.dirty = true
end

-- Requalifie amt cuivre de gain deja compte (de -> vers).
function M.Move(from, to, amt)
	if amt <= 0 then return end
	local day = M.EnsureDay()
	local s = M.sess
	s.s[from] = (s.s[from] or 0) - amt
	s.s[to] = (s.s[to] or 0) + amt
	if day then
		day.s[from] = (day.s[from] or 0) - amt
		day.s[to] = (day.s[to] or 0) + amt
	end
	M.dirty = true
end

local function ctxActive(name)
	return M.ctx[name] or GetTime() < (M.ctxEnd[name] or 0)
end

local function setCtx(name, on)
	M.ctx[name] = on
	if not on then M.ctxEnd[name] = GetTime() + 1.5 end
end

-- Quelle source pour une variation d (cuivre, signee) ? Renvoie le nom de la source.
function M.Classify(d)
	if ctxActive("trade") then return "trade" end
	if ctxActive("mail") then return "mail" end
	if ctxActive("ah") then return "ah" end
	if ctxActive("merchant") then
		if d > 0 then return "vendor" end
		local cost = repairCost()
		local was = M.repairCost
		M.repairCost = cost
		if was > 0 and (-d == was or cost < was) then return "repair" end
		return "spent"
	end
	if d > 0 and (M.questOpen or GetTime() - M.questEnd < 3) then return "quest" end
	if d > 0 then return "other" end
	return "spent"
end

function M.OnMoney()
	local now = GetMoney() or 0
	if M.last == nil then
		M.last = now
		return
	end
	local d = now - M.last
	M.last = now
	local rec = M.EnsureRec()
	if rec then rec.money = now end
	if d == 0 then return end
	if d > 0 and M.pend > 0 and GetTime() - M.pendAt < 3 and not (ctxActive("trade") or ctxActive("mail") or ctxActive("merchant")) then
		local p = d
		if p > M.pend then p = M.pend end
		M.pend = M.pend - p
		M.Add("loot", p)
		d = d - p
		if d == 0 then return end
	end
	local src = M.Classify(d)
	M.Add(src, d)
	if src == "other" then
		M.oAmt, M.oAt = d, GetTime()
	end
end

-- "12 Gold, 3 Silver, 4 Copper" (globales du client si presentes, repli anglais) -> cuivre.
local function coinAmount(msg, word, fallback)
	local w = getglobal(word)
	if type(w) ~= "string" or w == "" then w = fallback end
	w = sgsub(w, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	local _, _, n = sfind(msg, "(%d+) " .. w)
	if not n then
		_, _, n = sfind(msg, "(%d+) " .. slower(w))
	end
	return tonumber(n) or 0
end

function M.ParseMoney(msg)
	if type(msg) ~= "string" then return 0 end
	return coinAmount(msg, "GOLD", "Gold") * 10000 + coinAmount(msg, "SILVER", "Silver") * 100 + coinAmount(msg, "COPPER", "Copper")
end

function M.OnChatMoney(ev, a1)
	local amt = M.ParseMoney(a1)
	if amt <= 0 then return end
	if M.oAmt > 0 and GetTime() - M.oAt < 2 then
		local moved = amt
		if moved > M.oAmt then moved = M.oAmt end
		M.oAmt = M.oAmt - moved
		M.Move("other", "loot", moved)
		amt = amt - moved
	end
	if amt > 0 then
		M.pend = M.pend + amt
		M.pendAt = GetTime()
	end
end

-- Objet de valeur : prix vendeur par l'extension C_Item (absente : pas de prix, pas de ligne).
local function sellPrice(id)
	local ci = getglobal("C_Item")
	if ci and ci.GetItemSellPriceByID then
		local ok, v = pcall(ci.GetItemSellPriceByID, id)
		if ok and type(v) == "number" then return v end
	end
	return nil
end

function M.BuildPatterns()
	local list = M.lootPats
	for i = getn(list), 1, -1 do list[i] = nil end
	local self1 = getglobal("LOOT_ITEM_SELF")
	if type(self1) == "string" then
		local p = sgsub(self1, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
		p = sgsub(p, "%%s", "(.+)")
		tinsert(list, "^" .. p .. "$")
	end
	tinsert(list, "^You receive loot: (.+)%.$")
end

function M.OnLoot(ev, a1)
	local msg = a1
	if type(msg) ~= "string" then return end
	local link
	for i = 1, getn(M.lootPats) do
		local _, _, a = sfind(msg, M.lootPats[i])
		if a then link = a break end
	end
	if not link then return end
	local _, _, name = sfind(link, "%[(.-)%]")
	local _, _, id = sfind(link, "item:(%d+)")
	local _, _, cnt = sfind(link, "x(%d+)%.?$")
	id = tonumber(id)
	if not id then return end
	cnt = tonumber(cnt) or 1
	local price = sellPrice(id)
	if not price or price <= 0 then return end
	local total = price * cnt
	M.sess.v = M.sess.v + total
	M.dirty = true
	if total >= C.Get("tracker.valuemin") * 10000 then
		local size = MAXVALS
		local h = M.vhead + 1
		if h > size then h = 1 end
		M.vhead = h
		local e = M.vals[h]
		e.name, e.link, e.count, e.value = name or "?", link, cnt, total
		if M.nvals < size then M.nvals = M.nvals + 1 end
	end
end

-- ---------------------------------------------------------------- contextes (boutiques, courrier, quetes...)
function M.OnMerchantShow()
	setCtx("merchant", true)
	M.repairCost = repairCost()
end
function M.OnMerchantUpdate()
	if M.ctx.merchant then M.repairCost = repairCost() end
end
function M.OnMerchantClose() setCtx("merchant", false) end
function M.OnMailShow() setCtx("mail", true) end
function M.OnMailClose() setCtx("mail", false) end
function M.OnAhShow() setCtx("ah", true) end
function M.OnAhClose() setCtx("ah", false) end
function M.OnTradeShow() setCtx("trade", true) end
function M.OnTradeClose() setCtx("trade", false) end
function M.OnQuestOpen() M.questOpen = true end
function M.OnQuestDone()
	M.questOpen = false
	M.questEnd = GetTime()
end

-- ---------------------------------------------------------------- remises a zero
function M.ResetSession()
	M.NewSession()
	M.Refresh()
end

function M.ResetDay()
	local day = M.EnsureDay()
	if not day then return end
	day.g, day.l = 0, 0
	for k, _ in pairs(day.s) do day.s[k] = nil end
	M.dirty = true
	M.Refresh()
end

-- Efface le cumul et l'historique du personnage courant (jamais ses verrous ni son or actuel).
function M.ResetAll()
	local rec = M.EnsureRec()
	if not rec then return end
	rec.tg, rec.tl = 0, 0
	for k, _ in pairs(rec.days) do rec.days[k] = nil end
	M.day, M.dayEnd = nil, 0
	M.NewSession()
	M.Refresh()
end

function M.Forget(key)
	local data = M.Data()
	if key == M.key then return false end
	if type(data[key]) ~= "table" then return false end
	data[key] = nil
	M.Refresh()
	return true
end

-- ---------------------------------------------------------------- verrous d'instances
function M.RequestInfo()
	RequestRaidInfo()
end

-- Relit GetSavedInstanceInfo dans l'enregistrement du personnage (tables reutilisees : pas de creation en combat sauf 1er verrou).
function M.ReadLocks()
	local rec = M.EnsureRec()
	if not rec then return end
	if SUI.InCombat() then
		M.pendLocks = true
		return
	end
	M.pendLocks = false
	local now = time()
	local n = GetNumSavedInstances() or 0
	local out = 0
	for i = 1, n do
		local name, id, secs = GetSavedInstanceInfo(i)
		if name and secs and secs > 0 then
			out = out + 1
			local e = rec.lock[out]
			if not e then
				e = {}
				rec.lock[out] = e
			end
			e.n, e.id, e.at = name, id, now + secs
		end
	end
	for i = getn(rec.lock), out + 1, -1 do tremove(rec.lock, i) end
	rec.lockAt = now
	M.dirty = true
	M.Refresh()
end

function M.OnInfo() M.ReadLocks() end

function M.OnRegen()
	if M.pendLocks then M.ReadLocks() end
end

-- Verrous encore valables d'un enregistrement : nombre (les entrees expirees restent dans la liste mais ne comptent plus).
local function liveLock(e, now)
	return e.at and e.at > now
end

-- ---------------------------------------------------------------- limite horaire
function M.CheckZone(silent)
	local rec = M.EnsureRec()
	if not rec then return end
	local inI, typ = inInstance()
	local inside = false
	if inI then
		if typ == "party" then inside = true
		elseif typ == "raid" and C.Get("tracker.countraids") then inside = true end
	end
	if silent or M.inInst == nil then
		M.inInst = inside
		return
	end
	if inside and not M.inInst then
		local n = getn(rec.ent) + 1
		rec.ent[n] = time()
		rec.entz[n] = GetRealZoneText() or "?"
		M.dirty = true
		M.SoonRequest()
	elseif M.inInst and not inside then
		M.SoonRequest()
	end
	M.inInst = inside
end

function M.SoonRequest()
	SUI.After(5, M.RequestInfo, "tracker.req")
end

function M.OnZone() M.CheckZone(false) end

function M.OnWorld()
	M.last = GetMoney() or 0
	local rec = M.EnsureRec()
	if rec then rec.money = M.last end
	M.EnsureDay()
	if not M.zoneInit then
		M.zoneInit = true
		M.CheckZone(true)
		M.SoonRequest()
	else
		M.CheckZone(false)
	end
	M.dirty = true
end

-- Retire les entrees de plus d'une heure.
function M.PruneEntries(now)
	local rec = M.rec
	if not rec then return end
	while getn(rec.ent) > 0 and rec.ent[1] <= now - HOUR do
		tremove(rec.ent, 1)
		tremove(rec.entz, 1)
	end
end

-- Entrees dans la derniere heure, limite, secondes avant qu'une place se libere (0 si libre).
function M.Entries()
	local rec = M.EnsureRec()
	if not rec then return 0, C.Get("tracker.hourlimit"), 0 end
	local now = time()
	M.PruneEntries(now)
	local n = getn(rec.ent)
	local lim = C.Get("tracker.hourlimit")
	local wait = 0
	if n >= lim and n > 0 then
		wait = rec.ent[n - lim + 1] + HOUR - now
		if wait < 0 then wait = 0 end
	end
	return n, lim, wait
end

-- Alertes : reset proche (une fois par verrou), place de donjon liberee.
function M.CheckAlerts()
	local rec = M.rec
	if not rec or not C.Get("tracker.alert") then return end
	local now = time()
	local thr = C.Get("tracker.alertmin") * 60
	for i = 1, getn(rec.lock) do
		local e = rec.lock[i]
		local k = (e.n or "?") .. ":" .. tostring(e.id)
		local left = (e.at or 0) - now
		if left > 0 and left <= thr then
			if M.alerted[k] ~= e.at then
				M.alerted[k] = e.at
				SUI.Print(L("msg.tracker.alert", e.n or "?", M.Dur(left)))
			end
		elseif left > thr then
			M.alerted[k] = nil
		end
	end
	local n, lim = M.Entries()
	if n >= lim then
		M.limitFull = true
	elseif M.limitFull then
		M.limitFull = false
		SUI.Print(L("msg.tracker.slot", n, lim))
	end
end

-- ---------------------------------------------------------------- lignes (fenetre, infobulle, discussion)
local function row(l, r, col, head)
	local n = M.rn + 1
	if n > MAXROWS then return end
	M.rn = n
	M.rl[n], M.rr[n], M.rc[n], M.rh[n] = l, r or "", col, head and true or false
end

function M.Accounts()
	local money, tg, tl, n = 0, 0, 0, 0
	local data = M.Data()
	for k, r in pairs(data) do
		if type(r) == "table" then
			money = money + (r.money or 0)
			tg = tg + (r.tg or 0)
			tl = tl + (r.tl or 0)
			n = n + 1
		end
	end
	return money, tg, tl, n
end

function M.Rate()
	local s = M.sess
	if not s then return 0 end
	local el = GetTime() - s.t0
	if el < 60 then el = 60 end
	return floor((s.g - s.l) * HOUR / el)
end

function M.GoldRows(forTip)
	local s = M.sess
	local rec = M.EnsureRec()
	local day = M.EnsureDay()
	local net = s.g - s.l
	local c = T.c
	row(L("msg.tracker.g.session", M.Dur(GetTime() - s.t0)), M.Signed(net), net < 0 and c.bad or c.good)
	row(L("msg.tracker.g.rate"), M.Signed(M.Rate()) .. "/h", M.Rate() < 0 and c.bad or c.good)
	row(L("msg.tracker.g.gain"), M.Money(s.g))
	row(L("msg.tracker.g.loss"), M.Money(s.l))
	if day then
		row(L("msg.tracker.g.today"), M.Signed(day.g - day.l), (day.g - day.l) < 0 and c.bad or c.good)
	end
	local money, tg, tl = M.Accounts()
	row(L("msg.tracker.g.char"), M.Money(rec and rec.money or 0))
	row(L("msg.tracker.g.acct"), M.Money(money))
	if not forTip then
		row(L("msg.tracker.g.acctflow"), "+" .. M.Money(tg) .. " / -" .. M.Money(tl))
		row(L("msg.tracker.g.value"), M.Money(s.v))
		row(L("msg.tracker.g.src"), "", c.dim, true)
		for i = 1, getn(SRC) do
			local v = s.s[SRC[i]] or 0
			if v ~= 0 then row(srcName(SRC[i]), M.Signed(v), v < 0 and c.bad or c.good) end
		end
		if M.nvals > 0 then
			row(L("msg.tracker.g.vals"), "", c.dim, true)
			for i = 1, M.nvals do
				local idx = M.vhead - (i - 1)
				if idx < 1 then idx = idx + MAXVALS end
				local e = M.vals[idx]
				row(e.name .. " x" .. e.count, M.Money(e.value))
			end
		end
	end
end

-- Verrous du personnage courant, limite horaire, puis un resume des autres personnages.
function M.LockRows(forTip)
	local rec = M.EnsureRec()
	local c = T.c
	local now = time()
	if rec then
		row(L("msg.tracker.l.mine", rec.name or "?"), "", c.dim, true)
		local any = false
		for i = 1, getn(rec.lock) do
			local e = rec.lock[i]
			if liveLock(e, now) then
				any = true
				local left = e.at - now
				row(sformat("%s (%s)", e.n or "?", tostring(e.id)), M.Dur(left), left < C.Get("tracker.alertmin") * 60 and c.warn or nil)
			end
		end
		if not any then row(L("msg.tracker.l.none"), "") end
	end
	local n, lim, wait = M.Entries()
	row(L("msg.tracker.l.hour", n, lim), wait > 0 and M.Dur(wait) or L("msg.tracker.l.free"), n >= lim and c.warn or nil)
	if rec and not forTip then
		for i = 1, getn(rec.ent) do
			row("  " .. (rec.entz[i] or "?"), M.Dur(rec.ent[i] + HOUR - now), c.dim)
		end
	end
	if forTip then return end
	local names = M.Names()
	local first = true
	for i = 1, getn(names) do
		local r = M.Data()[names[i]]
		if names[i] ~= M.key and r then
			for j = 1, getn(r.lock) do
				local e = r.lock[j]
				if liveLock(e, now) then
					if first then
						row(L("msg.tracker.l.others"), "", c.dim, true)
						first = false
					end
					row(sformat("%s: %s", r.name or names[i], e.n or "?"), M.Dur(e.at - now))
				end
			end
		end
	end
end

local function nameLess(a, b) return a < b end

-- Noms des personnages suivis, tries (tableau reutilise).
function M.Names()
	local list = M.names
	if not list then
		list = {}
		M.names = list
	end
	for i = getn(list), 1, -1 do list[i] = nil end
	for k, r in pairs(M.Data()) do
		if type(r) == "table" then tinsert(list, k) end
	end
	table.sort(list, nameLess)
	return list
end

function M.CharRows()
	local names = M.Names()
	local data = M.Data()
	local now = time()
	local c = T.c
	for i = 1, getn(names) do
		local r = data[names[i]]
		local nl = 0
		for j = 1, getn(r.lock) do
			if liveLock(r.lock[j], now) then nl = nl + 1 end
		end
		row(names[i] .. (names[i] == M.key and " *" or ""), L("msg.tracker.c.line", M.Money(r.money or 0), nl),
			names[i] == M.key and c.good or nil)
	end
	local money = M.Accounts()
	row(L("msg.tracker.g.acct"), M.Money(money), c.dim, true)
end

-- Net par jour (du plus ancien au plus recent) du personnage courant.
function M.CollectDays()
	local rec = M.EnsureRec()
	local n = C.Get("tracker.days")
	if n > MAXDAYS then n = MAXDAYS end
	local now = time()
	M.gn = n
	for i = 1, n do
		local k = date("%Y-%m-%d", now - (n - i) * 86400)
		local d = rec and rec.days[k]
		M.gv[i] = d and (d.g - d.l) or 0
	end
	return n
end

function M.GraphRows()
	local n = M.CollectDays()
	local c = T.c
	for i = 1, 15 do row("", "") end
	local total, best, bestI = 0, 0, 0
	for i = 1, n do
		total = total + M.gv[i]
		if M.gv[i] > best then best, bestI = M.gv[i], i end
	end
	row(L("msg.tracker.h.period", n), M.Signed(total), total < 0 and c.bad or c.good)
	row(L("msg.tracker.h.avg"), M.Signed(floor(total / n)))
	row(L("msg.tracker.h.best"), M.Signed(best))
end

function M.Rows(tab)
	M.rn = 0
	if tab == "gold" then M.GoldRows(false)
	elseif tab == "lock" then M.LockRows(false)
	elseif tab == "chars" then M.CharRows()
	else M.GraphRows() end
	return M.rn
end

-- ---------------------------------------------------------------- export texte
function M.Export()
	local lines = {}
	tinsert(lines, L("msg.tracker.exp.head", date("%Y-%m-%d %H:%M", time())))
	local names = M.Names()
	local data = M.Data()
	local now = time()
	for i = 1, getn(names) do
		local r = data[names[i]]
		tinsert(lines, L("msg.tracker.exp.char", names[i], M.Money(r.money or 0), M.Money(r.tg or 0), M.Money(r.tl or 0)))
		for j = 1, getn(r.lock) do
			local e = r.lock[j]
			if liveLock(e, now) then tinsert(lines, L("msg.tracker.exp.lock", e.n or "?", tostring(e.id), M.Dur(e.at - now))) end
		end
		local keys = {}
		for k, _ in pairs(r.days) do tinsert(keys, k) end
		table.sort(keys, nameLess)
		for j = 1, getn(keys) do
			local d = r.days[keys[j]]
			tinsert(lines, L("msg.tracker.exp.day", keys[j], M.Money(d.g or 0), M.Money(d.l or 0)))
		end
	end
	local s = M.sess
	tinsert(lines, L("msg.tracker.exp.session", M.Money(s.g), M.Money(s.l), M.Money(M.Rate())))
	return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------- affichage : mini-barre, infobulle
function M.BarText()
	local s = M.sess
	local money = M.Accounts()
	return L("msg.tracker.bar", M.Signed(s.g - s.l), M.Signed(M.Rate()), M.Money(money))
end

function M.RefreshBar()
	if not M.frame then return end
	setText(M.text, M.BarText())
	local net = M.sess.g - M.sess.l
	setCol(M.text, net < 0 and T.c.bad or T.c.text)
	M.dirty = false
end

function M.ShowTip()
	local tt = getglobal("GameTooltip")
	if not tt then return end
	tt:SetOwner(M.frame, "ANCHOR_BOTTOM")
	tt:ClearLines()
	M.rn = 0
	M.GoldRows(true)
	M.LockRows(true)
	tt:AddLine(L("msg.tracker.title"), T.c.text[1], T.c.text[2], T.c.text[3])
	for i = 1, M.rn do
		tt:AddLine(M.rl[i] .. (M.rr[i] ~= "" and (": " .. M.rr[i]) or ""))
	end
	tt:Show()
end

function M.HideTip()
	local tt = getglobal("GameTooltip")
	if tt then tt:Hide() end
end

-- ---------------------------------------------------------------- affichage : fenetre
function M.SetTab(tab)
	M.tab = tab
	if M.win and M.win.exp:IsShown() then M.win.exp:Hide() end
	for i = 1, getn(TABS) do
		if M.win then T.SetSelected(M.win.tabs[i], TABS[i] == tab) end
	end
	M.RefreshWin()
end

function M.ShowGraph(on)
	local w = M.win
	for i = 1, MAXDAYS do
		if not on then w.cols[i]:Hide() end
	end
	if on then w.zero:Show() else w.zero:Hide() end
	w.lab1:SetText("")
	w.lab2:SetText("")
end

function M.DrawGraph()
	local w = M.win
	local n = M.gn
	local half = floor(GRAPH_H / 2)
	local maxv = 0
	for i = 1, n do
		local v = M.gv[i]
		if v < 0 then v = -v end
		if v > maxv then maxv = v end
	end
	local colw = floor(GRAPH_W / n)
	local bw = colw - 1
	if bw < 1 then bw = 1 end
	w.zero:Show()
	for i = 1, MAXDAYS do
		local t = w.cols[i]
		local v = M.gv[i]
		if i > n or not v or v == 0 or maxv == 0 then
			t:Hide()
		else
			local h = floor((v < 0 and -v or v) * (half - 4) / maxv + 0.5)
			if h < 1 then h = 1 end
			local col = v < 0 and T.c.bad or T.c.good
			local tex = T.BarTexture("tracker")          -- texture des colonnes : tracker.bartex
			if t.curTex ~= tex then
				t.curTex = tex
				t:SetTexture(tex)
			end
			t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
			t:SetWidth(bw)
			t:SetHeight(h)
			t:ClearAllPoints()
			if v < 0 then
				t:SetPoint("TOPLEFT", w.graph, "BOTTOMLEFT", (i - 1) * colw, half)
			else
				t:SetPoint("BOTTOMLEFT", w.graph, "BOTTOMLEFT", (i - 1) * colw, half)
			end
			t:Show()
		end
	end
	local now = time()
	w.lab1:SetText(date("%m-%d", now - (n - 1) * 86400))
	w.lab2:SetText(date("%m-%d", now))
end

function M.RefreshWin()
	local w = M.win
	if not w or not w:IsShown() then return end
	local tab = M.tab
	M.Rows(tab)
	for i = 1, MAXROWS do
		if i <= M.rn then
			setText(w.rl[i], M.rl[i])
			setText(w.rr[i], M.rr[i])
			setCol(w.rl[i], M.rh[i] and T.c.dim or T.c.text)
			setCol(w.rr[i], M.rc[i] or T.c.text)
		else
			setText(w.rl[i], "")
			setText(w.rr[i], "")
		end
	end
	if tab == "graph" then M.DrawGraph() else M.ShowGraph(false) end
end

function M.Refresh()
	M.RefreshBar()
	M.RefreshWin()
end

function M.ToggleWin()
	if not M.win then return end
	if M.win:IsShown() then M.win:Hide() else
		M.win:Show()
		M.RefreshWin()
	end
end

function M.ShowExport()
	if not M.win then return end
	M.win.exp:SetText(M.Export())
	M.win.exp:Show()
	M.win.exp:HighlightText()
end

-- ---------------------------------------------------------------- construction (une fois, hors combat)
local function onBarEnter() M.ShowTip() end
local function onBarLeave() M.HideTip() end
local function onBarClick()
	if arg1 == "LeftButton" or arg1 == nil then M.ToggleWin() end
end

-- Visibilite commune (tracker.vis / .fade) : la mini-barre fond (opacite) ; refusee par la regle, elle est aussi cachee (elle capte la souris).
function M.AttachVisibility()
	if not (SUI.Visibility and M.frame) then return end
	SUI.Visibility.Add(M.frame, "tracker", { mode = "alpha", module = "tracker", alpha = 1, cat = "tracker",
		onChange = function(visible)
			M.visOK = visible and true or false
			M.ApplyOptions()
		end })
end

function M.DetachVisibility()
	if not (SUI.Visibility and M.frame) then return end
	M.visOK = true
	-- differe : la coupure arrive depuis un observateur de Config (Remove peut en detacher un pendant sa boucle) ; rallume entre-temps : rien
	SUI.After(0, function()
		if M.on then return end
		SUI.Visibility.Remove(M.frame)
	end, "tracker.visoff")
end

function M.Build()
	if M.frame then return end
	local f = CreateFrame("Frame", "ShikiUI_Tracker", UIParent)
	f:SetWidth(C.Get("tracker.width"))
	f:SetHeight(20)
	f:EnableMouse(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	M.text = T.Text(f, 11, T.c.text, "CENTER")
	M.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	if SUI.Look then SUI.Look.ApplyText(M.text, "tracker", 11) end    -- police et taille : tracker.font / tracker.fontsize
	f:SetScript("OnEnter", onBarEnter)
	f:SetScript("OnLeave", onBarLeave)
	f:SetScript("OnMouseUp", onBarClick)
	M.frame = f
	SUI.Mover.Register("tracker", f, { label = "mod.tracker.mover", point = "TOP", x = 0, y = -34 })

	local w = T.Panel(UIParent, 440, 430)
	w:SetFrameStrata("DIALOG")
	w:SetClampedToScreen(true)      -- la mise en page place le bord gauche a 99 % de l'ecran : sans cela la fenetre (440 px) sort de l'ecran
	w:EnableMouse(true)
	w:Hide()
	w.title = T.Text(w, 13, T.c.text, "LEFT")
	w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -8)
	w.title:SetText(L("msg.tracker.title"))
	if SUI.Look then SUI.Look.ApplyText(w.title, "tracker", 13) end
	w.close = T.Button(w, "X", 22, 20, function() w:Hide() end)
	w.close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -6)
	T.GearButton(w, "tracker", { size = 16, point = "TOPRIGHT", x = -32, y = -8, title = L("msg.tracker.gear") })
	w.tabs = {}
	for i = 1, getn(TABS) do
		local id = TABS[i]
		local b = T.Button(w, L("msg.tracker.tab." .. id), 96, 20, function() M.SetTab(id) end)
		b:SetPoint("TOPLEFT", w, "TOPLEFT", 10 + (i - 1) * 100, -32)
		w.tabs[i] = b
	end
	w.rl, w.rr = {}, {}
	for i = 1, MAXROWS do
		local y = -60 - (i - 1) * 14
		local a = T.Text(w, 11, T.c.text, "LEFT")
		a:SetPoint("TOPLEFT", w, "TOPLEFT", 14, y)
		a:SetWidth(250)
		local b = T.Text(w, 11, T.c.text, "RIGHT")
		b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, y)
		b:SetWidth(170)
		w.rl[i], w.rr[i] = a, b
		if SUI.Look then
			SUI.Look.ApplyText(a, "tracker", 11)
			SUI.Look.ApplyText(b, "tracker", 11)
		end
	end
	w.graph = CreateFrame("Frame", nil, w)
	w.graph:SetWidth(GRAPH_W)
	w.graph:SetHeight(GRAPH_H)
	w.graph:SetPoint("TOPLEFT", w, "TOPLEFT", 20, -62)
	w.cols = {}
	for i = 1, MAXDAYS do
		local t = w.graph:CreateTexture(nil, "ARTWORK")
		t:SetTexture(T.tex.white)
		t:Hide()
		w.cols[i] = t
	end
	w.zero = w.graph:CreateTexture(nil, "BORDER")
	w.zero:SetTexture(T.tex.white)
	w.zero:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	w.zero:SetWidth(GRAPH_W)
	w.zero:SetHeight(1)
	w.zero:SetPoint("BOTTOMLEFT", w.graph, "BOTTOMLEFT", 0, floor(GRAPH_H / 2))
	w.zero:Hide()
	w.lab1 = T.Text(w.graph, 10, T.c.dim, "LEFT")
	w.lab1:SetPoint("TOPLEFT", w.graph, "BOTTOMLEFT", 0, -2)
	w.lab2 = T.Text(w.graph, 10, T.c.dim, "RIGHT")
	w.lab2:SetPoint("TOPRIGHT", w.graph, "BOTTOMRIGHT", 0, -2)
	if SUI.Look then
		SUI.Look.ApplyText(w.lab1, "tracker", 10)
		SUI.Look.ApplyText(w.lab2, "tracker", 10)
	end
	w.bReset = T.Button(w, L("msg.tracker.btn.reset"), 120, 20, function() M.ResetSession() end)
	w.bReset:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 10, 8)
	w.bLocks = T.Button(w, L("msg.tracker.btn.locks"), 120, 20, function() M.RequestInfo() end)
	w.bLocks:SetPoint("LEFT", w.bReset, "RIGHT", 6, 0)
	w.bExport = T.Button(w, L("msg.tracker.btn.export"), 120, 20, function() M.ShowExport() end)
	w.bExport:SetPoint("LEFT", w.bLocks, "RIGHT", 6, 0)
	w.exp = T.Edit(w, 410, 250)
	w.exp:SetMultiLine(true)
	w.exp:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -62)
	w.exp:SetFrameStrata("DIALOG")
	w.exp:SetScript("OnEscapePressed", function() this:Hide() end)
	w.exp:Hide()
	M.win = w
	SUI.Mover.Register("tracker.win", w, { label = "mod.tracker.mover.win", point = "CENTER", x = 0, y = 0, scale = true })
	if SUI.Mover.QuickDrag then SUI.Mover.QuickDrag(w, "tracker.win") end      -- glisser la fenetre d'un clic de souris
	M.ApplyOptions()
	M.SetTab(M.tab)
	M.Refresh()
	M.AttachVisibility()
end

-- ---------------------------------------------------------------- statut Perf (optionnel)
function M.HudSuffix()
	local s = M.sess
	if not s then return "" end
	return M.Signed(s.g - s.l)
end

function M.HookHud()
	local P = SUI.Perf
	local want = M.on and C.Get("tracker.hud")
	if want and P and P.HudText and not M.hudFn then
		local orig = P.HudText
		local live = { on = true }    -- drapeau propre a cette enveloppe : une ancienne enveloppe restee dans une chaine ne se reactive pas
		M.hudOrig, M.hudLive = orig, live
		M.hudFn = function()
			if not live.on then return orig() end
			return orig() .. "  " .. M.HudSuffix()
		end
		P.HudText = M.hudFn
	elseif not want and M.hudFn then
		if M.hudLive then M.hudLive.on = false end
		if P and P.HudText == M.hudFn then P.HudText = M.hudOrig end
		M.hudFn, M.hudOrig = nil, nil
	end
end

-- ---------------------------------------------------------------- reglages, cycle de vie
function M.ApplyOptions()
	if M.frame then
		M.frame:SetWidth(C.Get("tracker.width"))
		if M.on and C.Get("tracker.bar") and M.visOK then M.frame:Show() else M.frame:Hide() end
	end
	M.HookHud()
end

function M.OnKey(key, value)
	if key == nil or key == "tracker.days" then
		M.Prune()
	end
	if M.on and (key == nil or key == "tracker.countraids") then M.CheckZone(true) end
	M.ApplyOptions()
	if M.on then M.Refresh() end
end

function M.Tick()
	if not M.on then return end
	M.tickN = M.tickN + 1
	if M.tickN >= 10 then
		M.tickN = 0
		M.Slow()
	end
	if M.dirty or SUI.Mod(M.tickN, 5) == 0 then M.RefreshBar() end
	if M.win and M.win:IsShown() then M.RefreshWin() end
end

-- Toutes les 10 s : jour, entrees horaires, alertes ; toutes les 5 minutes dans une instance : relecture des verrous.
function M.Slow()
	M.EnsureDay()
	M.CheckAlerts()
	if M.inInst then
		M.slowN = (M.slowN or 0) + 1
		if M.slowN >= 30 then
			M.slowN = 0
			M.RequestInfo()
		end
	end
end

function M.Enable()
	M.on = true
	M.BuildPatterns()
	if not M.sess then M.NewSession() end
	for i = 1, MAXVALS do
		if not M.vals[i] then M.vals[i] = { name = "", link = "", count = 0, value = 0 } end
	end
	M.last = nil
	local rec = M.EnsureRec()
	if rec then
		M.last = GetMoney() or 0
		rec.money = M.last
	end
	for i = 1, getn(EVENTS) do SUI.On(EVENTS[i][1], M[EVENTS[i][2]]) end
	SUI.WhenSafe(M.Build)
	M.AttachVisibility()       -- idempotent : repose la mini-barre apres une coupure
	M.task = SUI.Every(1, M.Tick, "tracker.tick", true)
	if not M.watching then
		M.watching = true
		C.Watch("tracker.", M.OnKey)
	end
	M.inInst = nil
	M.zoneInit = false
	if rec and GetTime() - M.loadAt > 20 then       -- active apres coup (menu) : le monde est deja charge
		M.zoneInit = true
		M.CheckZone(true)
		M.SoonRequest()
	end
	M.ApplyOptions()
	M.Refresh()
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	for i = 1, getn(EVENTS) do SUI.Off(EVENTS[i][1], M[EVENTS[i][2]]) end
	M.zoneInit = false
	M.HookHud()
	M.DetachVisibility()
	if M.frame then M.frame:Hide() end
	if M.win then M.win:Hide() end
end

-- ---------------------------------------------------------------- commandes
local function printRows(tab)
	M.Rows(tab)
	for i = 1, M.rn do
		if M.rl[i] ~= "" or M.rr[i] ~= "" then
			SUI.Print(M.rl[i] .. (M.rr[i] ~= "" and (": " .. M.rr[i]) or ""))
		end
	end
end

function M.Command(rest)
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = ssub(rest, sp + 1)
	end
	word = slower(word)
	if not M.on then
		SUI.Print(L("msg.tracker.off"))
		return
	end
	if word == "" or word == "win" then
		M.ToggleWin()
	elseif word == "lock" then
		M.RequestInfo()
		printRows("lock")
	elseif word == "gold" then
		printRows("gold")
	elseif word == "chars" then
		printRows("chars")
	elseif word == "export" then
		if M.win then
			M.win:Show()
			M.ShowExport()
		end
		SUI.Print(L("msg.tracker.exported"))
	elseif word == "forget" then
		if M.Forget(arg) then SUI.Print(L("msg.tracker.forgot", arg)) else SUI.Print(L("msg.tracker.forget.no", arg)) end
	elseif word == "reset" then
		local what = slower(arg)
		if what == "" or what == "session" then
			M.ResetSession()
			SUI.Print(L("msg.tracker.reset.session"))
		elseif what == "day" then
			M.ResetDay()
			SUI.Print(L("msg.tracker.reset.day"))
		elseif what == "all" then
			if GetTime() - M.armAt < 10 then
				M.armAt = -100
				M.ResetAll()
				SUI.Print(L("msg.tracker.reset.all"))
			else
				M.armAt = GetTime()
				SUI.Print(L("msg.tracker.reset.arm"))
			end
		else
			SUI.Print(L("msg.tracker.help"))
		end
	else
		SUI.Print(L("msg.tracker.help"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("tracker", 58)

local function opt(key, typ, order, def, extra)
	local o = { key = "tracker." .. key, type = typ, cat = "tracker", label = "opt.tracker." .. key, tip = "tip.tracker." .. key,
		default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local TR_OPTIONS = {
		opt("bar", "bool", 10, true, { simple = true, section = "mod.tracker.sec.display" }),
		opt("width", "number", 20, 240, { min = 140, max = 400, step = 10, section = "mod.tracker.sec.display" }),
		opt("hud", "bool", 30, false, { section = "mod.tracker.sec.display" }),
		opt("days", "number", 40, 14, { min = 3, max = 30, step = 1, simple = true, section = "mod.tracker.sec.gold" }),
		opt("valuemin", "number", 50, 1, { min = 0, max = 100, step = 1, section = "mod.tracker.sec.gold" }),
		opt("alert", "bool", 60, true, { simple = true, section = "mod.tracker.sec.lock" }),
		opt("alertmin", "number", 70, 60, { min = 5, max = 720, step = 5, simple = true, section = "mod.tracker.sec.lock" }),
		opt("hourlimit", "number", 80, 5, { min = 1, max = 10, step = 1, simple = true, section = "mod.tracker.sec.lock" }),
		opt("countraids", "bool", 90, false, { section = "mod.tracker.sec.lock" }),
}
-- Options communes du socle : visibilite de la mini-barre (tracker.vis / .fade), texture des colonnes du graphe et police des textes.
local function addAll(list)
	for i = 1, getn(list) do
		list[i].section = "mod.tracker.sec.display"
		tinsert(TR_OPTIONS, list[i])
	end
end
if SUI.Visibility then addAll(SUI.Visibility.Options("tracker", { cat = "tracker", order = 800 })) end
if SUI.Look then addAll(SUI.Look.Options("tracker", { bar = true, font = true, cat = "tracker", order = 820 })) end

SUI.RegisterModule("tracker", {
	default = false,
	cost = "light",
	options = TR_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("tracker", function(rest) M.Command(rest or "") end, "help.tracker")
