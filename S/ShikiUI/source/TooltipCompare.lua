-- ShikiUI TooltipCompare : deux comparaisons quand on survole un equipement.
--  Chaque touche BASCULE l'affichage (une pression = affiche, une autre = masque) au lieu d'etre maintenue.
--  * Maj  (option tooltip.compareshift) : l'objet survole ET l'objet equipe cote a cote (infobulles du jeu, ShikiUI_EqTip1/2),
--    une infobulle par emplacement possible (deux pour les bagues, bijoux et armes a une main).
--  * Ctrl (option tooltip.compare ; tooltip.compareauto = toujours) : un petit cadre colle a l'infobulle liste SEULEMENT les
--    differences calculees (vert = gain, rouge = perte) avec l'equivalence entre pourcentages et caracteristiques : par exemple +1% de
--    critique vaut environ 20 d'agilite.
-- Les statistiques sont lues dans le texte des infobulles (anglais et francais), jamais dans une base de donnees : un texte inconnu
-- est simplement ignore. Cout : un OnUpdate enfant de GameTooltip (il ne tourne que pendant qu'une infobulle est visible) ; les
-- lectures sont mises en cache par lien. Appele par Mod_Tooltip (SUI.TooltipCompare.Show / Hide).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local K = {}
SUI.TooltipCompare = K

local getn, tinsert = table.getn, table.insert
local strfind, strlower, strsub = string.find, string.lower, string.sub
local floor = math.floor

-- ordre d'affichage des statistiques
K.ORDER = { "armor", "str", "agi", "sta", "int", "spi", "ap", "sp", "heal", "mp5", "crit", "hit", "scrit", "shit", "dodge", "parry", "block", "dps" }
K.PCT = { crit = true, hit = true, scrit = true, shit = true, dodge = true, parry = true, block = true }

-- caracteristiques pour 1% (approximation niveau 60, a titre indicatif)
K.AGI_PER_CRIT = { WARRIOR = 20, PALADIN = 20, DRUID = 20, SHAMAN = 20, ROGUE = 29, HUNTER = 53, MAGE = 20, WARLOCK = 20, PRIEST = 20 }
K.INT_PER_SCRIT = 59

-- emplacement(s) d'equipement par type d'objet
K.SLOTS = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
	INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 } }

local function num(s)
	if not s then return nil end
	s = string.gsub(s, ",", ".")
	return tonumber(s)
end

local PRIMARY = { { "^strength", "str" }, { "^force", "str" }, { "^agilit", "agi" }, { "^stamina", "sta" }, { "^endurance", "sta" },
	{ "^intellect", "int" }, { "^intelligence", "int" }, { "^spirit", "spi" }, { "^esprit", "spi" } }
local SCHOOLS = { "fire", "frost", "shadow", "holy", "nature", "arcane", "feu", "givre", "ombre", "sacr", "arcan" }

local function hasAny(s, list)
	local i
	for i = 1, getn(list) do
		if strfind(s, list[i], 1, true) then return true end
	end
	return false
end

-- Lit les lignes d'une infobulle (liste de textes) -> table de statistiques { str = n, crit = 1.0, ... }
function K.Parse(lines)
	local st = {}
	local i
	for i = 1, getn(lines) do
		local raw = lines[i]
		if type(raw) == "string" and raw ~= "" then
			local s = strlower(raw)
			local _, _, v, name = strfind(s, "^%+(%d+) (.+)$")
			local done = false
			if v then
				local p
				for p = 1, getn(PRIMARY) do
					if strfind(name, PRIMARY[p][1]) then
						st[PRIMARY[p][2]] = (st[PRIMARY[p][2]] or 0) + tonumber(v)
						done = true
						break
					end
				end
			end
			if not done then
				local _, _, a = strfind(s, "^(%d+) arm")
				if a then
					st.armor = tonumber(a)
					done = true
				end
			end
			if not done then
				local _, _, d = strfind(s, "%(([%d%.,]+) [^%)]*sec[^%)]*%)")
				if d and (strfind(s, "damage", 1, true) or strfind(s, "par seconde", 1, true)) then
					st.dps = num(d)
					done = true
				end
			end
			if not done and (strfind(s, "^equip") or strfind(s, "^\195\169quip") or strfind(s, "^\195\137quip")) and strfind(s, ":", 1, true) then
				-- ligne "Equip :" / "Equipe :" : on cherche le mot-cle puis le nombre
				local _, _, pct = strfind(s, "([%d%.,]+)%%")
				local _, _, n1 = strfind(s, "(%d+)")
				local spell = strfind(s, "spell", 1, true) or strfind(s, "sort", 1, true)
				if pct and (strfind(s, "critical", 1, true) or strfind(s, "critique", 1, true)) then
					st[spell and "scrit" or "crit"] = (st[spell and "scrit" or "crit"] or 0) + num(pct)
				elseif pct and (strfind(s, "to hit", 1, true) or strfind(s, "toucher", 1, true)) then
					st[spell and "shit" or "hit"] = (st[spell and "shit" or "hit"] or 0) + num(pct)
				elseif pct and (strfind(s, "dodge", 1, true) or strfind(s, "esquiv", 1, true)) then
					st.dodge = (st.dodge or 0) + num(pct)
				elseif pct and (strfind(s, "parry", 1, true) or strfind(s, "parade", 1, true)) then
					st.parry = (st.parry or 0) + num(pct)
				elseif pct and (strfind(s, "block", 1, true) or strfind(s, "bloqu", 1, true)) then
					st.block = (st.block or 0) + num(pct)
				elseif n1 and strfind(s, "5 sec", 1, true) and strfind(s, "mana", 1, true) then
					st.mp5 = (st.mp5 or 0) + tonumber(n1)
				elseif n1 and (strfind(s, "attack power", 1, true) or strfind(s, "puissance d", 1, true))
					and not strfind(s, "ranged", 1, true) and not strfind(s, "distance", 1, true)
					and not strfind(s, "fighting", 1, true) and not strfind(s, "contre", 1, true) then
					st.ap = (st.ap or 0) + tonumber(n1)
				elseif n1 and not hasAny(s, SCHOOLS) and (strfind(s, "healing", 1, true) or strfind(s, "soins", 1, true)) then
					st.heal = (st.heal or 0) + tonumber(n1)
					if strfind(s, "damage", 1, true) or strfind(s, "d.g.ts") then st.sp = (st.sp or 0) + tonumber(n1) end
				elseif n1 and not hasAny(s, SCHOOLS) and (strfind(s, "damage", 1, true) or strfind(s, "d.g.ts"))
					and (strfind(s, "spells", 1, true) or strfind(s, "sorts", 1, true)) then
					st.sp = (st.sp or 0) + tonumber(n1)
				end
			end
		end
	end
	return st
end

-- Differences nouvelle - equipee : liste ordonnee { cle, delta }
function K.Delta(new, old)
	local out = {}
	local i
	for i = 1, getn(K.ORDER) do
		local k = K.ORDER[i]
		local d = (new[k] or 0) - (old[k] or 0)
		if d > 0.049 or d < -0.049 then tinsert(out, { k, d }) end
	end
	return out
end

-- Equivalence indicative : texte entre parentheses ou nil
function K.Equiv(key, delta, class)
	local a = delta < 0 and -delta or delta
	local sign = delta < 0 and "-" or "+"
	if key == "crit" then
		return L("msg.tooltip.cmp.eq.agi", sign, floor(a * (K.AGI_PER_CRIT[class or ""] or 20) + 0.5))
	elseif key == "agi" then
		local per = K.AGI_PER_CRIT[class or ""] or 20
		return L("msg.tooltip.cmp.eq.crit", sign, floor(a / per * 10 + 0.5) / 10)
	elseif key == "scrit" then
		return L("msg.tooltip.cmp.eq.int", sign, floor(a * K.INT_PER_SCRIT + 0.5))
	elseif key == "int" then
		return L("msg.tooltip.cmp.eq.scrit", sign, floor(a / K.INT_PER_SCRIT * 10 + 0.5) / 10)
	end
	return nil
end

-- ---------------------------------------------------------------- lecture des infobulles
local cache = {}

-- GetItemInfo veut "item:id:..." (le lien colore complet ne marche pas) ; l'emplacement est le retour qui commence par INVTYPE_
-- (sa position varie selon le serveur). Renvoie nom, qualite, emplacement, niveau.
function K.Info(link)
	if not link then return nil end
	local _, _, code = strfind(link, "(item:[%-%d:]+)")
	local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = GetItemInfo(code or link)
	if not r1 then return nil end
	local loc
	local list = { r5, r6, r7, r8, r9, r10 }
	local i
	for i = 1, 6 do
		if type(list[i]) == "string" and strfind(list[i], "^INVTYPE_") then loc = list[i] end
	end
	return r1, r3, loc, r4
end

function K.Scanner()
	if K.scan then return K.scan end
	if not CreateFrame then return nil end
	local ok, f = pcall(CreateFrame, "GameTooltip", "ShikiUI_CmpScan", UIParent, "GameTooltipTemplate")
	if not ok or not f then return nil end
	K.scan = f
	return f
end

local function readLines(tip)
	local out = {}
	local n = tonumber(tip:NumLines()) or 0
	local i
	for i = 1, n do
		local fs = getglobal("ShikiUI_CmpScanTextLeft" .. i)
		out[i] = fs and fs:GetText() or ""
	end
	return out
end

function K.StatsOfLink(link)
	if not link then return nil end
	if cache[link] then return cache[link] end
	local tip = K.Scanner()
	if not tip then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:ClearLines()
	-- SetHyperlink veut "item:id:..." (pas le lien colore complet) et doit etre sous pcall (AtlasLoot)
	local _, _, code = strfind(link, "(item:[%-%d:]+)")
	pcall(tip.SetHyperlink, tip, code or link)
	local st = K.Parse(readLines(tip))
	tip:Hide()
	cache[link] = st
	return st
end

function K.StatsOfSlot(slot)
	local tip = K.Scanner()
	if not tip then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:ClearLines()
	tip:SetInventoryItem("player", slot)
	local st = K.Parse(readLines(tip))
	tip:Hide()
	return st
end

-- Emplacement a comparer pour un type d'objet : le plus faible des deux pour les doubles (bagues, bijoux, armes a une main)
function K.PickSlot(equipLoc)
	local list = K.SLOTS[equipLoc or ""]
	if not list then return nil end
	if getn(list) == 1 then return list[1] end
	local best, bestLv
	local i
	for i = 1, getn(list) do
		local link = GetInventoryItemLink("player", list[i])
		if not link then return list[i] end
		local _, _, _, lv = K.Info(link)
		lv = lv or 0
		if not bestLv or lv < bestLv then
			best, bestLv = list[i], lv
		end
	end
	return best
end

-- ---------------------------------------------------------------- cadre
local MAXROWS = 12

function K.Build()
	if K.frame then return K.frame end
	local f = T.Panel(UIParent, 190, 60)
	f:SetFrameStrata("TOOLTIP")
	f:Hide()
	f.title = T.Text(f, 11, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
	f.title:SetWidth(178)
	f.rows = {}
	local i
	for i = 1, MAXROWS do
		local r = T.Text(f, 11, T.c.text, "LEFT")
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(22 + (i - 1) * 13))
		r:SetWidth(178)
		r:Hide()
		f.rows[i] = r
	end
	K.frame = f
	return f
end

local function setColor(fs, c)
	if fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3], 1) end
end

-- Montre la comparaison de l'objet du lien avec l'objet equipe
function K.Show(link)
	if not link or not K.on then return end
	local _, q, equipLoc, lv = K.Info(link)
	local slot = K.PickSlot(equipLoc)
	if not slot then
		K.Hide()
		return
	end
	local cur = GetInventoryItemLink("player", slot)
	if not cur or cur == link then
		K.Hide()
		return
	end
	local key = link .. "|" .. cur
	if K.shownKey == key and K.frame and K.frame:IsShown() then return end
	local new = K.StatsOfLink(link)
	local old = K.StatsOfSlot(slot)
	if not new or not old then return end
	local f = K.Build()
	local cname, cq = K.Info(cur)
	cname = cname or "?"
	if string.len(cname) > 21 then cname = strsub(cname, 1, 20) .. "." end      -- une seule ligne (le titre ne doit pas deborder sur les statistiques)
	f.title:SetText(L("msg.tooltip.cmp.title", cname))
	local qc = getglobal("ITEM_QUALITY_COLORS")
	local col = qc and cq and qc[cq]
	if col then f.title:SetTextColor(col.r, col.g, col.b, 1) else setColor(f.title, T.c.text) end    -- style:ok couleur de qualite (donnee de jeu)
	local _, class = UnitClass("player")
	local d = K.Delta(new, old)
	local n = getn(d)
	if n > MAXROWS then n = MAXROWS end
	local i
	for i = 1, MAXROWS do f.rows[i]:Hide() end
	if n == 0 then
		f.rows[1]:SetText(L("msg.tooltip.cmp.same"))
		setColor(f.rows[1], T.c.dim)
		f.rows[1]:Show()
		n = 1
	else
		for i = 1, n do
			local k, v = d[i][1], d[i][2]
			local txt
			if K.PCT[k] then
				txt = (v > 0 and "+" or "") .. (floor(v * 10 + 0.5) / 10) .. "% " .. L("msg.tooltip.cmp.stat." .. k)
			else
				txt = (v > 0 and "+" or "") .. floor(v * 10 + 0.5) / 10 .. " " .. L("msg.tooltip.cmp.stat." .. k)
			end
			local eq = K.Equiv(k, v, class)
			if eq then txt = txt .. "  " .. eq end
			f.rows[i]:SetText(txt)
			setColor(f.rows[i], v > 0 and T.c.good or T.c.bad)
			f.rows[i]:Show()
		end
	end
	f:SetHeight(26 + n * 13)
	f:ClearAllPoints()
	local gt = GameTooltip
	local right = gt:GetRight() or 0
	if K.shopShown then
		f:SetPoint("TOPLEFT", gt, "BOTTOMLEFT", 0, -2)          -- Maj + Ctrl : les infobulles equipees occupent le cote
	elseif right + 195 > (GetScreenWidth() or 1024) / (UIParent:GetScale() or 1) then
		f:SetPoint("TOPRIGHT", gt, "TOPLEFT", -2, 0)
	else
		f:SetPoint("TOPLEFT", gt, "TOPRIGHT", 2, 0)
	end
	f:Show()
	K.shownKey = key
end

function K.Hide()
	K.shownKey = nil
	if K.frame then K.frame:Hide() end
end

-- ---------------------------------------------------------------- Ctrl : objet(s) equipe(s) a cote de l'objet survole
local SHOPW = 290          -- largeur approximative d'une infobulle d'objet (pour savoir s'il reste de la place a droite)

-- Infobulles PROPRES (pas ShoppingTooltip1/2) : le jeu masque et estompe ses ShoppingTooltip a chaque rafraichissement de l'infobulle
-- survolee (plusieurs fois par seconde), ce qui les fait clignoter. Les notres n'ont pas de proprietaire : seul notre code les masque.
function K.EqTip(i)
	local name = "ShikiUI_EqTip" .. i
	local st = getglobal(name)
	if st then return st end
	if not CreateFrame then return nil end
	local ok, f = pcall(CreateFrame, "GameTooltip", name, UIParent, "GameTooltipTemplate")
	if not ok or not f then return nil end
	f:SetFrameStrata("TOOLTIP")
	f:Hide()
	return f
end

function K.HideEquipped()
	if not K.shopShown then return end
	K.shopShown, K.shopKey = false, nil
	local i
	for i = 1, 2 do
		local st = getglobal("ShikiUI_EqTip" .. i)
		if st then st:Hide() end
	end
end

function K.ShowEquipped(link)
	local gt = GameTooltip
	local st1 = K.EqTip(1)
	if not link or not st1 or not gt then return end
	local _, _, loc = K.Info(link)
	local list = K.SLOTS[loc or ""]
	if not list then
		K.HideEquipped()
		return
	end
	local slots = {}
	local i
	for i = 1, getn(list) do
		local cur = GetInventoryItemLink("player", list[i])
		if cur and cur ~= link then tinsert(slots, list[i]) end
	end
	local n = getn(slots)
	if n == 0 then
		K.HideEquipped()
		return
	end
	local key = link .. "|" .. slots[1] .. "|" .. (slots[2] or 0)
	if K.shopShown and K.shopKey == key and st1:IsShown() then return end
	local right = gt:GetRight() or 0
	local fits = right + SHOPW * n <= (GetScreenWidth() or 1024) / (UIParent:GetScale() or 1)
	local prev = gt
	for i = 1, n do
		local st = K.EqTip(i)
		if st then
			st:SetOwner(UIParent, "ANCHOR_NONE")
			st:ClearAllPoints()
			if fits then
				st:SetPoint("TOPLEFT", prev, "TOPRIGHT", 2, 0)
			else
				st:SetPoint("TOPRIGHT", prev, "TOPLEFT", -2, 0)
			end
			st:SetScale(gt:GetScale() or 1)                       -- meme echelle et meme fond que l'infobulle survolee
			if SUI.Tooltip and SUI.Tooltip.on and SUI.Tooltip.cfg and SUI.Tooltip.cfg.style then T.Backdrop(st, T.c.panel, T.c.border) end
			st:SetInventoryItem("player", slots[i])
			st:AddLine(L("msg.tooltip.equipped"), T.c.dim[1], T.c.dim[2], T.c.dim[3])
			st:Show()
			prev = st
		end
	end
	for i = n + 1, 2 do
		local st = getglobal("ShikiUI_EqTip" .. i)
		if st then st:Hide() end
	end
	K.shopShown, K.shopKey = true, key
end

-- Surveille Ctrl tant que l'infobulle d'un objet est visible (enfant de GameTooltip : ne tourne que si elle est affichee)
-- Le jeu rafraichit l'infobulle plusieurs fois par seconde (Hide puis Show, lien vide un instant) : on ne masque donc qu'apres
-- un court delai d'absence, sinon les cadres clignotent.
local GRACE = 0.3

function K.Watch()
	if K.watch then return end
	local w = CreateFrame("Frame", "ShikiUI_TooltipCmpWatch", UIParent)
	w.t = 0
	K.idleE, K.idleC = 0, 0
	K.tick = function()
		local dt = arg1 or 0
		this.t = this.t + dt
		if this.t < 0.05 then return end
		dt, this.t = this.t, 0
		local link = SUI.Tooltip and SUI.Tooltip.link
		if link and GameTooltip:IsShown() then
			K.last, K.lastAge = link, 0
		else
			K.lastAge = (K.lastAge or 99) + dt
		end
		local cur = K.last
		if K.lastAge > GRACE then
			cur = nil
			K.tgE, K.tgC = false, false      -- le curseur a quitte l'objet : l'affichage bascule repart a zero (sinon il reste coince sur l'objet suivant)
		end
		-- Une pression sur la touche (front montant) bascule l'affichage : maintenir la touche enfoncee fait deriver Windows
		-- (repetition de touche), donc on ne lit pas l'etat maintenu.
		local sd = IsShiftKeyDown() and true or false
		local cd = IsControlKeyDown() and true or false
		if sd and not K.prevS and cur and K.shiftOn then K.tgE = not K.tgE end
		if cd and not K.prevC and cur and K.on then K.tgC = not K.tgC end
		K.prevS, K.prevC = sd, cd
		-- Maj : objet(s) equipe(s)
		if cur and K.shiftOn and K.tgE then
			K.idleE = 0
			K.ShowEquipped(cur)
		else
			K.idleE = K.idleE + dt
			if K.idleE > GRACE then K.HideEquipped() end
		end
		-- Ctrl : statistiques comparees
		if cur and K.on and (K.tgC or K.auto) then
			K.idleC = 0
			K.Show(cur)
		else
			K.idleC = K.idleC + dt
			if K.idleC > GRACE then K.Hide() end
		end
		-- plus rien a surveiller : la minuterie s arrete (elle repart a l affichage d une infobulle d objet, voir K.Wake)
		if not cur and K.lastAge > 1 and K.idleE > GRACE and K.idleC > GRACE then
			this:SetScript("OnUpdate", nil)
			K.running = false
		end
	end
	K.watch = w
end

-- Reveille la surveillance (appele a chaque infobulle d objet) : aucun OnUpdate ne tourne tant qu aucune infobulle n est affichee.
function K.Wake()
	if not (K.on or K.shiftOn) then return end
	K.Watch()
	K.idleE, K.idleC = 0, 0
	if not K.running then
		K.running = true
		K.prevS, K.prevC = IsShiftKeyDown() and true or false, IsControlKeyDown() and true or false   -- sinon une touche relachee pendant l'arret compte comme enfoncee et la 1re pression est perdue
		K.watch:SetScript("OnUpdate", K.tick)
	end
end

function K.Apply()
	K.on = C.Get("tooltip.compare") and true or false
	K.auto = C.Get("tooltip.compareauto") and true or false
	K.shiftOn = C.Get("tooltip.compareshift") and true or false
	if not K.on then K.tgC = false; K.Hide() end
	if not K.shiftOn then K.tgE = false; K.HideEquipped() end
end

-- /sui cmp : diagnostic de la comparaison (objet survole, emplacement, statistiques lues)
SUI.RegisterCommand("cmp", function()
	SUI.After(4, function()
	local link = SUI.Tooltip and SUI.Tooltip.link
	local _, _, el = K.Info(link)
	local slot = K.PickSlot(el)
	local n, o = K.StatsOfLink(link), K.StatsOfSlot(slot or 1)
	local cnt = 0
	if n then for _ in pairs(n) do cnt = cnt + 1 end end
	SUI.Print("cmp link=" .. tostring(link) .. " loc=" .. tostring(el) .. " slot=" .. tostring(slot) .. " new=" .. cnt .. " old=" .. tostring(o ~= nil) .. " on=" .. tostring(K.on))
	K.Show(link)
	SUI.Print("cmp key=" .. tostring(K.shownKey) .. " frame=" .. tostring(K.frame and K.frame:IsShown()))
	end, "cmpdebug")
end)
