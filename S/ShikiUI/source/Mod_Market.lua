-- ShikiUI Market : marche de l'hotel des ventes (module "market") ; reecrit, aucune ligne copiee.
-- Ce que fait le module :
--   1. SCAN COMPLET : "Scanner tout l'hotel" lit TOUTES les pages de l'hotel (QueryAuctionItems sans filtre, 50 lots par page, une page a la
--      fois, au rythme que CanSendAuctionQuery autorise ; le client 1.12 n'a pas de lecture globale). Progression, arret possible, et un arret
--      (ou la fermeture de l'hotel) garde ce qui a deja ete lu. Aucun achat, aucune mise en vente : lecture seule.
--   2. BASE DE PRIX (ShikiUIDB.global.market.db, partagee entre personnages) : par objet, le plus bas prix de rachat unitaire du jour, la
--      MEDIANE des plus bas prix des derniers jours (valeur marche), le nombre d'offres, une histoire de 14 jours. Plafonnee (8000 objets,
--      les plus anciens sortent) ; sans historique, la valeur marche est la mediane des 8 offres les moins cheres du scan.
--   3. FENETRE MARCHE (/sui market, ou l'onglet lateral du panneau de l'hotel) : "Bonnes affaires" (prix actuel sous la valeur marche d'au
--      moins X % et profit net, apres la commission, d'au moins Y), "Toute la base" (recherche par nom), tri par colonne, courbe de prix de
--      l'objet choisi. Double-clic = recherche cet objet dans l'hotel (l'achat passe par la confirmation du module Hotel des ventes).
--   4. INFOBULLES : ligne "Marche" (valeur, plus bas du jour, offres) sur les objets connus de la base (option market.tooltip).
-- Cout declare : LIGHT. AUCTION_ITEM_LIST_UPDATE n'est ecoute que pendant un scan ; une minuterie (0,3 s) n'existe que pendant un scan.
-- NON VERIFIE EN JEU : tout (surtout le nombre de pages d'un scan complet et le comportement du serveur sur une requete vide).
-- Lua 5.0 : pas de '#', '%', '...', string.match ; au plus 32 valeurs externes par fonction.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local floor = math.floor
local sfind, ssub, slower, sformat, sgfind = string.find, string.sub, string.lower, string.format, string.gfind

local M = {}
SUI.Market = M

local DAY = 86400
local PAGE = 50
local NROWS = 12
local MAXITEMS = 8000
local NHIST = 14
local NLOW = 8            -- offres les moins cheres gardees par objet pendant un scan
local TICK = 0.3
local WINW, WINH = 760, 470

M.db = nil
M.sc = nil            -- scan en cours : { page, pages, state, sentAt, acc, lots, items }
M.mode = "deals"      -- "deals" | "all"
M.sortKey, M.sortDesc = "profit", true
M.filter = ""
M.list = {}
M.nlist = 0
M.offset = 0
M.sel = nil

-- ---------------------------------------------------------------- utilitaires
local function money(c)
	c = floor(c or 0)
	local au = SUI.Auction
	if au and au.MoneyShort then return au.MoneyShort(c) end
	local g = floor(c / 10000)
	local s = floor((c - g * 10000) / 100)
	local k = c - g * 10000 - s * 100
	if g > 0 then return g .. "g " .. s .. "s" end
	if s > 0 then return s .. "s " .. k .. "c" end
	return k .. "c"
end

local function idOf(link)
	local _, _, id = sfind(link or "", "item:(%d+)")
	return tonumber(id)
end

function M.Day()
	local fn = getglobal("time")
	if type(fn) ~= "function" then return 0 end
	return floor(fn() / DAY)
end

local function qcolor(q)
	local tbl = getglobal("ITEM_QUALITY_COLORS")
	local col = type(q) == "number" and tbl and tbl[q]
	if col then return col.r, col.g, col.b end    -- style:ok couleur de qualite (donnee de jeu)
	local c = T.c.text
	return c[1], c[2], c[3]
end

local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

-- ---------------------------------------------------------------- base de prix
function M.LoadDB()
	if M.db then return M.db end
	local db = C.GetGlobal("market.db")
	if type(db) ~= "table" then
		db = {}
		C.SetGlobal("market.db", db)
	end
	if type(db.items) ~= "table" then db.items = {} end
	if type(db.scan) ~= "table" then db.scan = { t = 0, id = 0, items = 0, lots = 0 } end
	M.db = db
	return db
end

-- "jour:prix,jour:prix" -> tableaux paralleles (jours croissants)
local function histParse(h, days, vals)
	local n = 0
	if type(h) ~= "string" then return 0 end
	for d, v in sgfind(h, "(%d+):(%d+)") do
		n = n + 1
		days[n] = tonumber(d)
		vals[n] = tonumber(v)
	end
	return n
end

local function histWrite(days, vals, n)
	local out = ""
	local first = n - NHIST + 1
	if first < 1 then first = 1 end
	for i = first, n do
		if out ~= "" then out = out .. "," end
		out = out .. days[i] .. ":" .. vals[i]
	end
	return out
end

local function median(list, n)
	if n < 1 then return nil end
	local copy = {}
	for i = 1, n do copy[i] = list[i] end
	tsort(copy)
	return copy[floor((n + 1) / 2)]
end

-- valeur marche : mediane des prix les plus bas des 11 derniers jours (3 jours mini), sinon mediane des offres du scan
function M.MarketValue(e, lows, nl)
	local days, vals = {}, {}
	local n = histParse(e.h, days, vals)
	if n >= 3 then
		local from = n - 10
		if from < 1 then from = 1 end
		local sub, k = {}, 0
		for i = from, n do
			k = k + 1
			sub[k] = vals[i]
		end
		return median(sub, k)
	end
	if lows and nl and nl >= 1 then return median(lows, nl) end
	return e.mn
end

-- enregistre le resultat d'un scan pour un objet (acc = { name, q, tex, lows = {}, nl, no })
function M.Record(id, acc, day, scanId)
	local db = M.LoadDB()
	local e = db.items[id]
	if not e then
		e = {}
		db.items[id] = e
	end
	e.n, e.q = acc.name, acc.q
	if acc.tex then e.t = acc.tex end
	e.no = acc.no
	e.s = scanId
	e.d = day
	if acc.nl > 0 then
		tsort(acc.lows)
		local mn = acc.lows[1]
		e.mn = mn
		local days, vals = {}, {}
		local n = histParse(e.h, days, vals)
		if n > 0 and days[n] == day then
			if mn < vals[n] then vals[n] = mn end
		else
			n = n + 1
			days[n] = day
			vals[n] = mn
		end
		e.h = histWrite(days, vals, n)
		e.md = M.MarketValue(e, acc.lows, acc.nl)
	else
		e.mn = nil          -- que des encheres sans rachat
	end
end

function M.Trim()
	local db = M.LoadDB()
	local n = 0
	for _ in pairs(db.items) do n = n + 1 end
	if n <= MAXITEMS then return end
	local ages = {}
	local k = 0
	for id, e in pairs(db.items) do
		k = k + 1
		ages[k] = e.d or 0
	end
	tsort(ages)
	local cut = ages[n - MAXITEMS]
	for id, e in pairs(db.items) do
		if (e.d or 0) <= cut and n > MAXITEMS then
			db.items[id] = nil
			n = n - 1
		end
	end
end

function M.Clear()
	local db = M.LoadDB()
	db.items = {}
	db.scan = { t = 0, id = 0, items = 0, lots = 0 }
	M.Rebuild()
end

function M.Count()
	local n = 0
	for _ in pairs(M.LoadDB().items) do n = n + 1 end
	return n
end

-- valeur marche fiable : au moins 3 jours d'historique (sans cela, la mediane des offres du jour peut etre faussee par des prix absurdes)
function M.Reliable(e)
	local days, vals = {}, {}
	return histParse(e.h, days, vals) >= 3
end

-- profit net unitaire (apres commission) et ecart en % entre le prix actuel et la valeur marche
function M.Metrics(e)
	if not e or not e.mn or not e.md or e.md <= 0 then return nil, nil end
	local cut = C.Get("market.cut") or 5
	local pct = floor((e.md - e.mn) * 100 / e.md)
	local profit = floor(e.md * (100 - cut) / 100) - e.mn
	return pct, profit
end

-- ---------------------------------------------------------------- scan complet
function M.Scanning()
	return M.sc ~= nil
end

local function canQuery()
	local fn = getglobal("CanSendAuctionQuery")
	if type(fn) ~= "function" then return false end
	return fn() and true or false
end

local function sendQuery(page, name)
	local au = SUI.Auction
	if au and au.FixBlizzPage then au.FixBlizzPage() end
	QueryAuctionItems(name or "", nil, nil, nil, nil, nil, page, nil, nil)
end

function M.ReadPage()
	local sc = M.sc
	local num = GetNumAuctionItems("list") or 0
	for i = 1, num do
		local name, tex, count, quality, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
		local link = GetAuctionItemLink("list", i)
		local id = idOf(link)
		if id and name then
			sc.lots = sc.lots + 1
			local a = sc.acc[id]
			if not a then
				a = { name = name, q = quality or 1, lows = {}, nl = 0, no = 0 }
				if type(tex) == "string" then
					local _, _, short = sfind(tex, "Icons\\(.+)$")
					a.tex = short or tex
				end
				sc.acc[id] = a
				sc.items = sc.items + 1
			end
			a.no = a.no + 1
			count = count or 1
			if count < 1 then count = 1 end
			if buyout and buyout > 0 then
				local unit = floor(buyout / count)
				if a.nl < NLOW then
					a.nl = a.nl + 1
					a.lows[a.nl] = unit
				else
					local worst, wi = a.lows[1], 1
					for k = 2, NLOW do
						if a.lows[k] > worst then worst, wi = a.lows[k], k end
					end
					if unit < worst then a.lows[wi] = unit end
				end
			end
		end
	end
	return num
end

function M.Finish(partial)
	local sc = M.sc
	if not sc then return end
	M.sc = nil
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	local db = M.LoadDB()
	local day = M.Day()
	if not sc.names then db.scan.id = (db.scan.id or 0) + 1 end     -- un scan cible reste dans le dernier scan complet
	local n = 0
	for id, acc in pairs(sc.acc) do
		M.Record(id, acc, day, db.scan.id)
		n = n + 1
	end
	db.scan.t = time and time() or 0
	if not sc.names then        -- un scan cible ne remplace pas le bilan du dernier scan complet
		db.scan.items = n
		db.scan.lots = sc.lots
		db.scan.partial = partial and true or false
	end
	M.Trim()
	if not sc.quiet then SUI.Print(L(partial and "msg.market.scan.partial" or "msg.market.scan.done", n, sc.lots)) end
	M.Rebuild()
	M.WatchReport(sc.quiet)
end

function M.Stop(silent)
	if not M.sc then return end
	if silent and M.sc.lots == 0 then
		M.sc = nil
		if M.task then SUI.Cancel(M.task) M.task = nil end
		SUI.Off("AUCTION_ITEM_LIST_UPDATE", M.OnList)
		M.Refresh()
		return
	end
	M.Finish(true)
end

-- names (facultatif) : liste de noms a chercher un par un au lieu de balayer tout l'hotel (scan cible)
function M.Start(names, quiet)
	if M.sc then return end
	local au = SUI.Auction
	if not (au and au.open) then
		if not quiet then SUI.Print(L("msg.market.needah")) end
		return
	end
	if au.scan or au.loc then
		if not quiet then SUI.Print(L("msg.market.busy")) end
		return
	end
	M.LoadDB()
	M.sc = { page = 0, pages = 1, state = "query", sentAt = GetTime(), acc = {}, lots = 0, items = 0, names = names, ni = 1, quiet = quiet }
	SUI.On("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(TICK, M.Tick, "market.tick")
	M.Tick()
	M.Refresh()
end

function M.OnList()
	local sc = M.sc
	if not sc or sc.state ~= "wait" then return end
	M.ReadPage()
	local _, total = GetNumAuctionItems("list")
	total = total or 0
	sc.pages = floor((total + PAGE - 1) / PAGE)
	if sc.pages < 1 then sc.pages = 1 end
	if sc.page + 1 < sc.pages then
		sc.page = sc.page + 1
		sc.state = "query"
		sc.sentAt = GetTime()
		if canQuery() then
			sendQuery(sc.page, sc.names and sc.names[sc.ni])
			sc.state = "wait"
			sc.sentAt = GetTime()
		end
		M.dirtyBar = true
	elseif sc.names and sc.ni < getn(sc.names) then
		sc.ni = sc.ni + 1
		sc.page = 0
		sc.state = "query"
		sc.sentAt = GetTime()
		if canQuery() then
			sendQuery(0, sc.names[sc.ni])
			sc.state = "wait"
			sc.sentAt = GetTime()
		end
		M.dirtyBar = true
	else
		M.Finish(false)
		return
	end
	M.Refresh()
end

function M.Tick()
	local sc = M.sc
	if not sc then return end
	local au = SUI.Auction
	if not (au and au.open) then
		M.Stop(false)
		return
	end
	if sc.state == "query" then
		if canQuery() then
			sendQuery(sc.page, sc.names and sc.names[sc.ni])
			sc.state = "wait"
			sc.sentAt = GetTime()
		elseif GetTime() - sc.sentAt > 10 then
			SUI.Print(L("msg.market.timeout"))
			M.Stop(false)
			return
		end
	elseif sc.state == "wait" then
		if GetTime() - sc.sentAt > 10 then
			SUI.Print(L("msg.market.timeout"))
			M.Stop(false)
			return
		end
	end
	M.Refresh()
end

-- ---------------------------------------------------------------- liste (bonnes affaires / toute la base)
local function cmp(a, b)
	local ka = a[M.sortKey]
	local kb = b[M.sortKey]
	if ka == nil and kb == nil then return a.id < b.id end
	if ka == nil then return false end
	if kb == nil then return true end
	if ka == kb then
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end
	if M.sortDesc then return ka > kb end
	return ka < kb
end

function M.Rebuild()
	local db = M.LoadDB()
	local list = {}
	local n = 0
	local minpct = C.Get("market.dealpct") or 25
	local minprofit = (C.Get("market.minprofit") or 5) * 100
	local minq = C.Get("market.minquality") or 0
	local filt = slower(M.filter or "")
	local scanId = db.scan.id
	local watch = (M.mode == "watch") and M.WatchList() or nil
	if M.mode == "craft" then
		for id, rc in pairs(M.CraftBook()) do
			local e = db.items[id]
			local cost, sale = M.CraftCost(id, rc)
			if e and cost and sale and (filt == "" or sfind(slower(e.n or ""), filt, 1, true)) then
				local cut = C.Get("market.cut") or 5
				local profit = floor(sale * (100 - cut) / 100) - cost
				if profit >= minprofit then
					n = n + 1
					list[n] = { id = id, e = e, name = slower(e.n or ""), now = cost, val = sale, pct = floor(profit * 100 / cost), profit = profit, offers = e.no }
				end
			end
		end
	end
	for id, e in pairs(M.mode == "craft" and {} or db.items) do
		local ok = true
		if (e.q or 0) < minq then ok = false end
		if ok and filt ~= "" and not sfind(slower(e.n or ""), filt, 1, true) then ok = false end
		if ok and watch and not watch[slower(e.n or "")] then ok = false end
		local pct, profit = M.Metrics(e)
		local val = e.md
		if ok and M.mode == "deals" then
			if e.s ~= scanId or not pct or pct < minpct or profit < minprofit or not M.Reliable(e) then ok = false end
		elseif ok and M.mode == "vendor" then
			-- revente au marchand : plus bas prix de l'hotel sous le prix de vente du marchand (pas de commission, pas d'attente)
			local tt = SUI.Tooltip
			local sp = tt and tt.SellPrice and tt.SellPrice(id)
			if e.s ~= scanId or not e.mn or not sp or e.mn >= sp then
				ok = false
			else
				val = sp
				profit = sp - e.mn
				pct = floor(profit * 100 / sp)
				if profit < minprofit then ok = false end
			end
		end
		if ok then
			n = n + 1
			list[n] = { id = id, e = e, name = slower(e.n or ""), now = e.mn, val = val, pct = pct, profit = profit, offers = e.no }
		end
	end
	tsort(list, cmp)
	M.list = list
	M.nlist = n
	if M.offset > n - NROWS then M.offset = n - NROWS end
	if M.offset < 0 then M.offset = 0 end
	M.Refresh()
end

-- ---------------------------------------------------------------- recettes (cout de fabrication)
-- Les recettes sont lues a l'ouverture d'une fenetre de metier : db.craft[idProduit] = { c = quantite fabriquee, r = { [idComposant] = quantite } }
function M.CraftBook()
	local db = M.LoadDB()
	if type(db.craft) ~= "table" then db.craft = {} end
	return db.craft
end

function M.CraftCount()
	local n = 0
	for _ in pairs(M.CraftBook()) do n = n + 1 end
	return n
end

-- Cout des composants (plus bas prix de la base) et valeur de vente du produit ; nil si un prix manque
function M.CraftCost(id, rc)
	local items = M.LoadDB().items
	local cost = 0
	for rid, q in pairs(rc.r) do
		local e = items[rid]
		if not e or not e.mn then return nil, nil end
		cost = cost + e.mn * q
	end
	local pe = items[id]
	local val = pe and (pe.md or pe.mn)
	if not val or cost <= 0 then return nil, nil end
	return cost, val * (rc.c or 1)
end

function M.ScanTrade()
	if not M.on or not GetNumTradeSkills then return end
	local book = M.CraftBook()
	local added = 0
	for i = 1, GetNumTradeSkills() do
		local name, kind = GetTradeSkillInfo(i)
		local link = name and kind ~= "header" and GetTradeSkillItemLink and GetTradeSkillItemLink(i)
		local id = link and idOf(link)
		if id then
			local r, any = {}, false
			for j = 1, (GetTradeSkillNumReagents(i) or 0) do
				local rl = GetTradeSkillReagentItemLink(i, j)
				local rid = rl and idOf(rl)
				local _, _, cnt = GetTradeSkillReagentInfo(i, j)
				if rid then r[rid] = cnt or 1; any = true end
			end
			if any then
				local made = GetTradeSkillNumMade and GetTradeSkillNumMade(i) or 1
				if not book[id] then added = added + 1 end
				book[id] = { c = made and made > 0 and made or 1, r = r }
			end
		end
	end
	if added > 0 then SUI.Print(L("msg.market.craft.learned", added)) end
end

-- L'objet choisi est-il dans la liste d'achats ?
function M.IsTracked(id)
	local e = id and M.LoadDB().items[id]
	return e ~= nil and e.n ~= nil and M.WatchList()[slower(e.n)] ~= nil
end

-- Ajoute l'objet choisi a la liste d'achats (prix voulu : valeur marche moins l'ecart des bonnes affaires, sinon 90 % du plus bas) ou l'en retire.
function M.TrackSel()
	local e = M.sel and M.LoadDB().items[M.sel]
	if not e or not e.n then return end
	if M.IsTracked(M.sel) then
		M.WatchDel(e.n)
		SUI.Print(L("msg.market.watch.removed", e.n))
	else
		local max
		if e.md and e.md > 0 then
			max = floor(e.md * (100 - (C.Get("market.dealpct") or 25)) / 100)
		elseif e.mn then
			max = floor(e.mn * 0.9)
		end
		if not max or max < 1 then max = e.mn or 1 end
		M.WatchAdd(e.n, max)
		SUI.Print(L("msg.market.watch.added", e.n, money(max)))
	end
	if M.mode == "watch" then M.Rebuild() else M.Refresh() end
end

function M.SetMode(m)
	M.mode = m
	if m == "deals" or m == "vendor" or m == "craft" then
		M.sortKey, M.sortDesc = "profit", true
	else
		M.sortKey, M.sortDesc = "name", false
	end
	M.offset = 0
	M.sel = nil
	M.Rebuild()
end

function M.SetSort(key)
	if M.sortKey == key then
		M.sortDesc = not M.sortDesc
	else
		M.sortKey = key
		M.sortDesc = (key ~= "name")
	end
	M.offset = 0
	M.Rebuild()
end

function M.Scroll(d)
	local o = M.offset + d
	local maxo = M.nlist - NROWS
	if o > maxo then o = maxo end
	if o < 0 then o = 0 end
	if o ~= M.offset then
		M.offset = o
		M.Refresh()
	end
end

function M.Select(pos)
	local it = M.list[M.offset + pos]
	if it then
		M.sel = it.id
		M.Refresh()
	end
end

function M.SearchSel()
	local e = M.sel and M.LoadDB().items[M.sel]
	local au = SUI.Auction
	if not e then return end
	if not (au and au.open) then
		SUI.Print(L("msg.market.needah"))
		return
	end
	if M.sc then M.Stop(false) end
	if au.SetTab then au.SetTab(1) end
	if au.Search then au.Search(e.n) end
end

-- ---------------------------------------------------------------- infobulles
function M.AddTip(link)
	if not M.on or not C.Get("market.tooltip") then return end
	local id = idOf(link)
	local e = id and M.LoadDB().items[id]
	local gt = getglobal("GameTooltip")
	if not e or not gt or not e.md then return end
	local cnt = (SUI.Tooltip and SUI.Tooltip.count) or 1
	if type(cnt) ~= "number" or cnt < 1 then cnt = 1 end
	local v = money(e.md * cnt)
	if cnt > 1 then v = v .. " (" .. money(e.md) .. ")" end
	gt:AddDoubleLine(L("msg.market.tip.value"), v, T.c.dim[1], T.c.dim[2], T.c.dim[3], T.c.text[1], T.c.text[2], T.c.text[3])
	if e.mn then
		gt:AddDoubleLine(L("msg.market.tip.low"), money(e.mn) .. "  (" .. (e.no or 0) .. ")", T.c.dim[1], T.c.dim[2], T.c.dim[3], T.c.text[1], T.c.text[2], T.c.text[3])
	end
end

-- ---------------------------------------------------------------- fenetre
local COLS = {
	{ key = "name", x = 30, w = 300, j = "LEFT", tk = "msg.market.col.item" },
	{ key = "now", x = 332, w = 86, j = "RIGHT", tk = "msg.market.col.now" },
	{ key = "val", x = 422, w = 86, j = "RIGHT", tk = "msg.market.col.value" },
	{ key = "pct", x = 512, w = 50, j = "RIGHT", tk = "msg.market.col.pct" },
	{ key = "profit", x = 566, w = 90, j = "RIGHT", tk = "msg.market.col.profit" },
	{ key = "offers", x = 660, w = 48, j = "RIGHT", tk = "msg.market.col.offers" },
}

local function ageText(t)
	if not t or t <= 0 or not time then return L("msg.market.never") end
	local s = time() - t
	if s < 90 then return L("msg.market.age.now") end
	if s < 5400 then return L("msg.market.age.min", floor(s / 60)) end
	if s < 129600 then return L("msg.market.age.hour", floor(s / 3600)) end
	return L("msg.market.age.day", floor(s / 86400))
end

function M.Build()
	if M.win then return M.win end
	local f = T.Panel(UIParent, WINW, WINH)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:SetScript("OnMouseWheel", function() M.Scroll(-arg1 * 3) end)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:Hide()
	M.win = f
	f.title = T.Text(f, 14, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	f.title:SetText(L("msg.market.title"))
	f.info = T.Text(f, 10, T.c.dim, "LEFT")
	f.info:SetPoint("LEFT", f.title, "RIGHT", 12, 0)
	f.close = T.Button(f, "x", 20, 20, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	-- rangee scan : bouton, arret, barre de progression
	f.bScan = T.Button(f, L("msg.market.btn.scan"), 150, 22, function() M.Start() end)
	f.bScan:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
	f.bStop = T.Button(f, L("msg.market.btn.stop"), 70, 22, function() M.Stop(false) end)
	f.bStop:SetPoint("LEFT", f.bScan, "RIGHT", 6, 0)
	f.bar = T.Bar(f)
	f.bar:SetPoint("LEFT", f.bStop, "RIGHT", 10, 0)
	f.bar:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	f.bar:SetHeight(18)
	f.bar.txt = T.Text(f.bar, 10, T.c.text, "CENTER")
	f.bar.txt:SetPoint("CENTER", f.bar, "CENTER", 0, 0)
	-- rangee mode + filtre
	f.bDeals = T.Button(f, L("msg.market.mode.deals"), 110, 22, function() M.SetMode("deals") end)
	f.bDeals:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -64)
	f.bAll = T.Button(f, L("msg.market.mode.all"), 120, 22, function() M.SetMode("all") end)
	f.bAll:SetPoint("LEFT", f.bDeals, "RIGHT", 4, 0)
	f.bWatch = T.Button(f, L("msg.market.mode.watch"), 100, 22, function() M.SetMode("watch") end)
	f.bWatch:SetPoint("LEFT", f.bAll, "RIGHT", 4, 0)
	f.bVendor = T.Button(f, L("msg.market.mode.vendor"), 130, 22, function() M.SetMode("vendor") end)
	f.bVendor:SetPoint("LEFT", f.bWatch, "RIGHT", 4, 0)
	f.bCraft = T.Button(f, L("msg.market.mode.craft"), 100, 22, function() M.SetMode("craft") end)
	f.bCraft:SetPoint("LEFT", f.bVendor, "RIGHT", 4, 0)
	f.edit = T.Edit(f, 140, 22)
	f.edit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -64)
	f.edit:SetScript("OnTextChanged", function()
		local t = this:GetText() or ""
		if t ~= M.filter then
			M.filter = t
			M.offset = 0
			M.Rebuild()
		end
	end)
	f.editL = T.Text(f, 10, T.c.dim, "RIGHT")
	f.editL:SetPoint("RIGHT", f.edit, "LEFT", -6, 0)
	f.editL:SetText(L("msg.market.filter"))
	-- en-tetes de colonnes (clic = trier)
	f.heads = {}
	for i = 1, getn(COLS) do
		local c = COLS[i]
		local h = T.Button(f, L(c.tk), c.w - 2, 18, function() M.SetSort(this.key) end)
		h.key = c.key
		h:SetPoint("TOPLEFT", f, "TOPLEFT", c.x, -92)
		f.heads[i] = h
	end
	-- lignes
	f.rows = {}
	for i = 1, NROWS do
		local r = CreateFrame("Button", nil, f)
		r:SetWidth(WINW - 24)
		r:SetHeight(22)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -114 - (i - 1) * 23)
		r.pos = i
		r:RegisterForClicks("LeftButtonUp")
		r.bg = r:CreateTexture(nil, "BACKGROUND")
		r.bg:SetAllPoints(r)
		r.bg:SetTexture(1, 1, 1, 0)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetWidth(18)
		r.icon:SetHeight(18)
		r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
		r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		r.cell = {}
		for k = 1, getn(COLS) do
			local c = COLS[k]
			local fs = T.Text(r, 11, T.c.text, c.j)
			fs:SetPoint("LEFT", r, "LEFT", c.x - 12 + 4, 0)
			fs:SetWidth(c.w - 8)
			r.cell[c.key] = fs
		end
		r:SetScript("OnClick", function() M.Select(this.pos) end)
		r:SetScript("OnDoubleClick", function()
			M.Select(this.pos)
			M.SearchSel()
		end)
		r:SetScript("OnEnter", function()
			local it = M.list[M.offset + this.pos]
			if not it then return end
			local gt = getglobal("GameTooltip")
			gt:SetOwner(this, "ANCHOR_RIGHT")
			local ok = pcall(gt.SetHyperlink, gt, "item:" .. it.id .. ":0:0:0")
			if not ok or gt:NumLines() == 0 then gt:SetText(it.e.n or "?", qcolor(it.e.q)) end
			gt:AddLine(L("msg.market.row.tip"), T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
			gt:Show()
		end)
		r:SetScript("OnLeave", function()
			local gt = getglobal("GameTooltip")
			if gt then gt:Hide() end
		end)
		r:Hide()
		f.rows[i] = r
	end
	f.empty = T.Text(f, 12, T.c.dim, "CENTER")
	f.empty:SetPoint("CENTER", f, "CENTER", 0, 20)
	f.empty:SetWidth(WINW - 80)
	-- bandeau detail : courbe de prix de l'objet choisi
	f.dName = T.Text(f, 12, T.c.text, "LEFT")
	f.dName:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 66)
	f.dName:SetWidth(300)
	f.dInfo = T.Text(f, 10, T.c.dim, "LEFT")
	f.dInfo:SetPoint("TOPLEFT", f.dName, "BOTTOMLEFT", 0, -2)
	f.dInfo:SetWidth(300)
	f.bars = {}
	for i = 1, NHIST do
		local b = f:CreateTexture(nil, "ARTWORK")
		b:SetWidth(14)
		b:SetHeight(1)
		b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 340 + (i - 1) * 18, 30)
		b:SetTexture(1, 1, 1, 0.6)
		b:Hide()
		f.bars[i] = b
	end
	f.bSearch = T.Button(f, L("msg.market.btn.search"), 130, 22, function() M.SearchSel() end)
	f.bSearch:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
	f.bClear = T.Button(f, L("msg.market.btn.clear"), 110, 22, function() M.Clear() end)
	f.bClear:SetPoint("LEFT", f.bSearch, "RIGHT", 6, 0)
	f.bTrack = T.Button(f, L("msg.market.btn.track"), 150, 22, function() M.TrackSel() end)
	f.bTrack:SetPoint("LEFT", f.bClear, "RIGHT", 6, 0)
	f.help = T.Text(f, 10, T.c.dim, "RIGHT")
	f.help:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 14)
	f.help:SetWidth(260)
	f.help:SetText(L("msg.market.help"))
	T.GearButton(f, "market", { size = 16, point = "TOPRIGHT", x = -34, y = -10, title = L("msg.market.gear") })
	T.OnAccent(function() if M.win and M.win:IsShown() then M.Refresh() end end)
	return f
end

function M.Refresh()
	local f = M.win
	if not f or not f:IsShown() then return end
	local db = M.LoadDB()
	local sc = M.sc
	-- en-tete d'etat
	setText(f.info, L("msg.market.info", M.Count(), ageText(db.scan.t)))
	-- barre de progression
	if sc then
		f.bar:SetMinMaxValues(0, sc.pages)
		f.bar:SetValue(sc.page)
		setText(f.bar.txt, L("msg.market.progress", sc.page + 1, sc.pages, sc.lots))
		f.bStop:Show()
	else
		f.bar:SetMinMaxValues(0, 1)
		f.bar:SetValue(0)
		setText(f.bar.txt, db.scan.t and db.scan.t > 0 and L("msg.market.last", db.scan.items or 0, db.scan.lots or 0) or L("msg.market.noscan"))
		f.bStop:Hide()
	end
	local au = SUI.Auction
	local ready = au and au.open and not sc
	if ready then f.bScan:Show() else f.bScan:Hide() end
	f.bDeals:SetAlpha(M.mode == "deals" and 1 or 0.6)
	f.bAll:SetAlpha(M.mode == "all" and 1 or 0.6)
	f.bWatch:SetAlpha(M.mode == "watch" and 1 or 0.6)
	f.bVendor:SetAlpha(M.mode == "vendor" and 1 or 0.6)
	f.bCraft:SetAlpha(M.mode == "craft" and 1 or 0.6)
	for i = 1, getn(COLS) do
		local c = COLS[i]
		local mark = ""
		if M.sortKey == c.key then mark = M.sortDesc and " v" or " ^" end
		local tk = c.tk
		if c.key == "val" and M.mode == "vendor" then tk = "msg.market.col.vendor" end
		if M.mode == "craft" then
			if c.key == "now" then tk = "msg.market.col.cost" elseif c.key == "val" then tk = "msg.market.col.sale" end
		end
		f.heads[i].label:SetText(L(tk) .. mark)
	end
	-- lignes
	local ar, ag, ab = T.Accent()
	for i = 1, NROWS do
		local r = f.rows[i]
		local it = M.list[M.offset + i]
		if it then
			local e = it.e
			r.icon:SetTexture("Interface\\Icons\\" .. (e.t or "INV_Misc_QuestionMark"))
			local cr, cg, cb = qcolor(e.q)
			r.cell.name:SetTextColor(cr, cg, cb, 1)
			setText(r.cell.name, e.n or "?")
			setText(r.cell.now, it.now and money(it.now) or "-")
			setText(r.cell.val, it.val and money(it.val) or "-")
			if it.pct then
				setText(r.cell.pct, it.pct .. "%")
				local pc = T.c.dim
				if it.pct >= 40 then pc = T.c.good elseif it.pct >= 15 then pc = T.c.warn end
				r.cell.pct:SetTextColor(pc[1], pc[2], pc[3], 1)
			else
				setText(r.cell.pct, "-")
			end
			if it.profit then
				setText(r.cell.profit, money(it.profit))
				local fc = (it.profit > 0) and T.c.good or T.c.bad
				r.cell.profit:SetTextColor(fc[1], fc[2], fc[3], 1)
			else
				setText(r.cell.profit, "-")
			end
			setText(r.cell.offers, tostring(it.offers or 0))
			if M.sel == it.id then
				r.bg:SetTexture(ar, ag, ab, 0.28)
			elseif i / 2 == floor(i / 2) then
				r.bg:SetTexture(1, 1, 1, 0.05)
			else
				r.bg:SetTexture(1, 1, 1, 0.02)
			end
			r:Show()
		else
			r:Hide()
		end
	end
	if M.nlist == 0 then
		local key = "msg.market.empty.nodata"
		if M.Count() > 0 then key = (M.mode == "deals") and "msg.market.empty.deals" or (M.mode == "watch" and "msg.market.empty.watch" or (M.mode == "vendor" and "msg.market.empty.vendor" or (M.mode == "craft" and "msg.market.empty.craft" or "msg.market.empty.filter"))) end
		setText(f.empty, L(key))
		f.empty:Show()
	else
		f.empty:Hide()
	end
	-- detail
	local e = M.sel and db.items[M.sel]
	if e then
		local cr, cg, cb = qcolor(e.q)
		f.dName:SetTextColor(cr, cg, cb, 1)
		setText(f.dName, e.n or "?")
		local pct, profit = M.Metrics(e)
		setText(f.dInfo, L("msg.market.detail", e.mn and money(e.mn) or "-", e.md and money(e.md) or "-", e.no or 0))
		local days, vals = {}, {}
		local n = histParse(e.h, days, vals)
		local mx = 1
		for i = 1, n do
			if vals[i] > mx then mx = vals[i] end
		end
		for i = 1, NHIST do
			local b = f.bars[i]
			if i <= n then
				local h = floor(vals[i] * 34 / mx)
				if h < 2 then h = 2 end
				b:SetHeight(h)
				b:Show()
			else
				b:Hide()
			end
		end
		f.bSearch:Show()
		f.bTrack:Show()
		T.SetButtonText(f.bTrack, L(M.IsTracked(M.sel) and "msg.market.btn.untrack" or "msg.market.btn.track"))
	else
		setText(f.dName, "")
		setText(f.dInfo, "")
		for i = 1, NHIST do f.bars[i]:Hide() end
		f.bSearch:Hide()
		f.bTrack:Hide()
	end
end

function M.Open()
	if not M.on then return end
	M.LoadDB()
	local f = M.Build()
	f:Show()
	M.Rebuild()
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.Toggle()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

-- onglet lateral colle au panneau de l'hotel des ventes
function M.Attach()
	local au = SUI.Auction
	local pf = au and au.frame
	if not pf or M.tab then return end
	local b = T.Button(pf, L("msg.market.btn.tab"), 78, 22, function() M.Toggle() end)
	b:SetPoint("TOPRIGHT", pf, "TOPLEFT", -2, -8)
	M.tab = b
end

function M.OnShow()
	M.Attach()
	M.SnipeRefresh()
	if M.win and M.win:IsShown() then M.Refresh() end
end

function M.OnClose()
	M.SnipeRefresh()
	if M.sc then M.Stop(false) end
	if M.win and M.win:IsShown() then M.Refresh() end
end

-- ---------------------------------------------------------------- liste d'achats : "je veux cet objet sous ce prix"
-- db.watch[nom en minuscules] = { n = nom, max = prix unitaire maxi en cuivres } ; verifiee a la fin de chaque scan.
function M.WatchList()
	local db = M.LoadDB()
	if type(db.watch) ~= "table" then db.watch = {} end
	return db.watch
end

function M.WatchAdd(name, max)
	if type(name) ~= "string" or name == "" or not max or max < 1 then return false end
	M.WatchList()[string.lower(name)] = { n = name, max = floor(max) }
	return true
end

function M.WatchDel(name)
	local w = M.WatchList()
	local k = string.lower(name or "")
	if not w[k] then return false end
	w[k] = nil
	return true
end

function M.WatchCount()
	local n = 0
	for _ in pairs(M.WatchList()) do n = n + 1 end
	return n
end

-- Objets de la base dont le plus bas prix est au plus le prix voulu : { { id, n, mn, max }, ... } tries par nom.
function M.WatchHits()
	local w = M.WatchList()
	local hits = {}
	for id, e in pairs(M.LoadDB().items) do
		local k = e.n and string.lower(e.n)
		local it = k and w[k]
		if it and e.mn and e.mn <= it.max then tinsert(hits, { id = id, n = e.n, mn = e.mn, max = it.max }) end
	end
	tsort(hits, function(a, b) return a.n < b.n end)
	return hits
end

-- Points d'accroche pour les futures fonctions (achat, revente) : fn(hit) est appelee pour chaque alerte annoncee,
-- hit = { id, n, mn, max } (prix unitaire le plus bas, prix voulu).
M.hitHandlers = {}
M.reported = {}          -- id -> dernier prix annonce (le sniper n'annonce qu'une nouveaute)
function M.OnHit(fn)
	tinsert(M.hitHandlers, fn)
end

function M.WatchReport(onlyNew)
	if M.WatchCount() == 0 then return 0 end
	local hits = M.WatchHits()
	local seen = {}
	local n = 0
	for i = 1, getn(hits) do
		local h = hits[i]
		seen[h.id] = true
		if not (onlyNew and M.reported[h.id] == h.mn) then
			M.reported[h.id] = h.mn
			n = n + 1
			SUI.Print(L("msg.market.watch.hit", h.n, money(h.mn), money(h.max)))
			for k = 1, getn(M.hitHandlers) do M.hitHandlers[k](h) end
		end
	end
	for id in pairs(M.reported) do
		if not seen[id] then M.reported[id] = nil end
	end
	return n
end

-- ---------------------------------------------------------------- sniper : rescan cible periodique pendant que l'hotel est ouvert
function M.SnipeTick()
	local au = SUI.Auction
	if M.sc or not (au and au.open) or M.WatchCount() == 0 then return end
	local names = {}
	for _, it in pairs(M.WatchList()) do tinsert(names, it.n) end
	tsort(names)
	M.Start(names, true)
end

function M.SnipeRefresh()
	if M.snipeTask then
		SUI.Cancel(M.snipeTask)
		M.snipeTask = nil
	end
	local au = SUI.Auction
	if M.on and C.Get("market.snipe") and au and au.open then
		local sec = C.Get("market.snipesec") or 30
		if sec < 15 then sec = 15 end
		M.snipeTask = SUI.Every(sec, M.SnipeTick, "market.snipe")
	end
end

local function watchCmd(rest)
	local _, _, sub, arg = string.find(rest or "", "^(%S+)%s*(.-)$")
	if sub == "add" then
		local _, _, p, name = string.find(arg, "^(%S+)%s+(.+)$")
		local au = SUI.Auction
		local max = p and ((au and au.ParseMoney and au.ParseMoney(p)) or (tonumber(p) and tonumber(p) * 10000))
		if M.WatchAdd(name, max) then SUI.Print(L("msg.market.watch.added", name, money(max))) else SUI.Print(L("msg.market.watch.usage")) end
	elseif sub == "del" then
		if M.WatchDel(arg) then SUI.Print(L("msg.market.watch.removed", arg)) else SUI.Print(L("msg.market.watch.none", arg)) end
	elseif sub == "scan" then
		local names = {}
		for _, it in pairs(M.WatchList()) do tinsert(names, it.n) end
		if getn(names) == 0 then SUI.Print(L("msg.market.watch.empty")) return end
		tsort(names)
		M.Start(names)
	elseif sub == "clear" then
		M.LoadDB().watch = {}
		SUI.Print(L("msg.market.watch.cleared"))
	else
		local w = M.WatchList()
		if M.WatchCount() == 0 then SUI.Print(L("msg.market.watch.empty")) return end
		for _, it in pairs(w) do SUI.Print(L("msg.market.watch.line", it.n, money(it.max))) end
		M.WatchReport()
	end
end

-- ---------------------------------------------------------------- module
function M.Enable()
	M.on = true
	M.LoadDB()
	SUI.On("AUCTION_HOUSE_SHOW", M.OnShow)
	SUI.On("AUCTION_HOUSE_CLOSED", M.OnClose)
	SUI.On("TRADE_SKILL_SHOW", M.ScanTrade)
	SUI.After(1, M.Attach, "market.attach")
	if not M.watching then
		M.watching = true
		C.Watch("market.", function()
			M.SnipeRefresh()
			if M.win and M.win:IsShown() then M.Rebuild() end
		end)
	end
end

function M.Disable()
	M.on = false
	M.SnipeRefresh()
	SUI.Off("AUCTION_HOUSE_SHOW", M.OnShow)
	SUI.Off("AUCTION_HOUSE_CLOSED", M.OnClose)
	SUI.Off("TRADE_SKILL_SHOW", M.ScanTrade)
	if M.sc then M.Stop(true) end
	M.Close()
	if M.tab then M.tab:Hide() end
end

SUI.RegisterCategory("market", 57)
SUI.RegisterAction("market", "mod.menu.act.market", function() M.Open() end, 130)

local function opt(key, typ, order, def, extra)
	local o = { key = "market." .. key, type = typ, cat = "market", label = "opt.market." .. key, tip = "tip.market." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("market", {
	default = false,
	cost = "light",
	raid = "off",
	options = {
		opt("dealpct", "number", 10, 25, { min = 5, max = 80, step = 1, simple = true }),
		opt("minprofit", "number", 20, 5, { min = 0, max = 2000, step = 1, simple = true }),
		opt("minquality", "number", 30, 0, { min = 0, max = 5, step = 1 }),
		opt("cut", "number", 40, 5, { min = 0, max = 20, step = 1 }),
		opt("tooltip", "bool", 50, true, { simple = true }),
		opt("snipe", "bool", 60, false),
		opt("snipesec", "number", 70, 30, { min = 15, max = 300, step = 5 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("market", function(rest)
	rest = rest or ""
	if rest == "scan" then
		M.Start()
	elseif rest == "stop" then
		M.Stop(false)
	elseif string.sub(rest, 1, 5) == "watch" then
		watchCmd(string.sub(rest, 7))
	elseif rest == "clear" then
		M.Clear()
		SUI.Print(L("msg.market.cleared"))
	else
		if not M.on then SUI.Print(L("msg.market.off")) return end
		M.Toggle()
	end
end, "help.market")
