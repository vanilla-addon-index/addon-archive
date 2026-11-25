-- ShikiUI Vendor : vente du gris et reparation a l'ouverture d'un marchand (equivalent configurable de Scrap / AutoVendor ; reecrit).
-- Cout declare : LIGHT. Aucun evenement hors marchand : MERCHANT_SHOW / MERCHANT_CLOSED seulement ; PLAYER_MONEY et BAG_UPDATE ne sont
-- ecoutes que marchand ouvert. Une seule minuterie (SUI.Every), allumee pendant une vente et rendue a la fin. Aucune frame creee en combat
-- (SUI.WhenSafe) : un bouton "Vendre le gris", un bouton "Reparer" (seulement quand une reparation attend votre accord) et l'engrenage de
-- reglages, tous poses sur MerchantFrame sans toucher a Mod_Skin.
-- VENTE : a MERCHANT_SHOW (vendor.sell) ou au clic du bouton / /sui vendor sell. La liste des objets est figee au depart ; UN objet par tour de
--  minuterie (vendor.delay, 0,2 s) via UseContainerItem, jamais plus (limite de vitesse du serveur). On revalide la case avant chaque vente (le
--  lien doit etre le meme, la case non verrouillee, la regle toujours vraie) ; arret si la fenetre du marchand se ferme.
--  Plafond de securite : seuls les objets de qualite 0 (gris) sont vendus, SAUF ceux de la liste noire (vendor.black). La liste blanche
--  (vendor.white) l'emporte sur tout : un objet protege n'est jamais vendu, meme gris ou en liste noire. Jamais d'achat (aucun appel a
--  BuyMerchantItem / PickupMerchantItem). Au plus MAXSELL objets par passage.
-- LISTES : entrees "id~Nom" separees par ";" (id absent si on a saisi un nom). Un lien ou un identifiant est retenu par id ET par nom.
-- REPARATION : CanMerchantRepair, GetRepairAllCost, RepairAllItems. vendor.confirm.repair = seuil en or au-dela duquel on demande (0 = jamais) :
--  le cout est alors annonce et le bouton "Reparer" apparait. Banque de guilde (vendor.guild) : seulement si CanGuildBankRepair existe (absent
--  du client 1.12 d'origine : ignore proprement) ; si le cout reste non nul ensuite, repli sur la reparation personnelle.
-- GAIN : somme des hausses d'argent (PLAYER_MONEY) pendant la vente ; la reparation est payee AVANT et la vente attend SETTLE secondes pour que
--  les deux mouvements d'argent ne se melangent pas.
-- NON VERIFIE EN JEU : tout ; la position des boutons sur MerchantFrame ; le niveau du bouton apres affichage ; le 4e retour (qualite) de
--  GetContainerItemInfo et le 2e retour de GetRepairAllCost ; l'existence de CanGuildBankRepair / RepairAllItems(1) ; C_Item.GetItemSellPriceByID
--  (prix prevu, absent sans ClassicAPI : la valeur prevue est alors omise) ; le delai reel du serveur entre deux ventes.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind, ssub, slower, sformat, sgfind = string.find, string.sub, string.lower, string.format, string.gfind
local floor = math.floor

local M = {}
SUI.Vendor = M

local MAXSELL = 250          -- objets au plus par passage
local MAXLIST = 200          -- entrees au plus par liste
local MAXWAIT = 10           -- tours d'attente d'une case verrouillee avant de la laisser
local SETTLE = 0.6           -- secondes entre la reparation et le debut de la vente
local TAIL = 2               -- secondes d'attente de la derniere vente avant le bilan (le serveur peut crediter jusqu'a ~1 s apres : la derniere vente doit entrer dans le bilan)
local BTNW, BTNH = 124, 18
local GRAY = "|cff9d9d9d"    -- style:ok couleur de qualite 0 dans un lien d'objet (donnee du jeu)

M.on = false
M.open = false           -- marchand ouvert
M.selling = false
M.manual = false
M.pending = false        -- reparation en attente de l'accord du joueur
M.hid = 0
M.qi, M.nq = 1, 0        -- file de vente : indice courant, longueur
M.qb, M.qs, M.ql, M.qk, M.qc = {}, {}, {}, {}, {}
M.wait = 0
M.tailAt = nil
M.sold, M.failed, M.gain = 0, 0, 0
M.lastMoney = 0
M.tot = { sold = 0, gain = 0, repair = 0 }       -- cette session
M.lists = { white = { ent = {}, id = {}, name = {} }, black = { ent = {}, id = {}, name = {} } }
M.KEY = { white = "vendor.white", black = "vendor.black" }

-- ---------------------------------------------------------------- utilitaires
local function setText(b, text)
	if b.vtxt ~= text then
		b.vtxt = text
		T.SetButtonText(b, text)
	end
end

-- 12345 -> "1g 23s 45c" (les unites viennent de la langue ; la partie vide de tete est omise).
function M.Money(c)
	c = floor(c or 0)
	local g = floor(c / 10000)
	local s = floor(SUI.Mod(c, 10000) / 100)
	local k = SUI.Mod(c, 100)
	if g > 0 then return L("msg.vendor.money.g", g, s, k) end
	if s > 0 then return L("msg.vendor.money.s", s, k) end
	return L("msg.vendor.money.c", k)
end

-- Identifiant et nom d'une reference : lien d'objet, nombre seul, ou nom libre. -> id (nombre ou nil), nom d'affichage (ou nil)
function M.Parse(ref)
	ref = ref or ""
	local _, _, id = sfind(ref, "item:(%d+)")
	local _, _, name = sfind(ref, "%[(.-)%]")
	if not id then
		local _, _, num = sfind(ref, "^%s*(%d+)%s*$")
		id = num
	end
	if not name and not id then
		local _, _, t = sfind(ref, "^%s*(.-)%s*$")
		if t and t ~= "" then name = t end
	end
	if name then
		name = string.gsub(name, "[;~|]", "")
		if name == "" then name = nil end
	end
	return tonumber(id), name
end

-- Qualite : 4e retour de GetContainerItemInfo ; a defaut la couleur du lien (gris seulement). nil = inconnue (jamais vendue).
local function qualityOf(link, q)
	if type(q) == "number" then return q end
	if link and sfind(link, GRAY, 1, true) then return 0 end
	return nil
end

-- ---------------------------------------------------------------- listes blanche / noire
local function rebuild(which)
	local lst = M.lists[which]
	lst.ent, lst.id, lst.name = {}, {}, {}
	local s = C.Get(M.KEY[which]) or ""
	for item in sgfind(s, "([^;]+)") do
		if getn(lst.ent) < MAXLIST then
			local _, _, id, name = sfind(item, "^(%d*)~(.*)$")
			if not id then
				id, name = "", item
			end
			local e = { id = tonumber(id), name = name ~= "" and name or nil }
			if e.id or e.name then
				tinsert(lst.ent, e)
				if e.id then lst.id[e.id] = true end
				if e.name then lst.name[slower(e.name)] = true end
			end
		end
	end
end

function M.ReadLists()
	rebuild("white")
	rebuild("black")
end

local function save(which)
	local lst = M.lists[which]
	local parts = {}
	for i = 1, getn(lst.ent) do
		local e = lst.ent[i]
		tinsert(parts, (e.id and tostring(e.id) or "") .. "~" .. (e.name or ""))
	end
	C.SetBase(M.KEY[which], table.concat(parts, ";"))
end

function M.InList(which, id, name)
	local lst = M.lists[which]
	if id and lst.id[id] then return true end
	if name and lst.name[slower(name)] then return true end
	return false
end

local function listIndex(which, id, name)
	local lst = M.lists[which]
	for i = 1, getn(lst.ent) do
		local e = lst.ent[i]
		if (id and e.id == id) or (name and e.name and slower(e.name) == slower(name)) then return i end
	end
	return nil
end

-- Ajoute une reference. -> true, libelle | false, "bad" | "dup" | "full". Une entree passe d'une liste a l'autre (jamais dans les deux).
function M.ListAdd(which, ref)
	if not M.lists[which] then return false, "bad" end
	local id, name = M.Parse(ref)
	if not id and not name then return false, "bad" end
	local label = name or tostring(id)
	if listIndex(which, id, name) then return false, "dup" end
	if getn(M.lists[which].ent) >= MAXLIST then return false, "full" end
	local other = which == "white" and "black" or "white"
	local oi = listIndex(other, id, name)
	if oi then
		table.remove(M.lists[other].ent, oi)
		save(other)
	end
	tinsert(M.lists[which].ent, { id = id, name = name })
	save(which)
	return true, label
end

-- Retire une reference de la liste donnee (which == nil : des deux). -> nombre d'entrees retirees
function M.ListDel(which, ref)
	local id, name = M.Parse(ref)
	if not id and not name then return 0 end
	local n = 0
	local names = { "white", "black" }
	for k = 1, 2 do
		local w = names[k]
		if which == nil or which == w then
			local i = listIndex(w, id, name)
			while i do
				table.remove(M.lists[w].ent, i)
				n = n + 1
				i = listIndex(w, id, name)
			end
			if n > 0 then save(w) end
		end
	end
	return n
end

local function label(e)
	return e.name or ("#" .. tostring(e.id))
end

-- ---------------------------------------------------------------- analyse des sacs
-- Regle pour un objet : "black" (toujours vendre), "gray" (qualite 0), ou nil (a garder). 2e retour "white" si protege par la liste blanche.
function M.Classify(link, q)
	local id, name = M.Parse(link)
	if M.InList("white", id, name) then return nil, "white" end
	if M.InList("black", id, name) then return "black" end
	if qualityOf(link, q) == 0 then return "gray" end
	return nil
end

local function priceOf(id, count)
	local ci = getglobal("C_Item")
	if ci and ci.GetItemSellPriceByID and id then
		local ok, v = pcall(ci.GetItemSellPriceByID, id)
		if ok and type(v) == "number" then return v * (count or 1), true end
	end
	return 0, false
end

-- Parcourt les sacs. fill : range aussi la file de vente. -> nombre d'objets, valeur prevue, prix connus partout ?, dont liste noire, proteges
function M.Scan(fill)
	local n, value, allPriced, nblack, nwhite = 0, 0, true, 0, 0
	local nbag = NUM_BAG_SLOTS or 4
	for bag = 0, nbag do
		local ns = GetContainerNumSlots(bag) or 0
		for slot = 1, ns do
			local tex, count, _, q = GetContainerItemInfo(bag, slot)
			if tex then
				local link = GetContainerItemLink(bag, slot)
				if link then
					local kind, why = M.Classify(link, q)
					if why == "white" and qualityOf(link, q) == 0 then nwhite = nwhite + 1 end
					if kind and n < MAXSELL then
						n = n + 1
						if kind == "black" then nblack = nblack + 1 end
						local id = M.Parse(link)
						local v, known = priceOf(id, count)
						value = value + v
						if not known then allPriced = false end
						if fill then
							M.qb[n], M.qs[n], M.ql[n], M.qk[n], M.qc[n] = bag, slot, link, kind, count or 1
						end
					end
				end
			end
		end
	end
	if fill then M.nq = n end
	return n, value, allPriced, nblack, nwhite
end

-- ---------------------------------------------------------------- vente
function M.MerchantUp()
	local mf = getglobal("MerchantFrame")
	if mf and mf.IsVisible and not mf:IsVisible() then return false end
	return true
end

function M.StartSell(manual)
	if M.selling then return false end
	if not M.open then
		if manual then SUI.Print(L("msg.vendor.closed")) end
		return false
	end
	if SUI.InCombat() then
		if manual then SUI.Print(L("msg.vendor.combat")) end
		return false
	end
	local n = M.Scan(true)
	if n == 0 then
		if manual then SUI.Print(L("msg.vendor.nothing")) end
		return false
	end
	M.selling, M.manual = true, manual and true or false
	M.qi, M.wait, M.hid, M.tailAt = 1, 0, 0, nil
	M.sold, M.failed, M.gain = 0, 0, 0
	M.lastMoney = GetMoney()
	M.task = SUI.Every(C.Get("vendor.delay"), M.Step, "vendor.sell")
	M.Refresh()
	return true
end

-- Une vente par tour. La case doit toujours porter le meme objet, etre libre, et la regle doit toujours s'appliquer.
function M.Step()
	if not M.selling then
		SUI.Cancel(M.task)
		M.task = nil
		return
	end
	if not M.open then
		M.Finish(true)
		return
	end
	if not M.MerchantUp() then
		M.hid = M.hid + 1
		if M.hid >= 3 then M.Finish(true) end
		return
	end
	M.hid = 0
	if SUI.InCombat() then
		M.Finish(true)
		return
	end
	local i = M.qi
	if i > M.nq then
		if not M.tailAt then M.tailAt = GetTime() + TAIL end
		if GetTime() >= M.tailAt then M.Finish(false) end
		return
	end
	local bag, slot = M.qb[i], M.qs[i]
	local tex, _, locked, q = GetContainerItemInfo(bag, slot)
	local link = tex and GetContainerItemLink(bag, slot) or nil
	if link ~= M.ql[i] then                 -- la case a change depuis le releve : on la laisse (non comptee)
		M.qk[i] = false
		M.qi = i + 1
		M.wait = 0
		return
	end
	if locked then
		M.wait = M.wait + 1
		if M.wait > MAXWAIT then
			M.qi = i + 1
			M.wait = 0
		end
		return
	end
	M.wait = 0
	M.qi = i + 1
	if not M.Classify(link, q) then          -- la liste a change entre-temps (non comptee)
		M.qk[i] = false
		return
	end
	UseContainerItem(bag, slot)
end

-- Fin (normale ou fermeture) : compte ce qui est vraiment parti, annonce le bilan.
function M.Finish(closed)
	if not M.selling then return end
	M.selling = false
	SUI.Cancel(M.task)
	M.task = nil
	local tried = M.qi - 1
	if tried > M.nq then tried = M.nq end
	if closed and tried > 0 then tried = tried - 1 end   -- la derniere vente n'a pas eu le temps de repondre
	local failed, counted = 0, 0
	for i = 1, tried do
		if M.qk[i] then
			counted = counted + 1
			local tex = GetContainerItemInfo(M.qb[i], M.qs[i])
			local link = tex and GetContainerItemLink(M.qb[i], M.qs[i]) or nil
			if link == M.ql[i] then failed = failed + 1 end
		end
	end
	M.failed = failed
	M.sold = counted - failed
	M.tot.sold = M.tot.sold + M.sold
	M.tot.gain = M.tot.gain + M.gain
	if (M.manual or C.Get("vendor.announce")) and (M.sold > 0 or failed > 0) then
		if failed > 0 then
			SUI.Print(L("msg.vendor.sold2", M.sold, M.Money(M.gain), failed))
		else
			SUI.Print(L("msg.vendor.sold", M.sold, M.Money(M.gain)))
		end
	end
	M.Refresh()
end

function M.StopSell()
	if not M.selling then return false end
	M.Finish(true)
	SUI.Print(L("msg.vendor.stopped"))
	return true
end

-- ---------------------------------------------------------------- reparation
function M.GuildOk()
	local f = getglobal("CanGuildBankRepair")
	if type(f) ~= "function" then return false end
	local ok, r = pcall(f)
	return ok and r and true or false
end

local function repairCost()
	if type(CanMerchantRepair) ~= "function" or not CanMerchantRepair() then return 0 end
	local cost = GetRepairAllCost()
	if type(cost) ~= "number" then return 0 end
	return cost
end

-- Repare tout. force : ignore le seuil de confirmation. -> true si une reparation a ete demandee
function M.Repair(force)
	if not M.open then
		if force then SUI.Print(L("msg.vendor.closed")) end
		return false
	end
	local cost = repairCost()
	if cost <= 0 then
		M.pending = false
		M.Refresh()
		return false
	end
	local guild = C.Get("vendor.guild") and M.GuildOk()
	if not guild and GetMoney() < cost then
		SUI.Print(L("msg.vendor.norepair", M.Money(cost)))
		return false
	end
	local thr = (C.Get("vendor.confirm.repair") or 0) * 10000
	if not force and thr > 0 and cost > thr then
		M.pending = true
		SUI.Print(L("msg.vendor.askrepair", M.Money(cost), M.Money(thr)))
		M.Refresh()
		return false
	end
	M.pending = false
	if guild then
		pcall(RepairAllItems, 1)
		SUI.Print(L("msg.vendor.repaired.guild", M.Money(cost)))
		M.guildTask = SUI.After(1.5, M.GuildCheck, "vendor.guild")
	else
		RepairAllItems()
		M.tot.repair = M.tot.repair + cost
		SUI.Print(L("msg.vendor.repaired", M.Money(cost)))
	end
	M.Refresh()
	return true
end

-- La guilde n'a pas paye (cout toujours non nul) : repli sur la bourse du joueur.
function M.GuildCheck()
	M.guildTask = nil
	if not M.open then return end
	local cost = repairCost()
	if cost > 0 and GetMoney() >= cost then
		RepairAllItems()
		M.tot.repair = M.tot.repair + cost
		SUI.Print(L("msg.vendor.guildfail", M.Money(cost)))
	end
end

-- ---------------------------------------------------------------- evenements
function M.OnMoney()
	local now = GetMoney()
	local d = now - (M.lastMoney or now)
	M.lastMoney = now
	if d > 0 and M.selling then M.gain = M.gain + d end
end

function M.OnBag()
	if M.dirty or not M.open then return end
	M.dirty = true
	M.rtask = SUI.After(0.3, M.Refresh, "vendor.refresh")
end

function M.Attach()
	M.open = true
	M.lastMoney = GetMoney()
	SUI.On("PLAYER_MONEY", M.OnMoney)
	SUI.On("BAG_UPDATE", M.OnBag)
end

function M.Detach()
	SUI.Off("PLAYER_MONEY", M.OnMoney)
	SUI.Off("BAG_UPDATE", M.OnBag)
end

function M.OnShow()
	if not M.on then return end
	M.Attach()
	M.pending = false
	M.hid = 0
	SUI.WhenSafe(M.BuildUI)
	M.Level()
	SUI.After(0.3, M.Level, "vendor.lvl")
	local repaired = false
	if C.Get("vendor.repair") then repaired = M.Repair(false) end
	if C.Get("vendor.sell") then
		if repaired then
			M.startTask = SUI.After(SETTLE, M.AutoStart, "vendor.start")
		else
			M.StartSell(false)
		end
	end
	M.Refresh()
end

function M.AutoStart()
	M.startTask = nil
	if M.open then M.StartSell(false) end
end

function M.OnClosed()
	if M.selling then M.Finish(true) end
	M.open = false
	M.pending = false
	if M.startTask then
		SUI.Cancel(M.startTask)
		M.startTask = nil
	end
	if M.guildTask then
		SUI.Cancel(M.guildTask)
		M.guildTask = nil
	end
	M.Detach()
	M.Refresh()
end

-- ---------------------------------------------------------------- boutons sur MerchantFrame
function M.Level()
	if M.btn then T.GearLevel(M.btn) end
	if M.rbtn then T.GearLevel(M.rbtn) end
end

local function tipLine(text, c)
	GameTooltip:AddLine(text, c[1], c[2], c[3], 1)
end

function M.TipSell(b)
	tipLine(L("mod.vendor.tip.title"), T.c.text)
	if M.selling then
		tipLine(L("mod.vendor.tip.stop"), T.c.dim)
		return
	end
	if not M.open then return end
	local n, value, allPriced, nblack, nwhite = M.Scan(false)
	if n == 0 then
		tipLine(L("mod.vendor.tip.none"), T.c.dim)
	else
		tipLine(L("mod.vendor.tip.count", n), T.c.text)
		if nblack > 0 then tipLine(L("mod.vendor.tip.black", nblack), T.c.dim) end
		if value > 0 then
			local m = M.Money(value)
			if not allPriced then m = L("mod.vendor.tip.atleast", m) end
			tipLine(L("mod.vendor.tip.value", m), T.c.good)
		end
	end
	if nwhite > 0 then tipLine(L("mod.vendor.tip.white", nwhite), T.c.dim) end
	tipLine(L("mod.vendor.tip.hint"), T.c.dim)
	tipLine(L("mod.vendor.tip.lists"), T.c.dim)
end

function M.TipRepair(b)
	tipLine(L("mod.vendor.rtip.title"), T.c.text)
	tipLine(L("mod.vendor.rtip.cost", M.Money(repairCost())), T.c.text)
	tipLine(L("mod.vendor.rtip.hint"), T.c.dim)
end

local function attachTip(b, fn)
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		local self = this
		if oe then oe() end
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		fn(self)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if ol then ol() end
		if GameTooltip then GameTooltip:Hide() end
	end)
end

function M.OnButton()
	if M.selling then M.StopSell() else M.StartSell(true) end
end

function M.OnRepairButton()
	M.Repair(true)
end

function M.BuildUI()
	if M.btn then return end
	local par = getglobal("MerchantFrame")
	if not par then return end             -- pas d'interface Blizzard (hors jeu)
	local b = T.Button(par, L("mod.vendor.btn"), BTNW, BTNH, function() M.OnButton() end)
	b.suiGearParent = par
	b:SetPoint("TOPRIGHT", par, "TOPRIGHT", -52, -30)
	b:SetScript("OnShow", function()
		M.Level()
		SUI.After(0.3, M.Level, "vendor.lvl")
	end)
	attachTip(b, M.TipSell)
	M.btn = b
	local r = T.Button(par, L("mod.vendor.rbtn"), 70, BTNH, function() M.OnRepairButton() end)
	r.suiGearParent = par
	r:SetPoint("TOPRIGHT", b, "TOPLEFT", -4, 0)
	r:Hide()
	attachTip(r, M.TipRepair)
	M.rbtn = r
	T.GearButton(par, "vendor", { size = 16, point = "TOPRIGHT", x = -32, y = -31, title = L("mod.vendor.gear"),
		onCreate = function(g)
			M.gear = g
			M.ApplyOptions()
		end })
	M.ApplyOptions()
	M.Level()
end

-- Libelle et visibilite des boutons selon l'etat (ecrit seulement ce qui change).
function M.Refresh()
	M.dirty = false
	local b = M.btn
	if not b then return end
	local show = M.on and C.Get("vendor.btn")
	if M.selling then
		setText(b, L("mod.vendor.btn.stop"))
	elseif M.open and show then
		local n = M.Scan(false)
		if n > 0 then setText(b, L("mod.vendor.btn.n", n)) else setText(b, L("mod.vendor.btn")) end
	else
		setText(b, L("mod.vendor.btn"))
	end
	local r = M.rbtn
	if r then
		if show and M.open and M.pending then r:Show() else r:Hide() end
	end
end

function M.ApplyOptions()
	local show = M.on and C.Get("vendor.btn")
	if M.btn then
		if show then M.btn:Show() else M.btn:Hide() end
	end
	if M.gear then
		if show then M.gear:Show() else M.gear:Hide() end
	end
	M.Refresh()
end

function M.OnKey(key, value)
	if key == nil or key == "vendor.white" or key == "vendor.black" then
		M.ReadLists()
		M.dirty = true
	end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	M.ReadLists()
	SUI.On("MERCHANT_SHOW", M.OnShow)
	SUI.On("MERCHANT_CLOSED", M.OnClosed)
	if not M.watching then
		M.watching = true
		C.Watch("vendor.", M.OnKey)
	end
	SUI.WhenSafe(M.BuildUI)
	local mf = getglobal("MerchantFrame")
	if mf and mf.IsVisible and mf:IsVisible() and not M.open then M.Attach() end   -- active au comptoir : pas d'action automatique
	M.ApplyOptions()
end

function M.Disable()
	M.on = false
	if M.selling then M.Finish(true) end
	SUI.Off("MERCHANT_SHOW", M.OnShow)
	SUI.Off("MERCHANT_CLOSED", M.OnClosed)
	M.Detach()
	M.open = false
	M.pending = false
	if M.startTask then
		SUI.Cancel(M.startTask)
		M.startTask = nil
	end
	if M.guildTask then
		SUI.Cancel(M.guildTask)
		M.guildTask = nil
	end
	if M.btn then M.btn:Hide() end
	if M.rbtn then M.rbtn:Hide() end
	if M.gear then M.gear:Hide() end
end

-- ---------------------------------------------------------------- commandes
local function listOf(word)
	word = slower(word or "")
	if word == "white" or word == "w" or word == "keep" or word == "blanche" or word == "garder" then return "white" end
	if word == "black" or word == "b" or word == "sell" or word == "noire" or word == "vendre" then return "black" end
	return nil
end

function M.PrintList(which)
	local lst = M.lists[which]
	SUI.Print(L("msg.vendor.list." .. which, getn(lst.ent)))
	if getn(lst.ent) == 0 then SUI.Print(L("msg.vendor.list.none")) end
	for i = 1, getn(lst.ent) do SUI.Print(L("msg.vendor.list.line", label(lst.ent[i]))) end
end

function M.Status()
	SUI.Print(L("msg.vendor.status", M.on and 1 or 0, C.Get("vendor.sell") and 1 or 0, C.Get("vendor.repair") and 1 or 0,
		M.open and 1 or 0))
	SUI.Print(L("msg.vendor.lists", getn(M.lists.white.ent), getn(M.lists.black.ent)))
	SUI.Print(L("msg.vendor.session", M.tot.sold, M.Money(M.tot.gain), M.Money(M.tot.repair)))
end

function M.Command(rest)
	rest = rest or ""
	local _, _, word, arg = sfind(rest, "^%s*(%S*)%s*(.-)%s*$")
	word = slower(word or "")
	arg = arg or ""
	if word == "add" then
		local _, _, w2, ref = sfind(arg, "^(%S+)%s*(.-)$")
		local which = listOf(w2)
		if not which or ref == "" then
			SUI.Print(L("msg.vendor.usage"))
			return
		end
		local ok, res = M.ListAdd(which, ref)
		if ok then
			SUI.Print(L("msg.vendor.added." .. which, res))
		else
			SUI.Print(L("msg.vendor." .. res, ref))
		end
	elseif word == "del" or word == "remove" then
		local _, _, w2, ref = sfind(arg, "^(%S+)%s*(.-)$")
		local which = listOf(w2)
		if not which then ref = arg end
		if ref == nil or ref == "" then
			SUI.Print(L("msg.vendor.usage"))
			return
		end
		local n = M.ListDel(which, ref)
		if n > 0 then SUI.Print(L("msg.vendor.removed", ref)) else SUI.Print(L("msg.vendor.notfound", ref)) end
	elseif word == "list" then
		local which = listOf(arg)
		if which then
			M.PrintList(which)
		else
			M.PrintList("white")
			M.PrintList("black")
		end
	elseif word == "sell" then
		M.StartSell(true)
	elseif word == "repair" then
		M.Repair(true)
	elseif word == "stop" then
		if not M.StopSell() then SUI.Print(L("msg.vendor.idle")) end
	elseif word == "" or word == "status" then
		M.Status()
	else
		SUI.Print(L("msg.vendor.usage"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("vendor", 62)

local function opt(key, typ, order, def, extra)
	local o = { key = "vendor." .. key, type = typ, cat = "vendor", label = "opt.vendor." .. key, tip = "tip.vendor." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("vendor", {
	default = false,
	cost = "light",
	options = {
		opt("sell", "bool", 10, true, { simple = true }),
		opt("repair", "bool", 20, true, { simple = true }),
		opt("confirm.repair", "number", 30, 10, { min = 0, max = 500, step = 1, simple = true }),
		opt("guild", "bool", 40, true),
		opt("announce", "bool", 50, true, { simple = true }),
		opt("btn", "bool", 60, true, { simple = true }),
		opt("delay", "number", 70, 0.2, { min = 0.1, max = 1, step = 0.05 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : listes "id~Nom;id~Nom".
SUI.Config.Register({ ["vendor.white"] = "", ["vendor.black"] = "" })

SUI.RegisterCommand("vendor", function(rest) M.Command(rest or "") end, "help.vendor")
