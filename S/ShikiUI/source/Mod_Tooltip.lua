-- ShikiUI Tooltip : infobulles au style choisi, position (defaut / curseur), couleurs de classe et de rarete, cible de la cible, ID de
-- PNJ, ID et niveau d'objet, texte de vie, masquage en combat (v0.3, module "tooltip").
-- Principe (relu dans le pfUI installe, MIT, jamais execute par ce projet) : une frame enfant de GameTooltip dont l'OnShow decore
-- l'infobulle ; les methodes GameTooltip:Set<...>Item sont enrobees (une seule fois, le module coupe les laisse inertes) pour retenir
-- le lien de l'objet ; GameTooltip_SetDefaultAnchor est enrobee pour la position au curseur ; l'unite survolee est retrouvee comme
-- dans pfUI : unite dont le nom egale la 1re ligne de l'infobulle.
-- PRIX MARCHAND (tooltip.vendor) : prix de vente de l'objet (x la pile quand elle est connue : sac, butin, echange) lu dans la valeur
-- memorisee par Mod_Bags (SUI.Bags.INF.price), sinon C_Item.GetItemSellPriceByID (ClassicAPI), sinon le 11e retour de GetItemInfo
-- (Turtle WoW). Rien n'est ajoute si aucune source ne donne de prix, ni chez un marchand pour un objet du sac (le jeu l'affiche).
-- POSSEDE (tooltip.owned) : "Possede : X sacs / Y banque / Z autres personnages". Source : ShikiUIDB.global.bagcache, ecrit par
-- Mod_Bags (module des sacs actif et reglage bags.remember) : chars["Nom-Royaume"] = { t, money, class, bags = {entree...}, bank = {...} },
-- entree = "ref~nombre~qualite~categorie~icone~type~sous-type~nom" (ref = "id:ench:suffixe:unique"). Les sacs du personnage courant sont
-- comptes en direct, sa banque et les autres personnages viennent de l'instantane (index reconstruit quand bagcache.rev change).
-- Cout : aucun OnUpdate, une minuterie partagee a 0,5 s qui ne fait rien tant qu'aucune infobulle d'unite n'est affichee, aucune
-- frame creee en combat.
-- NON VERIFIE en jeu : OnShow d'une frame enfant a chaque affichage, GameTooltip_SetDefaultAnchor(GameTooltip, UIParent) pour le survol
-- du monde, GetItemInfo(lien) 4e retour = niveau d'objet (releve dans ItemDBScanner / DisplayIDFinder de l'utilisateur, serveur Turtle),
-- GetItemLevel (Nampower >= 2.14, releve dans SuperCleveRoidMacros), format du GUID de creature 0xF130 + entree sur 6 chiffres
-- hexadecimaux (releve dans AutoMarker). Champs de statistiques d'objet de Nampower : non utilises (noms non verifies).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Tooltip = M

local getn = table.getn
local strfind, strsub, strformat = string.find, string.sub, string.format
local floor = math.floor
local SPLIT = "^(%-?%d+)[^~]*~(%d+)~"

local TICK = 0.5

M.on = false
M.active = false
M.link = nil          -- lien de l'objet de l'infobulle courante
M.src = nil           -- methode GameTooltip qui a donne l'objet (SetBagItem...)
M.count = nil         -- taille de la pile survolee quand elle est connue
M.hint = nil          -- unite donnee par GameTooltip:SetUnit
M.world = false       -- infobulle ouverte par le survol du monde
M.decorated = false
M.unit = nil
M.borderSet = false
M.hooks = 0
M.cfg = { style = true, anchor = "default", scale = 1, bordercolor = true, classcolor = true, target = true, unitid = false, questmob = true,
	itemid = false, itemlevel = true, hpvalue = true, hpbar = true, combathide = false, vendor = true, owned = true }
M.units = { "mouseover", "target", "player", "pet", "party1", "party2", "party3", "party4" }
M.tgt = { mouseover = "mouseovertarget", target = "targettarget", player = "playertarget", pet = "pettarget",
	party1 = "party1target", party2 = "party2target", party3 = "party3target", party4 = "party4target" }
M.getters = { SetBagItem = "GetContainerItemLink", SetInventoryItem = "GetInventoryItemLink", SetLootItem = "GetLootSlotLink",
	SetLootRollItem = "GetLootRollItemLink", SetMerchantItem = "GetMerchantItemLink", SetQuestItem = "GetQuestItemLink",
	SetQuestLogItem = "GetQuestLogItemLink", SetCraftItem = "GetCraftReagentItemLink", SetCraftSpell = "GetCraftItemLink",
	SetAuctionItem = "GetAuctionItemLink", SetTradePlayerItem = "GetTradePlayerItemLink", SetTradeTargetItem = "GetTradeTargetItemLink" }
M.setters = { "SetHyperlink", "SetBagItem", "SetInventoryItem", "SetLootItem", "SetLootRollItem", "SetMerchantItem", "SetQuestItem",
	"SetQuestLogItem", "SetCraftItem", "SetCraftSpell", "SetTradeSkillItem", "SetAuctionItem", "SetTradePlayerItem", "SetTradeTargetItem" }

function M.ReadConfig()
	local cfg = M.cfg
	cfg.style = C.Get("tooltip.style")
	cfg.anchor = C.Get("tooltip.anchor")
	cfg.scale = C.Get("tooltip.scale")
	cfg.bordercolor = C.Get("tooltip.bordercolor")
	cfg.classcolor = C.Get("tooltip.classcolor")
	cfg.target = C.Get("tooltip.target")
	cfg.unitid = C.Get("tooltip.unitid")
	cfg.questmob = C.Get("tooltip.questmob")
	cfg.itemid = C.Get("tooltip.itemid")
	cfg.itemlevel = C.Get("tooltip.itemlevel")
	if SUI.TooltipCompare then SUI.TooltipCompare.Apply() end
	cfg.hpvalue = C.Get("tooltip.hpvalue")
	cfg.hpbar = C.Get("tooltip.hpbar")
	cfg.combathide = C.Get("tooltip.combathide")
	cfg.vendor = C.Get("tooltip.vendor")
	cfg.owned = C.Get("tooltip.owned")
end

-- ---------------------------------------------------------------- outils
local function abbrev(n)
	if n >= 1000000 then return strformat("%.1fm", n / 1000000) end
	if n >= 10000 then return strformat("%.0fk", n / 1000) end
	if n >= 1000 then return strformat("%.1fk", n / 1000) end
	return strformat("%d", floor(n))
end
M.Abbrev = abbrev

-- En 1.12 la vie des unites hostiles est un POURCENTAGE (maximum 100) : on n'affiche alors que le pourcentage.
function M.HpString(hp, max)
	if not max or max <= 0 then return "" end
	local pct = floor(hp / max * 100 + 0.5)
	if max == 100 then return pct .. "%" end
	return abbrev(hp) .. " / " .. abbrev(max) .. " (" .. pct .. "%)"
end

-- Jeton de classe -> couleur du jeu (donnee du jeu, pas du style)
local function classColor(unit)
	if not UnitIsPlayer(unit) then return nil end
	local _, class = UnitClass(unit)
	local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if col then return col.r, col.g, col.b end    -- style:ok couleur de classe (donnee de jeu)
	return nil
end

local function reactionColor(unit)
	local reaction = UnitReaction(unit, "player")
	local tbl = getglobal("UnitReactionColor")
	local col = reaction and tbl and tbl[reaction]
	if col then return col.r, col.g, col.b end    -- style:ok couleur de reaction (donnee de jeu)
	return nil
end

function M.UnitColor(unit)
	local r, g, b = classColor(unit)
	if r then return r, g, b end
	return reactionColor(unit)
end

-- NPC : entree de creature lue dans le GUID SuperWoW (0xF130 + 6 chiffres hexadecimaux d'entree)
function M.NpcId(unit)
	local _, guid = UnitExists(unit)
	if type(guid) ~= "string" then return nil end
	if strsub(guid, 1, 6) ~= "0xF130" then return nil end
	return tonumber(strsub(guid, 7, 12), 16)
end

function M.ItemId(link)
	if type(link) ~= "string" then return nil end
	local _, _, id = strfind(link, "item:(%d+)")
	return id and tonumber(id) or nil
end

function M.ItemLevel(id, link)
	local fn = getglobal("GetItemLevel")
	if fn then
		local ok, v = pcall(fn, id)
		if ok and type(v) == "number" and v > 0 then return v end
	end
	local _, _, _, lv = GetItemInfo(link)
	if type(lv) == "number" and lv > 0 then return lv end
	return nil
end

-- le jeu affiche-t-il deja "Item Level N" dans l'infobulle ?
function M.HasLevelLine()
	for i = 2, GameTooltip:NumLines() do
		local fs = getglobal("GameTooltipTextLeft" .. i)
		local s = fs and fs:GetText()
		if s and strfind(s, "^Item Level") then return true end
	end
	return false
end

-- ---------------------------------------------------------------- prix marchand et possession
local function coinText(c)
	c = floor(c or 0)
	local g, s, k = floor(c / 10000), floor(SUI.Mod(c, 10000) / 100), SUI.Mod(c, 100)
	local out = ""
	if g > 0 then out = L("msg.tooltip.coin.g", g) end
	if s > 0 or (g > 0 and k > 0) then out = out .. (out ~= "" and " " or "") .. L("msg.tooltip.coin.s", s) end
	if k > 0 or out == "" then out = out .. (out ~= "" and " " or "") .. L("msg.tooltip.coin.c", k) end
	return out
end
M.CoinText = coinText

-- Taille de la pile survolee (nil si inconnue).
function M.Count(name, a, b)
	local fname, idx = nil, 2
	if name == "SetBagItem" then fname, idx = "GetContainerItemInfo", 2
	elseif name == "SetLootItem" then fname, idx = "GetLootSlotInfo", 3
	elseif name == "SetTradePlayerItem" then fname, idx = "GetTradePlayerItemInfo", 3
	elseif name == "SetTradeTargetItem" then fname, idx = "GetTradeTargetItemInfo", 3 end
	local fn = fname and getglobal(fname)
	if not fn then return nil end
	local ok, r1, r2, r3 = pcall(fn, a, b)
	if not ok then return nil end
	local v = r2
	if idx == 3 then v = r3 end
	if type(v) == "number" and v > 0 then return v end
	return nil
end

-- Prix de vente a l'unite : valeur memorisee par les sacs, ClassicAPI, puis 11e retour de GetItemInfo ; nil si inconnu ou nul.
function M.SellPrice(id, link)
	local B = SUI.Bags
	local p = B and B.INF and link and B.INF.price[link]
	if type(p) == "number" and p > 0 then return p end
	local ci = getglobal("C_Item")
	if ci and ci.GetItemSellPriceByID then
		local ok, v = pcall(ci.GetItemSellPriceByID, id)
		if ok and type(v) == "number" then
			if v > 0 then return v end
		end
	end
	local _, _, _, _, _, _, _, _, _, _, v = GetItemInfo(id)
	if type(v) == "number" and v > 0 then return v end
	return nil
end

function M.AddVendor(id, link)
	local mf = getglobal("MerchantFrame")
	if M.src == "SetBagItem" and mf and mf.IsShown and mf:IsShown() then return false end   -- le jeu affiche deja le prix de revente
	if M.src == "SetMerchantItem" then return false end
	local p = M.SellPrice(id, link)
	if not p then return false end
	local n = M.count
	local text
	if n and n > 1 then
		text = L("msg.tooltip.vendor.stack", coinText(p), n, coinText(p * n))
	else
		text = L("msg.tooltip.vendor", coinText(p))
	end
	GameTooltip:AddLine(text, T.c.text[1], T.c.text[2], T.c.text[3])
	return true
end

-- Objets des sacs du personnage courant (comptes en direct) pour un numero d'objet.
function M.CountBags(id)
	local gi, gl, gn = getglobal("GetContainerItemInfo"), getglobal("GetContainerItemLink"), getglobal("GetContainerNumSlots")
	if not (gi and gl and gn) then return 0 end
	local total = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local size = gn(bag) or 0
		for slot = 1, size do
			local link = gl(bag, slot)
			if link and M.ItemId(link) == id then
				local tex, c = gi(bag, slot)
				if tex then total = total + (c or 1) end
			end
		end
	end
	return total
end

function M.CharKey()
	local name = UnitName("player")
	if not name or name == "" then return nil end
	return name .. "-" .. (GetRealmName() or "?")
end

local function addList(list, idx, who, mine)
	if type(list) ~= "table" then return end
	for i = 1, getn(list) do
		local s = list[i]
		if type(s) == "string" then
			local _, _, id, cnt = strfind(s, SPLIT)
			if id then
				id, cnt = tonumber(id), tonumber(cnt) or 1
				local e = idx[id]
				if not e then
					e = { mine = 0, others = 0, who = {} }
					idx[id] = e
				end
				if mine then
					e.mine = e.mine + cnt
				else
					e.others = e.others + cnt
					e.who[who] = (e.who[who] or 0) + cnt
				end
			end
		end
	end
end

-- Index numero d'objet -> { mine (banque du personnage courant), others, who[nom] }, reconstruit quand le cache change.
function M.Index()
	local root = C.GetGlobal("bagcache")
	if type(root) ~= "table" or type(root.chars) ~= "table" then
		M.idx, M.idxRev = nil, nil
		return nil
	end
	local me = M.CharKey()
	local rev = (root.rev or 0) .. "|" .. (me or "")
	if M.idx and M.idxRev == rev then return M.idx end
	local idx = {}
	for key, rec in pairs(root.chars) do
		if type(rec) == "table" then
			if key == me then
				addList(rec.bank, idx, key, true)
			else
				local nm = rec.name or key
				addList(rec.bags, idx, nm, false)
				addList(rec.bank, idx, nm, false)
			end
		end
	end
	M.idx, M.idxRev = idx, rev
	return idx
end

function M.AddOwned(id)
	local bags = M.CountBags(id)
	local idx = M.Index()
	local e = idx and idx[id]
	local bank = e and e.mine or 0
	local others = e and e.others or 0
	if bags + bank + others <= 0 then return false end
	local parts = ""
	if bags > 0 then parts = L("msg.tooltip.owned.bags", bags) end
	if bank > 0 then parts = parts .. (parts ~= "" and " / " or "") .. L("msg.tooltip.owned.bank", bank) end
	if others > 0 then parts = parts .. (parts ~= "" and " / " or "") .. L("msg.tooltip.owned.others", others) end
	GameTooltip:AddLine(L("msg.tooltip.owned", parts), T.c.text[1], T.c.text[2], T.c.text[3])
	if e and others > 0 then
		local names, n = "", 0
		for who, c in pairs(e.who) do
			n = n + 1
			if n <= 4 then names = names .. (names ~= "" and ", " or "") .. who .. " " .. c end
		end
		if n > 4 then names = names .. ", ..." end
		GameTooltip:AddLine(names, T.c.dim[1], T.c.dim[2], T.c.dim[3])
	end
	return true
end

-- ---------------------------------------------------------------- unite survolee
function M.FindUnit()
	local fs = getglobal("GameTooltipTextLeft1")
	local name = fs and fs:GetText()
	if not name then return nil end
	if M.hint and UnitExists(M.hint) and UnitName(M.hint) == name then return M.hint end
	for i = 1, getn(M.units) do
		local u = M.units[i]
		if UnitExists(u) and (UnitName(u) == name or UnitPVPName(u) == name) then return u end
	end
	return nil
end

-- Fond et bordure d'origine du client (valeurs du gabarit GameTooltip, GetBackdrop et TOOLTIP_DEFAULT_* si le client les donne).
local ORIG_BD = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",   -- style:ok chemins du jeu
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } }
local function defColor(name, r, g, b)
	local c = getglobal(name)
	if type(c) == "table" and c.r then return c.r, c.g, c.b end
	return r, g, b
end

function M.NeutralBorder()
	if M.on and M.cfg.style then
		local c = T.c.border
		return c[1], c[2], c[3], c[4]
	end
	local r, g, b = defColor("TOOLTIP_DEFAULT_COLOR", 1, 1, 1)    -- style:ok couleur d'origine du client
	return r, g, b, 1
end

function M.SetBorder(r, g, b)
	if r then
		GameTooltip:SetBackdropBorderColor(r, g, b, 1)
		M.borderSet = true
	elseif M.borderSet then
		local nr, ng, nb, na = M.NeutralBorder()
		GameTooltip:SetBackdropBorderColor(nr, ng, nb, na)
		M.borderSet = false
	end
end

-- Fond de l'infobulle : style ShikiUI quand le module est actif et "style" coche, sinon fond d'origine du client (reversible a chaud).
function M.StyleBackdrop()
	local bd = GameTooltip.suiBd
	if M.on and M.cfg.style then
		if bd then bd.k = "bd" end
		T.Backdrop(GameTooltip, T.c.panel, T.c.border)
		M.plain = false
	elseif not M.plain then
		M.plain = true
		if bd then bd.k = "off" end         -- le repeint du theme ne doit plus toucher a cette infobulle
		GameTooltip:SetBackdrop(ORIG_BD)
		local r, g, b = defColor("TOOLTIP_DEFAULT_BACKGROUND_COLOR", 0.09, 0.09, 0.19)   -- style:ok couleur d'origine du client
		GameTooltip:SetBackdropColor(r, g, b, 1)
		local br, bg, bb = defColor("TOOLTIP_DEFAULT_COLOR", 1, 1, 1)                    -- style:ok couleur d'origine du client
		GameTooltip:SetBackdropBorderColor(br, bg, bb, 1)
		M.borderSet = false
	end
end

function M.DecorateUnit(unit)
	local cfg = M.cfg
	M.unit = unit
	local r, g, b = M.UnitColor(unit)
	if r and cfg.classcolor then
		GameTooltipTextLeft1:SetTextColor(r, g, b, 1)
	end
	if r and cfg.bordercolor then M.SetBorder(r, g, b) else M.SetBorder(nil) end
	if cfg.target then
		local tu = M.tgt[unit]
		if tu and UnitExists(tu) then
			local tr, tg, tb = M.UnitColor(tu)
			if not tr then tr, tg, tb = T.c.text[1], T.c.text[2], T.c.text[3] end
			GameTooltip:AddLine(L("msg.tooltip.target", UnitName(tu) or "?"), tr, tg, tb)
		end
	end
	if cfg.unitid and not UnitIsPlayer(unit) then
		local id = M.NpcId(unit)
		if id then GameTooltip:AddLine(L("msg.tooltip.npcid", id), T.c.dim[1], T.c.dim[2], T.c.dim[3]) end
	end
	if cfg.questmob and not UnitIsPlayer(unit) and SUI.QuestTrack and SUI.QuestTrack.UnitObjective then
		local q = SUI.QuestTrack.UnitObjective(UnitName(unit))
		if q then
			GameTooltip:AddLine(L("msg.tooltip.questmob", q.title, q.text), T.c.good[1], T.c.good[2], T.c.good[3])
		end
	end
	M.UpdateHp()
end

function M.DecorateItem(link)
	local cfg = M.cfg
	local id = M.ItemId(link)
	if not id then M.SetBorder(nil) return end
	if cfg.bordercolor then
		local _, _, q = GetItemInfo(link)
		local tbl = getglobal("ITEM_QUALITY_COLORS")
		local col = type(q) == "number" and tbl and tbl[q]
		if col then M.SetBorder(col.r, col.g, col.b) else M.SetBorder(nil) end    -- style:ok couleur de qualite (donnee de jeu)
	else
		M.SetBorder(nil)
	end
	if cfg.itemlevel and not M.HasLevelLine() then
		local lv = M.ItemLevel(id, link)
		if lv then GameTooltip:AddLine(L("msg.tooltip.ilvl", lv), T.c.text[1], T.c.text[2], T.c.text[3]) end
	end
	if cfg.itemid then GameTooltip:AddLine(L("msg.tooltip.itemid", id), T.c.dim[1], T.c.dim[2], T.c.dim[3]) end
	if cfg.combathide and SUI.InCombat() then return end      -- "masquer en combat" : ni prix ni possession pendant un combat
	if cfg.vendor then M.AddVendor(id, link) end
	if SUI.Market and SUI.Market.AddTip then SUI.Market.AddTip(link) end
	if cfg.owned then M.AddOwned(id) end
end

-- ---------------------------------------------------------------- texte de vie sur la barre
function M.UpdateHp()
	if not M.hpText then return end
	local txt = ""
	local u = M.unit
	if M.on and M.cfg.hpvalue and u and GameTooltip:IsShown() and UnitExists(u) then
		txt = M.HpString(UnitHealth(u), UnitHealthMax(u))
	end
	if txt ~= M.lastHp then
		M.lastHp = txt
		M.hpText:SetText(txt)
	end
	local bar = getglobal("GameTooltipStatusBar")
	if bar then bar:SetAlpha((not M.on or M.cfg.hpbar) and 1 or 0) end
end

-- ---------------------------------------------------------------- OnShow / OnHide de la frame enfant
function M.OnShow()
	if not M.on or M.busy then return end
	M.busy = true
	local cfg = M.cfg
	local unit = M.FindUnit()
	if unit and M.world and cfg.combathide and SUI.InCombat() then
		M.busy = false
		GameTooltip:Hide()
		return
	end
	if not M.decorated then
		M.decorated = true
		if unit then
			M.DecorateUnit(unit)
		elseif M.link then
			M.unit = nil
			M.DecorateItem(M.link)
		else
			M.unit = nil
			M.SetBorder(nil)
		end
		if GameTooltip:IsShown() then GameTooltip:Show() end        -- remesure apres les lignes ajoutees
	end
	M.UpdateHp()
	M.busy = false
end

function M.OnHide()
	M.link = nil
	M.src = nil
	M.count = nil
	M.hint = nil
	M.unit = nil
	M.decorated = false
	M.world = false
	M.UpdateHp()
end

function M.Tick()
	if M.unit and GameTooltip:IsShown() then M.UpdateHp() end
end

-- ---------------------------------------------------------------- enrobages (poses une fois, inertes quand le module est coupe)
local function field(obj, key)
	return obj[key]
end

function M.Link(name, a, b)
	if name == "SetHyperlink" then
		if type(a) == "string" and strfind(a, "item:", 1, true) then return a end
		return nil
	end
	local fname = M.getters[name]
	if name == "SetTradeSkillItem" then fname = b and "GetTradeSkillReagentItemLink" or "GetTradeSkillItemLink" end
	local fn = fname and getglobal(fname)
	if not fn then return nil end
	local ok, link = pcall(fn, a, b)
	if ok and type(link) == "string" then return link end
	return nil
end

function M.HookSetter(name)
	local ok, orig = pcall(field, GameTooltip, name)
	if not ok or type(orig) ~= "function" then return end
	GameTooltip[name] = function(self, a, b)
		if M.on then
			M.link = M.Link(name, a, b)
			if SUI.TooltipCompare and SUI.TooltipCompare.Wake then SUI.TooltipCompare.Wake() end
			M.src = name
			M.count = M.Count(name, a, b)
		end
		return orig(self, a, b)
	end
	M.hooks = M.hooks + 1
end

function M.HookUnit()
	local ok, orig = pcall(field, GameTooltip, "SetUnit")
	if not ok or type(orig) ~= "function" then return end
	GameTooltip.SetUnit = function(self, unit)
		if M.on then M.hint = unit end
		return orig(self, unit)
	end
	M.hooks = M.hooks + 1
end

function M.OnDefaultAnchor(tooltip, parent)
	if M.on and M.cfg.anchor == "cursor" then
		tooltip:SetOwner(parent, "ANCHOR_CURSOR")
	else
		M.origAnchor(tooltip, parent)
	end
	-- apres SetOwner (qui peut cacher l'infobulle et donc remettre le drapeau a zero)
	if M.on then M.world = (parent == UIParent) end
end

function M.HookAnchor()
	if M.origAnchor then return end
	local orig = getglobal("GameTooltip_SetDefaultAnchor")
	if type(orig) ~= "function" then return end
	M.origAnchor = orig
	setglobal("GameTooltip_SetDefaultAnchor", M.OnDefaultAnchor)
end

-- ---------------------------------------------------------------- application des reglages
function M.ApplyOptions()
	if not M.built then return end
	local cfg = M.cfg
	if M.on then
		GameTooltip:SetScale(cfg.scale)
		M.watch:Show()
		M.StyleBackdrop()
		M.SetBorder(nil)
	else
		GameTooltip:SetScale(1)
		M.StyleBackdrop()
		M.SetBorder(nil)
		M.lastHp = nil
		M.hpText:SetText("")
		local bar = getglobal("GameTooltipStatusBar")
		if bar then bar:SetAlpha(1) end
	end
	M.decorated = false
	M.UpdateHp()
end

-- ---------------------------------------------------------------- construction (une seule fois, hors combat)
function M.Build()
	if M.built then return end
	if not (getglobal("GameTooltip") and getglobal("GameTooltipTextLeft1")) then return end   -- pas d'interface Blizzard (hors jeu)
	local watch = CreateFrame("Frame", "ShikiUI_TooltipWatch", GameTooltip)
	watch:SetScript("OnShow", M.OnShow)
	watch:SetScript("OnHide", M.OnHide)
	M.watch = watch
	local bar = getglobal("GameTooltipStatusBar")
	M.hpText = T.Text(bar or GameTooltip, 10, T.c.text, "CENTER", true)
	M.hpText:SetPoint("CENTER", bar or GameTooltip, "CENTER", 0, 0)
	for i = 1, getn(M.setters) do M.HookSetter(M.setters[i]) end
	M.HookUnit()
	M.HookAnchor()
	M.built = true
	M.ReadConfig()
	if not M.watching then
		M.watching = true
		C.Watch("tooltip.", M.OnKey)
	end
	if M.on then M.Activate() end
	M.ApplyOptions()
end

function M.OnKey(key, value)
	M.ReadConfig()
	M.ApplyOptions()
end

function M.Activate()
	if M.active or not M.built then return end
	M.active = true
	M.task = SUI.Every(TICK, M.Tick, "tooltip.tick", true)
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	SUI.WhenSafe(M.Build)
	M.Activate()
	M.ApplyOptions()
end

function M.Disable()
	M.on = false
	M.Deactivate()
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("tooltip", 28)

local function opt(key, typ, order, def, extra)
	local o = { key = "tooltip." .. key, type = typ, cat = "tooltip", label = "opt.tooltip." .. key, tip = "tip.tooltip." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("tooltip", {
	default = true,
	cost = "light",
	options = {
		opt("style", "bool", 10, true, { simple = true }),
		opt("anchor", "choice", 20, "default", { choices = { "default", "cursor" }, simple = true }),
		opt("scale", "number", 25, 1, { min = 0.7, max = 1.5, step = 0.1 }),
		opt("bordercolor", "bool", 30, true, { simple = true }),
		opt("classcolor", "bool", 40, true, { simple = true }),
		opt("target", "bool", 50, true, { simple = true }),
		opt("hpvalue", "bool", 60, true),
		opt("hpbar", "bool", 61, true),
		opt("unitid", "bool", 70, false),
		opt("questmob", "bool", 71, true, { simple = true }),
		opt("itemlevel", "bool", 80, true),
		opt("itemid", "bool", 81, false),
		opt("vendor", "bool", 82, true, { simple = true }),
		opt("owned", "bool", 83, true, { simple = true }),
		opt("combathide", "bool", 90, false),
		opt("compareshift", "bool", 94, true, { simple = true }),
		opt("compare", "bool", 95, true, { simple = true }),
		opt("compareauto", "bool", 96, false),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI releve : le module "tooltip".
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.tooltip then SUI.Migrate.MAP.tooltip = { "tooltip" } end

-- Mode Raid : pas d'infobulle du monde pendant les combats (les cadres d'unites gardent la leur), pas de texte de vie.
SUI.Config.AddPreset("raid", "*", { ["tooltip.combathide"] = true, ["tooltip.hpvalue"] = false })

SUI.RegisterCommand("tooltip", function(rest)
	if not M.built then SUI.Print(L("msg.tooltip.notready")) return end
	SUI.Print(L("msg.tooltip.info", M.hooks, M.cfg.anchor))
end, "help.tooltip")
