-- ShikiUI Auction : hotel des ventes ShikiUI en 4 onglets (Chercher / Vendre / Mes ventes / Analyse) ; reecrit, aucune ligne copiee.
-- Cout declare : LIGHT. Evenements : AUCTION_HOUSE_SHOW / AUCTION_HOUSE_CLOSED / NEW_AUCTION_UPDATE (hotel ouvert seulement) ;
-- AUCTION_ITEM_LIST_UPDATE n'est ecoute que pendant une recherche ou la localisation d'un achat ; AUCTION_OWNED_LIST_UPDATE seulement
-- quand l'onglet Mes ventes est affiche. La minuterie partagee (SUI.Every, 0,3 s) n'existe que pendant une recherche, un achat ou une pile.
-- Aucune table creee en combat ni pendant la lecture d'une page : 200 lignes de resultat preallouees (tableaux paralleles, insertion triee).
-- Le module est coupe par le mode Raid (raid = "off").
-- CHERCHER : /sui auction search <nom> (ou le champ du panneau, avec historique, favoris et suggestions) interroge page par page (50 par
--  page, auction.maxpages pages au plus, sans clic), attend CanSendAuctionQuery avant chaque requete, abandonne apres 8 s sans reponse.
--  Filtres : classe, sous-classe, niveau min/max, qualite, utilisable. Les resultats sont gardes tries par prix de rachat unitaire (les
--  encheres sans rachat viennent apres) ; l'affichage se retrie par prix unitaire, total, vendeur ou duree restante. Chaque ligne montre
--  l'ecart a un prix de reference (mediane de la recherche, sinon moyenne des medianes de l'historique local) : "bonne affaire".
-- ACHETER / ENCHERIR : jamais sans le clic de confirmation d'une fenetre qui rappelle objet, quantite, prix, vendeur, ecart a la reference
--  et argent restant. Le clic relance la requete de la page de l'enchere, retrouve la ligne exacte (nom, quantite, rachat, vendeur) et
--  seulement alors appelle PlaceAuctionBid ; si la ligne a change ou disparu, rien n'est achete. Aucun achat automatique.
-- VENDRE : l'objet se glisse dans l'emplacement du panneau (ou /sui auction sell <sac> <case>) ; prix suggere (sous le moins cher, mediane,
--  marge fixe), prix par unite ou par lot, duree, vente en LOTS (N lots de S : la pile est rangee, scindee puis posee lot par lot), resume
--  du depot, de la commission et de la recette ; mise en vente confirmee (auction.confirmpost : une demande arme 10 s, la seconde execute).
-- MES VENTES : liste de mes encheres (etat, enchere en cours, ecart au plus bas connu), annulation confirmee (armee 10 s).
-- ANALYSE : sur la recherche en cours seulement (jamais tout l'hotel) : offres, min / mediane / moyenne / max par unite, ecart, distribution
--  en barres, valeur d'un lot, tendance contre l'historique local, profit potentiel de revente (achat sous la reference - marge).
-- MEMOIRE (Config, chaines compactes plafonnees) : auction.prices (plus bas prix, 40 objets), auction.hist (une valeur par jour et par
--  objet : jour, plus bas, mediane, offres ; 60 objets, auction.histdays jours), auction.recent (12 recherches), auction.favs (30 noms).
-- SOURCES (relevees dans aux-addon installe, jamais executees ici) : QueryAuctionItems(nom, niveau min, niveau max, emplacement, classe,
--  sous-classe, page, utilisable, qualite), CanSendAuctionQuery, GetNumAuctionItems("list"|"owner") -> lot, total, GetAuctionItemInfo(type, i) ->
--  nom, texture, quantite, qualite, utilisable, niveau, mise, increment, rachat, offre, meilleur enchereur, vendeur, GetAuctionItemLink,
--  GetAuctionItemTimeLeft (1 a 4), GetAuctionSellItemInfo, ClickAuctionSellItemButton, StartAuction(mise, rachat, duree en minutes
--  120/480/1440), CalculateAuctionDeposit(duree), PlaceAuctionBid("list", i, montant), CancelAuction(i), GetOwnerAuctionItems(),
--  GetAuctionItemClasses / GetAuctionItemSubClasses, AUCTION_HOUSE_SHOW / AUCTION_HOUSE_CLOSED / AUCTION_ITEM_LIST_UPDATE /
--  AUCTION_OWNED_LIST_UPDATE / NEW_AUCTION_UPDATE. Licence d'aux : voir son dossier.
-- INTERFACE (option auction.ui, "shikiui" par defaut) : le cadre Blizzard (AuctionFrame) n'est jamais detruit ni cache par Hide() : en mode
--  ShikiUI il reste "affiche" (donc AUCTION_HOUSE_* et ses mises a jour continuent) mais invisible (alpha 0) et relegue au fond (strata
--  BACKGROUND, sous le panneau). Le bouton Blizzard du panneau (ou /sui ah) bascule vers l'interface Blizzard (alpha et strata rendus) et
--  inversement. La bascule vaut pour l'ouverture en cours ; l'option auction.ui (ou /sui ah blizzard|shikiui) fixe la valeur memorisee.
--  Sans panneau (auction.panel coupe) ou module coupe, l'interface Blizzard reste seule.
-- CLIENT 1.12 : le client change le niveau des cadres apres leur construction (voir Menu.SyncLevel) : tous les controles sont ENFANTS du
--  panneau ou d'une page et recales par M.SyncLevels (affichage, changement d'onglet, minuterie ; /sui auction diag).
-- NON VERIFIE EN JEU : tout ; l'argument qualite (nil quand tout est accepte) ; le 2e retour de GetNumAuctionItems ; PlaceAuctionBid sur
--  la liste "list" apres une nouvelle requete de la meme page ; GetOwnerAuctionItems et CancelAuction ; la pile en lots (SplitContainerItem
--  puis ClickAuctionSellItemButton) ; les durees reelles du serveur ; le glisser-deposer sur l'emplacement ; la position a cote de AuctionFrame.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
-- SUI.L ne formate que quatre arguments : les messages plus longs passent par LF.
local function LF(key, a, b, c, d, e, f)
	return string.format(L(key), a, b, c, d, e, f)
end
local T = SUI.Theme

local getn = table.getn
local sfind, ssub, slower, sformat = string.find, string.sub, string.lower, string.format
local floor = math.floor

local M = {}
SUI.Auction = M

local MAXRES = 200
local PAGE = 50
local TICK = 0.3
local BIG = 1000000000
local MAXOWN = 50
local NHIST = 60        -- objets gardes dans l'historique
local NBUCK = 10        -- barres de la distribution
local NHINT = 6         -- suggestions de recherche
local NROWS = 15        -- lignes de resultat preallouees
local NOWN = 12         -- lignes de Mes ventes
local NTREND = 14       -- barres de tendance
local DAY = 86400
local PW = 580          -- largeur du panneau
local NTAB = 4

M.on = false
M.open = false
M.scan = false          -- recherche en cours
M.state = "idle"        -- idle | query | wait
M.page = 0
M.pages = 1
M.query = nil           -- texte cherche
M.qlow = nil
M.sentAt = 0
M.n = 0                 -- nombre de resultats gardes
M.rName, M.rCnt, M.rUnit, M.rBid, M.rOwn, M.rQ, M.rLink, M.rKey, M.rLeft = {}, {}, {}, {}, {}, {}, {}, {}, {}
M.rTex, M.rBuy, M.rNext, M.rCur, M.rHigh, M.rPage, M.rIdx = {}, {}, {}, {}, {}, {}, {}
M.ex = { tex = nil, buy = 0, nextbid = 0, cur = 0, high = 0, page = 0, idx = 0 }    -- champs supplementaires de la ligne en cours de lecture
M.seen = 0              -- encheres lues pendant cette recherche
M.low, M.med, M.nbuy = nil, nil, 0
M.sugBuy, M.sugBid = nil, nil
M.ref, M.refSrc = nil, nil
M.itemId = nil
M.offset = 0
M.armUntil = 0
M.prices = {}           -- id -> cuivre
M.nprices = 0
M.order = {}            -- ordre d'insertion des prix memorises
M.hist = {}             -- id -> { name, n, d, mn, md, no } : un releve par jour
M.horder = {}           -- ids, le plus recent en dernier
M.recent, M.favs = {}, {}
M.me = nil
M.dirty = true
M.view = "shikiui"      -- interface montree pour l'ouverture en cours : shikiui | blizzard
M.hid = false           -- vrai tant que le cadre Blizzard est rendu invisible par ce module
M.bz = nil              -- { alpha, strata } d'origine du cadre Blizzard
M.tab = 1
M.ord, M.nord, M.ordN = {}, 0, 0      -- ordre d'affichage (indices dans les tableaux r*) apres tri et filtre
M.sort, M.sortDesc = "unit", false
M.onlyDeals = false
M.sel = nil             -- position affichee de la ligne choisie
M.selName, M.selCnt, M.selBuy, M.selOwn = nil, nil, nil, nil
M.fClass, M.fSub, M.fMinL, M.fMaxL = nil, nil, nil, nil
M.classes = {}
M.hints, M.nh, M.hintFav = {}, 0, {}
M.loc, M.dlg = nil, nil
M.sellName, M.sellUnit, M.sellMode = nil, nil, "unit"
M.lots, M.size = 1, 1
M.q = nil               -- pile de lots en cours
M.oN = 0
M.oName, M.oCnt, M.oBuy, M.oBid, M.oCur, M.oHigh, M.oLeft, M.oTex, M.oQ, M.oLink = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
M.oSel, M.oOffset, M.cancelUntil = nil, 0, 0
M.an = { bk = {}, tk = {}, tv = {}, tr = {}, n = 0, nt = 0, ntr = 0, units = 0, sellers = 0 }
M.sellerSet = {}
M.colorEpoch = 1

-- ---------------------------------------------------------------- utilitaires
local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

function M.Money(c)
	c = c or 0
	local g = floor(c / 10000)
	local s = floor((c - g * 10000) / 100)
	return sformat("%dg %ds %dc", g, s, c - g * 10000 - s * 100)
end

-- Montant compact : les deux plus grandes unites non nulles (1g 20s, 6s 5c, 12c).
function M.MoneyShort(c)
	c = floor(c or 0)
	if c < 0 then c = 0 end
	local g = floor(c / 10000)
	local s = floor((c - g * 10000) / 100)
	local k = c - g * 10000 - s * 100
	if g > 0 then
		if s > 0 then return g .. "g " .. s .. "s" end
		return g .. "g"
	end
	if s > 0 then
		if k > 0 then return s .. "s " .. k .. "c" end
		return s .. "s"
	end
	return k .. "c"
end

-- Lit "12g 5s 3c", "1g20s", "50s", "12.5g" ; un nombre seul vaut des pieces d'or. Retourne des cuivres, ou nil.
function M.ParseMoney(text)
	if type(text) ~= "string" then return nil end
	local total, found = 0, false
	for num, unit in string.gfind(slower(text), "(%d+%.?%d*)%s*([gsc]?)") do
		local v = tonumber(num)
		if v then
			found = true
			if unit == "s" then total = total + v * 100
			elseif unit == "c" then total = total + v
			else total = total + v * 10000 end
		end
	end
	if not found then return nil end
	total = floor(total + 0.0001)
	if total < 1 then return nil end
	return total
end

local function idOf(link)
	local _, _, id = sfind(link or "", "item:(%d+)")
	return tonumber(id)
end

local function qcolor(q)
	local tbl = getglobal("ITEM_QUALITY_COLORS")
	local col = type(q) == "number" and tbl and tbl[q]
	if col then return col.r, col.g, col.b end    -- style:ok couleur de qualite (donnee de jeu)
	local c = T.c.text
	return c[1], c[2], c[3]
end

-- Couleur d'un texte seulement si elle change (jetons du style : relus apres un changement de style, voir M.OnRestyle).
local function setColor(fs, key, r, g, b)
	if fs.ck ~= key or fs.ce ~= M.colorEpoch then
		fs.ck, fs.ce = key, M.colorEpoch
		fs:SetTextColor(r, g, b, 1)
	end
end

local function tokColor(fs, tok)
	local c = T.c[tok]
	setColor(fs, tok, c[1], c[2], c[3])
end

-- Ecart a la reference en texte : "-23%" = 23 pour cent moins cher, "+8%" = plus cher.
local function dealText(pct)
	if pct >= 0 then return "-" .. pct .. "%" end
	return "+" .. (-pct) .. "%"
end

function M.Wallet()
	local fn = getglobal("GetMoney")
	if type(fn) == "function" then return fn() or 0 end
	return 0
end

function M.LeftText(n)
	n = n or 3
	if n < 1 then n = 1 end
	if n > 4 then n = 4 end
	return L("msg.auction.left." .. n)
end

-- ---------------------------------------------------------------- listes (recherches recentes, favoris)
local function listRead(key, dst, cap)
	for i = getn(dst), 1, -1 do dst[i] = nil end
	for item in string.gfind(C.Get(key) or "", "[^;]+") do
		if getn(dst) < cap then dst[getn(dst) + 1] = item end
	end
end

local function listWrite(key, src)
	M.selfWrite = true
	C.SetBase(key, table.concat(src, ";"))
	M.selfWrite = false
end

local function listFind(src, name)
	local low = slower(name)
	for i = 1, getn(src) do
		if slower(src[i]) == low then return i end
	end
	return nil
end

function M.ReadLists()
	listRead("auction.recent", M.recent, 12)
	listRead("auction.favs", M.favs, 30)
end

function M.AddRecent(name)
	name = string.gsub(name or "", ";", " ")
	if name == "" then return end
	local at = listFind(M.recent, name)
	if at then table.remove(M.recent, at) end
	table.insert(M.recent, 1, name)
	for i = getn(M.recent), 13, -1 do M.recent[i] = nil end
	listWrite("auction.recent", M.recent)
end

function M.IsFav(name)
	return name ~= nil and listFind(M.favs, name) ~= nil
end

function M.ToggleFav(name)
	name = string.gsub(name or "", ";", " ")
	if name == "" then SUI.Print(L("msg.auction.nofavname")) return false end
	local at = listFind(M.favs, name)
	if at then
		table.remove(M.favs, at)
		SUI.Print(L("msg.auction.favoff", name))
	else
		if getn(M.favs) >= 30 then table.remove(M.favs, 1) end
		table.insert(M.favs, name)
		SUI.Print(L("msg.auction.favon", name))
	end
	listWrite("auction.favs", M.favs)
	M.dirty = true
	M.Refresh()
	return true
end

function M.ClearLists()
	for i = getn(M.recent), 1, -1 do M.recent[i] = nil end
	listWrite("auction.recent", M.recent)
	M.dirty = true
end

-- ---------------------------------------------------------------- resultats
function M.Clear()
	M.n = 0
	M.seen = 0
	M.dup = {}   -- signatures des lots deja ajoutes (un UPDATE non sollicite fait relire la page : jamais deux fois le meme lot)
	M.low, M.med, M.nbuy = nil, nil, 0
	M.sugBuy, M.sugBid = nil, nil
	M.ref, M.refSrc = nil, nil
	M.itemId = nil
	M.offset = 0
	M.sel = nil
	M.nord = 0
	M.an.n = 0
	M.an.nt = 0
	M.an.ntr = 0
	M.an.min = nil
	M.dirty = true
end

-- Insertion triee par cle (prix de rachat unitaire, ou BIG + mise unitaire sans rachat). Au-dela de MAXRES, le plus cher sort.
-- Les champs supplementaires (icone, rachat total, prochaine mise, page, indice) viennent de M.ex.
function M.Add(name, count, unit, bid, owner, quality, link, left)
	local key = unit > 0 and unit or (BIG + bid)
	local n = M.n
	if n >= MAXRES and key >= M.rKey[n] then return end
	if n < MAXRES then n = n + 1 end
	local i = n
	while i > 1 and M.rKey[i - 1] > key do
		M.rName[i], M.rCnt[i], M.rUnit[i], M.rBid[i] = M.rName[i - 1], M.rCnt[i - 1], M.rUnit[i - 1], M.rBid[i - 1]
		M.rOwn[i], M.rQ[i], M.rLink[i], M.rKey[i], M.rLeft[i] = M.rOwn[i - 1], M.rQ[i - 1], M.rLink[i - 1], M.rKey[i - 1], M.rLeft[i - 1]
		M.rTex[i], M.rBuy[i], M.rNext[i], M.rCur[i] = M.rTex[i - 1], M.rBuy[i - 1], M.rNext[i - 1], M.rCur[i - 1]
		M.rHigh[i], M.rPage[i], M.rIdx[i] = M.rHigh[i - 1], M.rPage[i - 1], M.rIdx[i - 1]
		i = i - 1
	end
	M.rName[i], M.rCnt[i], M.rUnit[i], M.rBid[i], M.rOwn[i], M.rQ[i], M.rLink[i], M.rKey[i], M.rLeft[i] =
		name, count, unit, bid, owner, quality, link, key, left
	local ex = M.ex
	M.rTex[i], M.rBuy[i], M.rNext[i], M.rCur[i] = ex.tex, ex.buy, ex.nextbid, ex.cur
	M.rHigh[i], M.rPage[i], M.rIdx[i] = ex.high, ex.page, ex.idx
	M.n = n
end

local ARR = { "rName", "rCnt", "rUnit", "rBid", "rOwn", "rQ", "rLink", "rKey", "rLeft", "rTex", "rBuy", "rNext", "rCur", "rHigh", "rPage", "rIdx" }

-- Retire la ligne k (achat termine) et recalcule tout.
function M.Remove(k)
	if k < 1 or k > M.n then return end
	for j = 1, getn(ARR) do
		local a = M[ARR[j]]
		for i = k, M.n - 1 do a[i] = a[i + 1] end
		a[M.n] = nil
	end
	M.n = M.n - 1
	M.sel = nil
	M.Stats()
	M.Analyze()
	M.Resort()
	M.dirty = true
end

function M.ReadPage()
	local batch = GetNumAuctionItems("list")
	if not batch then return end
	local exact = C.Get("auction.exact")
	local ex = M.ex
	for i = 1, batch do
		local name, tex, count, quality, _, _, minBid, minInc, buyout, curBid, high, owner = GetAuctionItemInfo("list", i)
		if name then
			M.seen = M.seen + 1
			if not count or count < 1 then count = 1 end
			local link = GetAuctionItemLink("list", i)
			M.NoteItem(name, link, quality)
			-- Filtre local : nom exact (option) ou le nom COMMENCE par le texte cherche (le serveur 1.12 ne renvoie
			-- de toute facon que des noms commencant par le texte : un mot du milieu du nom ne peut etre trouve qu'en
			-- passant par la base d'objets et une recherche du nom complet).
			local low = slower(name)
			local ok = M.qlow == "" or (exact and low == M.qlow) or (not exact and string.find(low, M.qlow, 1, true) == 1)
			if ok then
				local unit = 0
				if buyout and buyout > 0 then unit = floor(buyout / count) end
				local bid = floor((minBid or 0) / count)
				curBid = curBid or 0
				ex.tex, ex.buy, ex.cur, ex.page, ex.idx = tex, buyout or 0, curBid, M.page, i
				ex.high = 0
				if high and high ~= "" then ex.high = (high == M.me) and 2 or 1 end
				if curBid > 0 then ex.nextbid = curBid + (minInc or 1) else ex.nextbid = minBid or 0 end
				-- dedoublonnage : signature avec page + index de ligne (un vendeur peut poser DEUX piles strictement
				-- identiques : ce sont deux lots distincts ; une RELECTURE de la meme page retombe sur les memes couples)
				local sig = M.page .. "#" .. i .. "#" .. name .. "#" .. count .. "#" .. (buyout or 0) .. "#" .. (minBid or 0) .. "#" .. curBid .. "#" .. (owner or "?")
				if not M.dup[sig] then
					M.dup[sig] = true
					M.Add(name, count, unit, bid, owner, quality, link, GetAuctionItemTimeLeft("list", i))
				end
			end
		end
	end
end

-- Statistiques et prix propose (encheres des autres joueurs avec un prix de rachat seulement).
function M.Stats()
	local low, nb = nil, 0
	local seq = 0
	for i = 1, M.n do
		if M.rUnit[i] > 0 and M.rOwn[i] ~= M.me then
			nb = nb + 1
			if not low then low = M.rUnit[i] end
		end
	end
	M.nbuy = nb
	M.low = low
	M.med = nil
	if nb > 0 then
		local target = floor((nb + 1) / 2)
		for i = 1, M.n do
			if M.rUnit[i] > 0 and M.rOwn[i] ~= M.me then
				seq = seq + 1
				if seq == target then
					M.med = M.rUnit[i]
					break
				end
			end
		end
	end
	M.Suggest()
end

function M.Suggest()
	local base = (C.Get("auction.basis") == "median") and M.med or M.low
	M.sugBuy, M.sugBid = nil, nil
	if not base then return end
	local cut = floor(base * C.Get("auction.undercutpct") / 100)
	local fixed = C.Get("auction.undercut")
	if fixed > cut then cut = fixed end
	if C.Get("auction.basis") == "fixed" then cut = fixed end
	local buy = base - cut
	if buy < 1 then buy = 1 end
	local bid = floor(buy * C.Get("auction.bidpct") / 100)
	if bid < 1 then bid = 1 end
	M.sugBuy, M.sugBid = buy, bid
end

-- ---------------------------------------------------------------- memoire des prix
local function pricesString()
	local s = ""
	for i = 1, getn(M.order) do
		local id = M.order[i]
		if s ~= "" then s = s .. "," end
		s = s .. id .. "=" .. M.prices[id]
	end
	return s
end

function M.ReadPrices()
	for k, _ in pairs(M.prices) do M.prices[k] = nil end
	for i = getn(M.order), 1, -1 do M.order[i] = nil end
	M.nprices = 0
	for id, p in string.gfind(C.Get("auction.prices") or "", "(%d+)=(%d+)") do
		local nid = tonumber(id)
		if nid and not M.prices[nid] and M.nprices < 40 then
			M.prices[nid] = tonumber(p)
			M.nprices = M.nprices + 1
			M.order[M.nprices] = nid
		end
	end
end

function M.RememberPrice(id, price)
	if not id or not price or price < 1 then return end
	if M.prices[id] then
		M.prices[id] = price
	else
		if M.nprices >= 40 then
			local old = M.order[1]
			M.prices[old] = nil
			for i = 1, M.nprices - 1 do M.order[i] = M.order[i + 1] end
			M.order[M.nprices] = nil
			M.nprices = M.nprices - 1
		end
		M.nprices = M.nprices + 1
		M.order[M.nprices] = id
		M.prices[id] = price
	end
	C.SetBase("auction.prices", pricesString())
end

-- ---------------------------------------------------------------- historique local : un releve par jour et par objet
-- Chaine compacte : "id^nom^jour:bas:mediane:offres,jour:...~id^nom^..." ; 60 objets (le moins recemment releve sort), auction.histdays jours.
function M.Day()
	local fn = getglobal("time")
	if type(fn) ~= "function" then return nil end
	return floor(fn() / DAY)
end

function M.HistRead()
	for k, _ in pairs(M.hist) do M.hist[k] = nil end
	for i = getn(M.horder), 1, -1 do M.horder[i] = nil end
	for rec in string.gfind(C.Get("auction.hist") or "", "[^~]+") do
		local _, _, id, name, days = sfind(rec, "^(%d+)%^([^%^]*)%^(.*)$")
		id = tonumber(id)
		if id and not M.hist[id] and getn(M.horder) < NHIST then
			local h = { name = name, n = 0, d = {}, mn = {}, md = {}, no = {} }
			for d, mn, md, no in string.gfind(days, "(%d+):(%d+):(%d+):(%d+)") do
				h.n = h.n + 1
				h.d[h.n], h.mn[h.n], h.md[h.n], h.no[h.n] = tonumber(d), tonumber(mn), tonumber(md), tonumber(no)
			end
			M.hist[id] = h
			M.horder[getn(M.horder) + 1] = id
		end
	end
end

function M.HistWrite()
	local parts = {}
	for i = 1, getn(M.horder) do
		local id = M.horder[i]
		local h = M.hist[id]
		local days = {}
		for j = 1, h.n do days[j] = h.d[j] .. ":" .. h.mn[j] .. ":" .. h.md[j] .. ":" .. h.no[j] end
		parts[i] = id .. "^" .. h.name .. "^" .. table.concat(days, ",")
	end
	M.selfWrite = true
	C.SetBase("auction.hist", table.concat(parts, "~") .. (getn(parts) > 0 and "~" or ""))
	M.selfWrite = false
end

function M.HistRecord(id, name, mn, md, no)
	local day = M.Day()
	if not day or not id or not mn or not md or mn < 1 or md < 1 then return false end
	local h = M.hist[id]
	if not h then
		if getn(M.horder) >= NHIST then
			M.hist[M.horder[1]] = nil
			table.remove(M.horder, 1)
		end
		h = { name = "", n = 0, d = {}, mn = {}, md = {}, no = {} }
		M.hist[id] = h
	else
		for i = 1, getn(M.horder) do
			if M.horder[i] == id then table.remove(M.horder, i) break end
		end
	end
	M.horder[getn(M.horder) + 1] = id
	h.name = string.gsub(name or "", "[%^~]", " ")
	if h.n > 0 and h.d[h.n] == day then
		h.mn[h.n], h.md[h.n], h.no[h.n] = mn, md, no or 0
	else
		local cap = C.Get("auction.histdays")
		while h.n >= cap do
			for i = 1, h.n - 1 do h.d[i], h.mn[i], h.md[i], h.no[i] = h.d[i + 1], h.mn[i + 1], h.md[i + 1], h.no[i + 1] end
			h.d[h.n], h.mn[h.n], h.md[h.n], h.no[h.n] = nil, nil, nil, nil
			h.n = h.n - 1
		end
		h.n = h.n + 1
		h.d[h.n], h.mn[h.n], h.md[h.n], h.no[h.n] = day, mn, md, no or 0
	end
	M.HistWrite()
	return true
end

-- Moyenne des medianes des jours PASSES (sans aujourd'hui) ; nombre de jours.
function M.HistStats(id)
	local h = id and M.hist[id]
	if not h or h.n == 0 then return nil end
	local today = M.Day()
	local sum, cnt = 0, 0
	for j = 1, h.n do
		if h.d[j] ~= today and h.md[j] > 0 then
			sum = sum + h.md[j]
			cnt = cnt + 1
		end
	end
	if cnt == 0 then return nil end
	return floor(sum / cnt), cnt
end

function M.HistClear()
	for k, _ in pairs(M.hist) do M.hist[k] = nil end
	for i = getn(M.horder), 1, -1 do M.horder[i] = nil end
	M.HistWrite()
	M.an.ntr = 0
	M.dirty = true
end

-- ---------------------------------------------------------------- analyse de la recherche en cours
-- Ecart a la reference en pourcent (positif = moins cher que la reference) ; nil sans reference ou sans prix de rachat.
function M.DealPct(k)
	local ref = M.ref
	local u = M.rUnit[k]
	if not ref or ref <= 0 or not u or u <= 0 then return nil end
	return floor((ref - u) * 100 / ref)
end

function M.Analyze()
	local a = M.an
	a.n, a.units, a.sum, a.min, a.max, a.mean = 0, 0, 0, nil, nil, nil
	a.sellers, a.spread, a.spreadPct, a.blo, a.bhi = 0, nil, nil, nil, nil
	a.trend, a.hdays, a.havg, a.partial = nil, 0, nil, false
	a.pn, a.pcost, a.pnet, a.nt = 0, 0, 0, 0
	for b = 1, NBUCK do a.bk[b] = 0 end
	local seen = M.sellerSet
	for k, _ in pairs(seen) do seen[k] = nil end
	for i = 1, M.n do
		if M.rUnit[i] > 0 and M.rOwn[i] ~= M.me then
			a.n = a.n + 1
			a.units = a.units + M.rCnt[i]
			a.sum = a.sum + M.rBuy[i]
			if not a.min then a.min = M.rUnit[i] end
			a.max = M.rUnit[i]
			local o = M.rOwn[i] or "?"
			if not seen[o] then
				seen[o] = true
				a.sellers = a.sellers + 1
			end
		end
	end
	if M.n >= MAXRES or M.page + 1 < M.pages then a.partial = true end
	-- reference : mediane de la recherche (3 offres au moins), sinon moyenne des medianes de l'historique, sinon la mediane disponible
	local ref, src = nil, nil
	if M.nbuy >= 3 and M.med then
		ref, src = M.med, "search"
	else
		local avg, days = M.HistStats(M.itemId)
		if avg then
			ref, src = avg, "history"
		elseif M.med then
			ref, src = M.med, "search"
		end
	end
	M.ref, M.refSrc = ref, src
	if a.n > 0 then
		a.mean = floor(a.sum / a.units)
		a.spread = a.max - a.min
		if a.min > 0 then a.spreadPct = floor(a.spread * 100 / a.min) end
		local lo, hi = a.min, a.max
		if M.med and hi > M.med * 3 then hi = M.med * 3 end
		a.blo, a.bhi = lo, hi
		local width = (hi - lo) / NBUCK
		for i = 1, M.n do
			if M.rUnit[i] > 0 and M.rOwn[i] ~= M.me then
				local b = 1
				if width > 0 then b = floor((M.rUnit[i] - lo) / width) + 1 end
				if b > NBUCK then b = NBUCK end
				if b < 1 then b = 1 end
				a.bk[b] = a.bk[b] + M.rCnt[i]
			end
		end
		local avg, days = M.HistStats(M.itemId)
		if avg and M.med then
			a.havg, a.hdays = avg, days
			a.trend = floor((M.med - avg) * 100 / avg)
		end
	end
	-- profit de revente : lots achetables dont le prix + marge reste sous la reference ; gain net apres commission de l'hotel
	if ref then
		local margin = C.Get("auction.margin")
		local cut = C.Get("auction.cut")
		for i = 1, M.n do
			if M.rUnit[i] > 0 and M.rOwn[i] ~= M.me and M.rUnit[i] * (100 + margin) <= ref * 100 then
				local net = floor(ref * M.rCnt[i] * (100 - cut) / 100) - M.rBuy[i]
				if net > 0 then
					a.pn = a.pn + 1
					a.pcost = a.pcost + M.rBuy[i]
					a.pnet = a.pnet + net
					local j = nil
					if a.nt < 3 then
						a.nt = a.nt + 1
						j = a.nt
					elseif net > a.tv[3] then
						j = 3
					end
					if j then
						a.tk[j], a.tv[j] = i, net
						while j > 1 and a.tv[j] > a.tv[j - 1] do
							a.tk[j], a.tk[j - 1] = a.tk[j - 1], a.tk[j]
							a.tv[j], a.tv[j - 1] = a.tv[j - 1], a.tv[j]
							j = j - 1
						end
					end
				end
			end
		end
	end
end

-- Medianes des derniers jours de l'objet pour la mini-courbe de tendance.
function M.FillTrend()
	local a = M.an
	a.ntr = 0
	local h = M.itemId and M.hist[M.itemId]
	if not h then return end
	local first = h.n - NTREND + 1
	if first < 1 then first = 1 end
	for j = first, h.n do
		a.ntr = a.ntr + 1
		a.tr[a.ntr] = h.md[j]
	end
end

-- Valeur d'un lot de qty unites : au plus bas, a la mediane, a la moyenne, au prix conseille (et net apres commission).
function M.LotValue(qty)
	local a = M.an
	if not a.min or qty < 1 then return nil end
	local sell = M.sugBuy and (M.sugBuy * qty) or nil
	local net = sell and floor(sell * (100 - C.Get("auction.cut")) / 100) or nil
	return a.min * qty, (M.med or a.min) * qty, a.mean * qty, sell, net
end

-- Fin d'une recherche : analyse, historique du jour (recherche complete a nom exact seulement), tri d'affichage.
function M.Finish(finished)
	M.Analyze()
	if finished and M.itemId and M.n > 0 and M.qlow ~= "" and C.Get("auction.exact") and M.nbuy > 0 and M.page + 1 >= M.pages then
		M.HistRecord(M.itemId, M.rName[1], M.low, M.med, M.nbuy)
	end
	M.FillTrend()
	M.Resort()
end

-- ---------------------------------------------------------------- tri et filtre d'affichage
local function totalKey(k)
	if M.rBuy[k] > 0 then return M.rBuy[k] end
	return BIG + (M.rNext[k] or 0)
end

local function cmpRows(a, b)
	local s = M.sort
	local va, vb
	if s == "time" then
		va, vb = M.rLeft[a] or 0, M.rLeft[b] or 0
	elseif s == "seller" then
		va, vb = slower(M.rOwn[a] or ""), slower(M.rOwn[b] or "")
	elseif s == "total" then
		va, vb = totalKey(a), totalKey(b)
	else
		va, vb = M.rKey[a], M.rKey[b]
	end
	if va ~= vb then
		if M.sortDesc then return va > vb end
		return va < vb
	end
	return a < b
end

function M.Resort()
	local keepName, keepCnt, keepBuy, keepOwn = M.selName, M.selCnt, M.selBuy, M.selOwn
	local dp = C.Get("auction.dealpct")
	local nv = 0
	for k = 1, M.n do
		local pass = true
		if M.onlyDeals then
			local d = M.DealPct(k)
			pass = d ~= nil and d >= dp and M.rOwn[k] ~= M.me
		end
		if pass then
			nv = nv + 1
			M.ord[nv] = k
		end
	end
	for j = nv + 1, M.ordN do M.ord[j] = nil end
	M.ordN = nv
	M.nord = nv
	if nv > 1 then table.sort(M.ord, cmpRows) end
	M.sel = nil
	if keepName then
		for j = 1, nv do
			local k = M.ord[j]
			if M.rName[k] == keepName and M.rCnt[k] == keepCnt and M.rBuy[k] == keepBuy and M.rOwn[k] == keepOwn then
				M.sel = j
				break
			end
		end
	end
	M.dirty = true
end

function M.SetSort(key)
	if M.sort == key then
		M.sortDesc = not M.sortDesc
	else
		M.sort = key
		M.sortDesc = false
	end
	M.Resort()
	M.Refresh()
end

function M.SetDeals(on)
	M.onlyDeals = on and true or false
	M.offset = 0
	M.Resort()
	M.Refresh()
end

function M.Select(pos)
	if pos and pos >= 1 and pos <= M.nord then
		M.sel = pos
		local k = M.ord[pos]
		M.selName, M.selCnt, M.selBuy, M.selOwn = M.rName[k], M.rCnt[k], M.rBuy[k], M.rOwn[k]
	else
		M.sel = nil
		M.selName = nil
	end
	M.dirty = true
	M.Refresh()
end

function M.SelIndex()
	if M.sel and M.sel >= 1 and M.sel <= M.nord then return M.ord[M.sel] end
	return nil
end

-- ---------------------------------------------------------------- filtres de recherche
function M.HasFilter()
	return (M.fClass ~= nil) or (M.fMinL ~= nil) or (M.fMaxL ~= nil)
end

function M.ReadClasses()
	for i = getn(M.classes), 1, -1 do M.classes[i] = nil end
	local fn = getglobal("GetAuctionItemClasses")
	if type(fn) == "function" then
		local t = { fn() }
		for i = 1, getn(t) do M.classes[i] = t[i] end
	end
end

function M.SubClasses()
	local fn = getglobal("GetAuctionItemSubClasses")
	if M.fClass and type(fn) == "function" then return { fn(M.fClass) } end
	return {}
end

-- Passe a la classe suivante (d = 1) ou precedente (d = -1) ; 0 = toutes.
function M.CycleClass(d)
	local n = getn(M.classes)
	if n == 0 then return end
	local cur = M.fClass or 0
	cur = cur + d
	if cur > n then cur = 0 end
	if cur < 0 then cur = n end
	M.fClass = (cur > 0) and cur or nil
	M.fSub = nil
	M.dirty = true
	M.Refresh()
end

function M.CycleSub(d)
	if not M.fClass then return end
	local subs = M.SubClasses()
	local n = getn(subs)
	if n == 0 then return end
	local cur = M.fSub or 0
	cur = cur + d
	if cur > n then cur = 0 end
	if cur < 0 then cur = n end
	M.fSub = (cur > 0) and cur or nil
	M.dirty = true
	M.Refresh()
end

function M.CycleQuality(d)
	local q = C.Get("auction.quality") + d
	if q > 5 then q = 0 end
	if q < 0 then q = 5 end
	C.Set("auction.quality", q)
end

function M.ResetFilters()
	M.fClass, M.fSub, M.fMinL, M.fMaxL = nil, nil, nil, nil
	C.Set("auction.quality", 0)
	C.Set("auction.usable", false)
	M.onlyDeals = false
	local f = M.frame
	if f then
		M.setting = true
		f.minl:SetText("")
		f.maxl:SetText("")
		M.setting = false
	end
	M.Resort()
	M.Refresh()
end

-- ---------------------------------------------------------------- recherche
function M.SendQuery(page)
	local q = C.Get("auction.quality")
	if q <= 0 then q = nil end
	-- l'interface Blizzard fait de l'arithmetique sur AuctionFrameBrowse.page quand la liste change : elle ne le renseigne que via son
	-- propre bouton de recherche, donc nous le fixons (sinon "attempt to perform arithmetic on field 'page'")
	M.FixBlizzPage()
	QueryAuctionItems(M.query, M.fMinL, M.fMaxL, nil, M.fClass, M.fSub, page, C.Get("auction.usable") and 1 or nil, q)
end

function M.Search(name)
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	if type(name) ~= "string" then return false end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if (name == "" and not M.HasFilter()) or string.len(name) > 63 then SUI.Print(L("msg.auction.noname")) return false end
	M.StopLocate()
	if M.scan then M.StopScan(false) end
	M.Clear()
	M.query = name
	M.qlow = slower(name)
	M.page = 0
	M.pages = 1
	M.scan = true
	M.state = "query"
	M.sentAt = GetTime()
	M.AddRecent(name)
	SUI.On("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(TICK, M.Tick, "auction.tick")
	M.Refresh()
	return true
end

function M.StopScan(finished)
	if not M.scan then return end
	M.scan = false
	M.state = "idle"
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	M.Stats()
	if M.n > 0 then
		M.itemId = idOf(M.rLink[1])
		if finished and M.low and M.itemId and C.Get("auction.remember") and C.Get("auction.exact") then
			M.RememberPrice(M.itemId, M.low)
		end
	end
	M.Finish(finished)
	M.dirty = true
	M.Refresh()
end

function M.OnList()
	if M.loc then M.LocateRead() return end
	if not M.scan or M.state ~= "wait" then return end
	M.ReadPage()
	M.Resort()
	local _, total = GetNumAuctionItems("list")
	total = total or 0
	M.pages = floor((total + PAGE - 1) / PAGE)
	if M.pages < 1 then M.pages = 1 end
	local maxp = C.Get("auction.maxpages")
	if M.page + 1 < M.pages and M.page + 1 < maxp then
		M.page = M.page + 1
		M.state = "query"
		M.sentAt = GetTime()
		M.dirty = true
		-- page suivante tout de suite si le client l'autorise (le delai de 5 s est supprime par AuctionQueryThrottle) : on n'attend pas le tick
		if CanSendAuctionQuery() then
			M.SendQuery(M.page)
			M.state = "wait"
			M.sentAt = GetTime()
		end
	else
		M.StopScan(true)
	end
end

function M.Tick()
	if M.frame and M.LevelsStale() then M.SyncLevels() end
	if M.loc then M.LocateTick() return end
	if not M.scan then return end
	if M.state == "query" then
		if CanSendAuctionQuery() then
			M.SendQuery(M.page)
			M.state = "wait"
			M.sentAt = GetTime()
		elseif GetTime() - M.sentAt > 8 then
			M.StopScan(false)
			SUI.Print(L("msg.auction.timeout"))
		end
	elseif M.state == "wait" then
		if GetTime() - M.sentAt > 8 then
			M.StopScan(false)
			SUI.Print(L("msg.auction.timeout"))
		end
	end
	if M.dirty then M.Refresh() end
end

-- ---------------------------------------------------------------- achat et enchere (toujours apres un clic de confirmation)
function M.CanBuy(k)
	return k ~= nil and M.rBuy[k] > 0 and M.rOwn[k] ~= M.me
end

function M.CanBid(k)
	if not k or M.rOwn[k] == M.me or M.rHigh[k] == 2 then return false end
	return M.rBuy[k] == 0 or M.rNext[k] < M.rBuy[k]
end

-- Ouvre la fenetre de confirmation pour la ligne choisie ; rien n'est achete a ce stade.
function M.AskBuy(mode)
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	if M.scan then SUI.Print(L("msg.auction.busy")) return false end
	local k = M.SelIndex()
	if not k then SUI.Print(L("msg.auction.nosel")) return false end
	if mode == "buy" and not M.CanBuy(k) then SUI.Print(L("msg.auction.cantbuy")) return false end
	if mode == "bid" and not M.CanBid(k) then SUI.Print(L("msg.auction.cantbid")) return false end
	M.dlg = { mode = mode, name = M.rName[k], cnt = M.rCnt[k], buy = M.rBuy[k], owner = M.rOwn[k], page = M.rPage[k], q = M.rQ[k],
		amount = (mode == "buy") and M.rBuy[k] or M.rNext[k], left = M.rLeft[k], unit = M.rUnit[k], pct = M.DealPct(k), cur = M.rCur[k] }
	M.ShowDialog()
	return true
end

function M.CancelDialog()
	M.dlg = nil
	M.HideDialog()
end

-- Clic sur "Confirmer" : seul point d'entree d'un achat.
function M.ConfirmDialog()
	local d = M.dlg
	if not d then return false end
	M.dlg = nil
	M.HideDialog()
	if d.amount > M.Wallet() then
		SUI.Print(L("msg.auction.nomoney", M.Money(d.amount)))
		return false
	end
	return M.BeginLocate(d)
end

function M.BeginLocate(d)
	if M.scan then SUI.Print(L("msg.auction.busy")) return false end
	M.StopLocate()
	d.state, d.sentAt, d.tries, d.curPage = "query", GetTime(), 0, d.page
	M.loc = d
	SUI.On("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(TICK, M.Tick, "auction.tick")
	M.dirty = true
	M.Refresh()
	return true
end

function M.StopLocate()
	if not M.loc then return end
	M.loc = nil
	if not M.scan then
		if M.task then
			SUI.Cancel(M.task)
			M.task = nil
		end
		SUI.Off("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	end
	M.dirty = true
end

function M.LocateTick()
	local d = M.loc
	if not d then return end
	if d.state == "query" then
		if CanSendAuctionQuery() then
			M.SendQuery(d.curPage)
			d.state = "wait"
			d.sentAt = GetTime()
		elseif GetTime() - d.sentAt > 8 then
			M.StopLocate()
			SUI.Print(L("msg.auction.timeout"))
		end
	elseif GetTime() - d.sentAt > 8 then
		M.StopLocate()
		SUI.Print(L("msg.auction.timeout"))
	end
end

-- Ligne de la page courante identique a l'enchere confirmee (nom, quantite, rachat, vendeur) ; nil sinon.
function M.MatchList(d)
	local batch = GetNumAuctionItems("list") or 0
	for i = 1, batch do
		local name, _, count, _, _, _, minBid, minInc, buyout, curBid, _, owner = GetAuctionItemInfo("list", i)
		if name == d.name and count == d.cnt and (buyout or 0) == d.buy and owner == d.owner then
			if d.mode == "buy" then return i end
			local nextbid = ((curBid or 0) > 0) and ((curBid or 0) + (minInc or 1)) or (minBid or 0)
			if nextbid <= d.amount then return i, nextbid end
		end
	end
	return nil
end

function M.LocateRead()
	local d = M.loc
	if not d or d.state ~= "wait" then return end
	local i = M.MatchList(d)
	if i then
		M.StopLocate()
		M.Execute(d, i)
		return
	end
	d.tries = d.tries + 1
	local nextp = nil
	if d.tries == 1 then
		nextp = d.page + 1
	elseif d.tries == 2 and d.page > 0 then
		nextp = d.page - 1
	end
	if nextp and nextp < M.pages + 1 then
		d.curPage = nextp
		d.state = "query"
		d.sentAt = GetTime()
	else
		M.StopLocate()
		SUI.Print(L("msg.auction.gone", d.name))
	end
end

-- La ligne est retrouvee : dernier controle d'argent, puis l'offre part.
function M.Execute(d, i)
	if d.amount > M.Wallet() then
		SUI.Print(L("msg.auction.nomoney", M.Money(d.amount)))
		return false
	end
	PlaceAuctionBid("list", i, d.amount)
	if d.mode == "buy" then
		SUI.Print(L("msg.auction.bought", d.cnt, d.name, M.Money(d.amount)))
		for k = 1, M.n do
			if M.rName[k] == d.name and M.rCnt[k] == d.cnt and M.rBuy[k] == d.buy and M.rOwn[k] == d.owner then
				M.Remove(k)
				break
			end
		end
	else
		SUI.Print(L("msg.auction.bidsent", d.cnt, d.name, M.Money(d.amount)))
		for k = 1, M.n do
			if M.rName[k] == d.name and M.rCnt[k] == d.cnt and M.rBuy[k] == d.buy and M.rOwn[k] == d.owner then
				M.rCur[k], M.rHigh[k] = d.amount, 2
				M.rNext[k] = d.amount + 1
			end
		end
	end
	M.dirty = true
	M.Refresh()
	return true
end

-- ---------------------------------------------------------------- mise en vente
function M.Duration()
	return tonumber(C.Get("auction.duration")) or 1440
end

function M.Sell(bag, slot)
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	if type(bag) ~= "number" or type(slot) ~= "number" then SUI.Print(L("msg.auction.help")) return false end
	if not GetContainerItemLink(bag, slot) then SUI.Print(L("msg.auction.noitem")) return false end
	ClearCursor()
	ClickAuctionSellItemButton()
	ClearCursor()
	PickupContainerItem(bag, slot)
	ClickAuctionSellItemButton()
	ClearCursor()
	local name = GetAuctionSellItemInfo()
	if not name then SUI.Print(L("msg.auction.noitem")) return false end
	M.armUntil = 0
	M.sellName = nil
	M.OnSellChanged(true)
	return M.Search(name)
end

function M.SearchSlot()
	local name = GetAuctionSellItemInfo()
	if not name then SUI.Print(L("msg.auction.nosell")) return false end
	return M.Search(name)
end

-- Clic ou depot sur l'emplacement de vente du panneau : depose (ou reprend) l'objet du curseur.
function M.SlotClick()
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	ClickAuctionSellItemButton()
	M.OnSellChanged(false)
	return true
end

-- L'objet de l'emplacement de vente a change (depot, retrait, evenement NEW_AUCTION_UPDATE) : plan et prix repartent de zero.
function M.OnSellChanged(noSearch)
	local name, _, count = GetAuctionSellItemInfo()
	count = count or 1
	if name ~= M.sellName then
		M.sellName = name
		M.sellUnit = nil
		M.armUntil = 0
		M.lots, M.size = 1, count
		if name and not noSearch and M.open and not M.scan and C.Get("auction.autoprice") and slower(name) ~= M.qlow then
			M.Search(name)
		end
	elseif name and M.slotCount ~= count then
		M.lots, M.size = 1, count
	end
	M.slotCount = name and count or nil
	M.dirty = true
	if M.frame then M.Refresh() end
end

-- Prix de rachat par unite retenu : celui saisi, sinon le prix propose (valable pour l'objet cherche seulement).
function M.SellUnitPrice(name)
	if M.sellUnit then return M.sellUnit end
	if M.sugBuy and name and slower(name) == M.qlow then return M.sugBuy end
	return nil
end

function M.OwnedCount(name, count)
	local fn = getglobal("GetItemCount")
	if type(fn) == "function" and name then
		local ok, n = pcall(fn, name)
		if ok and type(n) == "number" then return n + (count or 0) end
	end
	return count or 0
end

-- Plan de vente : lots, taille d'un lot (bornes par la quantite possedee).
function M.Plan(count, name)
	local lots, size = M.lots or 1, M.size or count
	if size < 1 then size = 1 end
	if lots < 1 then lots = 1 end
	local owned = M.OwnedCount(name, count)
	if owned < 1 then owned = count end
	if size > owned then size = owned end
	if lots * size > owned then lots = floor(owned / size) end
	if lots < 1 then lots = 1 end
	return lots, size, owned
end

function M.Post(confirmed)
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	if M.scan then SUI.Print(L("msg.auction.busy")) return false end
	local name, _, count = GetAuctionSellItemInfo()
	if not name then SUI.Print(L("msg.auction.nosell")) return false end
	local unit = M.SellUnitPrice(name)
	if not unit then SUI.Print(L("msg.auction.nosearch", name)) return false end
	count = count or 1
	local lots, size = M.Plan(count, name)
	local ubid = floor(unit * C.Get("auction.bidpct") / 100)
	if ubid < 1 then ubid = 1 end
	local buy = unit * size
	local bid = ubid * size
	local dur = M.Duration()
	if C.Get("auction.confirmpost") and not (confirmed and GetTime() < M.armUntil) then
		M.armUntil = GetTime() + 10
		if lots == 1 and size == count then
			SUI.Print(L("msg.auction.arm", count, name, M.Money(bid), M.Money(buy)))
		else
			SUI.Print(LF("msg.auction.armlots", lots, size, name, M.Money(buy), M.Money(buy * lots)))
		end
		M.Refresh()
		return false
	end
	M.armUntil = 0
	if lots == 1 and size == count then
		StartAuction(bid, buy, dur)
		SUI.Print(L("msg.auction.posted", count, name, M.Money(buy)))
		M.sellName = nil
		M.slotCount = nil
		M.Refresh()
		return true
	end
	return M.StartQueue(name, lots, size, bid, buy, dur)
end

-- ---------------------------------------------------------------- vente en lots : la pile est rangee, scindee, posee lot par lot
local function itemName(link)
	local _, _, n = sfind(link or "", "%[(.-)%]")
	return n
end

-- Cherche dans les sacs une pile de l'objet : la taille exacte d'abord, sinon la plus petite pile plus grande.
function M.FindStack(name, size)
	local bestB, bestS, bestC = nil, nil, nil
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link and itemName(link) == name then
				local _, cnt, locked = GetContainerItemInfo(bag, slot)
				cnt = cnt or 1
				if not locked and cnt >= size then
					if cnt == size then return bag, slot, cnt end
					if not bestC or cnt < bestC then bestB, bestS, bestC = bag, slot, cnt end
				end
			end
		end
	end
	return bestB, bestS, bestC
end

function M.FreeSlot()
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			if not GetContainerItemLink(bag, slot) then return bag, slot end
		end
	end
	return nil
end

function M.StartQueue(name, lots, size, bid, buy, dur)
	if M.q then SUI.Print(L("msg.auction.qbusy")) return false end
	M.q = { name = name, lots = lots, size = size, bid = bid, buy = buy, dur = dur, done = 0, step = "return", at = GetTime() }
	if M.qtask then SUI.Cancel(M.qtask) end
	M.qtask = SUI.Every(0.4, M.QueueTick, "auction.queue")
	M.QueueTick()
	return true
end

function M.StopQueue(msg)
	local q = M.q
	M.q = nil
	if M.qtask then
		SUI.Cancel(M.qtask)
		M.qtask = nil
	end
	if q and msg then SUI.Print(msg) end
	M.sellName = nil
	M.slotCount = nil
	M.dirty = true
	if M.frame then M.Refresh() end
end

function M.QueueTick()
	local q = M.q
	if not q then return end
	if not M.open then M.StopQueue(L("msg.auction.qstop", q.done, q.lots)) return end
	if GetTime() - q.at > 8 then M.StopQueue(L("msg.auction.qstop", q.done, q.lots)) return end
	if q.step == "return" then
		-- l'objet pose dans l'emplacement de vente retourne dans les sacs pour pouvoir etre scinde
		if GetAuctionSellItemInfo() then
			ClearCursor()
			ClickAuctionSellItemButton()
			if CursorHasItem() then
				local b, s = M.FreeSlot()
				if not b then ClearCursor() M.StopQueue(L("msg.auction.qnoroom")) return end
				PickupContainerItem(b, s)
			end
		end
		q.step = "pick"
		q.at = GetTime()
		return
	end
	if q.step == "pick" then
		if GetAuctionSellItemInfo() then return end        -- l'emplacement n'est pas encore vide
		if q.done >= q.lots then M.StopQueue(L("msg.auction.qdone", q.done, q.size, q.name)) return end
		if CursorHasItem() then return end
		local b, s, cnt = M.FindStack(q.name, q.size)
		if not b then M.StopQueue(L("msg.auction.qnostack", q.done, q.lots)) return end
		ClearCursor()
		if cnt > q.size then SplitContainerItem(b, s, q.size) else PickupContainerItem(b, s) end
		ClickAuctionSellItemButton()
		local n, _, c = GetAuctionSellItemInfo()
		if n ~= q.name or c ~= q.size then
			ClearCursor()
			M.StopQueue(L("msg.auction.qstop", q.done, q.lots))
			return
		end
		StartAuction(q.bid, q.buy, q.dur)
		q.done = q.done + 1
		q.at = GetTime()
		if q.done >= q.lots then M.StopQueue(L("msg.auction.qdone", q.done, q.size, q.name)) end
	end
end

-- ---------------------------------------------------------------- mes ventes
function M.ReadOwned()
	local n = GetNumAuctionItems("owner") or 0
	if n > MAXOWN then n = MAXOWN end
	local m = 0
	for i = 1, n do
		local name, tex, count, quality, _, _, minBid, _, buyout, curBid, high = GetAuctionItemInfo("owner", i)
		if name then
			m = m + 1
			M.oName[m], M.oTex[m], M.oCnt[m], M.oQ[m] = name, tex, count or 1, quality
			M.oBid[m], M.oBuy[m], M.oCur[m] = minBid or 0, buyout or 0, curBid or 0
			M.oHigh[m] = (high and high ~= "") and high or false
			M.oLeft[m] = GetAuctionItemTimeLeft("owner", i)
			M.oLink[m] = GetAuctionItemLink("owner", i)
		end
	end
	M.oN = m
	if M.oSel and M.oSel > m then M.oSel = nil end
	M.dirty = true
end

function M.RequestOwned()
	local fn = getglobal("GetOwnerAuctionItems")
	if type(fn) == "function" then fn() end
	M.ReadOwned()
	M.Refresh()
end

function M.OnOwned()
	M.ReadOwned()
	M.Refresh()
end

function M.WatchOwned(on)
	if on and not M.watchOwned then
		M.watchOwned = true
		SUI.On("AUCTION_OWNED_LIST_UPDATE", M.OnOwned)
	elseif not on and M.watchOwned then
		M.watchOwned = false
		SUI.Off("AUCTION_OWNED_LIST_UPDATE", M.OnOwned)
	end
end

function M.SelectOwned(pos)
	if pos and pos >= 1 and pos <= M.oN then M.oSel = pos else M.oSel = nil end
	M.cancelUntil = 0
	M.dirty = true
	M.Refresh()
end

-- Annule la vente choisie : une premiere demande arme 10 s (la ligne est relue avant d'annuler), la seconde annule.
function M.CancelSale(confirmed)
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	local i = M.oSel
	if not i or i > M.oN then SUI.Print(L("msg.auction.nosel")) return false end
	local name, _, count, _, _, _, _, _, buyout, _, high = GetAuctionItemInfo("owner", i)
	if name ~= M.oName[i] or count ~= M.oCnt[i] or (buyout or 0) ~= M.oBuy[i] then
		SUI.Print(L("msg.auction.cstale"))
		M.RequestOwned()
		return false
	end
	if not (confirmed and GetTime() < M.cancelUntil) then
		M.cancelUntil = GetTime() + 10
		local warn = ""
		if high and high ~= "" then warn = " " .. L("msg.auction.cbid") end
		SUI.Print(L("msg.auction.carm", count or 1, name, M.Money(buyout or 0)) .. warn)
		M.Refresh()
		return false
	end
	M.cancelUntil = 0
	CancelAuction(i)
	SUI.Print(L("msg.auction.cdone", count or 1, name))
	M.oSel = nil
	SUI.After(0.6, function() if M.on and M.open then M.RequestOwned() end end, "auction.owned")
	M.Refresh()
	return true
end

-- ---------------------------------------------------------------- interface Blizzard / ShikiUI
local function blizzFrame()
	return getglobal("AuctionFrame")
end

-- Interface effectivement montree : ShikiUI seulement si le panneau est autorise (sinon rien ne s'afficherait).
function M.Mode()
	if M.on and M.open and C.Get("auction.panel") and M.view == "shikiui" then return "shikiui" end
	return "blizzard"
end

-- Cache (alpha 0, fond) ou rend le cadre Blizzard selon le mode. Idempotent ; le cadre n'est ni detruit ni cache par Hide().
function M.ApplyView()
	local bf = blizzFrame()
	if not bf then return end
	if M.Mode() == "shikiui" then
		if not M.hid then
			M.bz = { (bf.GetAlpha and bf:GetAlpha()) or 1, (bf.GetFrameStrata and bf:GetFrameStrata()) or "MEDIUM" }
			M.hid = true
		end
		bf:SetAlpha(0)
		bf:SetFrameStrata("BACKGROUND")
	elseif M.hid then
		M.hid = false
		local o = M.bz or { 1, "MEDIUM" }
		bf:SetAlpha(o[1])
		bf:SetFrameStrata(o[2])
		M.bz = nil
	end
end

-- Bouton / commande : bascule l'interface de cette ouverture.
function M.SetView(v)
	if v ~= "shikiui" and v ~= "blizzard" then return false end
	M.view = v
	M.ApplyOptions()
	M.Refresh()
	return true
end

function M.ToggleView()
	if not M.open then SUI.Print(L("msg.auction.closed")) return false end
	return M.SetView(M.Mode() == "shikiui" and "blizzard" or "shikiui")
end

-- Ferme l'hotel des ventes (bouton Fermer du panneau).
function M.CloseHouse()
	local fn = getglobal("CloseAuctionHouse")
	if type(fn) == "function" then fn() end
end

-- ---------------------------------------------------------------- niveaux des cadres (client 1.12)
-- Chaque controle est range avec son decalage de niveau par rapport au panneau : si le client change le niveau du panneau apres la
-- construction, les controles passeraient SOUS lui (plus de clic, plus de saisie). M.SyncLevels les recale.
local function kid(f, fr, off)
	local k = f.kids
	k[getn(k) + 1] = fr
	fr.loff = off
	return fr
end

function M.LevelsStale()
	local f = M.frame
	if not f then return false end
	local base = f:GetFrameLevel() or 0
	if f.baseLvl ~= base then return true end
	local k = f.kids
	local nk = getn(k)
	if nk > 0 then
		if k[1]:GetFrameLevel() ~= base + k[1].loff then return true end
		if k[nk]:GetFrameLevel() ~= base + k[nk].loff then return true end
	end
	return false
end

function M.SyncLevels()
	local f = M.frame
	if not f then return 0 end
	local base = f:GetFrameLevel() or 0
	local n = 0
	local k = f.kids
	for i = 1, getn(k) do
		local fr = k[i]
		local want = base + fr.loff
		if fr:GetFrameLevel() ~= want then
			fr:SetFrameLevel(want)
			n = n + 1
		end
	end
	f.baseLvl = base
	return n
end

-- ---------------------------------------------------------------- aides d'interface
function M.Tip(fr)
	local gt = getglobal("GameTooltip")
	if not gt or not fr.tipT then return end
	gt:SetOwner(fr, "ANCHOR_RIGHT")
	gt:SetText(L(fr.tipT), T.c.text[1], T.c.text[2], T.c.text[3])
	local d = fr.tipD and L(fr.tipD) or nil
	if fr.tipFn then d = fr.tipFn(fr) or d end
	if d and d ~= "" then gt:AddLine(d, T.c.dim[1], T.c.dim[2], T.c.dim[3], 1) end
	gt:Show()
end

function M.TipHide()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

-- Infobulle d'un controle : titre (cle), description (cle) ; garde le comportement de survol du theme.
local function tip(fr, tk, dk, fn)
	fr.tipT, fr.tipD, fr.tipFn = tk, dk, fn
	local oe, ol = fr:GetScript("OnEnter"), fr:GetScript("OnLeave")
	fr:SetScript("OnEnter", function()
		if oe then oe() end
		M.Tip(this)
	end)
	fr:SetScript("OnLeave", function()
		if ol then ol() end
		M.TipHide()
	end)
end

local function txt(parent, size, color, justify, w, x, y)
	local fs = T.Text(parent, size, color, justify)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
	if w then fs:SetWidth(w) end
	return fs
end

local function btn(f, parent, label, w, h, x, y, onclick, tk, dk, off, fn)
	local b = T.Button(parent, label, w, h, onclick)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	kid(f, b, off or 2)
	if tk then tip(b, tk, dk, fn) end
	return b
end

local function edit(f, parent, w, x, y, tk, dk)
	local e = T.Edit(parent, w, 18)
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	kid(f, e, 2)
	if tk then tip(e, tk, dk) end
	return e
end

local function check(f, parent, x, y, label, lw, onchange, tk, dk)
	local c = T.Check(parent, onchange)
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	kid(f, c, 2)
	tip(c, tk, dk)
	local fs = txt(parent, 11, T.c.dim, "LEFT", lw, x + 20, y - 3)
	fs:SetText(label)
	return c
end

function M.SetEn(b, on)
	local d = not on
	if b.dis ~= d then
		b.dis = d
		b.disabled = d
		b:SetAlpha(d and 0.4 or 1)
	end
end

local function btnText(b, text)
	if b.cur ~= text then
		b.cur = text
		T.SetButtonText(b, text)
	end
end

function M.OnRestyle()
	M.colorEpoch = M.colorEpoch + 1
	if M.on and M.frame and M.frame:IsShown() then M.dirty = true end
end

-- ---------------------------------------------------------------- dimensions et colonnes
function M.RowH()
	return (C.Get("auction.density") == "compact") and 14 or 18
end

function M.Height()
	local h = 212 + C.Get("auction.rows") * M.RowH()
	if h < 372 then h = 372 end
	return h
end

M.col = {}

-- Positions des colonnes (depuis la droite) selon les colonnes visibles.
function M.Cols()
	local c = M.col
	local x = PW - 16
	x = x - 40
	c.time = x
	if C.Get("auction.showseller") then
		x = x - 4 - 70
		c.sell = x
	else
		c.sell = nil
	end
	x = x - 4 - 44
	c.deal = x
	if C.Get("auction.showtotal") then
		x = x - 4 - 76
		c.tot = x
	else
		c.tot = nil
	end
	x = x - 4 - 76
	c.unit = x
	c.name = C.Get("auction.icons") and (M.RowH() + 4) or 0
	c.namew = x - 4 - c.name
	return c
end

local function place(fs, row, x, w)
	if x then
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", row, "LEFT", x, 0)
		fs:SetWidth(w)
		fs:Show()
	else
		fs:Hide()
	end
end

function M.LayoutRows()
	local f = M.frame
	if not f then return end
	local c = M.Cols()
	local rh = M.RowH()
	local p = f.pages[1]
	for i = 1, NROWS do
		local r = f.rows[i]
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(86 + (i - 1) * rh))
		r:SetHeight(rh)
		r.icon:ClearAllPoints()
		r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
		r.icon:SetWidth(rh - 2)
		r.icon:SetHeight(rh - 2)
		if C.Get("auction.icons") then r.icon:Show() else r.icon:Hide() end
		place(r.name, r, c.name, c.namew)
		place(r.price, r, c.unit, 76)
		place(r.total, r, c.tot, 76)
		place(r.deal, r, c.deal, 44)
		place(r.seller, r, c.sell, 70)
		place(r.time, r, c.time, 40)
	end
	local hd = f.hdr
	hd.name:ClearAllPoints()
	hd.name:SetPoint("TOPLEFT", p, "TOPLEFT", c.name, -70)
	hd.name:SetWidth(c.namew)
	local list = { { hd.unit, c.unit, 76 }, { hd.total, c.tot, 76 }, { hd.deal, c.deal, 44 }, { hd.seller, c.sell, 70 }, { hd.time, c.time, 40 } }
	for i = 1, getn(list) do
		local b, x, w = list[i][1], list[i][2], list[i][3]
		if x then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", p, "TOPLEFT", x, -70)
			b:SetWidth(w)
			b:Show()
		else
			b:Hide()
		end
	end
	f.tail:ClearAllPoints()
	f.tail:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(86 + C.Get("auction.rows") * rh + 2))
end

-- ---------------------------------------------------------------- onglets
function M.SetTab(n)
	n = tonumber(n)
	if not n or n < 1 or n > NTAB then return false end
	M.tab = n
	local f = M.frame
	M.CancelDialog()
	if f then
		M.HideHints()
		for i = 1, NTAB do
			if i == n then f.pages[i]:Show() else f.pages[i]:Hide() end
			T.SetSelected(f.tabs[i], i == n)
		end
		M.SyncLevels()
	end
	if n == 3 and M.open and M.on then
		M.WatchOwned(true)
		M.RequestOwned()
	else
		M.WatchOwned(false)
	end
	M.dirty = true
	M.Refresh()
	return true
end

local TABKEYS = { "search", "sell", "sales", "analysis" }

function M.TabFromName(s)
	s = slower(s or "")
	local n = tonumber(s)
	if n then return n end
	for i = 1, NTAB do
		if TABKEYS[i] == s then return i end
	end
	if s == "chercher" then return 1 elseif s == "vendre" then return 2 elseif s == "ventes" then return 3 elseif s == "analyse" then return 4 end
	return nil
end

-- ---------------------------------------------------------------- suggestions de recherche (historique, favoris, objets connus)
local function hintAdd(s, fav)
	if M.nh >= NHINT then return end
	local low = slower(s)
	for i = 1, M.nh do
		if slower(M.hints[i]) == low then return end
	end
	M.nh = M.nh + 1
	M.hints[M.nh] = s
	M.hintFav[M.nh] = fav
end

-- ---------------------------------------------------------------- base d'objets (recherche par mot du milieu du nom)
-- Le serveur 1.12 ne renvoie que les noms COMMENCANT par le texte cherche : "giants" ne trouve jamais "Elixir of Giants".
-- Chaque objet croise lors d'un scan est memorise (nom -> identifiant, qualite...) dans ShikiUIDB.global.itembase ;
-- la zone de suggestion propose ensuite les noms connus qui CONTIENNENT le texte : un clic relance la recherche du nom complet.
M.ITEMBASE_MAX = 4000

function M.LoadBase()
	local db = C.GetGlobal("itembase")
	if type(db) ~= "table" then
		db = {}
		C.SetGlobal("itembase", db)
	end
	M.itemBase = db
	local n = 0
	for _ in pairs(db) do n = n + 1 end
	M.nBase = n
end

-- Plafond depasse : les 300 plus anciennement vus partent.
function M.TrimBase()
	local list = {}
	for name, e in pairs(M.itemBase) do
		tinsert(list, { name, e.t or 0 })
	end
	table.sort(list, function(a, b) return (a[2] or 0) < (b[2] or 0) end)
	local cut = 300
	for i = 1, getn(list) do
		if cut <= 0 or M.nBase <= M.ITEMBASE_MAX - 300 then break end
		M.itemBase[list[i][1]] = nil
		M.nBase = M.nBase - 1
		cut = cut - 1
	end
end

-- Retient un objet croise au scan (nouveau : relit qualite / niveau / famille ; connu : date de derniere vue seulement).
function M.NoteItem(name, link, quality)
	if not M.itemBase or type(name) ~= "string" or name == "" then return end
	local e = M.itemBase[name]
	if not e then
		if M.nBase >= M.ITEMBASE_MAX then
			M.TrimBase()
			if M.nBase >= M.ITEMBASE_MAX then return end
		end
		e = {}
		M.itemBase[name] = e
		M.nBase = M.nBase + 1
		e.id = idOf(link or "")
		e.q = quality
		local gi = getglobal("GetItemInfo")
		if e.id and type(gi) == "function" then
			-- signature 1.12 incertaine : seule la qualite (4e retour) est retenue, le reste est ignore
			local ok, _, _, q2 = pcall(gi, e.id)
			if ok and q2 ~= nil then e.q = q2 end
		end
	end
	e.t = time and time() or 0
end

function M.BuildHints(text)
	M.nh = 0
	local q = slower(text or "")
	for i = 1, getn(M.favs) do
		if q == "" or sfind(slower(M.favs[i]), q, 1, true) then hintAdd(M.favs[i], true) end
	end
	for i = 1, getn(M.recent) do
		if q == "" or sfind(slower(M.recent[i]), q, 1, true) then hintAdd(M.recent[i], false) end
	end
	if q ~= "" then
		for i = getn(M.horder), 1, -1 do
			local h = M.hist[M.horder[i]]
			if h and h.name ~= "" and sfind(slower(h.name), q, 1, true) then hintAdd(h.name, false) end
		end
		-- base d'objets : les noms connus qui CONTIENNENT le texte (le serveur ne trouve que les prefixes)
		if M.itemBase and M.nh < NHINT then
			for name in pairs(M.itemBase) do
				if M.nh >= NHINT then break end
				if sfind(slower(name), q, 1, true) then hintAdd(name, false) end
			end
		end
	end
	return M.nh
end

function M.ShowHints(text)
	local f = M.frame
	if not f or M.tab ~= 1 then return end
	M.BuildHints(text)
	if M.nh == 0 then f.hint:Hide() return end
	f.hint:SetHeight(M.nh * 16 + 4)
	for i = 1, NHINT do
		local b = f.hint.b[i]
		if i <= M.nh then
			btnText(b, (M.hintFav[i] and "* " or "") .. M.hints[i])
			b:Show()
		else
			b:Hide()
		end
	end
	f.hint:Show()
	M.SyncLevels()
end

function M.HideHints()
	local f = M.frame
	if f and f.hint then f.hint:Hide() end
end

function M.HideHintsLater()
	SUI.After(0.25, function()
		local f = M.frame
		if f and f.edit and not f.edit:HasFocus() then M.HideHints() end
	end, "auction.hint")
end

function M.SetEditText(e, s)
	M.setting = true
	e:SetText(s or "")
	M.setting = false
end

function M.PickHint(pos, btn)
	local name = M.hints[pos]
	if not name then return end
	if btn == "RightButton" then
		local at = listFind(M.recent, name)
		if at then
			table.remove(M.recent, at)
			listWrite("auction.recent", M.recent)
		end
		at = listFind(M.favs, name)
		if at then
			table.remove(M.favs, at)
			listWrite("auction.favs", M.favs)
		end
		M.ShowHints(M.frame.edit:GetText())
		return
	end
	M.SetEditText(M.frame.edit, name)
	M.HideHints()
	M.frame.edit:ClearFocus()
	M.Search(name)
end

function M.OnSearchText(e)
	if M.setting then return end
	if e:HasFocus() then M.ShowHints(e:GetText()) end
end

-- Le champ de recherche (et celui de l'onglet Analyse) suit la recherche courante.
function M.SyncEdits()
	local f = M.frame
	if not f then return end
	local q = M.query or ""
	if not f.edit:HasFocus() and f.edit:GetText() ~= q then M.SetEditText(f.edit, q) end
	if not f.aedit:HasFocus() and f.aedit:GetText() ~= q then M.SetEditText(f.aedit, q) end
end

-- ---------------------------------------------------------------- lignes de resultat : actions
function M.RowClick(pos, btn)
	M.Select(M.offset + pos)
	if btn == "RightButton" then
		local k = M.SelIndex()
		if k then
			M.SetEditText(M.frame.edit, M.rName[k])
			M.Search(M.rName[k])
		end
	end
end

function M.RowDouble(pos)
	M.Select(M.offset + pos)
	local k = M.SelIndex()
	if not k then return end
	if M.CanBuy(k) then M.AskBuy("buy") elseif M.CanBid(k) then M.AskBuy("bid") end
end

function M.RowTip(row)
	local gt = getglobal("GameTooltip")
	if not gt then return end
	local k = M.ord[M.offset + row.pos]
	if not k then return end
	gt:SetOwner(row, "ANCHOR_RIGHT")
	local _, _, s = sfind(M.rLink[k] or "", "(item:%d+:%d+:%d+:%d+)")
	local shown = false
	if s then shown = pcall(gt.SetHyperlink, gt, s) end
	if not shown then gt:SetText(M.rName[k], T.c.text[1], T.c.text[2], T.c.text[3]) end
	local d = T.c.dim
	if M.rBuy[k] > 0 then
		gt:AddLine(L("msg.auction.tt.buy", M.Money(M.rBuy[k]), M.Money(M.rUnit[k])), d[1], d[2], d[3])
	else
		gt:AddLine(L("msg.auction.tt.nobuy"), d[1], d[2], d[3])
	end
	gt:AddLine(L("msg.auction.tt.bid", M.Money(M.rNext[k])), d[1], d[2], d[3])
	local pct = M.DealPct(k)
	if pct then
		gt:AddLine(L("msg.auction.tt.ref", M.MoneyShort(M.ref), L("msg.auction.src." .. M.refSrc), dealText(pct)), d[1], d[2], d[3])
	end
	gt:AddLine(L("msg.auction.tt.seller", M.rOwn[k] or "?", M.LeftText(M.rLeft[k])), d[1], d[2], d[3])
	if M.rHigh[k] == 2 then gt:AddLine(L("msg.auction.tt.mine"), d[1], d[2], d[3]) end
	gt:AddLine(L("msg.auction.tt.keys"), d[1], d[2], d[3], 1)
	gt:Show()
end

-- ---------------------------------------------------------------- fenetre de confirmation d'achat / d'enchere
function M.ShowDialog()
	local f = M.frame
	local d = M.dlg
	if not f or not d then return end
	local dl = f.dlg
	setText(dl.title, d.mode == "buy" and L("msg.auction.dlg.buy") or L("msg.auction.dlg.bid"))
	setText(dl.l1, d.cnt .. "x " .. d.name)
	local r, g, b = qcolor(d.q)
	dl.l1:SetTextColor(r, g, b, 1)
	local unit = floor(d.amount / d.cnt)
	if d.mode == "buy" then
		setText(dl.l2, L("msg.auction.dlg.price", M.Money(d.amount), M.MoneyShort(unit)))
	else
		setText(dl.l2, L("msg.auction.dlg.bidprice", M.Money(d.amount), M.MoneyShort(unit)))
	end
	setText(dl.l3, L("msg.auction.dlg.seller", d.owner or "?", M.LeftText(d.left)))
	if d.pct then
		if d.pct >= C.Get("auction.dealpct") then
			setText(dl.l4, L("msg.auction.dlg.good", dealText(d.pct), M.MoneyShort(M.ref or 0)))
			tokColor(dl.l4, "good")
		elseif d.pct <= -C.Get("auction.dealpct") then
			setText(dl.l4, L("msg.auction.dlg.dear", dealText(d.pct), M.MoneyShort(M.ref or 0)))
			tokColor(dl.l4, "bad")
		else
			setText(dl.l4, L("msg.auction.dlg.fair", dealText(d.pct), M.MoneyShort(M.ref or 0)))
			tokColor(dl.l4, "dim")
		end
	else
		setText(dl.l4, L("msg.auction.dlg.noref"))
		tokColor(dl.l4, "dim")
	end
	local wallet = M.Wallet()
	if wallet >= d.amount then
		setText(dl.l5, L("msg.auction.dlg.wallet", M.Money(wallet), M.Money(wallet - d.amount)))
		tokColor(dl.l5, "dim")
		M.SetEn(dl.ok, true)
	else
		setText(dl.l5, L("msg.auction.dlg.poor", M.Money(wallet)))
		tokColor(dl.l5, "bad")
		M.SetEn(dl.ok, false)
	end
	btnText(dl.ok, d.mode == "buy" and L("msg.auction.dlg.okbuy") or L("msg.auction.dlg.okbid"))
	dl:Show()
	M.SyncLevels()
end

function M.HideDialog()
	local f = M.frame
	if f and f.dlg then f.dlg:Hide() end
end

-- ---------------------------------------------------------------- panneau : rafraichissement
function M.Refresh()
	local f = M.frame
	if not f then return end
	if M.LevelsStale() then M.SyncLevels() end
	local n = M.tab
	btnText(f.tabs[3], L("msg.auction.tab.sales") .. (M.oN > 0 and (" (" .. M.oN .. ")") or ""))
	setText(f.help, L("msg.auction.help." .. TABKEYS[n]))
	if n == 1 then
		M.RefreshSearch(f)
	elseif n == 2 then
		M.RefreshSell(f)
	elseif n == 3 then
		M.RefreshSales(f)
	else
		M.RefreshAnalysis(f)
	end
	btnText(f.bz, M.Mode() == "shikiui" and L("msg.auction.btn.blizzard") or L("msg.auction.btn.shikiui"))
	M.dirty = false
end

function M.RefreshSearch(f)
	if M.scan then
		setText(f.status, L("msg.auction.scanning", M.page + 1, M.pages, M.seen))
	elseif M.loc then
		setText(f.status, L("msg.auction.locating", M.loc.name))
	elseif M.query then
		if M.query == "" then
			setText(f.status, L("msg.auction.foundall", M.n))
		else
			setText(f.status, L("msg.auction.found", M.n, M.query))
		end
	else
		setText(f.status, L("msg.auction.idle"))
	end
	if M.low then
		local s = L("msg.auction.stats", M.MoneyShort(M.low), M.med and M.MoneyShort(M.med) or "-", M.sugBuy and M.MoneyShort(M.sugBuy) or "-")
		if M.ref then s = s .. L("msg.auction.statsref", M.MoneyShort(M.ref), L("msg.auction.src." .. M.refSrc)) end
		setText(f.stats, s)
	else
		setText(f.stats, L("msg.auction.nostats"))
	end
	M.SyncEdits()
	local busy = M.scan or M.loc
	if busy then f.stop:Show() else f.stop:Hide() end
	T.SetSelected(f.favstar, M.IsFav(f.edit:GetText()))
	-- filtres
	local cname = M.classes[M.fClass or 0]
	btnText(f.fclass, L("msg.auction.f.class", cname or L("msg.auction.f.all")))
	local subs = M.fClass and M.SubClasses() or nil
	local sname = subs and subs[M.fSub or 0] or nil
	btnText(f.fsub, L("msg.auction.f.sub", sname or L("msg.auction.f.all")))
	M.SetEn(f.fsub, M.fClass ~= nil)
	local q = C.Get("auction.quality")
	btnText(f.fqual, L("msg.auction.f.qual", q > 0 and L("msg.auction.q." .. q) or L("msg.auction.f.all")))
	if q > 0 then
		local r, g, b = qcolor(q)
		setColor(f.fqual.label, "q" .. q, r, g, b)
	else
		tokColor(f.fqual.label, "text")
	end
	T.SetCheck(f.fusable, C.Get("auction.usable"))
	T.SetCheck(f.fdeals, M.onlyDeals)
	-- en-tetes
	local arrow = M.sortDesc and " v" or " ^"
	btnText(f.hdr.unit, L("msg.auction.col.unit") .. (M.sort == "unit" and arrow or ""))
	btnText(f.hdr.total, L("msg.auction.col.total") .. (M.sort == "total" and arrow or ""))
	btnText(f.hdr.seller, L("msg.auction.col.seller") .. (M.sort == "seller" and arrow or ""))
	btnText(f.hdr.time, L("msg.auction.col.time") .. (M.sort == "time" and arrow or ""))
	setText(f.hdr.name, L("msg.auction.col.item"))
	setText(f.hdr.deal.label, L("msg.auction.col.deal"))
	-- lignes
	local rows = C.Get("auction.rows")
	local maxoff = M.nord - rows
	if maxoff < 0 then maxoff = 0 end
	if M.offset > maxoff then M.offset = maxoff end
	local style = C.Get("auction.dealstyle")
	local dp = C.Get("auction.dealpct")
	local ar, ag, ab = T.Accent()
	for i = 1, NROWS do
		local r = f.rows[i]
		local pos = M.offset + i
		local k = M.ord[pos]
		if i <= rows and pos <= M.nord and k then
			setText(r.name, M.rCnt[k] .. "x " .. M.rName[k])
			local qr, qg, qb = qcolor(M.rQ[k])
			setColor(r.name, "q" .. (M.rQ[k] or 0), qr, qg, qb)
			if r.tex ~= M.rTex[k] then
				r.tex = M.rTex[k]
				if M.rTex[k] then r.icon:SetTexture(M.rTex[k]) end
			end
			setText(r.price, M.rUnit[k] > 0 and M.MoneyShort(M.rUnit[k]) or ("(" .. M.MoneyShort(M.rBid[k]) .. ")"))
			setText(r.total, M.rBuy[k] > 0 and M.MoneyShort(M.rBuy[k]) or "-")
			local pct = M.DealPct(k)
			local good = pct ~= nil and pct >= dp and M.rOwn[k] ~= M.me
			if pct and style ~= "none" then
				setText(r.deal, dealText(pct))
				if style == "row" then
					tokColor(r.deal, "dim")
				elseif good then
					tokColor(r.deal, "good")
				elseif pct <= -dp then
					tokColor(r.deal, "bad")
				else
					tokColor(r.deal, "dim")
				end
			else
				setText(r.deal, "")
			end
			if good and (style == "row" or style == "both") then
				local c = T.c.good
				r.tint:SetVertexColor(c[1], c[2], c[3], 0.18)
				r.tint:Show()
			else
				r.tint:Hide()
			end
			if M.rOwn[k] == M.me then
				setText(r.seller, L("msg.auction.me"))
				tokColor(r.seller, "warn")
			else
				setText(r.seller, M.rOwn[k] or "?")
				tokColor(r.seller, "dim")
			end
			setText(r.time, M.LeftText(M.rLeft[k]))
			local lf = M.rLeft[k] or 3
			tokColor(r.time, lf <= 1 and "bad" or (lf == 2 and "warn" or "dim"))
			if M.rUnit[k] > 0 then tokColor(r.price, "good") else tokColor(r.price, "dim") end
			if M.sel == pos then
				r.sel:SetVertexColor(ar, ag, ab, 0.28)
				r.sel:Show()
			else
				r.sel:Hide()
			end
			r:Show()
		else
			r:Hide()
		end
	end
	-- selection et actions
	local k = M.SelIndex()
	if k then
		local pct = M.DealPct(k)
		local s = LF("msg.auction.detail", M.rCnt[k], M.rName[k], M.rBuy[k] > 0 and M.MoneyShort(M.rBuy[k]) or "-",
			M.rUnit[k] > 0 and M.MoneyShort(M.rUnit[k]) or "-", M.rOwn[k] or "?", M.LeftText(M.rLeft[k]))
		if pct then s = s .. " - " .. dealText(pct) end
		setText(f.detail, s)
	else
		setText(f.detail, L("msg.auction.detail.none"))
	end
	local ok = not busy
	M.SetEn(f.buy, ok and M.CanBuy(k) and true or false)
	M.SetEn(f.bid, ok and M.CanBid(k) and true or false)
	M.SetEn(f.findb, k ~= nil)
	M.SetEn(f.favb, k ~= nil)
	M.SetEn(f.up, M.offset > 0)
	M.SetEn(f.down, M.offset < maxoff)
end

function M.RefreshSell(f)
	if not M.open then return end
	local name, tex, count, q = GetAuctionSellItemInfo()
	count = count or 1
	if M.sellName ~= name then M.OnSellChanged(true) return end
	if name then
		setText(f.sname, name)
		local r, g, b = qcolor(q)
		setColor(f.sname, "q" .. (q or 0), r, g, b)
		if f.slot.tex ~= tex then
			f.slot.tex = tex
			if tex then f.slot.icon:SetTexture(tex) end
		end
		f.slot.icon:Show()
		setText(f.slot.count, count > 1 and tostring(count) or "")
	else
		setText(f.sname, L("msg.auction.sell.empty"))
		tokColor(f.sname, "dim")
		f.slot.icon:Hide()
		f.slot.tex = nil
		setText(f.slot.count, "")
	end
	local lots, size, owned = M.Plan(count, name)
	if name then
		setText(f.sinfo, L("msg.auction.sell.owned", owned, count))
	else
		setText(f.sinfo, L("msg.auction.sell.drag"))
	end
	-- marche
	local mk = name and M.qlow and slower(name) == M.qlow
	if mk and M.low then
		local a = M.an
		local s = L("msg.auction.mk.low", M.MoneyShort(M.low), M.med and M.MoneyShort(M.med) or "-", M.nbuy)
		if M.ref then s = s .. "\n" .. L("msg.auction.mk.ref", M.MoneyShort(M.ref), L("msg.auction.src." .. M.refSrc)) end
		if a.trend then s = s .. "\n" .. L("msg.auction.mk.trend", (a.trend >= 0 and "+" or "") .. a.trend .. "%", a.hdays) end
		setText(f.market, s)
	elseif name then
		setText(f.market, M.scan and L("msg.auction.mk.wait") or L("msg.auction.mk.none"))
	else
		setText(f.market, "")
	end
	-- strategie, duree, mode
	local basis = C.Get("auction.basis")
	for i = 1, 3 do T.SetSelected(f.strat[i], f.strat[i].mode == basis) end
	local dur = C.Get("auction.duration")
	for i = 1, 3 do T.SetSelected(f.dur[i], tostring(f.dur[i].mins) == dur) end
	btnText(f.pmode, M.sellMode == "lot" and L("msg.auction.sell.bylot") or L("msg.auction.sell.byunit"))
	-- prix
	local unit = name and M.SellUnitPrice(name) or nil
	if unit and not f.price:HasFocus() then
		local shown = (M.sellMode == "lot") and unit * size or unit
		local s = M.Money(shown)
		if f.price:GetText() ~= s then M.SetEditText(f.price, s) end
	elseif not unit and not f.price:HasFocus() and f.price:GetText() ~= "" then
		M.SetEditText(f.price, "")
	end
	if not f.lotsE:HasFocus() and f.lotsE:GetText() ~= tostring(lots) then M.SetEditText(f.lotsE, tostring(lots)) end
	if not f.sizeE:HasFocus() and f.sizeE:GetText() ~= tostring(size) then M.SetEditText(f.sizeE, tostring(size)) end
	if not unit then
		setText(f.echo, name and L("msg.auction.sell.needprice") or "")
		for i = 1, 5 do setText(f.sum[i], "") end
	else
		local ubid = floor(unit * C.Get("auction.bidpct") / 100)
		if ubid < 1 then ubid = 1 end
		local buy = unit * size
		local cut = C.Get("auction.cut")
		setText(f.echo, L("msg.auction.sell.echo", M.Money(unit), M.Money(buy)))
		setText(f.sum[1], L("msg.auction.sum1", lots, size, name, lots * size))
		setText(f.sum[2], L("msg.auction.sum2", M.Money(buy), M.MoneyShort(unit), M.Money(ubid * size)))
		local dfn = getglobal("CalculateAuctionDeposit")
		local dep = nil
		if type(dfn) == "function" and name then
			local ok, v = pcall(dfn, M.Duration())
			if ok and type(v) == "number" then dep = floor(v * size / count) * lots end
		end
		local fee = floor(buy * cut / 100) * lots
		setText(f.sum[3], L("msg.auction.sum3", dep and M.Money(dep) or "?", cut .. "%", M.Money(fee)))
		setText(f.sum[4], L("msg.auction.sum4", M.Money(buy * lots - fee)))
		if mk and M.low then
			local pl = floor((unit - M.low) * 100 / M.low)
			local s = L("msg.auction.sum5", (pl >= 0 and "+" or "") .. pl .. "%")
			if M.ref and M.ref > 0 then
				local pr = floor((unit - M.ref) * 100 / M.ref)
				s = s .. " " .. L("msg.auction.sum5b", (pr >= 0 and "+" or "") .. pr .. "%")
				if unit * 2 < M.ref or unit > M.ref * 2 then
					s = s .. " " .. L("msg.auction.pricewarn")
					tokColor(f.sum[5], "bad")
				elseif pl < 0 then
					tokColor(f.sum[5], "good")
				else
					tokColor(f.sum[5], "dim")
				end
			else
				tokColor(f.sum[5], "dim")
			end
			setText(f.sum[5], s)
		else
			setText(f.sum[5], L("msg.auction.sum5none"))
			tokColor(f.sum[5], "dim")
		end
	end
	local arming = GetTime() < M.armUntil
	btnText(f.post, arming and L("msg.auction.btn.confirm") or L("msg.auction.btn.post"))
	M.SetEn(f.post, name ~= nil and unit ~= nil and not M.scan and not M.q)
	M.SetEn(f.refresh, name ~= nil and not M.scan)
	M.SetEn(f.takeback, name ~= nil)
end

local function saleState(i)
	if M.oHigh[i] then return L("msg.auction.st.bid", M.oHigh[i]), "good" end
	return L("msg.auction.st.none"), "dim"
end

function M.RefreshSales(f)
	local rows = NOWN
	local maxoff = M.oN - rows
	if maxoff < 0 then maxoff = 0 end
	if M.oOffset > maxoff then M.oOffset = maxoff end
	local total, bids = 0, 0
	for i = 1, M.oN do
		total = total + M.oBuy[i]
		if M.oHigh[i] then bids = bids + 1 end
	end
	setText(f.ssum, M.oN > 0 and L("msg.auction.sales.sum", M.oN, M.MoneyShort(total), bids) or L("msg.auction.sales.empty"))
	local ar, ag, ab = T.Accent()
	for i = 1, NOWN do
		local r = f.orows[i]
		local pos = M.oOffset + i
		if pos <= M.oN then
			setText(r.name, M.oCnt[pos] .. "x " .. M.oName[pos])
			local qr, qg, qb = qcolor(M.oQ[pos])
			setColor(r.name, "q" .. (M.oQ[pos] or 0), qr, qg, qb)
			if r.tex ~= M.oTex[pos] then
				r.tex = M.oTex[pos]
				if M.oTex[pos] then r.icon:SetTexture(M.oTex[pos]) end
			end
			setText(r.bid, M.MoneyShort(M.oCur[pos] > 0 and M.oCur[pos] or M.oBid[pos]))
			setText(r.buy, M.oBuy[pos] > 0 and M.MoneyShort(M.oBuy[pos]) or "-")
			setText(r.time, M.LeftText(M.oLeft[pos]))
			local s, tok = saleState(pos)
			setText(r.state, s)
			tokColor(r.state, tok)
			-- position face au plus bas prix connu (memoire des prix)
			local id = idOf(M.oLink[pos])
			local known = id and M.prices[id]
			if known and M.oBuy[pos] > 0 then
				local unit = floor(M.oBuy[pos] / M.oCnt[pos])
				local pl = floor((unit - known) * 100 / known)
				setText(r.vs, (pl >= 0 and "+" or "") .. pl .. "%")
				tokColor(r.vs, pl > 0 and "warn" or "good")
			else
				setText(r.vs, "")
			end
			if M.oSel == pos then
				r.sel:SetVertexColor(ar, ag, ab, 0.28)
				r.sel:Show()
			else
				r.sel:Hide()
			end
			r:Show()
		else
			r:Hide()
		end
	end
	local i = M.oSel
	if i and i <= M.oN then
		setText(f.sdetail, L("msg.auction.sales.detail", M.oCnt[i], M.oName[i], M.Money(M.oBid[i]), M.oBuy[i] > 0 and M.Money(M.oBuy[i]) or "-"))
	else
		setText(f.sdetail, L("msg.auction.detail.none"))
	end
	local arming = GetTime() < M.cancelUntil
	btnText(f.cancelb, arming and L("msg.auction.btn.confirm") or L("msg.auction.btn.cancel"))
	M.SetEn(f.cancelb, i ~= nil)
	M.SetEn(f.pricesb, i ~= nil)
	M.SetEn(f.sup, M.oOffset > 0)
	M.SetEn(f.sdown, M.oOffset < maxoff)
end

function M.RefreshAnalysis(f)
	local a = M.an
	local x = f.an
	M.SyncEdits()
	if M.scan then
		setText(x.status, L("msg.auction.scanning", M.page + 1, M.pages, M.seen))
	elseif a.n > 0 then
		setText(x.status, L("msg.auction.an.status", a.n, M.query ~= "" and M.query or "*"))
	else
		setText(x.status, M.query and L("msg.auction.an.nodata") or L("msg.auction.an.idle"))
	end
	if M.scan or M.loc then x.stop:Show() else x.stop:Hide() end
	local has = a.n > 0
	local vals = {}
	if has then
		vals[1] = L("msg.auction.an.offers", a.n, a.units, a.sellers)
		vals[2] = M.Money(a.min)
		vals[3] = M.med and M.Money(M.med) or "-"
		vals[4] = M.Money(a.mean)
		vals[5] = M.Money(a.max)
		vals[6] = L("msg.auction.an.spread", M.MoneyShort(a.spread), (a.spreadPct or 0) .. "%")
	else
		for i = 1, 6 do vals[i] = "-" end
	end
	for i = 1, 6 do setText(x.val[i], vals[i]) end
	setText(x.note, (has and a.partial) and L("msg.auction.an.partial", M.n) or "")
	-- distribution
	local mx = 0
	for b = 1, NBUCK do
		if (a.bk[b] or 0) > mx then mx = a.bk[b] end
	end
	for b = 1, NBUCK do
		local bar = x.bar[b]
		if has and mx > 0 then
			bar:SetValue((a.bk[b] or 0) / mx)
			bar:Show()
		else
			bar:SetValue(0)
		end
	end
	setText(x.blo, has and M.MoneyShort(a.blo) or "")
	setText(x.bhi, has and M.MoneyShort(a.bhi) or "")
	-- valeur d'un lot
	local qty = tonumber(x.qty:GetText()) or 1
	if qty < 1 then qty = 1 end
	local vmin, vmed, vmean, vsell, vnet = M.LotValue(qty)
	if vmin then
		setText(x.lot1, L("msg.auction.an.lot1", qty, M.Money(vmin), M.Money(vmed), M.Money(vmean)))
		if vsell then
			setText(x.lot2, L("msg.auction.an.lot2", M.Money(vsell), M.Money(vnet)))
		else
			setText(x.lot2, "")
		end
	else
		setText(x.lot1, L("msg.auction.an.nolot"))
		setText(x.lot2, "")
	end
	-- tendance
	if has and a.trend then
		setText(x.trend, L("msg.auction.an.trend", M.MoneyShort(M.med or 0), M.MoneyShort(a.havg), (a.trend >= 0 and "+" or "") .. a.trend .. "%", a.hdays))
		tokColor(x.trend, "text")
	elseif has then
		setText(x.trend, L("msg.auction.an.notrend"))
		tokColor(x.trend, "dim")
	else
		setText(x.trend, "")
	end
	local tmx = 0
	for j = 1, a.ntr do
		if a.tr[j] > tmx then tmx = a.tr[j] end
	end
	for j = 1, NTREND do
		local bar = x.tbar[j]
		if j <= a.ntr and tmx > 0 then
			bar.v = a.tr[j]
			bar:SetValue(a.tr[j] / tmx)
			bar:Show()
		else
			bar.v = nil
			bar:Hide()
		end
	end
	-- profit de revente
	if has and M.ref then
		local margin, cut = C.Get("auction.margin"), C.Get("auction.cut")
		if a.pn > 0 then
			setText(x.profit, LF("msg.auction.an.profit", a.pn, margin .. "%", M.Money(a.pcost), M.Money(a.pnet), cut .. "%"))
			tokColor(x.profit, "good")
		else
			setText(x.profit, L("msg.auction.an.noprofit", margin .. "%"))
			tokColor(x.profit, "dim")
		end
		for j = 1, 3 do
			if j <= a.nt then
				local k = a.tk[j]
				setText(x.top[j], LF("msg.auction.an.top", j, M.rCnt[k], M.rName[k], M.MoneyShort(M.rBuy[k]), M.MoneyShort(a.tv[j]), M.rOwn[k] or "?"))
			else
				setText(x.top[j], "")
			end
		end
		setText(x.refl, L("msg.auction.an.ref", M.Money(M.ref), L("msg.auction.src." .. M.refSrc)))
	else
		setText(x.profit, has and L("msg.auction.an.noref") or "")
		tokColor(x.profit, "dim")
		for j = 1, 3 do setText(x.top[j], "") end
		setText(x.refl, "")
	end
	M.SetEn(x.deals, has and M.ref ~= nil)
	M.SetEn(x.go, not M.scan)
end

function M.Scroll(d)
	M.offset = M.offset + d
	if M.offset < 0 then M.offset = 0 end
	M.Refresh()
end

function M.ScrollOwned(d)
	M.oOffset = M.oOffset + d
	if M.oOffset < 0 then M.oOffset = 0 end
	M.Refresh()
end

function M.Wheel(d)
	if not d or d == 0 then return end
	if M.tab == 1 then
		M.Scroll(d > 0 and -3 or 3)
	elseif M.tab == 3 then
		M.ScrollOwned(d > 0 and -3 or 3)
	end
end

function M.ApplyOptions()
	local f = M.frame
	if not f then return end
	f:SetHeight(M.Height())
	M.LayoutRows()
	if M.open and C.Get("auction.panel") then f:Show() else f:Hide() end
	M.ApplyView()
	M.dirty = true
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
	local rec = SUI.Mover and SUI.Mover.items and SUI.Mover.items["auction"]
	if l and b and rec and SUI.Mover.Commit then
		local sc = f:GetScale() or 1
		SUI.Mover.Commit(rec, l * sc, b * sc)
	elseif l and b and SUI.Layout then      -- sans Mover : memoriser quand meme (sinon Layout.Apply ramenerait le cadre en arriere)
		local sc = f:GetScale() or 1
		local _, _, s = C.GetPos(SUI.Layout.ReadKey("auction"))
		C.SetPos(SUI.Layout.WriteKey("auction"), l * sc, b * sc, s)
		SUI.Layout.Apply("auction")
	elseif SUI.Layout then
		SUI.Layout.Apply("auction")
	end
	return true
end

function M.Place(f)
	local reg = SUI.Mover and SUI.Mover.Register
	if not (reg and reg("auction", f, { label = "mod.mover.n.auction", point = "LEFT", x = 420, y = 0, scale = true })) then
		SUI.Layout.Register(f, "auction", "LEFT", 420, 0)
	end
	f:SetScript("OnMouseDown", function() M.DragStart(f) end)
	f:SetScript("OnMouseUp", function() M.DragStop(f) end)
	f:SetScript("OnHide", function() M.DragStop(f) end)
end

-- ---------------------------------------------------------------- construction : onglet Chercher
function M.BuildSearch(f, p)
	f.edit = edit(f, p, 210, 0, 0, "msg.auction.tip.search", "msg.auction.tip.search.d")
	f.edit:SetMaxLetters(63)
	f.edit:SetScript("OnEnterPressed", function()
		M.HideHints()
		M.Search(this:GetText())
		this:ClearFocus()
	end)
	f.edit:SetScript("OnTextChanged", function() M.OnSearchText(this) end)
	f.edit:SetScript("OnEditFocusGained", function() M.ShowHints(this:GetText()) end)
	f.edit:SetScript("OnEditFocusLost", function() M.HideHintsLater() end)
	f.hintb = btn(f, p, "v", 20, 18, 214, 0, function()
		if f.hint:IsShown() then M.HideHints() else M.ShowHints("") end
	end, "msg.auction.tip.hist", "msg.auction.tip.hist.d")
	f.go = btn(f, p, L("msg.auction.btn.search"), 64, 18, 238, 0, function() M.HideHints() M.Search(f.edit:GetText()) end,
		"msg.auction.btn.search", "msg.auction.tip.go.d")
	f.stop = btn(f, p, L("msg.auction.btn.stop"), 44, 18, 306, 0, function() M.StopScan(false) M.StopLocate() M.Refresh() end,
		"msg.auction.btn.stop", "msg.auction.tip.stop.d")
	f.stop:Hide()
	f.favstar = btn(f, p, "*", 30, 18, 354, 0, function() M.ToggleFav(f.edit:GetText()) end, "msg.auction.tip.fav", "msg.auction.tip.fav.d")
	-- filtres
	f.fclass = btn(f, p, "", 124, 18, 0, -24, function(b, bt) M.CycleClass(bt == "RightButton" and -1 or 1) end,
		"msg.auction.tip.class", "msg.auction.tip.cycle.d")
	f.fsub = btn(f, p, "", 124, 18, 128, -24, function(b, bt) M.CycleSub(bt == "RightButton" and -1 or 1) end,
		"msg.auction.tip.sub", "msg.auction.tip.cycle.d")
	local lv = txt(p, 11, T.c.dim, "LEFT", 22, 258, -27)
	lv:SetText(L("msg.auction.f.lvl"))
	f.minl = edit(f, p, 26, 282, -24, "msg.auction.tip.lvl", "msg.auction.tip.lvl.d")
	f.minl:SetNumeric(true)
	f.minl:SetMaxLetters(2)
	f.maxl = edit(f, p, 26, 312, -24, "msg.auction.tip.lvl", "msg.auction.tip.lvl.d")
	f.maxl:SetNumeric(true)
	f.maxl:SetMaxLetters(2)
	f.minl:SetScript("OnTextChanged", function()
		if M.setting then return end
		local v = tonumber(this:GetText())
		M.fMinL = (v and v > 0) and v or nil
	end)
	f.maxl:SetScript("OnTextChanged", function()
		if M.setting then return end
		local v = tonumber(this:GetText())
		M.fMaxL = (v and v > 0) and v or nil
	end)
	f.fqual = btn(f, p, "", 112, 18, 344, -24, function(b, bt) M.CycleQuality(bt == "RightButton" and -1 or 1) end,
		"msg.auction.tip.qual", "msg.auction.tip.cycle.d")
	f.freset = btn(f, p, L("msg.auction.btn.reset"), 44, 18, 460, -24, function() M.ResetFilters() end,
		"msg.auction.btn.reset", "msg.auction.tip.reset.d")
	f.fusable = check(f, p, 0, -48, L("msg.auction.f.usable"), 90, function(on) C.Set("auction.usable", on) end,
		"msg.auction.f.usable", "tip.auction.usable")
	f.fdeals = check(f, p, 112, -48, L("msg.auction.f.deals"), 118, function(on) M.SetDeals(on) end,
		"msg.auction.f.deals", "msg.auction.tip.deals.d")
	f.status = txt(p, 11, T.c.text, "RIGHT", 300, 264, -50)
	-- en-tetes de colonnes (positions : M.LayoutRows)
	f.hdr = {}
	f.hdr.name = txt(p, 10, T.c.dim, "LEFT", 200, 0, -70)
	f.hdr.unit = btn(f, p, "", 76, 14, 0, -70, function() M.SetSort("unit") end, "msg.auction.col.unit", "msg.auction.tip.sort.d")
	f.hdr.total = btn(f, p, "", 76, 14, 0, -70, function() M.SetSort("total") end, "msg.auction.col.total", "msg.auction.tip.sort.d")
	f.hdr.seller = btn(f, p, "", 70, 14, 0, -70, function() M.SetSort("seller") end, "msg.auction.col.seller", "msg.auction.tip.sort.d")
	f.hdr.time = btn(f, p, "", 40, 14, 0, -70, function() M.SetSort("time") end, "msg.auction.col.time", "msg.auction.tip.sort.d")
	f.hdr.deal = CreateFrame("Frame", nil, p)
	f.hdr.deal:SetWidth(44)
	f.hdr.deal:SetHeight(14)
	f.hdr.deal.label = T.Text(f.hdr.deal, 10, T.c.dim, "RIGHT")
	f.hdr.deal.label:SetPoint("RIGHT", f.hdr.deal, "RIGHT", 0, 0)
	kid(f, f.hdr.deal, 2)
	f.rows = {}
	for i = 1, NROWS do
		local r = CreateFrame("Button", nil, p)
		kid(f, r, 2)
		r:SetWidth(PW - 16)
		r:SetHeight(18)
		r.pos = i
		r.sel = r:CreateTexture(nil, "BACKGROUND")
		r.sel:SetAllPoints(r)
		r.sel:SetTexture(T.tex.white)
		r.sel:Hide()
		r.tint = r:CreateTexture(nil, "BACKGROUND")
		r.tint:SetAllPoints(r)
		r.tint:SetTexture(T.tex.white)
		r.tint:Hide()
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.name = T.Text(r, 11, T.c.text, "LEFT")
		r.price = T.Text(r, 11, T.c.good, "RIGHT")
		r.total = T.Text(r, 11, T.c.dim, "RIGHT")
		r.deal = T.Text(r, 11, T.c.dim, "RIGHT")
		r.seller = T.Text(r, 11, T.c.dim, "LEFT")
		r.time = T.Text(r, 11, T.c.dim, "RIGHT")
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r:SetScript("OnClick", function() M.RowClick(this.pos, arg1) end)
		r:SetScript("OnDoubleClick", function() M.RowDouble(this.pos) end)
		r:SetScript("OnEnter", function() M.RowTip(this) end)
		r:SetScript("OnLeave", function() M.TipHide() end)
		r:EnableMouseWheel(true)
		r:SetScript("OnMouseWheel", function() M.Wheel(arg1) end)
		r:Hide()
		f.rows[i] = r
	end
	-- bas de page (suit les lignes : M.LayoutRows)
	f.tail = CreateFrame("Frame", nil, p)
	f.tail:SetWidth(PW - 16)
	f.tail:SetHeight(80)
	kid(f, f.tail, 1)
	local t = f.tail
	f.up = btn(f, t, "<", 20, 16, 0, -2, function() M.Scroll(-C.Get("auction.rows")) end, "msg.auction.tip.prev", "msg.auction.tip.page.d")
	f.down = btn(f, t, ">", 20, 16, 24, -2, function() M.Scroll(C.Get("auction.rows")) end, "msg.auction.tip.next", "msg.auction.tip.page.d")
	f.stats = txt(t, 11, T.c.dim, "LEFT", 512, 52, -4)
	f.detail = txt(t, 11, T.c.text, "LEFT", PW - 16, 0, -24)
	f.detail:SetHeight(26)
	f.buy = btn(f, t, L("msg.auction.btn.buy"), 120, 20, 0, -54, function() M.AskBuy("buy") end, "msg.auction.btn.buy", "msg.auction.tip.buy.d")
	f.bid = btn(f, t, L("msg.auction.btn.bid"), 110, 20, 126, -54, function() M.AskBuy("bid") end, "msg.auction.btn.bid", "msg.auction.tip.bid.d")
	f.favb = btn(f, t, L("msg.auction.btn.fav"), 90, 20, 242, -54, function()
		local k = M.SelIndex()
		if k then M.ToggleFav(M.rName[k]) end
	end, "msg.auction.btn.fav", "msg.auction.tip.favsel.d")
	f.findb = btn(f, t, L("msg.auction.btn.find"), 130, 20, 338, -54, function()
		local k = M.SelIndex()
		if k then
			M.SetEditText(f.edit, M.rName[k])
			M.Search(M.rName[k])
		end
	end, "msg.auction.btn.find", "msg.auction.tip.find.d")
	-- suggestions (au-dessus des lignes)
	f.hint = T.Panel(p, 210, NHINT * 16 + 4)
	f.hint:SetPoint("TOPLEFT", f.edit, "BOTTOMLEFT", 0, 0)
	f.hint:EnableMouse(true)
	kid(f, f.hint, 6)
	f.hint.b = {}
	for i = 1, NHINT do
		local b = T.Button(f.hint, "", 204, 15, function(self, bt) M.PickHint(self.pos, bt) end)
		b:SetPoint("TOPLEFT", f.hint, "TOPLEFT", 3, -2 - (i - 1) * 16)
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
		b.label:SetJustifyH("LEFT")
		b.pos = i
		kid(f, b, 7)
		tip(b, "msg.auction.tip.hint", "msg.auction.tip.hint.d")
		f.hint.b[i] = b
	end
	f.hint:Hide()
end

-- ---------------------------------------------------------------- construction : onglet Vendre
local function sellEdit(f, p, w, x, y, tk, dk, fn)
	local e = edit(f, p, w, x, y, tk, dk)
	e:SetScript("OnTextChanged", function()
		if M.setting then return end
		fn(this:GetText())
		M.dirty = true
		SUI.After(0.05, function() if M.on and M.open and M.tab == 2 then M.Refresh() end end, "auction.sellref")
	end)
	return e
end

function M.AdjustPrice(dp)
	local name = GetAuctionSellItemInfo()
	local base = M.SellUnitPrice(name)
	if not base then return end
	local new = floor(base * (100 + dp) / 100)
	if new == base then new = base + (dp > 0 and 1 or -1) end
	if new < 1 then new = 1 end
	M.sellUnit = new
	M.armUntil = 0
	M.Refresh()
end

function M.BuildSell(f, p)
	local s = CreateFrame("Button", nil, p)
	s:SetWidth(40)
	s:SetHeight(40)
	s:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
	T.Backdrop(s, T.c.inset, T.c.border)
	kid(f, s, 2)
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2)
	s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2)
	s.icon:Hide()
	s.count = T.Text(s, 11, T.c.text, "RIGHT", true)
	s.count:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -3, 3)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	s:SetScript("OnClick", function() M.SlotClick() end)
	s:SetScript("OnReceiveDrag", function() M.SlotClick() end)
	tip(s, "msg.auction.tip.slot", "msg.auction.tip.slot.d")
	f.slot = s
	f.sname = txt(p, 12, T.c.text, "LEFT", 230, 50, -2)
	f.sinfo = txt(p, 11, T.c.dim, "LEFT", 230, 50, -18)
	f.market = txt(p, 11, T.c.dim, "LEFT", 270, 294, -2)
	f.market:SetHeight(44)
	f.refresh = btn(f, p, L("msg.auction.btn.refresh"), 90, 18, 50, -34, function() M.SearchSlot() end,
		"msg.auction.btn.refresh", "msg.auction.tip.refresh.d")
	f.takeback = btn(f, p, L("msg.auction.btn.take"), 110, 18, 144, -34, function() M.SlotClick() end,
		"msg.auction.btn.take", "msg.auction.tip.take.d")
	-- strategie de prix
	local l1 = txt(p, 11, T.c.dim, "LEFT", 90, 0, -62)
	l1:SetText(L("msg.auction.sell.strat"))
	f.strat = {}
	local modes = { "lowest", "median", "fixed" }
	for i = 1, 3 do
		local b = btn(f, p, L("choice.auction.basis." .. modes[i]), 130, 18, 92 + (i - 1) * 134, -60, function(self)
			M.sellUnit = nil
			M.armUntil = 0
			C.Set("auction.basis", self.mode)
			M.Refresh()
		end, "choice.auction.basis." .. modes[i], "msg.auction.tip.basis." .. modes[i])
		b.mode = modes[i]
		f.strat[i] = b
	end
	-- prix
	local l2 = txt(p, 11, T.c.dim, "LEFT", 90, 0, -88)
	l2:SetText(L("msg.auction.sell.price"))
	f.pmode = btn(f, p, "", 80, 18, 92, -86, function()
		M.sellMode = (M.sellMode == "lot") and "unit" or "lot"
		M.Refresh()
	end, "msg.auction.tip.pmode", "msg.auction.tip.pmode.d")
	f.price = sellEdit(f, p, 118, 176, -86, "msg.auction.tip.price", "msg.auction.tip.price.d", function(text)
		local v = M.ParseMoney(text)
		if not v then M.sellUnit = nil return end
		local size = M.size or 1
		if M.sellMode == "lot" then v = floor(v / (size > 0 and size or 1)) end
		if v < 1 then v = 1 end
		M.sellUnit = v
		M.armUntil = 0
	end)
	f.step = {}
	local deltas = { -5, -1, 1, 5 }
	for i = 1, 4 do
		local b = btn(f, p, (deltas[i] > 0 and "+" or "") .. deltas[i] .. "%", 34, 18, 298 + (i - 1) * 36, -86, function(self) M.AdjustPrice(self.dp) end,
			"msg.auction.tip.step", "msg.auction.tip.step.d")
		b.dp = deltas[i]
		f.step[i] = b
	end
	f.sugb = btn(f, p, L("msg.auction.btn.sug"), 96, 18, 442, -86, function()
		M.sellUnit = nil
		M.armUntil = 0
		M.Refresh()
	end, "msg.auction.btn.sug", "msg.auction.tip.sug.d")
	f.echo = txt(p, 11, T.c.dim, "LEFT", PW - 16, 92, -108)
	-- lots et duree
	local l3 = txt(p, 11, T.c.dim, "LEFT", 90, 0, -132)
	l3:SetText(L("msg.auction.sell.lots"))
	f.lotsE = sellEdit(f, p, 34, 92, -130, "msg.auction.tip.lots", "msg.auction.tip.lots.d", function(text)
		local v = tonumber(text)
		if v and v >= 1 and v <= 99 then M.lots = floor(v) end
		M.armUntil = 0
	end)
	f.lotsE:SetNumeric(true)
	f.lotsE:SetMaxLetters(2)
	local l4 = txt(p, 11, T.c.dim, "CENTER", 24, 128, -133)
	l4:SetText(L("msg.auction.sell.of"))
	f.sizeE = sellEdit(f, p, 40, 154, -130, "msg.auction.tip.size", "msg.auction.tip.size.d", function(text)
		local v = tonumber(text)
		if v and v >= 1 and v <= 999 then M.size = floor(v) end
		M.armUntil = 0
	end)
	f.sizeE:SetNumeric(true)
	f.sizeE:SetMaxLetters(3)
	f.maxb = btn(f, p, L("msg.auction.btn.max"), 44, 18, 198, -130, function()
		local name, _, count = GetAuctionSellItemInfo()
		if not name then return end
		local owned = M.OwnedCount(name, count or 1)
		local size = M.size or 1
		if size < 1 then size = 1 end
		local n = floor(owned / size)
		if n < 1 then n = 1 end
		if n > 99 then n = 99 end
		M.lots = n
		M.armUntil = 0
		M.Refresh()
	end, "msg.auction.btn.max", "msg.auction.tip.max.d")
	local l5 = txt(p, 11, T.c.dim, "LEFT", 50, 270, -133)
	l5:SetText(L("msg.auction.sell.dur"))
	f.dur = {}
	local mins = { 120, 480, 1440 }
	for i = 1, 3 do
		local b = btn(f, p, L("choice.auction.duration." .. mins[i]), 74, 18, 322 + (i - 1) * 78, -130, function(self)
			M.armUntil = 0
			C.Set("auction.duration", tostring(self.mins))
			M.Refresh()
		end, "opt.auction.duration", "tip.auction.duration")
		b.mins = mins[i]
		f.dur[i] = b
	end
	-- resume
	f.sum = {}
	for i = 1, 5 do f.sum[i] = txt(p, 11, i == 5 and T.c.dim or T.c.text, "LEFT", PW - 16, 0, -160 - (i - 1) * 15) end
	f.post = btn(f, p, L("msg.auction.btn.post"), 150, 22, PW - 16 - 150, -240, function() M.Post(true) end,
		"msg.auction.btn.post", "msg.auction.tip.post.d")
end

-- ---------------------------------------------------------------- construction : onglet Mes ventes
function M.BuildSales(f, p)
	f.ssum = txt(p, 11, T.c.text, "LEFT", 400, 0, 0)
	f.srefresh = btn(f, p, L("msg.auction.btn.refresh"), 90, 18, PW - 16 - 90, -2, function() M.RequestOwned() end,
		"msg.auction.btn.refresh", "msg.auction.tip.srefresh.d")
	local hd = { { "msg.auction.col.item", 0, 210, "LEFT" }, { "msg.auction.col.bid", 214, 70, "RIGHT" }, { "msg.auction.col.buy", 288, 70, "RIGHT" },
		{ "msg.auction.col.time", 362, 40, "RIGHT" }, { "msg.auction.col.state", 408, 100, "LEFT" }, { "msg.auction.col.vs", 508, 56, "RIGHT" } }
	for i = 1, getn(hd) do
		local fs = txt(p, 10, T.c.dim, hd[i][4], hd[i][3], hd[i][2], -24)
		fs:SetText(L(hd[i][1]))
	end
	f.orows = {}
	for i = 1, NOWN do
		local r = CreateFrame("Button", nil, p)
		kid(f, r, 2)
		r:SetWidth(PW - 16)
		r:SetHeight(18)
		r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -38 - (i - 1) * 18)
		r.pos = i
		r.sel = r:CreateTexture(nil, "BACKGROUND")
		r.sel:SetAllPoints(r)
		r.sel:SetTexture(T.tex.white)
		r.sel:Hide()
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
		r.icon:SetWidth(16)
		r.icon:SetHeight(16)
		r.name = T.Text(r, 11, T.c.text, "LEFT")
		r.name:SetPoint("LEFT", r, "LEFT", 20, 0)
		r.name:SetWidth(190)
		r.bid = T.Text(r, 11, T.c.dim, "RIGHT")
		r.bid:SetPoint("LEFT", r, "LEFT", 214, 0)
		r.bid:SetWidth(70)
		r.buy = T.Text(r, 11, T.c.good, "RIGHT")
		r.buy:SetPoint("LEFT", r, "LEFT", 288, 0)
		r.buy:SetWidth(70)
		r.time = T.Text(r, 11, T.c.dim, "RIGHT")
		r.time:SetPoint("LEFT", r, "LEFT", 362, 0)
		r.time:SetWidth(40)
		r.state = T.Text(r, 11, T.c.dim, "LEFT")
		r.state:SetPoint("LEFT", r, "LEFT", 408, 0)
		r.state:SetWidth(100)
		r.vs = T.Text(r, 11, T.c.dim, "RIGHT")
		r.vs:SetPoint("LEFT", r, "LEFT", 508, 0)
		r.vs:SetWidth(56)
		r:SetScript("OnClick", function() M.SelectOwned(M.oOffset + this.pos) end)
		r:SetScript("OnEnter", function()
			local gt = getglobal("GameTooltip")
			local pos = M.oOffset + this.pos
			if not gt or not M.oLink[pos] then return end
			gt:SetOwner(this, "ANCHOR_RIGHT")
			local _, _, s = sfind(M.oLink[pos], "(item:%d+:%d+:%d+:%d+)")
			if not (s and pcall(gt.SetHyperlink, gt, s)) then gt:SetText(M.oName[pos], T.c.text[1], T.c.text[2], T.c.text[3]) end
			gt:Show()
		end)
		r:SetScript("OnLeave", function() M.TipHide() end)
		r:EnableMouseWheel(true)
		r:SetScript("OnMouseWheel", function() M.Wheel(arg1) end)
		r:Hide()
		f.orows[i] = r
	end
	local y = -38 - NOWN * 18 + 0
	f.sup = btn(f, p, "<", 20, 16, 0, y - 4, function() M.ScrollOwned(-NOWN) end, "msg.auction.tip.prev", "msg.auction.tip.page.d")
	f.sdown = btn(f, p, ">", 20, 16, 24, y - 4, function() M.ScrollOwned(NOWN) end, "msg.auction.tip.next", "msg.auction.tip.page.d")
	f.sdetail = txt(p, 11, T.c.text, "LEFT", PW - 16, 52, y - 4)
	f.cancelb = btn(f, p, L("msg.auction.btn.cancel"), 140, 20, 0, y - 28, function() M.CancelSale(true) end,
		"msg.auction.btn.cancel", "msg.auction.tip.cancel.d")
	f.pricesb = btn(f, p, L("msg.auction.btn.compare"), 160, 20, 146, y - 28, function()
		local i = M.oSel
		if i and M.oName[i] then
			M.SetTab(1)
			M.SetEditText(f.edit, M.oName[i])
			M.Search(M.oName[i])
		end
	end, "msg.auction.btn.compare", "msg.auction.tip.compare.d")
end

-- ---------------------------------------------------------------- construction : onglet Analyse
function M.BuildAnalysis(f, p)
	local x = {}
	f.an = x
	f.aedit = edit(f, p, 210, 0, 0, "msg.auction.tip.aedit", "msg.auction.tip.aedit.d")
	f.aedit:SetMaxLetters(63)
	f.aedit:SetScript("OnEnterPressed", function()
		M.Search(this:GetText())
		this:ClearFocus()
	end)
	x.go = btn(f, p, L("msg.auction.btn.analyze"), 84, 18, 216, 0, function() M.Search(f.aedit:GetText()) end,
		"msg.auction.btn.analyze", "msg.auction.tip.analyze.d")
	x.stop = btn(f, p, L("msg.auction.btn.stop"), 44, 18, 304, 0, function() M.StopScan(false) M.StopLocate() M.Refresh() end,
		"msg.auction.btn.stop", "msg.auction.tip.stop.d")
	x.stop:Hide()
	x.status = txt(p, 11, T.c.text, "RIGHT", 250, PW - 16 - 250, -3)
	-- tableau des prix
	local labels = { "msg.auction.an.l.offers", "msg.auction.an.l.min", "msg.auction.an.l.med", "msg.auction.an.l.mean", "msg.auction.an.l.max", "msg.auction.an.l.spread" }
	x.val = {}
	for i = 1, 6 do
		local lab = txt(p, 11, T.c.dim, "LEFT", 100, 0, -30 - (i - 1) * 15)
		lab:SetText(L(labels[i]))
		x.val[i] = txt(p, 11, T.c.text, "LEFT", 180, 100, -30 - (i - 1) * 15)
	end
	x.note = txt(p, 10, T.c.warn, "LEFT", 280, 0, -120)
	-- distribution
	local dh = txt(p, 11, T.c.dim, "LEFT", 270, 294, -30)
	dh:SetText(L("msg.auction.an.dist"))
	x.bar = {}
	for b = 1, NBUCK do
		local bar = T.Bar(p)
		bar:SetOrientation("VERTICAL")
		bar:SetWidth(24)
		bar:SetHeight(56)
		bar:SetPoint("TOPLEFT", p, "TOPLEFT", 294 + (b - 1) * 27, -46)
		bar:SetValue(0)
		bar:EnableMouse(true)
		bar.bi = b
		kid(f, bar, 2)
		tip(bar, "msg.auction.an.dist", nil, function(fr)
			local a = M.an
			if not a.blo then return nil end
			local w = (a.bhi - a.blo) / NBUCK
			local lo = floor(a.blo + (fr.bi - 1) * w)
			local hi = floor(a.blo + fr.bi * w)
			return L("msg.auction.an.bucket", M.MoneyShort(lo), fr.bi == NBUCK and "+" or M.MoneyShort(hi), a.bk[fr.bi])
		end)
		x.bar[b] = bar
	end
	x.blo = txt(p, 10, T.c.dim, "LEFT", 100, 294, -104)
	x.bhi = txt(p, 10, T.c.dim, "RIGHT", 100, 294 + 270 - 100, -104)
	-- valeur d'un lot
	local lh = txt(p, 11, T.c.text, "LEFT", 200, 0, -140)
	lh:SetText(L("msg.auction.an.lothead"))
	x.qty = sellEdit(f, p, 40, 0, -156, "msg.auction.tip.qty", "msg.auction.tip.qty.d", function() end)
	x.qty:SetNumeric(true)
	x.qty:SetMaxLetters(4)
	M.SetEditText(x.qty, "1")
	x.qty:SetScript("OnTextChanged", function()
		if M.setting then return end
		M.dirty = true
		M.Refresh()
	end)
	x.lot1 = txt(p, 11, T.c.text, "LEFT", 500, 48, -159)
	x.lot2 = txt(p, 11, T.c.dim, "LEFT", 500, 48, -175)
	-- tendance
	local th = txt(p, 11, T.c.text, "LEFT", 270, 294, -140)
	th:SetText(L("msg.auction.an.trendhead"))
	x.trend = txt(p, 11, T.c.text, "LEFT", 270, 294, -156)
	x.trend:SetHeight(26)
	x.tbar = {}
	for j = 1, NTREND do
		local bar = T.Bar(p)
		bar:SetOrientation("VERTICAL")
		bar:SetWidth(15)
		bar:SetHeight(28)
		bar:SetPoint("TOPLEFT", p, "TOPLEFT", 294 + (j - 1) * 19, -186)
		bar:SetValue(0)
		bar:EnableMouse(true)
		bar.bi = j
		kid(f, bar, 2)
		tip(bar, "msg.auction.an.trendhead", nil, function(fr)
			if not fr.v then return nil end
			return L("msg.auction.an.tbar", M.Money(fr.v))
		end)
		bar:Hide()
		x.tbar[j] = bar
	end
	-- profit potentiel
	local ph = txt(p, 11, T.c.text, "LEFT", 400, 0, -222)
	ph:SetText(L("msg.auction.an.profithead"))
	x.profit = txt(p, 11, T.c.good, "LEFT", PW - 16, 0, -238)
	x.profit:SetHeight(26)
	x.top = {}
	for j = 1, 3 do x.top[j] = txt(p, 11, T.c.dim, "LEFT", PW - 16, 0, -266 - (j - 1) * 14) end
	x.refl = txt(p, 10, T.c.dim, "LEFT", 400, 0, -310)
	x.deals = btn(f, p, L("msg.auction.btn.deals"), 180, 20, PW - 16 - 180, -306, function()
		M.SetTab(1)
		M.SetDeals(true)
	end, "msg.auction.btn.deals", "msg.auction.tip.deals2.d")
end

-- ---------------------------------------------------------------- construction : fenetre de confirmation
function M.BuildDialog(f)
	local d = T.Panel(f, 380, 188)
	d:SetPoint("CENTER", f, "CENTER", 0, 0)
	d:EnableMouse(true)
	kid(f, d, 10)
	d.title = txt(d, 13, T.c.text, "LEFT", 356, 12, -10)
	d.l1 = txt(d, 12, T.c.text, "LEFT", 356, 12, -32)
	d.l2 = txt(d, 11, T.c.text, "LEFT", 356, 12, -52)
	d.l3 = txt(d, 11, T.c.dim, "LEFT", 356, 12, -68)
	d.l4 = txt(d, 11, T.c.dim, "LEFT", 356, 12, -84)
	d.l5 = txt(d, 11, T.c.dim, "LEFT", 356, 12, -100)
	d.ok = T.Button(d, "", 170, 24, function() M.ConfirmDialog() end)
	d.ok:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 12)
	kid(f, d.ok, 11)
	tip(d.ok, "msg.auction.dlg.ok", "msg.auction.dlg.ok.d")
	d.no = T.Button(d, L("msg.auction.btn.back"), 170, 24, function() M.CancelDialog() end)
	d.no:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 12)
	kid(f, d.no, 11)
	d:Hide()
	f.dlg = d
end

function M.Build()
	if M.frame then return end
	local f = T.Panel(UIParent, PW, M.Height())
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function() M.Wheel(arg1) end)
	f:Hide()
	f.kids = {}
	f.pages = {}
	f.tabs = {}
	for i = 1, NTAB do
		local b = T.Button(f, L("msg.auction.tab." .. TABKEYS[i]), 94, 20, function(self) M.SetTab(self.tabn) end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * 98, -8)
		b.tabn = i
		kid(f, b, 2)
		tip(b, "msg.auction.tab." .. TABKEYS[i], "msg.auction.tab." .. TABKEYS[i] .. ".d")
		f.tabs[i] = b
		local pg = CreateFrame("Frame", nil, f)
		pg:SetWidth(PW - 16)
		pg:SetHeight(300)
		pg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -36)
		kid(f, pg, 1)
		f.pages[i] = pg
	end
	f.close = T.Button(f, L("msg.auction.btn.close"), 56, 20, function() M.CloseHouse() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	kid(f, f.close, 2)
	tip(f.close, "msg.auction.btn.close", "msg.auction.tip.close.d")
	f.bz = T.Button(f, L("msg.auction.btn.blizzard"), 80, 20, function() M.ToggleView() end)
	f.bz:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
	kid(f, f.bz, 2)
	tip(f.bz, "msg.auction.tip.bz", "msg.auction.tip.bz.d")
	f.help = T.Text(f, 10, T.c.dim, "LEFT")
	f.help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	f.help:SetWidth(PW - 16)
	M.BuildSearch(f, f.pages[1])
	M.BuildSell(f, f.pages[2])
	M.BuildSales(f, f.pages[3])
	M.BuildAnalysis(f, f.pages[4])
	M.BuildDialog(f)
	f:SetScript("OnShow", function() M.SyncLevels() end)
	-- engrenage : ouvre les reglages du module, a gauche du bouton Blizzard (cree APRES l'OnShow : niveau recale a l'ouverture, jamais en combat)
	T.GearButton(f, "auction", { size = 18, point = "TOPRIGHT", x = -152, y = -9, title = L("msg.auction.gear"),
		onCreate = function(g)
			g:ClearAllPoints()
			g:SetPoint("RIGHT", f.bz, "LEFT", -4, 0)
		end })
	M.frame = f
	M.me = UnitName("player")
	M.Place(f)
	M.ReadClasses()
	M.ApplyOptions()
	M.SetTab(M.StartTab())
	T.OnAccent(M.OnRestyle)
end

function M.StartTab()
	local s = C.Get("auction.starttab")
	if s == "last" then return M.tab end
	return M.TabFromName(s) or 1
end

-- ---------------------------------------------------------------- evenements et cycle de vie
-- Blizzard_AuctionUI : AuctionFrameBrowse_Update calcule avec AuctionFrameBrowse.page, qui peut etre nil quand la liste change sans
-- passer par le bouton de recherche de Blizzard (notre requete, un autre addon, le retour d'une vente). On enrobe la fonction UNE fois.
function M.FixBlizzPage()
	M.blizzHooked = M.blizzHooked or {}
	local names = { "Browse", "Bid", "Auctions" }
	for i = 1, getn(names) do
		local n = names[i]
		local fr = getglobal("AuctionFrame" .. n)
		if fr and fr.page == nil then fr.page = 0 end
		local fname = "AuctionFrame" .. n .. "_Update"
		local orig = getglobal(fname)
		if not M.blizzHooked[n] and type(orig) == "function" then
			M.blizzHooked[n] = true
			setglobal(fname, function()
				local b = getglobal("AuctionFrame" .. n)
				if b and b.page == nil then b.page = 0 end
				return orig()
			end)
		end
	end
end

function M.OnShow()
	M.open = true
	M.FixBlizzPage()
	M.me = UnitName("player")
	M.armUntil = 0
	M.view = C.Get("auction.ui")
	SUI.On("NEW_AUCTION_UPDATE", M.OnSellEvent)
	M.sellName = nil
	M.ApplyOptions()
	if M.frame then M.SetTab(M.StartTab()) end
	M.Refresh()
	-- le cadre Blizzard (module a la demande) peut etre cree/affiche apres cet evenement : on reapplique une fois.
	SUI.After(0.2, function() if M.on and M.open then M.ApplyView() end end, "auction.view")
end

function M.OnSellEvent()
	if M.on and M.open then M.OnSellChanged(false) end
end

function M.OnClose()
	M.open = false
	M.ApplyView()
	M.Release()
	if M.frame then M.frame:Hide() end
end

-- Rend minuterie et evenements ; abandonne la recherche, l'achat et la pile en cours.
function M.Release()
	M.scan = false
	M.state = "idle"
	M.armUntil = 0
	M.cancelUntil = 0
	M.loc = nil
	M.dlg = nil
	if M.q then M.StopQueue(nil) end
	M.WatchOwned(false)
	if M.frame and M.frame.dlg then M.frame.dlg:Hide() end
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("AUCTION_ITEM_LIST_UPDATE", M.OnList)
	SUI.Off("NEW_AUCTION_UPDATE", M.OnSellEvent)
end

local DATAKEYS = { ["auction.prices"] = true, ["auction.hist"] = true, ["auction.recent"] = true, ["auction.favs"] = true }

function M.OnKey(key)
	if key == nil or key == "auction.prices" then M.ReadPrices() end
	if not M.selfWrite then
		if key == nil or key == "auction.hist" then M.HistRead() end
		if key == nil or key == "auction.recent" or key == "auction.favs" then M.ReadLists() end
	end
	if key == nil or key == "auction.ui" then M.view = C.Get("auction.ui") end
	if key == nil or key == "auction.basis" or key == "auction.undercut" or key == "auction.undercutpct" or key == "auction.bidpct" then
		if not M.scan and M.n > 0 then M.Stats() end
	end
	if (key == nil or not DATAKEYS[key]) and not M.scan and M.n > 0 then
		M.Analyze()
		M.Resort()
	end
	M.ApplyOptions()
	if M.frame and M.frame:IsShown() then M.Refresh() end
end

function M.Enable()
	-- Blizzard_AuctionUI plante (field page nil) si une mise a jour de liste arrive sans recherche Browse
	-- prealable (nos requetes d'addon declenchent ce cas) : l'update Blizzard est protege par pcall.
	-- le wrapper est transparent : pose une fois, il reste pour toute la session (aucune restauration necessaire)
	if not M.origBrowse then
		local upd = getglobal("AuctionFrameBrowse_Update")
  -- (DBGH retire 2026-11-20 : residu de debug)
		if type(upd) == "function" and not M.browseSafe then
			M.origBrowse = upd
			local wrapped = function(a, b, c, d, e)
				local ok = pcall(upd, a, b, c, d, e)
				return ok
			end
			M.browseSafe = true
			setglobal("AuctionFrameBrowse_Update", wrapped)
		end
	end
	M.on = true
	M.ReadPrices()
	M.HistRead()
	M.ReadLists()
	M.LoadBase()
	SUI.WhenSafe(M.Build)
	SUI.On("AUCTION_HOUSE_SHOW", M.OnShow)
	SUI.On("AUCTION_HOUSE_CLOSED", M.OnClose)
	if not M.watching then
		M.watching = true
		C.Watch("auction.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("AUCTION_HOUSE_SHOW", M.OnShow)
	SUI.Off("AUCTION_HOUSE_CLOSED", M.OnClose)
	M.open = false
	M.ApplyView()
	M.Release()
	if M.frame then M.frame:Hide() end
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
	if word == "search" then
		M.Search(arg)
	elseif word == "stop" then
		M.StopScan(false)
		M.StopLocate()
	elseif word == "sell" then
		local _, _, b, s = sfind(arg, "^(%d+)%s+(%d+)$")
		M.Sell(tonumber(b), tonumber(s))
	elseif word == "slot" then
		M.SearchSlot()
	elseif word == "post" then
		M.Post(true)
	elseif word == "toggle" then
		M.ToggleView()
	elseif word == "blizzard" or word == "shikiui" then
		C.Set("auction.ui", word)
		M.SetView(word)
		SUI.Print(L("msg.auction.ui." .. word))
	elseif word == "tab" then
		local n = M.TabFromName(arg)
		if n then M.SetTab(n) else SUI.Print(L("msg.auction.help")) end
	elseif word == "analyze" or word == "analyse" then
		if arg ~= "" then M.Search(arg) end
		M.SetTab(4)
	elseif word == "fav" then
		M.ToggleFav(arg ~= "" and arg or (M.query or ""))
	elseif word == "hist" then
		if slower(arg) == "clear" then
			M.HistClear()
			SUI.Print(L("msg.auction.hist.cleared"))
			return
		end
		if getn(M.horder) == 0 then SUI.Print(L("msg.auction.hist.none")) end
		for i = getn(M.horder), 1, -1 do
			local h = M.hist[M.horder[i]]
			SUI.Print(L("msg.auction.hist.line", h.name, h.n, M.Money(h.md[h.n]), M.Money(h.mn[h.n])))
		end
	elseif word == "recent" then
		if slower(arg) == "clear" then
			M.ClearLists()
			SUI.Print(L("msg.auction.recent.cleared"))
		end
	elseif word == "diag" then
		local f = M.frame
		if not f then SUI.Print(L("msg.auction.diag.none")) return end
		local stale = M.LevelsStale()
		SUI.Print(L("msg.auction.diag", f:GetFrameLevel() or 0, getn(f.kids), stale and L("msg.auction.diag.stale") or L("msg.auction.diag.ok"), M.SyncLevels()))
	elseif word == "prices" then
		if slower(arg) == "clear" then
			C.SetBase("auction.prices", "")
			SUI.Print(L("msg.auction.prices.cleared"))
			return
		end
		if M.nprices == 0 then SUI.Print(L("msg.auction.prices.none")) end
		for i = 1, getn(M.order) do
			local id = M.order[i]
			local name = GetItemInfo(id)
			SUI.Print(L("msg.auction.prices.line", name or ("#" .. id), M.Money(M.prices[id])))
		end
	elseif word == "top" then
		local n = tonumber(arg) or 5
		if M.n == 0 then SUI.Print(L("msg.auction.nores")) end
		for i = 1, n do
			if i > M.n then break end
			SUI.Print(L("msg.auction.top", M.rCnt[i], M.rName[i], M.rUnit[i] > 0 and M.Money(M.rUnit[i]) or "-", M.rOwn[i] or "?"))
		end
	else
		SUI.Print(L("msg.auction.help"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("auction", 48)

local function opt(key, typ, order, def, extra)
	local o = { key = "auction." .. key, type = typ, cat = "auction", label = "opt.auction." .. key, tip = "tip.auction." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("auction", {
	default = false,
	cost = "light",
	raid = "off",
	options = {
		opt("ui", "choice", 5, "shikiui", { choices = { "shikiui", "blizzard" }, simple = true }),
		opt("panel", "bool", 10, true, { simple = true }),
		opt("starttab", "choice", 12, "search", { choices = { "search", "sell", "sales", "analysis", "last" }, simple = true }),
		opt("rows", "number", 20, 10, { min = 5, max = 15, step = 1 }),
		opt("density", "choice", 22, "comfort", { choices = { "comfort", "compact" } }),
		opt("icons", "bool", 24, true),
		opt("showtotal", "bool", 26, true),
		opt("showseller", "bool", 28, true),
		opt("maxpages", "number", 30, 10, { min = 1, max = 40, step = 1, simple = true }),
		opt("exact", "bool", 40, false, { simple = true }),
		opt("quality", "number", 50, 0, { min = 0, max = 5, step = 1 }),
		opt("usable", "bool", 60, false),
		opt("dealpct", "number", 62, 15, { min = 3, max = 60, step = 1, simple = true }),
		opt("dealstyle", "choice", 64, "both", { choices = { "both", "text", "row", "none" } }),
		opt("basis", "choice", 70, "lowest", { choices = { "lowest", "median", "fixed" }, simple = true }),
		opt("undercut", "number", 80, 1, { min = 0, max = 10000, step = 1 }),
		opt("undercutpct", "number", 90, 3, { min = 0, max = 30, step = 1, simple = true }),
		opt("bidpct", "number", 100, 95, { min = 50, max = 100, step = 1 }),
		opt("duration", "choice", 110, "1440", { choices = { "120", "480", "1440" }, simple = true }),
		opt("confirmpost", "bool", 120, true, { simple = true }),
		opt("autoprice", "bool", 125, true),
		opt("remember", "bool", 130, true),
		opt("margin", "number", 140, 5, { min = 0, max = 50, step = 1 }),
		opt("cut", "number", 150, 5, { min = 0, max = 20, step = 1 }),
		opt("histdays", "number", 160, 14, { min = 3, max = 30, step = 1 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : chaines compactes plafonnees.
--  auction.prices "id=cuivre,..." plus bas prix par objet ; auction.hist historique du jour ; auction.recent / auction.favs "nom;nom".
SUI.Config.Register({ ["auction.prices"] = "", ["auction.hist"] = "", ["auction.recent"] = "", ["auction.favs"] = "" })

-- Equivalent pfUI : aucun module d'hotel des ventes releve dans pfUI\modules (pas de ligne Migrate.MAP).

SUI.RegisterCommand("auction", function(rest) M.Command(rest or "") end, "help.auction")
-- /sui ah : bascule Blizzard / ShikiUI ; /sui ah blizzard|shikiui fixe l'interface par defaut ; le reste va a /sui auction.
SUI.RegisterCommand("ah", function(rest)
	rest = rest or ""
	if rest == "" then M.ToggleView() else M.Command(rest) end
end)
