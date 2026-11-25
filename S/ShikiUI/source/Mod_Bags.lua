-- Mod_Bags : sacs unifies et banque de ShikiUI (remplace le module "bags" de pfUI, voir Migrate.MAP).
-- Une fenetre pour tous les sacs (grille reglable), une pour la banque : tri (qualite / type / nom), recherche, filtres, bordure par
-- qualite, ligne de valeur (argent, places libres, valeur de la camelote). Reecriture complete : aucun code de pfUI n'a ete copie.
-- Signatures relevees dans pfUI (MIT) et ItemRack : GetContainerNumSlots GetContainerItemInfo (texture, nombre, verrou, qualite)
-- GetContainerItemLink PickupContainerItem UseContainerItem GetKeyRingSize (sac -2) GetNumBankSlots NUM_BANKBAGSLOTS GetItemInfo
-- (9 retours : nom, lien, qualite, niveau, type, sous-type, pile, emplacement, texture) GetItemQualityColor GetMoney
-- SetItemButtonTexture / Count / Desaturated ContainerIDToInventoryID ; modeles de bouton
-- ContainerFrameItemButtonTemplate (sacs, sac -2 et sacs de banque) et BankItemButtonGenericTemplate (banque, sac -1) avec un cadre
-- parent portant l'identifiant du sac et un bouton portant l'identifiant de l'emplacement ; ClassicAPI (optionnel) : C_Item.
-- GetItemSellPriceByID, C_Item.GetItemInfoInstant ; evenements BAG_UPDATE BAG_UPDATE_COOLDOWN ITEM_LOCK_CHANGED PLAYERBANKSLOTS_CHANGED
-- PLAYERBANKBAGSLOTS_CHANGED BANKFRAME_OPENED BANKFRAME_CLOSED. Rien de tout cela n'a ete execute en jeu.
-- AFFICHAGE (bags.layout) : "grid" (grille d'origine) ou "categories" : sections Equipement / Consommables / Quete / Echange et artisanat /
-- Camelote / Autres / Emplacements libres, classees par GetItemInfo (type et sous-type FR ou EN, qualite 0 = camelote), en-tetes
-- reduisibles (etat memorise dans ShikiUIDB.global.bagcache.prefs.collapsed).
-- MEMOIRE PAR PERSONNAGE (bags.remember) : ShikiUIDB.global.bagcache = { rev, prefs, chars = { ["Nom-Royaume"] = { name, class, t, money,
-- nbag, nbank, bags = {entree...}, bank = {entree...} } } } ; entree = "ref~nombre~qualite~categorie~icone~type~sous-type~nom"
-- (ref = "id:ench:suffixe:unique"). Au plus MAXSNAP entrees par liste et MAXCHARS personnages. Ecrit a la fermeture des sacs, pendant
-- l'ouverture de la banque (elle n'est lisible que la) et a la deconnexion (shutdown). Lu par Mod_Tooltip (ligne "Possede").
-- VUE HORS-LIGNE : bouton "Voir : <personnage>" de la fenetre des sacs ; lecture seule (icones, quantites, infobulle par lien), recherche
-- et filtre actifs. BOUTON "Tout deposer" (bags.depositall) : un objet par tour via UseContainerItem, banque ouverte, jamais en combat.
-- Cout declare : medium (une minuterie partagee de 0,1 s qui ne fait rien tant qu'aucune fenetre n'est ouverte ; boutons crees une fois).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, floor, ceil = table.getn, math.floor, math.ceil

local M = {}
SUI.Bags = M

local TICK = 0.1
local PAD = 6
local HEADER = 54
local FOOTER = 24
local BANKROW = 28
local DIM = 0.25
local STALL = 40             -- passes sans progres avant d'abandonner un tri (4 s)
local NO_TINT = 1            -- style:ok teinte neutre : aucune teinte (ce n'est pas une couleur de style)
local MINW = 236
local BARH = 26                  -- hauteur de la barre de titre (zone de glisser)
local barDragStart, barDragStop

M.on = false
M.wins = {}
M.orig = {}
M.filters = { "all", "gear", "junk", "good" }
M.tickN = 0
M.dInfo = false

local WDEF = {
	bag = { key = "bag", name = "ShikiUI_Bag", title = "msg.bags.title.bag", layout = "bags.window", pt = "BOTTOMRIGHT", x = -40, y = 120 },
	bank = { key = "bank", name = "ShikiUI_Bank", title = "msg.bags.title.bank", layout = "bags.bank", pt = "BOTTOMLEFT", x = 40, y = 120 },
}
M.WDEF = WDEF
M.order = { "bag", "bank" }

local cfg = { columns = 10, size = 32, spacing = 2, sort = "quality" }

-- fonctions de Blizzard remplacees pendant que le module est actif (restaurees a la desactivation)
local REPLACED = { "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag", "CloseBag", "OpenAllBags", "CloseAllBags",
	"ToggleKeyRing" }

function M.ReadConfig()
	cfg.columns = C.Get("bags.columns")
	cfg.size = C.Get("bags.size")
	cfg.spacing = C.Get("bags.spacing")
	cfg.quality = C.Get("bags.quality")
	cfg.borderlimit = C.Get("bags.borderlimit")
	cfg.counts = C.Get("bags.counts")
	cfg.sort = C.Get("bags.sort")
	cfg.junklast = C.Get("bags.junklast")
	cfg.sortopen = C.Get("bags.sortopen")
	cfg.value = C.Get("bags.value")
	cfg.keyring = C.Get("bags.keyring")
	cfg.bankwin = C.Get("bags.bankwin")
	cfg.search = C.Get("bags.search")
	cfg.filters = C.Get("bags.filters")
	cfg.layout = C.Get("bags.layout")
	cfg.remember = C.Get("bags.remember")
	cfg.depositall = C.Get("bags.depositall")
	cfg.hideslots = C.Get("bags.hideslots")
	cfg.hidebankslots = C.Get("bags.hidebankslots")
	cfg.newitems = C.Get("bags.newitems")
	cfg.setcat = C.Get("bags.setcat")
	cfg.minecat = C.Get("bags.minecat")
end

-- ---------------------------------------------------------------- informations d'objets (cache par lien)
local INF = { name = {}, id = {}, ltype = {}, sub = {}, eq = {}, q = {}, price = {}, tries = {} }
M.INF = INF

local function fillInfo(link)
	local id = INF.id[link]
	local nm, _, q, _, ty, sub, _, eq = GetItemInfo(id)
	if nm then
		INF.ltype[link] = string.lower(ty or "")
		INF.sub[link] = string.lower(sub or "")
		INF.eq[link] = eq or ""
		INF.q[link] = q
		INF.tries[link] = nil
		return true
	end
	INF.tries[link] = (INF.tries[link] or 0) + 1
	return false
end

local function lookup(link)
	if INF.id[link] == nil then
		local _, _, name = string.find(link, "%[(.-)%]")
		local _, _, id = string.find(link, "item:(%d+)")
		INF.name[link] = string.lower(name or "")
		INF.id[link] = tonumber(id) or 0
		local ci = getglobal("C_Item")
		local p = false
		if ci and ci.GetItemSellPriceByID then
			local ok, v = pcall(ci.GetItemSellPriceByID, INF.id[link])
			if ok and type(v) == "number" then p = v end
		end
		INF.price[link] = p
		INF.ltype[link] = false
		fillInfo(link)
	elseif INF.ltype[link] == false and (INF.tries[link] or 0) < 6 then
		if fillInfo(link) then M.dInfo = true end
	end
end

-- ---------------------------------------------------------------- sacs
local function slotCount(bag)
	if bag == -2 then return GetKeyRingSize() or 0 end
	return GetContainerNumSlots(bag) or 0
end

function M.FillBags(win)
	local list = win.list
	local n = 0
	local nbag = NUM_BAG_SLOTS or 4
	if win.key == "bag" then
		for bag = 0, nbag do
			n = n + 1
			list[n] = bag
		end
		if cfg.keyring then
			n = n + 1
			list[n] = -2
		end
	else
		n = 1
		list[1] = -1
		local nb = GetNumBankSlots() or 0
		for i = 1, nb do
			n = n + 1
			list[n] = nbag + i
		end
	end
	for i = n + 1, win.nlist do list[i] = nil end
	win.nlist = n
	return n
end

-- Type d'un sac : "bag" (ordinaire) | "special" | "quiver" | "key" | nil (inconnu). Les sacs speciaux ou inconnus ne sont pas tries.
function M.BagKind(bag)
	if bag == -2 then return "key" end
	if bag == 0 or bag == -1 then return "bag" end
	local ci = getglobal("C_Item")
	local gid = getglobal("GetInventoryItemID")
	local c2i = getglobal("ContainerIDToInventoryID")
	if ci and ci.GetItemInfoInstant and gid and c2i then
		local id = gid("player", c2i(bag))
		if id then
			local _, _, _, _, _, cls, sub = ci.GetItemInfoInstant(id)
			if cls == 1 then
				if sub == 0 then return "bag" end
				return "special"
			elseif cls == 11 then
				return "quiver"
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- boutons d'objets
local function bagTag(bag)
	if bag < 0 then return "k" .. (0 - bag) end
	return tostring(bag)
end

local function paintHighlight(b)
	local ok = pcall(function()
		local r, g, bl = T.Accent()
		local hl = b:GetHighlightTexture()
		hl:SetTexture(T.tex.white)
		hl:SetVertexColor(r, g, bl, 0.3)
		local pu = b:GetPushedTexture()
		pu:SetTexture(T.tex.white)
		pu:SetVertexColor(r, g, bl, 0.5)
	end)
	return ok
end

local function newHolder(win, bag)
	local h = CreateFrame("Frame", win.def.name .. "_H" .. bagTag(bag), win.frame)
	h:SetID(bag)
	h:SetAllPoints(win.frame)
	h.bag = bag
	h.btn = {}
	win.holder[bag] = h
	return h
end

local function newItem(win, bag, slot)
	local h = win.holder[bag] or newHolder(win, bag)
	local tpl = "ContainerFrameItemButtonTemplate"
	if bag == -1 then tpl = "BankItemButtonGenericTemplate" end
	local b = CreateFrame("Button", "ShikiUI_Item_" .. bagTag(bag) .. "_" .. slot, h, tpl)
	b:SetID(slot)
	b.bag, b.slot, b.win = bag, slot, win
	pcall(b.SetNormalTexture, b, "")
	T.Backdrop(b, T.c.inset, T.c.border)
	-- l'icone du modele de Blizzard remplit tout le bouton et recouvrirait la bordure de qualite : on la rentre d'un pixel et on rogne son bord
	local ic = getglobal("ShikiUI_Item_" .. bagTag(bag) .. "_" .. slot .. "IconTexture")
	if ic and ic.SetPoint then
		ic:ClearAllPoints()
		ic:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		ic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	paintHighlight(b)
	-- Alt + clic : menu pour deplacer l'objet de categorie ; tout autre clic garde le comportement du jeu
	local oldClick = b:GetScript("OnClick")
	b:SetScript("OnClick", function()
		if IsAltKeyDown and IsAltKeyDown() and this and this.link then
			M.OpenCatMenu(this)
			return
		end
		if oldClick then oldClick() end
	end)
	h.btn[slot] = b
	return b
end

function M.PaintBorder(b)
	local q = b.q
	local key = 0
	if q and cfg.quality and q >= cfg.borderlimit and b.link then key = q + 1 end
	if b.bq == key then return end
	b.bq = key
	if key > 0 then
		local r, g, bl = GetItemQualityColor(q)
		b:SetBackdropBorderColor(r, g, bl, 1)
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

-- Recharge d'un bouton : on n'appelle JAMAIS le code Blizzard (il fait getglobal(nom.."Cooldown") et plante sur nil
-- quand le bouton n'a pas l'enfant attendu, ex. boutons de banque). On cree l'enfant au besoin et on gere nous-memes.
function M.UpdateCooldown(bag, b)
	local cd = b.cd
	if not cd then
		local nm = b.GetName and b:GetName()
		if nm then cd = getglobal(nm .. "Cooldown") end
		if not cd and nm then
			local ok, f = pcall(CreateFrame, "Cooldown", nm .. "Cooldown", b, "CooldownFrameTemplate")
			if not ok or not f then ok, f = pcall(CreateFrame, "Cooldown", nm .. "Cooldown", b) end
			if ok and f then
				cd = f
				pcall(f.SetAllPoints, f, b)
			end
		end
		if not cd then return end
		b.cd = cd
	end
	local set = getglobal("CooldownFrame_SetTimer")
	if not set or not GetContainerItemCooldown then return end
	local start, dur, en = GetContainerItemCooldown(b.bag or bag, b.slot or b:GetID())
	local ok = pcall(set, cd, start or 0, dur or 0, en or 0)
	if not ok then b.cd = nil end
end

-- Relit un emplacement. Retourne true si son contenu (objet ou quantite) a change.
function M.UpdateSlot(b)
	local bag, slot = b.bag, b.slot
	local tex, count, locked, quality = GetContainerItemInfo(bag, slot)
	local link = nil
	if tex then link = GetContainerItemLink(bag, slot) end
	local changed = (link ~= b.link) or (count ~= b.count)
	b.link, b.count = link, count
	if link then
		lookup(link)
		b.q = quality or INF.q[link]
		if b.q == nil then b.q = 1 end
	else
		b.q = nil
	end
	if link and INF.ltype[link] == false then b.win.unres = true end
	SetItemButtonTexture(b, tex)
	SetItemButtonCount(b, (cfg.counts and count) or 0)
	SetItemButtonDesaturated(b, locked, 0.5, 0.5, 0.5)
	pcall(M.UpdateCooldown, bag, b)
	M.PaintBorder(b)
	return changed
end

-- ---------------------------------------------------------------- recherche, filtres, valeur
local function matches(b, win)
	local link = b.link
	local f = win.filter
	if f ~= "all" then
		if not link then return false end
		if f == "gear" then
			local eq = INF.eq[link]
			if not eq or eq == "" then return false end
		elseif f == "junk" then
			if (b.q or 1) ~= 0 then return false end
		elseif f == "good" then
			if (b.q or 0) < 2 then return false end
		end
	end
	local q = win.query
	if q ~= "" then
		if not link then return false end
		local ty, sub = INF.ltype[link], INF.sub[link]
		if not (string.find(INF.name[link], q, 1, true) or (ty and string.find(ty, q, 1, true)) or (sub and string.find(sub, q, 1, true))) then
			return false
		end
	end
	return true
end

function M.ApplyDim(win)
	local active = (win.query ~= "" or win.filter ~= "all")
	for i = 1, win.n do
		local b = win.order[i]
		local a = 1
		if active and not matches(b, win) then a = DIM end
		if b.dimA ~= a then
			b.dimA = a
			b:SetAlpha(a)
		end
	end
end

local function money(c)
	c = floor(c or 0)
	return L("msg.bags.money", floor(c / 10000), floor(SUI.Mod(c, 10000) / 100), SUI.Mod(c, 100))
end
M.Money = money

-- Totaux d'une fenetre : places libres / totales, valeur de la camelote (qualite 0) et de tout le contenu, ou nil sans prix.
function M.Totals(win)
	local free, total, junk, all = 0, 0, 0, 0
	local priced = false
	for i = 1, win.n do
		local b = win.order[i]
		total = total + 1
		if not b.link then
			free = free + 1
		else
			local p = INF.price[b.link]
			if p then
				priced = true
				local v = p * (b.count or 1)
				all = all + v
				if b.q == 0 then junk = junk + v end
			end
		end
	end
	return free, total, junk, all, priced
end

function M.UpdateValue(win)
	if not win.value then return end
	if win.offline then
		M.ViewValue(win)
		return
	end
	if not cfg.value then
		win.value:SetText("")
		win.value.suiTxt = nil
		return
	end
	local free, total, junk, _, priced = M.Totals(win)
	local s
	if win.key == "bag" then
		s = L("msg.bags.value.bag", money(GetMoney()), free, total)
		if priced then s = s .. L("msg.bags.value.junk", money(junk)) end
	else
		s = L("msg.bags.value.bank", free, total)
		if priced then s = s .. L("msg.bags.value.junk", money(junk)) end
	end
	if win.value.suiTxt ~= s then
		win.value.suiTxt = s
		win.value:SetText(s)
	end
end

-- ---------------------------------------------------------------- categories
local CATKEYS = { "new", "set", "mine", "equip", "consum", "quest", "trade", "junk", "other", "free" }
local CATIDX = { new = 1, set = 2, mine = 3, equip = 4, consum = 5, quest = 6, trade = 7, junk = 8, other = 9, free = 10 }
local TRADE = { "trade", "marchandise", "reagent", "composant", "recipe", "recette", "gem" }
local GEARNO = { INVTYPE_BAG = true, INVTYPE_AMMO = true, INVTYPE_QUIVER = true }
local HDRH, GAP = 16, 4
local MAXSNAP, MAXCHARS = 200, 12
local ICONPFX = "Interface\\Icons\\"      -- style:ok dossier d'icones du jeu (donnee de jeu, pas du style)
local KEEP = { [6948] = true }            -- Pierre de foyer : jamais deposee en banque
M.CATS = CATKEYS

-- Categorie d'un objet a partir de son type et sous-type (en minuscules, FR ou EN), de sa qualite et de son emplacement d'equipement.
function M.Classify(ty, sub, q, eq)
	ty = ty or ""
	if ty == "quest" or string.find(ty, "^qu.-te$") then return "quest" end
	if q == 0 then return "junk" end
	if ty == "consumable" or ty == "consommable" then return "consum" end
	for i = 1, getn(TRADE) do
		if string.find(ty, TRADE[i], 1, true) then return "trade" end
	end
	if string.find(ty, "^r.-actif$") then return "trade" end
	if (eq and eq ~= "" and not GEARNO[eq]) or ty == "weapon" or ty == "armor" or ty == "arme" or ty == "armure" then return "equip" end
	return "other"
end

-- Butin recent : un objet est "nouveau" tant que son identifiant n'a jamais ete vu dans tes sacs / sur toi / en banque.
-- Les identifiants vus sont memorises (compte) et mis a jour a la fermeture des sacs : le nouveau butin reste en tete jusque-la.
function M.IsFresh(id)
	local kn = M.CacheRoot().prefs.known
	if type(kn) ~= "table" or not id or id <= 0 then return false end
	return not kn[id]
end

function M.MarkSeen(scope)
	local pr = M.CacheRoot().prefs
	if type(pr.known) ~= "table" then pr.known = {} end
	local kn = pr.known
	local nbag = NUM_BAG_SLOTS or 4
	local list = {}
	if scope == "bank" then
		list[1] = -1
		for i = 1, (GetNumBankSlots() or 0) do list[getn(list) + 1] = nbag + i end
	else
		for bag = 0, nbag do list[bag + 1] = bag end
	end
	for i = 1, getn(list) do
		local bag = list[i]
		for slot = 1, slotCount(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				lookup(link)
				local id = INF.id[link]
				if id and id > 0 then kn[id] = true end
			end
		end
	end
	if scope ~= "bank" then
		for s = 1, 19 do
			local link = GetInventoryItemLink("player", s)
			if link then
				lookup(link)
				local id = INF.id[link]
				if id and id > 0 then kn[id] = true end
			end
		end
		-- les objets des jeux d'equipement sont connus d'office
		local codes = SUI.Items and SUI.Items.SetCodes and SUI.Items.SetCodes()
		if codes then
			for c in pairs(codes) do
				local _, _, id = string.find(c, "^(%d+)")
				if id then kn[tonumber(id)] = true end
			end
		end
	end
end

function M.CatOf(b)
	local link = b.link
	if not link then return "free" end
	if cfg.newitems and M.IsFresh(INF.id[link]) then return "new" end
	local id = INF.id[link]
	local ov = M.catT and M.catT[id]                              -- categorie choisie a la main (Alt + clic -> menu)
	if ov and CATIDX[ov] and (ov ~= "mine" or cfg.minecat) then return ov end
	local mt = cfg.minecat and M.mineT
	if mt and mt[id] == true then return "mine" end              -- ancien marquage (version precedente)
	local c = M.Classify(INF.ltype[link] or "", INF.sub[link], b.q, INF.eq[link])
	if c == "equip" and M.setLookup then
		local code = SUI.Items.Code(link)
		if code and M.setLookup[code] then return "set" end
	end
	-- equipement deja porte par ce compte (sauf si tu l'as retire a la main) : utilise, donc pas "a vendre"
	if c == "equip" and cfg.minecat and M.wornT and M.wornT[id] and not (mt and mt[id] == false) then return "mine" end
	return c
end

-- Objets "utilises" : marque a la main (prefs.mine[id] = true / false) ou deja equipes (prefs.worn[id], memorise au fil du jeu).
function M.NoteWorn()
	local pr = M.CacheRoot().prefs
	if type(pr.worn) ~= "table" then pr.worn = {} end
	for sl = 1, 19 do
		local link = GetInventoryItemLink("player", sl)
		if link then
			local _, _, id = string.find(link, "item:(%d+)")
			id = tonumber(id)
			if id and id > 0 then pr.worn[id] = true end
		end
	end
end

-- Alt + clic sur un objet : menu pour le deplacer dans la categorie de ton choix (ou revenir au classement automatique).
M.MENUCATS = { "mine", "equip", "consum", "trade", "quest", "junk", "other" }

function M.RelayoutAll()
	for k = 1, getn(M.order) do
		local w = M.wins[M.order[k]]
		if w then w.dLayout, w.dAll = true, true end
	end
end

-- Range l'objet id dans la categorie key (nil = classement automatique).
function M.SetItemCat(id, key)
	local pr = M.CacheRoot().prefs
	if type(pr.cat) ~= "table" then pr.cat = {} end
	pr.cat[id] = key
	if type(pr.mine) == "table" then pr.mine[id] = nil end
	M.catT, M.mineT = pr.cat, pr.mine
	M.RelayoutAll()
end

function M.CatMenuClose()
	if M.catMenu then M.catMenu:Hide() end
	if M.catCatcher then M.catCatcher:Hide() end
end

function M.CatMenuPick(key)
	if M.catId then M.SetItemCat(M.catId, key) end
	M.CatMenuClose()
end

function M.BuildCatMenu()
	if M.catMenu then return M.catMenu end
	local n = getn(M.MENUCATS) + 1
	local c = CreateFrame("Button", "ShikiUI_BagCatCatcher", UIParent)
	c:SetAllPoints(UIParent)
	c:SetFrameStrata("DIALOG")
	c:EnableMouse(true)
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	c:SetScript("OnClick", function() M.CatMenuClose() end)
	c:Hide()
	local f = T.Panel(UIParent, 190, 30 + n * 20)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	f.title = T.Text(f, 11, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
	f.items = {}
	for i = 1, n do
		local btn = T.Button(f, "", 174, 18, function(bt) M.CatMenuPick(bt.key) end)
		btn:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26 - (i - 1) * 20)
		f.items[i] = btn
	end
	M.catMenu, M.catCatcher = f, c
	return f
end

function M.OpenCatMenu(b)
	local link = b and b.link
	if not link then return end
	local id = INF.id[link]
	if not id or id <= 0 then return end
	local f = M.BuildCatMenu()
	M.catId = id
	local _, _, name = string.find(link, "%[(.-)%]")
	f.title:SetText(L("msg.bags.menu.move", name or "?"))
	local pr = M.CacheRoot().prefs
	M.catT, M.mineT, M.wornT = pr.cat, pr.mine, pr.worn
	local cur = M.catT and M.catT[id]
	for i = 1, getn(f.items) do
		local key = M.MENUCATS[i]
		local btn = f.items[i]
		btn.key = key
		T.SetButtonText(btn, key and L("msg.bags.cat." .. key) or L("msg.bags.cat.auto"))
		T.SetSelected(btn, cur == key)
	end
	local gc = getglobal("GetCursorPosition")
	f:ClearAllPoints()
	if type(gc) == "function" then
		local x, y = gc()
		local sc = UIParent:GetEffectiveScale()
		if not sc or sc == 0 then sc = 1 end
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / sc - 10, (y or 0) / sc + 10)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	M.catCatcher:Show()
	f:Show()
end

-- texte d'en-tete : "Equipement" devient "Equipement hors jeux" quand une categorie "jeux" existe
function M.CatLabelKey(key)
	if key == "equip" and M.setLookup and next(M.setLookup) then return "equipx" end
	return key
end

-- ---------------------------------------------------------------- infobulles des boutons
local function tipEnter()
	local self = this
	if self.tipOE then self.tipOE() end
	local gt = getglobal("GameTooltip")
	if not gt or not self.tipT then return end
	gt:SetOwner(self, "ANCHOR_BOTTOM")
	gt:AddLine(L(self.tipT), T.c.text[1], T.c.text[2], T.c.text[3])
	if self.tipX then gt:AddLine(L(self.tipX), T.c.dim[1], T.c.dim[2], T.c.dim[3], 1) end
	gt:Show()
end

local function tipLeave()
	local self = this
	if self.tipOL then self.tipOL() end
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

-- Infobulle d'un bouton : titre et texte donnes par CLE de texte (traduits a l'affichage).
function M.Tip(f, title, text)
	f.tipT, f.tipX = title, text
	if f.tipSet then return end
	f.tipSet = true
	f.tipOE, f.tipOL = f:GetScript("OnEnter"), f:GetScript("OnLeave")
	f:SetScript("OnEnter", tipEnter)
	f:SetScript("OnLeave", tipLeave)
end

-- ---------------------------------------------------------------- memoire par personnage
function M.CharKey()
	local name = UnitName("player")
	if not name or name == "" then return nil end
	return name .. "-" .. (GetRealmName() or "?")
end

function M.DispName(key, rec)
	if type(rec) == "table" and rec.name then return rec.name end
	local _, _, n = string.find(key or "", "^(.-)%-")
	return n or key or "?"
end

function M.CacheRoot()
	local r = C.GetGlobal("bagcache")
	if type(r) ~= "table" then
		r = M.mem or { v = 1, rev = 0, prefs = {}, chars = {} }
		M.mem = r
		C.SetGlobal("bagcache", r)
	end
	if type(r.chars) ~= "table" then r.chars = {} end
	if type(r.prefs) ~= "table" then r.prefs = {} end
	return r
end

function M.IsCollapsed(cat)
	local c = M.CacheRoot().prefs.collapsed
	return (type(c) == "table" and c[cat]) and true or false
end

function M.SetCollapsed(cat, on)
	local pr = M.CacheRoot().prefs
	if type(pr.collapsed) ~= "table" then pr.collapsed = {} end
	pr.collapsed[cat] = on and true or nil
end

-- Une entree de la memoire : ref~nombre~qualite~categorie~icone~type~sous-type~nom
function M.Encode(link, count, q, tex)
	lookup(link)
	local _, _, ref = string.find(link, "item:(%-?%d+:%-?%d+:%-?%d+:%-?%d+)")
	if not ref then ref = (INF.id[link] or 0) .. ":0:0:0" end
	local _, _, nm = string.find(link, "%[(.-)%]")
	local ty, sub = INF.ltype[link] or "", INF.sub[link] or ""
	local t = tex or ""
	if string.sub(t, 1, string.len(ICONPFX)) == ICONPFX then t = string.sub(t, string.len(ICONPFX) + 1) end
	return ref .. "~" .. (count or 1) .. "~" .. (q or 1) .. "~" .. M.Classify(ty, sub, q, INF.eq[link]) .. "~" .. t .. "~" .. ty .. "~" .. sub .. "~" .. (nm or "?")
end

function M.Parse(s)
	if type(s) ~= "string" then return nil end
	local _, _, ref, cnt, q, cat, tex, ty, sub, name = string.find(s, "^([^~]*)~(%d+)~(%d+)~([^~]*)~([^~]*)~([^~]*)~([^~]*)~(.*)$")
	if not ref then return nil end
	local _, _, id = string.find(ref, "^(%-?%d+)")
	if tex ~= "" and not string.find(tex, "\\", 1, true) then tex = ICONPFX .. tex end
	return { ref = ref, id = tonumber(id) or 0, count = tonumber(cnt) or 1, q = tonumber(q) or 1, cat = cat, tex = tex, ty = ty, sub = sub,
		name = name, lname = string.lower(name) }
end

-- Parcourt les sacs ("bags") ou la banque ("bank") et retourne la liste d'entrees et le nombre total d'emplacements.
function M.ScanSet(kind)
	local list = {}
	local nbag = NUM_BAG_SLOTS or 4
	if kind == "bank" then
		list[1] = -1
		for i = 1, (GetNumBankSlots() or 0) do list[getn(list) + 1] = nbag + i end
	else
		for b = 0, nbag do list[b + 1] = b end
	end
	local out, n, total = {}, 0, 0
	for i = 1, getn(list) do
		local bag = list[i]
		local size = slotCount(bag)
		total = total + size
		for slot = 1, size do
			if n < MAXSNAP then
				local tex, count, _, q = GetContainerItemInfo(bag, slot)
				if tex then
					local link = GetContainerItemLink(bag, slot)
					if link then
						n = n + 1
						out[n] = M.Encode(link, count, q or 1, tex)
					end
				end
			end
		end
	end
	return out, total
end

function M.Prune(root, keep)
	for k, v in pairs(root.chars) do
		if type(v) ~= "table" then root.chars[k] = nil end
	end
	while true do
		local n, oldest, ot = 0, nil, nil
		for k, v in pairs(root.chars) do
			n = n + 1
			if k ~= keep and (not oldest or (v.t or 0) < ot) then oldest, ot = k, (v.t or 0) end
		end
		if n <= MAXCHARS or not oldest then return end
		root.chars[oldest] = nil
	end
end

-- Instantane du personnage courant. what : "bags" | "bank". La banque n'est lue que banque ouverte ; jamais d'ecrasement par du vide.
function M.Snapshot(what, force)
	if not M.on or not cfg.remember then return false end
	if SUI.InCombat() and not force then
		M.snapLate = true
		return false
	end
	local key = M.CharKey()
	if not key then return false end
	local root = M.CacheRoot()
	local rec = root.chars[key]
	if type(rec) ~= "table" then
		rec = { bags = {}, bank = {} }
		root.chars[key] = rec
	end
	local out, total
	if what == "bank" then
		if not M.bankOpen then return false end
		out, total = M.ScanSet("bank")
		if total > 0 then rec.bank, rec.nbank = out, total end
	else
		out, total = M.ScanSet("bags")
		if total > 0 then rec.bags, rec.nbag = out, total end
	end
	local _, class = UnitClass("player")
	local tf = getglobal("time")
	rec.name, rec.class = UnitName("player"), class
	rec.t = tf and tf() or 0
	rec.money = GetMoney()
	root.rev = (root.rev or 0) + 1
	M.Prune(root, key)
	return true
end

-- ---------------------------------------------------------------- sections par categories
local function cmpBtn(a, b)
	local qa, qb = a.q or 0, b.q or 0
	if qa ~= qb then return qa > qb end
	local na, nb = INF.name[a.link] or "", INF.name[b.link] or ""
	if na ~= nb then return na < nb end
	if (a.count or 1) ~= (b.count or 1) then return (a.count or 1) > (b.count or 1) end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

function M.ToggleCat(win, cat)
	M.SetCollapsed(cat, not M.IsCollapsed(cat))
	for i = 1, getn(M.order) do
		local w = M.wins[M.order[i]]
		if w then w.dLayout = true end
	end
end

local function headClick(b)
	M.ToggleCat(b.win, b.cat)
end

function M.GetHead(win, cat)
	local h = win.heads[cat]
	if h then return h end
	if SUI.InCombat() then return nil end
	h = T.Button(win.frame, "", 100, HDRH, headClick)
	h.cat, h.win = cat, win
	h.label:ClearAllPoints()
	h.label:SetPoint("LEFT", h, "LEFT", 6, 0)
	h.label:SetJustifyH("LEFT")
	M.Tip(h, "msg.bags.cat.tip.t", "msg.bags.cat.tip")
	win.heads[cat] = h
	return h
end

function M.HideHeads(win)
	for cat, h in pairs(win.heads) do h:Hide() end
end

-- Relit le contenu des emplacements avant de classer (sans reessayer les objets inconnus : ce sont la minuterie et les rafraichissements).
function M.SyncLinks(win)
	for i = 1, win.n do
		local b = win.order[i]
		local tex, count, _, quality = GetContainerItemInfo(b.bag, b.slot)
		local link = nil
		if tex then link = GetContainerItemLink(b.bag, b.slot) end
		b.link, b.count = link, count
		if link then
			if INF.id[link] == nil then lookup(link) end
			b.q = quality or INF.q[link]
			if b.q == nil then b.q = 1 end
		else
			b.q = nil
		end
	end
end

-- Range les boutons de win.order par categorie (en-tetes reduisibles). Retourne la hauteur du contenu et vrai si tous les en-tetes existent.
function M.PlaceCats(win, w)
	local sz, sp, cols = cfg.size, cfg.spacing, cfg.columns
	local cg = win.cg
	do
		local pr = M.CacheRoot().prefs
		M.mineT, M.wornT, M.catT = pr.mine, pr.worn, pr.cat
	end
	M.setLookup = nil
	if cfg.setcat and SUI.Items and SUI.Items.SetCodes and SUI.Items.Code then M.setLookup = SUI.Items.SetCodes() end
	for k = 1, getn(CATKEYS) do
		local g = cg[CATKEYS[k]]
		for j = getn(g), 1, -1 do g[j] = nil end
	end
	for i = 1, win.n do
		local b = win.order[i]
		local g = cg[M.CatOf(b)]
		g[getn(g) + 1] = b
	end
	local idx = 0
	local y = HEADER
	local ok = true
	for k = 1, getn(CATKEYS) do
		local key = CATKEYS[k]
		local g = cg[key]
		local n = getn(g)
		local head = win.heads[key]
		if n > 0 then
			if key ~= "free" then table.sort(g, cmpBtn) end
			for j = 1, n do
				idx = idx + 1
				win.order[idx] = g[j]
			end
			head = head or M.GetHead(win, key)
			local collapsed = M.IsCollapsed(key)
			if head then
				head:SetWidth(w - PAD * 2)
				head:ClearAllPoints()
				head:SetPoint("TOPLEFT", win.frame, "TOPLEFT", PAD, -y)
				T.SetButtonText(head, (collapsed and "+ " or "- ") .. L("msg.bags.cat." .. M.CatLabelKey(key)) .. " (" .. n .. ")")
				head:Show()
				y = y + HDRH + 2
			else
				ok = false
			end
			if collapsed then
				for j = 1, n do g[j]:Hide() end
			else
				for j = 1, n do
					local b = g[j]
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", win.frame, "TOPLEFT", PAD + SUI.Mod(j - 1, cols) * (sz + sp), -(y + floor((j - 1) / cols) * (sz + sp)))
					b:Show()
				end
				y = y + ceil(n / cols) * (sz + sp) - sp
			end
			y = y + GAP
		elseif head then
			head:Hide()
		end
	end
	local h = y - HEADER - GAP
	if h < sz then h = sz end
	return h, ok
end

-- ---------------------------------------------------------------- mise en page
-- Cree ce qui manque (jamais en combat) puis place les boutons. Retourne false si des boutons manquent encore.
function M.Layout(win)
	if not win.frame then return false end
	if win.offline then return true end         -- vue d'un autre personnage : voir M.LayoutView
	local nb = M.FillBags(win)
	local complete = true
	local combat = SUI.InCombat()
	local sz, sp, cols = cfg.size, cfg.spacing, cfg.columns
	local idx = 0
	local order = win.order
	for i = 1, nb do
		local bag = win.list[i]
		local size = slotCount(bag)
		win.size[bag] = size
		local h = win.holder[bag]
		for slot = 1, size do
			local b = h and h.btn[slot]
			if not b then
				if combat then
					complete = false
				else
					b = newItem(win, bag, slot)
					h = win.holder[bag]
				end
			end
			if b then
				idx = idx + 1
				order[idx] = b
				local col = SUI.Mod(idx - 1, cols)
				local row = floor((idx - 1) / cols)
				b:SetWidth(sz)
				b:SetHeight(sz)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", win.frame, "TOPLEFT", PAD + col * (sz + sp), -(HEADER + row * (sz + sp)))
				b:Show()
			end
		end
		if h then
			for slot = size + 1, getn(h.btn) do
				if h.btn[slot] then
					h.btn[slot]:Hide()
					h.btn[slot].link = nil
				end
			end
		end
	end
	-- sacs qui ne sont plus dans la liste (cle retiree, sac de banque achete / retire)
	for bag, h in pairs(win.holder) do
		local listed = false
		for i = 1, nb do
			if win.list[i] == bag then listed = true end
		end
		if not listed then
			for slot = 1, getn(h.btn) do
				if h.btn[slot] then
					h.btn[slot]:Hide()
					h.btn[slot].link = nil
				end
			end
		end
	end
	for i = idx + 1, win.n do order[i] = nil end
	win.n = idx
	local rows = ceil(idx / cols)
	if rows < 1 then rows = 1 end
	local w = PAD * 2 + cols * sz + (cols - 1) * sp
	if w < MINW then w = MINW end
	local hideS = (win.key == "bank" and cfg.hidebankslots) or (win.key == "bag" and cfg.hideslots)
	local extra = ((win.key == "bank" or M.HasBagSlots(win)) and not hideS) and BANKROW or 0
	if win.key == "bag" and win.slots then M.PlaceBagSlots(win) end
	if win.key == "bank" then M.UpdateBankBags(win) end
	local gridH = rows * (sz + sp) - sp
	if cfg.layout == "categories" then
		M.SyncLinks(win)
		local ch, hok = M.PlaceCats(win, w)
		gridH = ch
		if not hok then complete = false end
	else
		M.HideHeads(win)
	end
	win.frame:SetWidth(w)
	win.frame:SetHeight(HEADER + gridH + PAD + extra + FOOTER)
	win.fullW = w
	win.laid = true
	return complete
end

function M.Refresh(win)
	for i = 1, win.n do pcall(M.UpdateSlot, win.order[i]) end
	M.ApplyDim(win)
	M.UpdateValue(win)
	win.dAll = false
end

-- ---------------------------------------------------------------- tri
local sortMode, sortJunk = "quality", true

local function cmp(a, b)
	if sortJunk then
		local ja, jb = (a.q == 0), (b.q == 0)
		if ja ~= jb then return jb end
	end
	if sortMode == "name" then
		if a.name ~= b.name then return a.name < b.name end
	elseif sortMode == "type" then
		if a.ty ~= b.ty then return a.ty < b.ty end
		if a.q ~= b.q then return a.q > b.q end
		if a.name ~= b.name then return a.name < b.name end
	else
		if a.q ~= b.q then return a.q > b.q end
		if a.ty ~= b.ty then return a.ty < b.ty end
		if a.sub ~= b.sub then return a.sub < b.sub end
		if a.name ~= b.name then return a.name < b.name end
	end
	if a.count ~= b.count then return a.count > b.count end
	return a.key < b.key
end

function M.StartSort(win)
	if not win or not win.frame or not win.frame:IsShown() then return false end
	if win.sort then return false end
	if SUI.InCombat() then
		SUI.Print(L("msg.bags.sort.combat"))
		return false
	end
	if CursorHasItem() then
		SUI.Print(L("msg.bags.sort.cursor"))
		return false
	end
	local s = { bag = {}, slot = {}, n = 0, phase = 0, moves = 0, idle = 0 }
	local skipped = 0
	for i = 1, win.nlist do
		local bag = win.list[i]
		local kind = M.BagKind(bag)
		if kind == "bag" or kind == nil then   -- inconnu (pas d'API de sac) : trie quand meme, un echec arrete le tri
			for slot = 1, slotCount(bag) do
				s.n = s.n + 1
				s.bag[s.n], s.slot[s.n] = bag, slot
			end
		elseif kind ~= "key" then
			skipped = skipped + 1
		end
	end
	if skipped > 0 then SUI.Print(L("msg.bags.sort.skipped", skipped)) end
	if s.n == 0 then return false end
	win.sort = s
	SUI.Print(L("msg.bags.sort.start"))
	return true
end

-- Une etape : une permutation a la fois, en relisant l'etat reel (les objets de meme lien et meme quantite sont interchangeables).
-- Retourne "done" | "wait" | "moved" | "fail".
function M.SortStep(win)
	local s = win.sort
	local n = s.n
	for i = 1, n do
		local _, _, locked = GetContainerItemInfo(s.bag[i], s.slot[i])
		if locked then return "wait" end
	end
	if s.phase == 1 then
		if CursorHasItem() then
			PickupContainerItem(s.dropBag, s.dropSlot)
			s.phase = 0
			s.moves = s.moves + 1
			return "moved"
		end
		s.phase = 0
	elseif CursorHasItem() then
		return "wait"
	end
	if s.moves > 3 * n + 20 then return "fail" end
	sortMode, sortJunk = cfg.sort, cfg.junklast
	local cur, recs = {}, {}
	for i = 1, n do
		local tex, count = GetContainerItemInfo(s.bag[i], s.slot[i])
		local link = nil
		if tex then link = GetContainerItemLink(s.bag[i], s.slot[i]) end
		if link then
			lookup(link)
			local key = link .. "#" .. count
			cur[i] = key
			local _, _, _, q = GetContainerItemInfo(s.bag[i], s.slot[i])
			recs[getn(recs) + 1] = { key = key, count = count, q = q or INF.q[link] or 1, ty = INF.ltype[link] or "", sub = INF.sub[link] or "",
				name = INF.name[link] or "" }
		else
			cur[i] = ""
		end
	end
	table.sort(recs, cmp)
	for i = 1, getn(recs) do
		if cur[i] ~= recs[i].key then
			local from = nil
			for j = i + 1, n do
				if cur[j] == recs[i].key then
					from = j
					break
				end
			end
			if not from then return "fail" end
			PickupContainerItem(s.bag[from], s.slot[from])
			PickupContainerItem(s.bag[i], s.slot[i])
			s.moves = s.moves + 1
			if CursorHasItem() then
				s.phase = 1
				s.dropBag, s.dropSlot = s.bag[from], s.slot[from]
			end
			return "moved"
		end
	end
	return "done"
end

-- Arret d'un tri : si une permutation a laisse un objet sur le curseur, on le repose ou il doit aller (au mieux).
local function abortSort(win)
	local s = win.sort
	win.sort = nil
	win.dAll = true
	if s and s.phase == 1 and CursorHasItem() then
		PickupContainerItem(s.dropBag, s.dropSlot)
		s.phase = 0
	end
end

local function sortTick(win)
	local s = win.sort
	local r = M.SortStep(win)
	if r == "moved" then
		s.idle = 0
	elseif r == "wait" then
		s.idle = s.idle + 1
		if s.idle > STALL then r = "fail" end
	end
	if r == "done" then
		abortSort(win)
		SUI.Print(L("msg.bags.sort.done", s.moves))
	elseif r == "fail" then
		abortSort(win)
		SUI.Print(L("msg.bags.sort.fail"))
	end
end

-- ---------------------------------------------------------------- vue hors-ligne (sacs d'un autre personnage, lecture seule)
local function viewEnter()
	local b = this
	local e = b.e
	local gt = getglobal("GameTooltip")
	if not e or not gt then return end
	gt:SetOwner(b, "ANCHOR_RIGHT")
	if GetItemInfo(e.id) then
		pcall(gt.SetHyperlink, gt, "item:" .. e.ref)   -- seulement un objet deja connu du client ; pcall (AtlasLoot)
	else
		local r, g, bl = GetItemQualityColor(e.q)
		gt:AddLine(e.name, r, g, bl)
		gt:AddLine(L("msg.bags.view.uncached"), T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	end
	if e.count > 1 then gt:AddLine(L("msg.bags.view.count", e.count), T.c.dim[1], T.c.dim[2], T.c.dim[3]) end
	gt:Show()
end

local function viewLeave()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

local function newViewBtn(win)
	local b = CreateFrame("Button", nil, win.vpanel)
	b.win = win
	T.Backdrop(b, T.c.inset, T.c.border)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.cnt = T.Text(b, 10, T.c.text, "RIGHT", true)
	b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b:SetScript("OnEnter", viewEnter)
	b:SetScript("OnLeave", viewLeave)
	return b
end

function M.BuildView(win)
	local pn = CreateFrame("Frame", nil, win.frame)
	pn:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 0, -HEADER)
	pn:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", 0, 0)
	pn:Hide()
	win.vpanel = pn
	win.vb = {}
	win.vn = 0
	win.vh = { T.Text(pn, 11, T.c.text, "LEFT"), T.Text(pn, 11, T.c.text, "LEFT") }
end

local function cmpView(a, b)
	if cfg.layout == "categories" then
		local ca, cb = CATIDX[a.cat] or CATIDX.other, CATIDX[b.cat] or CATIDX.other
		if ca ~= cb then return ca < cb end
		if a.q ~= b.q then return a.q > b.q end
		if a.lname ~= b.lname then return a.lname < b.lname end
	end
	return a.i < b.i
end

function M.SortViews(d)
	if not d then return end
	table.sort(d.bags, cmpView)
	table.sort(d.bank, cmpView)
end

function M.LoadView(rec)
	local d = { rec = rec, bags = {}, bank = {} }
	local src = { rec.bags, rec.bank }
	local dst = { d.bags, d.bank }
	for k = 1, 2 do
		local l = src[k]
		if type(l) == "table" then
			for i = 1, getn(l) do
				local e = M.Parse(l[i])
				if e then
					e.i = i
					dst[k][getn(dst[k]) + 1] = e
				end
			end
		end
	end
	M.SortViews(d)
	return d
end

local function ageText(t)
	local tf = getglobal("time")
	if not t or t == 0 or not tf then return "?" end
	local d = tf() - t
	if d < 0 then d = 0 end
	if d < 3600 then return L("msg.bags.view.age.m", floor(d / 60)) end
	if d < 86400 then return L("msg.bags.view.age.h", floor(d / 3600)) end
	return L("msg.bags.view.age.d", floor(d / 86400))
end

function M.ViewValue(win)
	local d = win.vdata
	if not d or not win.value then return end
	local rec = d.rec
	local s = money(rec.money) .. "  -  " .. L("msg.bags.view.counts", getn(d.bags), getn(d.bank)) .. "  -  " .. ageText(rec.t)
	if win.value.suiTxt ~= s then
		win.value.suiTxt = s
		win.value:SetText(s)
	end
end

local function matchesEntry(e, win)
	local f = win.filter
	if f == "gear" and e.cat ~= "equip" and e.cat ~= "set" then return false end
	if f == "junk" and e.q ~= 0 then return false end
	if f == "good" and e.q < 2 then return false end
	local q = win.query
	if q ~= "" then
		if not (string.find(e.lname, q, 1, true) or string.find(e.ty, q, 1, true) or string.find(e.sub, q, 1, true)) then return false end
	end
	return true
end

function M.ApplyViewDim(win)
	local active = (win.query ~= "" or win.filter ~= "all")
	for i = 1, win.vn or 0 do
		local b = win.vb[i]
		if b and b.e then
			local a = 1
			if active and not matchesEntry(b.e, win) then a = DIM end
			if b.dimA ~= a then
				b.dimA = a
				b:SetAlpha(a)
			end
		end
	end
end

local function paintView(b, e)
	if e.tex ~= "" then b.icon:SetTexture(e.tex) end
	b.cnt:SetText((cfg.counts and e.count > 1) and e.count or "")
	if cfg.quality and cfg.borderlimit <= e.q then
		local r, g, bl = GetItemQualityColor(e.q)
		b:SetBackdropBorderColor(r, g, bl, 1)
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
end

-- Une section (sacs ou banque) du panneau hors-ligne. Retourne l'indice du dernier bouton, la hauteur atteinte et vrai si tout existe.
local function placeSection(win, list, fs, label, idx, y)
	local sz, sp, cols = cfg.size, cfg.spacing, cfg.columns
	local pn = win.vpanel
	local n = getn(list)
	local ok = true
	local combat = SUI.InCombat()
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", pn, "TOPLEFT", PAD, -y)
	fs:SetText(label)
	y = y + 16
	for j = 1, n do
		idx = idx + 1
		local b = win.vb[idx]
		if not b and not combat then
			b = newViewBtn(win)
			win.vb[idx] = b
		end
		if b then
			b.e = list[j]
			b.dimA = nil
			b:SetWidth(sz)
			b:SetHeight(sz)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", pn, "TOPLEFT", PAD + SUI.Mod(j - 1, cols) * (sz + sp), -(y + floor((j - 1) / cols) * (sz + sp)))
			paintView(b, list[j])
			b:SetAlpha(1)
			b:Show()
		else
			ok = false
		end
	end
	if n > 0 then y = y + ceil(n / cols) * (sz + sp) - sp end
	return idx, y + GAP * 2, ok
end

function M.LayoutView(win)
	local d = win.vdata
	if not d or not win.vpanel then return false end
	local sz, sp, cols = cfg.size, cfg.spacing, cfg.columns
	local w = PAD * 2 + (cols * sz) + ((cols - 1) * sp)
	if w < MINW then w = MINW end
	local idx, y, ok1, ok2 = 0, 6, true, true
	idx, y, ok1 = placeSection(win, d.bags, win.vh[1], L("msg.bags.view.bags") .. " (" .. getn(d.bags) .. ")", idx, y)
	local lab = L("msg.bags.view.nobank")
	if d.rec.nbank ~= nil then lab = L("msg.bags.view.bank") .. " (" .. getn(d.bank) .. ")" end
	idx, y, ok2 = placeSection(win, d.bank, win.vh[2], lab, idx, y)
	for i = idx + 1, win.vn or 0 do
		local b = win.vb[i]
		if b then
			b:Hide()
			b.e = nil
		end
	end
	win.vn = idx
	win.frame:SetWidth(w)
	win.frame:SetHeight(HEADER + y + PAD + FOOTER)
	win.fullW = w
	M.ApplyViewDim(win)
	M.ViewValue(win)
	return ok1 and ok2
end

function M.TickView(win)
	if win.vDirty then
		win.vDirty = false
		win.dDim = false
		if not M.LayoutView(win) and not win.vwait then
			win.vwait = true
			SUI.WhenSafe(function()
				win.vwait = false
				win.vDirty = true
			end)
		end
	elseif win.dDim then
		win.dDim = false
		M.ApplyViewDim(win)
	end
end

function M.UpdateViewBtn(win)
	if not win.vbtn then return end
	local name = UnitName("player") or "?"
	if win.offline and win.vdata then name = M.DispName(win.view, win.vdata.rec) end
	T.SetButtonText(win.vbtn, L("msg.bags.view.btn", name))
end

-- key == nil (ou le personnage courant) : retour aux sacs reels.
function M.SetView(win, key, silent)
	if not win then return false end
	if win.pick then win.pick:Hide() end
	local me = M.CharKey()
	if not key or key == me then
		if not win.offline then return true end
		win.offline, win.view, win.vdata = false, nil, nil
		if win.vpanel then win.vpanel:Hide() end
		for bag, h in pairs(win.holder) do h:Show() end
		if win.sbtn then win.sbtn:Show() end
		if win.slots and not cfg.hideslots then
			for i = 1, getn(win.slots) do win.slots[i].btn:Show() end
		end
		win.title:SetText(L(win.def.title))
		M.UpdateViewBtn(win)
		win.dLayout, win.dAll, win.dDim = true, true, true
		win.value.suiTxt = nil
		return true
	end
	if SUI.InCombat() then
		if not silent then SUI.Print(L("msg.bags.view.combat")) end
		return false
	end
	local rec = M.CacheRoot().chars[key]
	if type(rec) ~= "table" then
		if not silent then SUI.Print(L("msg.bags.view.none")) end
		return false
	end
	if not win.vpanel then M.BuildView(win) end
	win.view, win.offline = key, true
	win.vdata = M.LoadView(rec)
	for bag, h in pairs(win.holder) do h:Hide() end
	M.HideHeads(win)
	if win.sbtn then win.sbtn:Hide() end
	if win.slots then
		for i = 1, getn(win.slots) do win.slots[i].btn:Hide() end
	end
	win.vpanel:Show()
	win.title:SetText(L("msg.bags.view.title", M.DispName(key, rec)))
	M.UpdateViewBtn(win)
	win.vDirty, win.dDim = true, true
	win.value.suiTxt = nil
	return true
end

local function pickClick(b)
	M.SetView(b.win, b.key)
end

local function cmpKeys(a, b)
	return a.n < b.n
end

-- Liste deroulante "Voir : <personnage>" : le personnage courant, puis les autres memorises (ordre alphabetique).
function M.TogglePick(win)
	if win.pick and win.pick:IsShown() then
		win.pick:Hide()
		return
	end
	if SUI.InCombat() then
		SUI.Print(L("msg.bags.view.combat"))
		return
	end
	local me = M.CharKey()
	local chars = M.CacheRoot().chars
	local list = {}
	for k, rec in pairs(chars) do
		if k ~= me then list[getn(list) + 1] = { key = k, n = string.lower(M.DispName(k, rec)), name = M.DispName(k, rec) } end
	end
	table.sort(list, cmpKeys)
	if not win.pick then
		local pk = CreateFrame("Frame", nil, win.frame)
		pk:SetFrameLevel(win.frame:GetFrameLevel() + 30)
		pk:EnableMouse(true)
		T.Backdrop(pk, T.c.panel, T.c.border)
		pk:SetPoint("TOPRIGHT", win.vbtn, "BOTTOMRIGHT", 0, -2)
		win.pick = pk
	end
	local shown = win.view or me
	local n = getn(list) + 1
	for i = 1, n do
		local row = win.prow[i]
		if not row then
			row = T.Button(win.pick, "", 130, 18, pickClick)
			row.win = win
			win.prow[i] = row
		end
		local key, label = me, L("msg.bags.view.me", UnitName("player") or "?")
		if i > 1 then key, label = list[i - 1].key, list[i - 1].name end
		row.key = key
		T.SetButtonText(row, label)
		T.SetSelected(row, key == shown)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", win.pick, "TOPLEFT", 4, -4 - (i - 1) * 20)
		row:Show()
	end
	for i = n + 1, getn(win.prow) do win.prow[i]:Hide() end
	win.pick:SetWidth(138)
	win.pick:SetHeight(8 + n * 20 - 2)
	win.pick:Show()
end

-- ---------------------------------------------------------------- "Tout deposer en banque"
local function depositFilterOk(bag, slot)
	local win = M.wins.bag
	if not win or (win.query == "" and win.filter == "all") then return true end
	local h = win.holder[bag]
	local b = h and h.btn[slot]
	if not b then return true end
	return matches(b, win)
end

function M.UpdateDepositBtn()
	local w = M.wins.bank
	if not w or not w.dbtn then return end
	if M.on and M.bankOpen and cfg.depositall then w.dbtn:Show() else w.dbtn:Hide() end
end

function M.StopDeposit(silent)
	local d = M.dep
	M.dep = nil
	if d and not silent then SUI.Print(L("msg.bags.deposit.done", d.moved)) end
end

function M.StartDeposit()
	if M.dep then return false end
	if not M.on or not M.bankOpen then
		SUI.Print(L("msg.bags.deposit.closed"))
		return false
	end
	if SUI.InCombat() then
		SUI.Print(L("msg.bags.deposit.combat"))
		return false
	end
	if CursorHasItem() then
		SUI.Print(L("msg.bags.deposit.cursor"))
		return false
	end
	local d = { bag = {}, slot = {}, n = 0, i = 0, moved = 0, idle = 0 }
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		for slot = 1, slotCount(bag) do
			local tex = GetContainerItemInfo(bag, slot)
			local link = tex and GetContainerItemLink(bag, slot)
			if link then
				lookup(link)
				if not KEEP[INF.id[link]] and depositFilterOk(bag, slot) then
					d.n = d.n + 1
					d.bag[d.n], d.slot[d.n] = bag, slot
				end
			end
		end
	end
	if d.n == 0 then
		SUI.Print(L("msg.bags.deposit.none"))
		return false
	end
	M.dep = d
	SUI.Print(L("msg.bags.deposit.start", d.n))
	return true
end

-- Une etape toutes les deux passes : on attend que l'emplacement precedent soit libere avant le suivant.
function M.DepTick()
	local d = M.dep
	local bf = getglobal("BankFrame")
	if SUI.InCombat() or not M.bankOpen or CursorHasItem() or (bf and bf.IsShown and not bf:IsShown()) then
		M.StopDeposit(false)
		return
	end
	if d.wait then
		local tex, _, locked = GetContainerItemInfo(d.bag[d.i], d.slot[d.i])
		if locked and d.idle < STALL then
			d.idle = d.idle + 1
			return
		end
		local link = tex and GetContainerItemLink(d.bag[d.i], d.slot[d.i]) or nil
		if link ~= d.link then d.moved = d.moved + 1 end
		d.wait = false
	end
	d.i = d.i + 1
	if d.i > d.n then
		M.StopDeposit(false)
		return
	end
	local bag, slot = d.bag[d.i], d.slot[d.i]
	local tex = GetContainerItemInfo(bag, slot)
	if not tex then return end
	d.link = GetContainerItemLink(bag, slot)
	UseContainerItem(bag, slot)
	d.wait, d.idle = true, 0
end

-- ---------------------------------------------------------------- construction des fenetres (hors combat)
local function onSearch()
	local e = this
	local win = e.win
	local q = string.lower(e:GetText() or "")
	if win.query ~= q then
		win.query = q
		win.dDim = true
	end
end

function M.CycleFilter(win)
	local cur = 1
	for i = 1, getn(M.filters) do
		if M.filters[i] == win.filter then cur = i end
	end
	cur = cur + 1
	if cur > getn(M.filters) then cur = 1 end
	win.filter = M.filters[cur]
	T.SetButtonText(win.fbtn, L("choice.bags.filter." .. win.filter))
	win.dDim = true
end

local function winHide()
	local win = this.win
	M.DragStop(win)
	if win.pick then win.pick:Hide() end
	if win.offline then M.SetView(win, nil) end      -- on rouvre toujours sur ses propres sacs
	if win.key == "bag" then
		M.MarkSeen("bag")
		M.Snapshot("bags")
	end
	if win.sort then
		abortSort(win)
		SUI.Print(L("msg.bags.sort.fail"))
	end
end

local function buyBankSlot()
	local sp = getglobal("StaticPopup_Show")
	if sp then sp("CONFIRM_BUY_BANK_SLOT") end
end

-- ---------------------------------------------------------------- deplacement par la barre de titre
-- Meme enregistrement que le service Mover (position par mode et par profil, remise a zero, nom lisible) : Layout.Register a deja
-- adopte le cadre. Verrou : ui.locked (decoche = deplacable, ou mode "Deplacer l'interface"). Jamais en combat.
function M.CanMove()
	if SUI.InCombat() then return false, "combat" end
	if C.Get("ui.locked") then return false, "locked" end
	return true
end

-- force : Maj enfoncee = convention universelle ShikiUI (Maj+glisser deplace toujours, verrou contourne ; combat reste interdit)
function M.DragStart(win, force)
	if not win or not win.frame or win.dragging then return false end
	local ok, why = M.CanMove()
	if not ok and not (force and why == "locked") then
		if why == "locked" and not M.warnedLock and not force then
			M.warnedLock = true
			SUI.Print(L("msg.bags.locked"))
		end
		return false
	end
	M.warnedLock = false
	win.frame:StartMoving()
	win.dragging = true
	return true
end

function M.DragStop(win)
	if not win or not win.dragging then return false end
	win.dragging = false
	local f = win.frame
	f:StopMovingOrSizing()
	local l, b = f:GetLeft(), f:GetBottom()
	local key = win.def.layout
	local rec = SUI.Mover and SUI.Mover.items and SUI.Mover.items[key]
	if l and b and rec and SUI.Mover.Commit then
		local sc = f:GetScale() or 1
		SUI.Mover.Commit(rec, l * sc, b * sc)
	elseif l and b then      -- sans Mover : memoriser quand meme (sinon Layout.Apply ramenerait le cadre en arriere)
		local sc = f:GetScale() or 1
		local _, _, s = C.GetPos(SUI.Layout.ReadKey(key))
		C.SetPos(SUI.Layout.WriteKey(key), l * sc, b * sc, s)
		SUI.Layout.Apply(key)
	else
		SUI.Layout.Apply(key)
	end
	return true
end

-- Remet les fenetres a leur place d'origine (position du profil effacee).
function M.ResetPos()
	for i = 1, getn(M.order) do
		local key = WDEF[M.order[i]].layout
		if SUI.Mover and SUI.Mover.items and SUI.Mover.items[key] and SUI.Mover.Reset then
			SUI.Mover.Reset(key)
		else
			C.ClearPosAll(key)
			SUI.Layout.Apply(key)
		end
	end
end

barDragStart = function()
	local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
	M.DragStart(this.win, shift)
end
barDragStop = function() M.DragStop(this.win) end

function M.BuildWindow(key)
	local def = WDEF[key]
	local f = CreateFrame("Frame", def.name, UIParent)
	local win = { key = key, def = def, frame = f, holder = {}, order = {}, n = 0, list = {}, nlist = 0, size = {}, query = "", filter = "all",
		dAll = true, dDim = false, dBags = {} }
	f.win = win
	f:SetFrameStrata("HIGH")          -- au-dessus des barres d'action (MEDIUM) ; les boites de dialogue (DIALOG) restent au-dessus
	f:SetClampedToScreen(true)        -- jamais deplacee hors de l'ecran
	f:SetToplevel(true)               -- un clic ramene la fenetre au premier plan (sacs et banque peuvent se chevaucher)
	f:SetWidth(MINW)
	f:SetHeight(120)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:EnableMouse(true)
	-- barre de titre : poignee de deplacement (creee avant les boutons, qui restent au-dessus et cliquables)
	win.bar = CreateFrame("Frame", nil, f)
	win.bar.win = win
	win.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	win.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	win.bar:SetHeight(BARH)
	win.bar:EnableMouse(true)
	win.bar:RegisterForDrag("LeftButton")
	win.bar:SetScript("OnDragStart", barDragStart)
	win.bar:SetScript("OnDragStop", barDragStop)
	win.title = T.Text(f, 12, T.c.text, "LEFT")
	win.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -8)
	win.title:SetText(L(def.title))
	win.close = T.Button(f, "x", 18, 18, function() f:Hide() end)
	win.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -5)
	win.sbtn = T.Button(f, L("msg.bags.btn.sort"), 54, 18, function() M.StartSort(win) end)
	win.sbtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -28)
	win.fbtn = T.Button(f, L("choice.bags.filter.all"), 62, 18, function() M.CycleFilter(win) end)
	win.fbtn:SetPoint("RIGHT", win.sbtn, "LEFT", -4, 0)
	win.edit = T.Edit(f, 90, 18)
	win.edit.win = win
	win.edit:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -28)
	win.edit:SetPoint("RIGHT", win.fbtn, "LEFT", -4, 0)
	win.edit:SetScript("OnTextChanged", onSearch)
	win.value = T.Text(f, 10, T.c.dim, "LEFT")
	win.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 6)
	win.heads = {}
	win.cg = {}
	for i = 1, getn(CATKEYS) do win.cg[CATKEYS[i]] = {} end
	M.Tip(win.sbtn, "msg.bags.tip.sort.t", "msg.bags.tip.sort")
	M.Tip(win.fbtn, "msg.bags.tip.filter.t", "msg.bags.tip.filter")
	M.Tip(win.edit, "msg.bags.tip.search.t", "msg.bags.tip.search")
	T.GearButton(f, "bags", { size = 16, point = "TOPRIGHT", x = -28, y = -7, title = L("msg.bags.gear"),
		onCreate = function(g) win.gear = g end })
	if key == "bag" then
		win.prow = {}
		win.vbtn = T.Button(f, "", 112, 18, function() M.TogglePick(win) end)
		win.vbtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, -5)
		M.Tip(win.vbtn, "msg.bags.view.tip.t", "msg.bags.view.tip")
		M.UpdateViewBtn(win)
		if not cfg.remember then win.vbtn:Hide() end
	end
	f:SetScript("OnHide", winHide)
	if key == "bank" then
		win.buy = T.Button(f, "+", 18, 18, buyBankSlot)
		win.buy:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 5)
		win.buy:Hide()
		win.dbtn = T.Button(f, L("msg.bags.btn.deposit"), 86, 18, function() M.StartDeposit() end)
		win.dbtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 22, 5)
		M.Tip(win.dbtn, "msg.bags.deposit.tip.t", "msg.bags.deposit.tip")
		win.dbtn:Hide()
	end
	f:Hide()
	SUI.Layout.Register(f, def.layout, def.pt, def.x, def.y)
	tinsert(UISpecialFrames, def.name)
	M.wins[key] = win
	return win
end

-- BankFrame.lua de Blizzard deduit l'emplacement d'inventaire d'un bouton de sac de banque de son NOM : GetInventorySlotInfo(strsub(nom,
-- 10)), soit "Bag1" pour "BankFrameBag1" (prefixe de 9 caracteres). Un nom ne respectant pas ce gabarit ("SUIBankBagBag1" donnait
-- "gBag1") provoquait "Invalid inventory slot in GetInventorySlotInfo" a l'ouverture de la banque. Le prefixe ci-dessous a 9 caracteres.
local BANKPFX = "ShikiBank"
M.BANKPFX = BANKPFX
M.BANKWRAP = "BankFrameItemButton_Update"

-- Filet de securite : la mise a jour de Blizzard est enveloppee a la main (pas de hooksecurefunc) ; une erreur sur un bouton qui est
-- le notre est avalee (comptee dans M.bankErr) au lieu d'ouvrir la fenetre d'erreur. Les boutons de Blizzard passent sans filtre.
function M.WrapBankUpdate()
	if M.bankOrig then return end
	local orig = getglobal(M.BANKWRAP)
	if type(orig) ~= "function" then return end
	M.bankOrig = orig
	M.bankWrap = function(a, b, c)
		local nm = a and a.GetName and a:GetName()
		if nm and string.sub(nm, 1, string.len(BANKPFX)) == BANKPFX then
			local ok = pcall(orig, a, b, c)
			if not ok then M.bankErr = (M.bankErr or 0) + 1 end
			return
		end
		return orig(a, b, c)
	end
	setglobal(M.BANKWRAP, M.bankWrap)
end

function M.UnwrapBankUpdate()
	if not M.bankOrig then return end
	if getglobal(M.BANKWRAP) == M.bankWrap then setglobal(M.BANKWRAP, M.bankOrig) end
	M.bankOrig, M.bankWrap = nil, nil
end

-- Rangee de sacs de la banque (modeles de Blizzard, voir pfUI) : creee une fois, jamais en combat, protegee par pcall.
function M.BuildBankBags(win)
	if win.bankbags then return end
	win.bankbags = {}
	local nbag = NUM_BAG_SLOTS or 4
	for i = 1, (NUM_BANKBAGSLOTS or 6) do
		local ok, b = pcall(function(i)
			local c = CreateFrame("CheckButton", BANKPFX .. "Bag" .. i, win.frame, "BankItemButtonBagTemplate")
			c:SetID(nbag + i)   -- verifie en jeu : les boutons de Blizzard (BankFrameBag1..6) ont les identifiants 5 a 10 (= numero du conteneur)
			-- Le modele de Blizzard deduit l'emplacement d'inventaire a la creation (avant SetID) : GetInventorySlot() donnait 39 (case de banque).
			-- Icone, clic (poser / reprendre un sac) et infobulle sont donc geres ici, avec l'emplacement verifie en jeu : ContainerIDToInventoryID(4 + i) = 63 + i.
			c.bagIndex = i
			c.invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(nbag + i) or (63 + i)
			c:SetScript("OnEvent", nil)
			c:SetScript("OnClick", M.BankBagClick)
			c:SetScript("OnDragStart", M.BankBagClick)
			c:SetScript("OnReceiveDrag", M.BankBagClick)
			c:SetScript("OnEnter", M.BankBagEnter)
			c:SetScript("OnLeave", function() GameTooltip:Hide() end)
			c:SetWidth(22)
			c:SetHeight(22)
			c:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", PAD + (i - 1) * 25, FOOTER + 2)
			T.Backdrop(c, T.c.inset, T.c.border)
			return c
		end, i)
		if ok then win.bankbags[i] = b end
	end
end

function M.BankBagClick()
	local b = this
	if not b.invSlot then return end
	if b.bagIndex > (GetNumBankSlots() or 0) then
		local sp = getglobal("StaticPopup_Show")
		if sp then sp("CONFIRM_BUY_BANK_SLOT") end
		return
	end
	if CursorHasItem() then PutItemInBag(b.invSlot) else PickupBagFromSlot(b.invSlot) end
end

function M.BankBagEnter()
	local b = this
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	if b.bagIndex > (GetNumBankSlots() or 0) then
		GameTooltip:SetText(L("msg.bags.bankslot.buy"))
	elseif GameTooltip.SetInventoryItem and GetInventoryItemLink("player", b.invSlot) then
		GameTooltip:SetInventoryItem("player", b.invSlot)
	else
		GameTooltip:SetText(L("msg.bags.bankslot.empty"))
	end
	GameTooltip:Show()
end

-- icone (ou case vide) de chaque emplacement de sac de la banque ; teinte rouge tant que l'emplacement n'est pas achete
function M.PaintBankBags(win)
	if not win or not win.bankbags then return end
	local owned = GetNumBankSlots() or 0
	for i = 1, getn(win.bankbags) do
		local b = win.bankbags[i]
		if b and b.invSlot then
			local t = getglobal(b:GetName() .. "IconTexture")
			if t then
				local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", b.invSlot)
				if tex then
					t:SetTexture(tex)
					t:Show()
				else
					t:SetTexture(nil)
				end
				if i > owned then t:SetVertexColor(T.c.bad[1], T.c.bad[2], T.c.bad[3]) else t:SetVertexColor(T.c.text[1], T.c.text[2], T.c.text[3]) end
			end
		end
	end
end

function M.UpdateBankBags(win)
	if win.key ~= "bank" then return end
	local owned = GetNumBankSlots() or 0
	M.BuildBankBags(win)
	for i = 1, getn(win.bankbags) do
		if win.bankbags[i] then
			if cfg.hidebankslots then win.bankbags[i]:Hide() else win.bankbags[i]:Show() end
		end
	end
	M.PaintBankBags(win)
	if win.buy then
		if owned < (NUM_BANKBAGSLOTS or 6) then win.buy:Show() else win.buy:Hide() end
	end
end

-- Emplacements de sacs du jeu (CharacterBag0Slot..3Slot) : ce sont des enfants de la barre principale de Blizzard, que le module
-- "actionbars" masque. Sans eux on ne peut plus poser ni retirer un sac. On les range en bas de la fenetre des sacs (ils redeviennent
-- ce qu'ils etaient a la desactivation du module) ; ils ne sont pris que si leur barre d'origine est masquee.
local BAGSLOTS = { "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }
local SLOTSCALE = 0.75

function M.HasBagSlots(win)
	return win.slots ~= nil and getn(win.slots) > 0
end

function M.PlaceBagSlots(win)
	if not win.slots then return end
	for i = 1, getn(win.slots) do
		local b = win.slots[i].btn
		if cfg.hideslots then b:Hide() else b:Show() end
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", (PAD + (i - 1) * 25) / SLOTSCALE, (FOOTER + 2) / SLOTSCALE)
	end
end

-- Le cadre d'origine (texture normale 64x64 decentree) donne des crochets etires une fois le bouton sorti de la barre : on le remplace par
-- le meme fond que les cases du sac, icone remplissant la case.
function M.StyleBagSlot(b, rec)
	local n = b.GetNormalTexture and b:GetNormalTexture()
	if n and n.GetTexture then rec.normal = n:GetTexture() end
	if b.SetNormalTexture then b:SetNormalTexture("") end
	b:SetWidth(30)
	b:SetHeight(30)
	local nm = b.GetName and b:GetName()
	local ic = nm and getglobal(nm .. "IconTexture")
	if ic and ic.SetTexCoord then
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:ClearAllPoints()
		ic:SetAllPoints(b)
	end
	if not rec.styled and T.Backdrop then
		rec.styled = true
		T.Backdrop(b, T.c.inset, T.c.border)
	end
end

function M.AttachBagSlots(win)
	if win.key ~= "bag" or (win.slots and getn(win.slots) > 0) then return end
	win.slots = {}
	for i = 1, getn(BAGSLOTS) do
		local b = getglobal(BAGSLOTS[i])
		if b and b.SetParent then
			local par = b:GetParent()
			local hidden = (par == nil) or (par.IsVisible and not par:IsVisible())
			if hidden then
				local rec = { btn = b, parent = par }
				rec.pt, rec.rel, rec.rpt, rec.x, rec.y = b:GetPoint()
				rec.scale = b:GetScale()
				win.slots[getn(win.slots) + 1] = rec
				b:SetParent(win.frame)
				b:SetFrameLevel(win.frame:GetFrameLevel() + 3)
				b:SetScale(SLOTSCALE)
				pcall(M.StyleBagSlot, b, rec)
				b:Show()
			end
		end
	end
	M.PlaceBagSlots(win)
end

function M.DetachBagSlots(win)
	if not win or not win.slots then return end
	for i = 1, getn(win.slots) do
		local rec = win.slots[i]
		local b = rec.btn
		if rec.parent then b:SetParent(rec.parent) end
		if rec.normal and b.SetNormalTexture then pcall(b.SetNormalTexture, b, rec.normal) end
		b:SetScale(rec.scale or 1)
		b:ClearAllPoints()
		if rec.pt then b:SetPoint(rec.pt, rec.rel, rec.rpt, rec.x, rec.y) end
	end
	win.slots = nil
	win.dLayout = true
end

-- ---------------------------------------------------------------- ouverture / fermeture
function M.Open(key)
	if not M.on then return end
	local win = M.wins[key]
	if not win then
		if SUI.InCombat() then
			if not M.warned then
				M.warned = true
				SUI.Print(L("msg.bags.combat"))
			end
			SUI.WhenSafe(function() M.Open(key) end)
			return
		end
		win = M.BuildWindow(key)
	end
	M.warned = false
	if key == "bag" then
		M.AttachBagSlots(win)
		M.UpdateViewBtn(win)
	end
	win.frame:Show()
	if not M.Layout(win) then
		M.warned = true
		SUI.Print(L("msg.bags.combat"))
		SUI.WhenSafe(function()
			if win.frame:IsShown() then
				M.Layout(win)
				M.Refresh(win)
			end
		end)
	end
	if key == "bank" then M.UpdateBankBags(win) end
	M.Refresh(win)
	if cfg.sortopen and not SUI.InCombat() then M.StartSort(win) end
end

function M.Close(key)
	local win = M.wins[key]
	if win then win.frame:Hide() end
end

function M.Toggle(key)
	local win = M.wins[key]
	if win and win.frame:IsShown() then M.Close(key) else M.Open(key) end
end

-- remplacements des fonctions d'ouverture des sacs de Blizzard
local function fnToggleBackpack() M.Toggle("bag") end
local function fnOpenBackpack() M.Open("bag") end
local function fnCloseAll() M.Close("bag") end
local function fnToggleKeyRing()
	if cfg.keyring then
		M.Toggle("bag")
	elseif M.orig.ToggleKeyRing then
		M.orig.ToggleKeyRing()
	end
end
local function fnOpenAll(force)
	if force then M.Open("bag") else M.Toggle("bag") end
end

function M.Takeover()
	local map = { ToggleBackpack = fnToggleBackpack, OpenBackpack = fnOpenBackpack, CloseBackpack = fnCloseAll, ToggleBag = fnToggleBackpack,
		OpenBag = fnOpenBackpack, CloseBag = fnCloseAll, OpenAllBags = fnOpenAll, CloseAllBags = fnCloseAll, ToggleKeyRing = fnToggleKeyRing }
	for i = 1, getn(REPLACED) do
		local name = REPLACED[i]
		if M.orig[name] == nil then M.orig[name] = getglobal(name) or false end
		setglobal(name, map[name])
	end
	M.taken = true
end

function M.Release()
	if not M.taken then return end
	for i = 1, getn(REPLACED) do
		local name = REPLACED[i]
		if M.orig[name] then setglobal(name, M.orig[name]) end
	end
	M.taken = false
end

-- La fenetre de banque d'origine reste "ouverte" mais invisible (son code est necessaire au jeu, voir pfUI).
function M.HideBlizzBank()
	local bf = getglobal("BankFrame")
	if M.bankHidden or not bf then return end
	M.bankHidden = true
	bf:SetScale(0.001)
	bf:SetPoint("TOPLEFT", 0, 0)
	bf:SetAlpha(0)
end

function M.ShowBlizzBank()
	local bf = getglobal("BankFrame")
	if not M.bankHidden or not bf then return end
	M.bankHidden = false
	bf:SetScale(1)
	bf:SetAlpha(1)
end

-- ---------------------------------------------------------------- minuterie et evenements
function M.Tick()
	M.tickN = M.tickN + 1
	if M.dep and SUI.Mod(M.tickN, 2) == 0 then M.DepTick() end
	if M.bankOpen and M.bankDirty and SUI.Mod(M.tickN, 5) == 0 then
		M.bankDirty = false
		M.Snapshot("bank")
	end
	for i = 1, getn(M.order) do
		local win = M.wins[M.order[i]]
		if win and win.frame:IsShown() and win.offline then
			M.TickView(win)
		elseif win and win.frame:IsShown() then
			if win.dLayout then
				win.dLayout = false
				if not M.Layout(win) and not win.waiting then
					-- des emplacements manquent (creation interdite en combat) : on recommence a la sortie du combat
					win.waiting = true
					SUI.WhenSafe(function()
						win.waiting = false
						win.dLayout = true
					end)
				end
				win.dAll = true
			else
				-- un sac a change de taille (sac pose ou retire) : mise en page a refaire
				for j = 1, win.nlist do
					local bag = win.list[j]
					if slotCount(bag) ~= (win.size[bag] or 0) then win.dLayout = true end
				end
				if win.key == "bank" and (GetNumBankSlots() or 0) ~= (win.owned or 0) then
					win.owned = GetNumBankSlots() or 0
					win.dLayout = true
					M.UpdateBankBags(win)
				end
			end
			if win.dAll or win.dLayout then
				if not win.dLayout then M.Refresh(win) end
			else
				local changed = false
				for k = 1, win.n do
					local b = win.order[k]
					if win.dBags[b.bag] or win.dLock then
						local okS, chg = pcall(M.UpdateSlot, b)
						if okS and chg then changed = true end
					end
				end
				if win.dCd then
					for k = 1, win.n do pcall(M.UpdateCooldown, win.order[k].bag, win.order[k]) end
				end
				for k in pairs(win.dBags) do win.dBags[k] = nil end
				win.dLock, win.dCd = false, false
				if (changed or M.dInfo) and cfg.layout == "categories" then win.dLayout = true end
				if changed or M.dInfo or win.dDim then
					M.ApplyDim(win)
					M.UpdateValue(win)
					win.dDim = false
				end
			end
			if win.unres and SUI.Mod(M.tickN, 10) == 0 then
				-- des objets n'etaient pas encore dans le cache du client : on reessaie (au plus 6 fois par objet)
				win.unres = false
				for k = 1, win.n do
					local l = win.order[k].link
					if l then
						lookup(l)
						if INF.ltype[l] == false and (INF.tries[l] or 0) < 6 then win.unres = true end
					end
				end
				if M.dInfo and cfg.layout == "categories" then win.dLayout = true end
				win.dDim = true
			end
			if win.sort and SUI.Mod(M.tickN, 2) == 0 and not SUI.InCombat() then sortTick(win) end
		end
	end
	M.dInfo = false
end

local EVENTS = { "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
	"BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED", "UNIT_INVENTORY_CHANGED" }

function M.OnEvent(ev, a1)
	if ev == "UNIT_INVENTORY_CHANGED" then
		if a1 == "player" then M.NoteWorn() end
		return
	end
	local bag = M.wins.bag
	local bank = M.wins.bank
	if M.bankOpen and (ev == "PLAYERBANKSLOTS_CHANGED" or ev == "PLAYERBANKBAGSLOTS_CHANGED"
		or (ev == "BAG_UPDATE" and a1 and (a1 == -1 or a1 > (NUM_BAG_SLOTS or 4)))) then
		M.bankDirty = true
	end
	if bank and M.bankOpen and (ev == "PLAYERBANKBAGSLOTS_CHANGED" or ev == "BAG_UPDATE" or ev == "ITEM_LOCK_CHANGED" or ev == "BANKFRAME_OPENED") then
		M.PaintBankBags(bank)
	end
	if ev == "BAG_UPDATE" then
		if bag and a1 then bag.dBags[a1] = true end
		if bank and a1 then bank.dBags[a1] = true end
	elseif ev == "ITEM_LOCK_CHANGED" then
		if bag then bag.dLock = true end
		if bank then bank.dLock = true end
	elseif ev == "BAG_UPDATE_COOLDOWN" then
		if bag then bag.dCd = true end
		if bank then bank.dCd = true end
	elseif ev == "PLAYERBANKSLOTS_CHANGED" or ev == "PLAYERBANKBAGSLOTS_CHANGED" then
		if bank then
			bank.dBags[-1] = true
			for i = 1, (NUM_BANKBAGSLOTS or 6) do bank.dBags[(NUM_BAG_SLOTS or 4) + i] = true end
			if ev == "PLAYERBANKBAGSLOTS_CHANGED" then bank.dLayout = true end
		end
	elseif ev == "PLAYER_MONEY" then
		if bag then bag.dDim = true end
	elseif ev == "BANKFRAME_OPENED" then
		M.bankOpen, M.bankDirty = true, true
		M.MarkSeen("bank")
		if cfg.bankwin then
			M.HideBlizzBank()
			M.Open("bank")
			M.Open("bag")
		end
		M.UpdateDepositBtn()
	elseif ev == "BANKFRAME_CLOSED" then
		M.bankOpen, M.bankDirty = false, false
		M.StopDeposit(true)
		M.Close("bank")
		M.ShowBlizzBank()
		M.UpdateDepositBtn()
		M.Snapshot("bags")
	elseif ev == "PLAYER_REGEN_ENABLED" then
		if M.snapLate then
			M.snapLate = false
			M.Snapshot("bags")
		end
	end
end

function M.OnKey(key, value)
	if not M.on then return end
	M.ReadConfig()
	for i = 1, getn(M.order) do
		local win = M.wins[M.order[i]]
		if win then
			win.dLayout = true
			win.dAll = true
			if win.vbtn then
				if cfg.remember then
					win.vbtn:Show()
				else
					win.vbtn:Hide()
					M.SetView(win, nil, true)
				end
			end
			if win.offline then
				M.SortViews(win.vdata)
				win.vDirty = true
			end
			if win.edit then
				if cfg.search then
					win.edit:Show()
				else
					win.edit:Hide()
					if win.query ~= "" then          -- recherche coupee : on retire aussi son effet (objets attenues)
						win.query = ""
						win.edit:SetText("")
					end
				end
				if cfg.filters then
					win.fbtn:Show()
				else
					win.fbtn:Hide()
					if win.filter ~= "all" then
						win.filter = "all"
						T.SetButtonText(win.fbtn, L("choice.bags.filter.all"))
					end
				end
				win.dDim = true
			end
			for k = 1, win.n do win.order[k].bq = nil end
			if win.frame:IsShown() then M.Tick() end
		end
	end
	M.UpdateDepositBtn()
end

function M.OnStyle()
	for i = 1, getn(M.order) do
		local win = M.wins[M.order[i]]
		if win then
			win.dAll = true
			if win.offline then win.vDirty = true end
			for bag, h in pairs(win.holder) do
				for slot = 1, getn(h.btn) do
					if h.btn[slot] then
						h.btn[slot].bq = nil
						paintHighlight(h.btn[slot])
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	M.ReadConfig()
	M.Takeover()
	M.WrapBankUpdate()
	for i = 1, getn(EVENTS) do SUI.On(EVENTS[i], M.OnEvent) end
	M.task = SUI.Every(TICK, M.Tick, "bags.tick", true)
	M.bankOpen, M.bankDirty, M.dep = false, false, nil
	M.snapTask = SUI.After(5, function()
		M.NoteWorn()
		M.Snapshot("bags")
		if type(M.CacheRoot().prefs.known) ~= "table" then M.MarkSeen("bag") end     -- premiere fois : tout ce que tu as deja n'est pas du butin
	end, "bags.snap0")
	if not M.watching then
		M.watching = true
		C.Watch("bags.", M.OnKey)
		T.OnAccent(M.OnStyle)
	end
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Cancel(M.snapTask)
	M.snapTask = nil
	M.bankOpen, M.bankDirty, M.dep = false, false, nil
	for i = 1, getn(EVENTS) do SUI.Off(EVENTS[i], M.OnEvent) end
	M.Release()
	M.UnwrapBankUpdate()
	M.ShowBlizzBank()
	for i = 1, getn(M.order) do
		local win = M.wins[M.order[i]]
		if win then win.frame:Hide() end
	end
	M.DetachBagSlots(M.wins.bag)
end

-- ---------------------------------------------------------------- commande /sui bags
function M.Command(rest)
	local _, _, sub, arg = string.find(rest or "", "^%s*(%S*)%s*(.*)$")
	sub = string.lower(sub or "")
	if not M.on then return end
	if sub == "" then
		M.Toggle("bag")
	elseif sub == "sort" then
		M.Open("bag")
		M.StartSort(M.wins.bag)
	elseif sub == "find" then
		M.Open("bag")
		local win = M.wins.bag
		if win then
			win.edit:SetText(arg or "")
			win.query = string.lower(arg or "")
			win.dDim = true
		end
	elseif sub == "bank" then
		M.Toggle("bank")
	elseif sub == "reset" then
		if SUI.InCombat() then
			SUI.Print(L("msg.bags.combat"))
			SUI.WhenSafe(M.ResetPos)
		else
			M.ResetPos()
			SUI.Print(L("msg.bags.reset"))
		end
	else
		SUI.Print(L("msg.bags.usage"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("bags", 21)

local OPTS = {
	{ key = "bags.columns", type = "number", min = 6, max = 20, step = 1, default = 10, simple = true },
	{ key = "bags.size", type = "number", min = 24, max = 44, step = 2, default = 32, simple = true },
	{ key = "bags.spacing", type = "number", min = 0, max = 8, step = 1, default = 2 },
	{ key = "bags.layout", type = "choice", choices = { "grid", "categories" }, default = "grid", simple = true },
	{ key = "bags.quality", type = "bool", default = true, simple = true },
	{ key = "bags.borderlimit", type = "number", min = 0, max = 4, step = 1, default = 2 },
	{ key = "bags.counts", type = "bool", default = true },
	{ key = "bags.sort", type = "choice", choices = { "quality", "type", "name" }, default = "quality", simple = true },
	{ key = "bags.junklast", type = "bool", default = true },
	{ key = "bags.sortopen", type = "bool", default = false },
	{ key = "bags.value", type = "bool", default = true, simple = true },
	{ key = "bags.keyring", type = "bool", default = false },
	{ key = "bags.bankwin", type = "bool", default = true },
	{ key = "bags.search", type = "bool", default = true },
	{ key = "bags.filters", type = "bool", default = true },
	{ key = "bags.remember", type = "bool", default = true, simple = true },
	{ key = "bags.depositall", type = "bool", default = false },
	{ key = "bags.hideslots", type = "bool", default = false, simple = true },
	{ key = "bags.hidebankslots", type = "bool", default = false, simple = true },
	{ key = "bags.newitems", type = "bool", default = true, simple = true },
	{ key = "bags.setcat", type = "bool", default = true, simple = true },
	{ key = "bags.minecat", type = "bool", default = true, simple = true },
}
local options = {}
for i = 1, getn(OPTS) do
	local o = OPTS[i]
	o.cat = "bags"
	o.label = "opt." .. o.key
	o.tip = "tip." .. o.key
	o.order = i * 10
	options[i] = o
end

SUI.RegisterModule("bags", {
	default = false,         -- mise au point : rien n'a ete verifie en jeu ; l'utilisateur l'active (ou /sui migrate take bags)
	cost = "medium",
	options = options,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
	shutdown = function() M.Snapshot("bags", true) end,      -- deconnexion : dernier instantane des sacs du personnage
})

-- Remplace le module "bags" de pfUI : ShikiUI attend tant que pfUI le fait tourner (voir Migrate.lua).
if SUI.Migrate and SUI.Migrate.MAP then SUI.Migrate.MAP.bags = { "bags" } end

-- Mode Raid : pas de tri automatique a l'ouverture, pas de ligne de valeur (l'utilisateur peut les rallumer).
SUI.Config.AddPreset("raid", "*", { ["bags.sortopen"] = false, ["bags.value"] = false })

SUI.RegisterCommand("bags", M.Command, "help.bags")
