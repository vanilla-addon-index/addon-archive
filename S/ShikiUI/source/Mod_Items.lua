-- ShikiUI Items : jeux d'equipement, barre de bijoux et echange automatique par evenement (equivalent configurable d'ItemRack et de
-- TrinketMenu ; reecrit, aucune ligne copiee).
-- Cout declare : MEDIUM. Evenements : BAG_UPDATE et UNIT_INVENTORY_CHANGED ne font que lever un drapeau (aucun balayage). Deux minuteries
-- partagees (SUI.Every) : "items.swap" (0,25 s) allumee SEULEMENT pendant un echange, "items.cd" (reglage items.tick, 0,5 s) seulement tant que la barre
-- est visible (2 lectures de temps de recharge). Aucune table creee en combat : tampons paralleles, 10 jeux, 8 lignes de menu et 22 cadres prealloues
-- une fois (SUI.WhenSafe). Le balayage des sacs ne se fait qu'au moment d'un echange ou de l'ouverture du menu de bijoux.
-- JEUX : 10 emplacements numerotes ("items.set1".."items.set10", donnees du profil "Nom|emplacement=id:suffixe,...") ; un jeu garde pour chaque
--  emplacement porte (1 a 19) l'objet "id:suffixe aleatoire" (l'enchantement est ignore : il peut changer sans casser le jeu). Un emplacement vide
--  a l'enregistrement n'est pas touche a l'equipement. /sui items save|equip|del|list.
-- ECHANGE : un seul geste par tour de minuterie ; ramasse l'objet du sac puis l'emplacement porte (l'ancien objet reste sur le curseur), au tour
--  suivant il est repose dans l'emplacement du sac. Deux emplacements portes qui s'echangent (bagues, bijoux, armes) passent par le curseur.
--  Attente si le curseur est occupe, si un objet est verrouille ou si un sort attend sa cible ; abandon au bout de 10 s. En combat seuls les
--  emplacements 16 a 18 (armes, distance) sont touches (comme ItemRack) ; le reste reste en file pour la sortie de combat (items.queue).
--  Verification 0,5 s apres la fin, une reprise si un emplacement n'a pas change.
-- EVENEMENTS : items.auto.combat (entree en combat), .rest (sortie de combat), .raid / .party / .pvp / .world (changement de zone). Rien par defaut.
--  Pas d'echange a la connexion (seulement aux changements).
-- BIJOUX : deux boutons (emplacements 13 et 14, clic = utiliser, temps de recharge), menu des bijoux des sacs (clic gauche -> 13, droit -> 14).
-- SOURCES (relevees dans les addons installes, jamais executees ici) : ItemRack (PickupContainerItem / PickupInventoryItem, ITEM_LOCK_CHANGED,
--  emplacements 16 a 18 en combat, GetInventoryItemLink / Cooldown / Texture, GetItemInfo 8e et 9e retours), TrinketMenu (emplacements 13 / 14,
--  UseInventoryItem, IsInventoryItemLocked, GetContainerItemCooldown).
-- ACCES EN CONTEXTE : un bouton "Builds" cree par ce module sur la fenetre du personnage (clic = menu rapide des jeux, clic droit = fenetre Builds),
--  le clic droit sur le bouton "Jeux" de la barre, le lien du menu des bijoux, /sui builds menu, et une touche (Raccourcis : "Menu rapide").
--  Menu rapide : equiper (clic), enregistrer ici (clic droit), jeu courant, case "Jeu monture auto" + choix du jeu + etat monte / a pied, jeu par spe.
--  Fenetre Builds : renommer, dupliquer, copier vers une spe (clic droit sur Spe n), objets manquants en rouge, export / import en texte court
--  ("SB1!Nom!1=1001,5=2001:-12"), comparaison de deux jeux. La banque n'est pas lue : un objet en banque compte comme manquant.
-- NON VERIFIE EN JEU : tout ; le comportement du curseur apres PickupInventoryItem (objet remplace laisse sur le curseur) ; la duree des
--  verrous d'objets ; IsInInstance (types raid / party / pvp / arena) ; les emplacements portes ne sont jamais echanges pendant un sort cible.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local sfind, ssub, slower, sformat = string.find, string.sub, string.lower, string.format

local M = {}
SUI.Items = M

local NSETS = 10
local MAXBAG = 200
local MAXMENU = 8
local MAXQ = 40
local WEAPON = { [16] = true, [17] = true, [18] = true }
local PREV = 11            -- numero interne du jeu "stuff precedent" (hors des 10 jeux de l'utilisateur)
local MOUNT_ICONS = { "Ability_Mount_" }         -- fragments d'icone d'aura de monture (le client 1.12 n'a pas IsMounted)
local SLOTNAMES = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "WRISTSLOT",
	"HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT",
	"TABARDSLOT" }

local function getSet(k)
	if k == PREV then return M.prev end
	return M.sets[k]
end

M.on = false
M.sets = {}            -- 1..10 : { name = nil|"Nom", code = { [emplacement] = "id:suffixe" } }
M.prev = { name = nil, code = {} }           -- jeu interne PREV : ce qui etait porte avant la monture (jamais dans les 10 jeux)
M.lastSet = nil        -- dernier jeu equipe (pour "jeu suivant")
M.mounted = false      -- monture detectee au dernier controle
M.mountSwapped = false -- le jeu de monture est equipe et M.prev garde l'ancien stuff
M.restorePending = false
M.winSel = 1           -- jeu choisi dans la fenetre Builds
M.extra, M.nextra = {}, 0   -- fragments d'icone de monture ajoutes par l'utilisateur
M.cur = {}             -- code porte par emplacement (false si vide)
M.bc, M.bb, M.bs, M.bu = {}, {}, {}, {}      -- sacs : code, sac, case, utilise
M.nb = 0
M.qk, M.qs, M.qb, M.qc = {}, {}, {}, {}      -- file : genre (1 sac, 2 porte), emplacement cible, sac | autre emplacement, case
M.nq, M.qi = 0, 1
M.busy = false
M.hk, M.hb, M.hs = 0, 0, 0                   -- pose en attente (1 sac, 2 emplacement porte)
M.wait = 0
M.try = 0
M.missing, M.deferred = 0, 0
M.pending = nil
M.nextSet = nil
M.curSet = nil
M.zone = nil
M.dirty = true         -- sacs ou equipement modifies
M.menuOpen = false
M.menuSlot = 13
M.nt = 0               -- bijoux du menu
M.tb, M.ts, M.tl = {}, {}, {}
M.choices = { "none", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }

-- ---------------------------------------------------------------- codes d'objets
-- "id:suffixe" d'un lien ; l'identifiant numerique en second retour.
function M.Code(link)
	if not link then return false end
	local _, _, id, suf = sfind(link, "item:(%d+):%-?%d+:(%-?%d+)")
	if not id then
		_, _, id = sfind(link, "item:(%d+)")
		suf = "0"
	end
	if not id then return false end
	return id .. ":" .. suf, tonumber(id)
end

local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

-- ---------------------------------------------------------------- donnees des jeux
function M.ReadSets()
	for k = 1, NSETS do
		local s = M.sets[k]
		if not s then
			s = { name = nil, code = {} }
			M.sets[k] = s
		end
		s.name = nil
		for i = 1, 19 do s.code[i] = nil end
		local raw = C.Get("items.set" .. k) or ""
		local _, _, name, list = sfind(raw, "^([%w_]+)|(.*)$")
		if name then
			s.name = name
			for sl, code in string.gfind(list, "(%d+)=([%d:%-]+)") do
				local n = tonumber(sl)
				if n and n >= 1 and n <= 19 then s.code[n] = code end
			end
		end
	end
end

-- Numero du jeu pour un nom (insensible a la casse) ou un numero ; nil si absent.
function M.Find(ref)
	if ref == nil then return nil end
	local n = tonumber(ref)
	if n then
		if M.sets[n] and M.sets[n].name then return n end
		return nil
	end
	local low = slower(tostring(ref))
	for k = 1, NSETS do
		local s = M.sets[k]
		if s and s.name and slower(s.name) == low then return k end
	end
	return nil
end

function M.Count(k)
	local n = 0
	for i = 1, 19 do
		if M.sets[k].code[i] then n = n + 1 end
	end
	return n
end

-- Enregistre l'equipement porte sous un nom (cree le jeu ou remplace celui de meme nom).
local function validName(name)
	return type(name) == "string" and sfind(name, "^[%w_]+$") ~= nil and string.len(name) <= 12
end

-- Numero du jeu qui porte exactement ce nom (insensible a la casse), sans interpreter un nombre comme un numero.
function M.NameIndex(name)
	local low = slower(tostring(name))
	for k = 1, NSETS do
		local s = M.sets[k]
		if s and s.name and slower(s.name) == low then return k end
	end
	return nil
end

-- Ecrit le jeu k (nom + codes) dans les donnees du profil.
function M.Write(k, name)
	local s = M.sets[k]
	local list = ""
	for sl = 1, 19 do
		local code = s.code[sl]
		if code then
			if list ~= "" then list = list .. "," end
			list = list .. sl .. "=" .. code
		end
	end
	C.SetBase("items.set" .. k, name .. "|" .. list)
end

-- Enregistre l'equipement porte dans le jeu k sous un nom (le jeu k est remplace).
function M.SaveAt(k, name)
	if SUI.InCombat() then SUI.Print(L("msg.items.combat")) return false end
	if not validName(name) then
		SUI.Print(L("msg.items.badname"))
		return false
	end
	if not k or k < 1 or k > NSETS then SUI.Print(L("msg.items.full")) return false end
	local other = M.NameIndex(name)
	if other and other ~= k then
		SUI.Print(L("msg.items.nameused", name))
		return false
	end
	local list = ""
	for s = 1, 19 do
		local code = M.Code(GetInventoryItemLink("player", s))
		if code then
			if list ~= "" then list = list .. "," end
			list = list .. s .. "=" .. code
		end
	end
	C.SetBase("items.set" .. k, name .. "|" .. list)
	SUI.Print(L("msg.items.saved", name, k))
	return true
end

-- Enregistre l'equipement porte sous un nom (cree le jeu ou remplace celui de meme nom).
function M.Save(name)
	if not validName(name) then
		SUI.Print(L("msg.items.badname"))
		return false
	end
	local k = M.Find(name)
	if not k then
		for i = 1, NSETS do
			if not M.sets[i].name then k = i break end
		end
	end
	if not k then SUI.Print(L("msg.items.full")) return false end
	return M.SaveAt(k, name)
end

-- Renomme le jeu k (les objets sont gardes).
function M.Rename(k, name)
	local s = k and M.sets[k]
	if not s or not s.name then SUI.Print(L("msg.items.notfound", tostring(k))) return false end
	if not validName(name) then SUI.Print(L("msg.items.badname")) return false end
	local other = M.NameIndex(name)
	if other and other ~= k then SUI.Print(L("msg.items.nameused", name)) return false end
	local old = s.name
	M.Write(k, name)
	SUI.Print(L("msg.items.renamed", old, name))
	return true
end

-- Change (code = "id:suffixe") ou retire (code = nil) un emplacement d'un jeu.
function M.SetSlot(k, slot, code)
	local s = k and M.sets[k]
	if not s or not s.name then SUI.Print(L("msg.items.pickfirst")) return false end
	if type(slot) ~= "number" or slot < 1 or slot > 19 then return false end
	local name = s.name
	s.code[slot] = code or nil
	M.Write(k, name)
	return true
end

function M.Delete(ref)
	if SUI.InCombat() then SUI.Print(L("msg.items.combat")) return false end
	local k = M.Find(ref)
	if not k then SUI.Print(L("msg.items.notfound", tostring(ref))) return false end
	local name = M.sets[k].name
	C.SetBase("items.set" .. k, "")
	SUI.Print(L("msg.items.deleted", name))
	return true
end

-- ---------------------------------------------------------------- plan d'echange
function M.ScanBags()
	local n = 0
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag)
		for slot = 1, size do
			local link = GetContainerItemLink(bag, slot)
			if link and n < MAXBAG then
				n = n + 1
				M.bc[n] = M.Code(link)
				M.bb[n] = bag
				M.bs[n] = slot
				M.bu[n] = false
			end
		end
	end
	M.nb = n
end

function M.FindBag(code)
	for i = 1, M.nb do
		if not M.bu[i] and M.bc[i] == code then return i end
	end
	return nil
end

function M.FindWorn(code, skip, set)
	for o = 1, 19 do
		if o ~= skip and M.cur[o] == code and set.code[o] ~= code then return o end
	end
	return nil
end

local function addStep(kind, slot, b, c)
	if M.nq >= MAXQ then return end
	M.nq = M.nq + 1
	M.qk[M.nq], M.qs[M.nq], M.qb[M.nq], M.qc[M.nq] = kind, slot, b, c
end

-- mode : 0 tout, 1 combat (armes seulement), 2 rien (mort)
function M.Plan(k, mode)
	local set = getSet(k)
	M.nq, M.missing, M.deferred = 0, 0, 0
	local scanned = false
	for s = 1, 19 do M.cur[s] = M.Code(GetInventoryItemLink("player", s)) end
	for s = 1, 19 do
		local want = set.code[s]
		if want and M.cur[s] ~= want then
			if mode == 2 or (mode == 1 and not WEAPON[s]) then
				M.deferred = M.deferred + 1
			else
				if not scanned then
					M.ScanBags()
					scanned = true
				end
				local f = M.FindBag(want)
				if f then
					addStep(1, s, M.bb[f], M.bs[f])
					M.bc[f] = M.cur[s]          -- l'ancien objet portee ira dans cette case
					M.bu[f] = false
					M.cur[s] = want
				else
					local o = M.FindWorn(want, s, set)
					if o then
						addStep(2, s, o, 0)
						M.cur[o] = M.cur[s]
						M.cur[s] = want
					else
						M.missing = M.missing + 1
					end
				end
			end
		end
	end
end

-- Emplacements du jeu qui ne portent pas encore le bon objet (hors emplacements interdits par le mode).
function M.CountBad(k, mode)
	local set = getSet(k)
	local bad = 0
	for s = 1, 19 do
		local want = set.code[s]
		if want and not (mode == 1 and not WEAPON[s]) and M.Code(GetInventoryItemLink("player", s)) ~= want then bad = bad + 1 end
	end
	return bad
end

function M.Mode()
	if UnitIsDeadOrGhost("player") then return 2 end
	if SUI.InCombat() then return 1 end
	return 0
end

-- ---------------------------------------------------------------- moteur d'echange
function M.Stop()
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	M.busy = false
	M.hk = 0
	M.nq = 0
	M.qi = 1
end

function M.Begin(k, quiet)
	local mode = M.Mode()
	M.curSet = k
	M.quiet = quiet
	M.Plan(k, mode)
	local name = getSet(k).name
	if M.deferred > 0 and C.Get("items.queue") then
		if M.pending ~= k then
			M.pending = k
			SUI.Print(L("msg.items.deferred", name))
		end
	end
	if M.nq == 0 then
		if M.deferred == 0 then
			if M.missing > 0 then SUI.Print(L("msg.items.partial", name, M.missing)) elseif not quiet then SUI.Print(L("msg.items.already", name)) end
		end
		return M.deferred == 0
	end
	M.busy = true
	M.qi = 1
	M.hk = 0
	M.wait = 0
	M.vt = nil
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(0.25, M.Step, "items.swap")
	return true
end

-- Equipe un jeu (nom ou numero). Si un echange est en cours, celui-ci suit.
function M.Equip(ref, quiet)
	local k
	if ref == PREV then
		if M.mountSwapped then k = PREV end         -- jeu interne : seulement tant qu'un stuff precedent est memorise
	else
		k = M.Find(ref)
		if k and M.mountSwapped and not M.inMount then M.MountDone() end     -- un choix de l'utilisateur annule la memoire de monture
	end
	if not k then
		SUI.Print(L("msg.items.notfound", tostring(ref)))
		return false
	end
	if M.bankBusy then return true end
	if not quiet and k ~= PREV and M.IsBankOpen() and M.Mode() == 0 and not M.busy and C.Get("items.bank") then
		if M.BankSwap(k) then return true end
	end
	if M.busy then
		M.nextSet = k
		return true
	end
	M.try = 0
	if k ~= PREV then M.lastSet = k end
	return M.Begin(k, quiet)
end

-- ---------------------------------------------------------------- banque ouverte : un clic sur un jeu prend / range ses objets
-- Banque ouverte : si des objets du jeu manquent sur le personnage, ils sont pris en banque et vont dans les sacs ;
-- si TOUT le jeu est porte, il est range en banque. Banque fermee : comportement normal (equiper).
local BANKBAGS = { -1, 5, 6, 7, 8, 9, 10 }
M.bankOpen = false
M.bankBusy = false
M.bq = {}               -- file : { kind = 1 range (porte -> banque) | 2 prend (banque -> sacs), a, b, c }
M.bn, M.bi = 0, 1

-- Banque ouverte ? l'evenement, ou (module active banque deja ouverte) le cadre de banque du jeu.
function M.IsBankOpen()
	if M.bankOpen then return true end
	local bf = getglobal("BankFrame")
	if bf and bf.IsShown and bf:IsShown() then return true end
	return false
end

function M.OnBank(ev)
	M.bankOpen = (ev == "BANKFRAME_OPENED")
	if not M.bankOpen then M.BankStop() end
end

function M.BankStop()
	if M.btask then
		SUI.Cancel(M.btask)
		M.btask = nil
	end
	M.bankBusy = false
	M.bn, M.bi = 0, 1
	M.bvt, M.bwait = nil, 0
end

-- Case libre de la banque non encore reservee (used : table "sac:case" -> vrai).
function M.BankFreeSlot(used)
	for i = 1, getn(BANKBAGS) do
		local bag = BANKBAGS[i]
		local size = GetContainerNumSlots(bag) or 0
		for slot = 1, size do
			local key = bag .. ":" .. slot
			if not used[key] and not GetContainerItemLink(bag, slot) then
				used[key] = true
				return bag, slot
			end
		end
	end
	return nil
end

function M.BagFreeCount()
	local n = 0
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag) or 0
		for slot = 1, size do
			if not GetContainerItemLink(bag, slot) then n = n + 1 end
		end
	end
	return n
end

-- Prepare la file pour le jeu k ; vrai si la banque s'en occupe (rien d'autre a faire), faux = equipement normal.
-- Regle : tout le jeu est sur le personnage (porte OU dans les sacs) -> tout va en banque ; sinon, ce qui manque et dort en banque
-- vient dans les sacs ; rien en banque -> equipement normal.
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

function M.BankSwap(k)
	local set = getSet(k)
	if not set then return false end
	local wantN = 0
	for s = 1, 19 do
		if set.code[s] then wantN = wantN + 1 end
	end
	if wantN == 0 then return false end
	local name = set.name or "?"
	-- 1) ou est chaque objet du jeu : porte (emplacement), dans les sacs, en banque, ou introuvable
	local usedBag, usedBank = {}, {}
	local nWorn, nBag, nBank = 0, 0, 0
	local plan = {}          -- s -> { w = 1 porte | 2 sac | 3 banque, a, b }
	local missing = 0
	for s = 1, 19 do
		local want = set.code[s]
		if want then
			local w = nil
			if M.Code(GetInventoryItemLink("player", s)) == want then
				w = { w = 1, a = s }
			elseif PAIR[s] and M.Code(GetInventoryItemLink("player", PAIR[s])) == want then
				w = { w = 1, a = PAIR[s] }
			end
			if not w then
				for bag = 0, (NUM_BAG_SLOTS or 4) do
					local size = GetContainerNumSlots(bag) or 0
					for slot = 1, size do
						local key = bag .. ":" .. slot
						if not w and not usedBag[key] and M.Code(GetContainerItemLink(bag, slot)) == want then
							usedBag[key] = true
							w = { w = 2, a = bag, b = slot }
						end
					end
				end
			end
			if not w then
				for i = 1, getn(BANKBAGS) do
					local bag = BANKBAGS[i]
					local size = GetContainerNumSlots(bag) or 0
					for slot = 1, size do
						local key = bag .. ":" .. slot
						if not w and not usedBank[key] and M.Code(GetContainerItemLink(bag, slot)) == want then
							usedBank[key] = true
							w = { w = 3, a = bag, b = slot }
						end
					end
				end
			end
			plan[s] = w
			if not w then missing = missing + 1
			elseif w.w == 1 then nWorn = nWorn + 1
			elseif w.w == 2 then nBag = nBag + 1
			else nBank = nBank + 1 end
		end
	end
	M.bn, M.bi = 0, 1
	if nBank == 0 and missing == 0 then
		-- tout est sur moi : on range tout en banque
		local used = {}
		for s = 1, 19 do
			local p = plan[s]
			if p then
				local bag, slot = M.BankFreeSlot(used)
				if not bag then
					M.bn = 0
					SUI.Print(L("msg.items.bank.full", wantN))
					return true
				end
				M.bn = M.bn + 1
				if p.w == 1 then
					M.bq[M.bn] = { kind = 1, a = p.a, b = bag, c = slot }
				else
					M.bq[M.bn] = { kind = 3, a = p.a, b = p.b, c = bag, d = slot }
				end
			end
		end
		SUI.Print(L("msg.items.bank.store", name, M.bn))
	elseif nBank > 0 then
		-- ce qui manque sur moi dort en banque : on le prend (chaque objet de la banque ne sert qu'une fois)
		for s = 1, 19 do
			local p = plan[s]
			if p and p.w == 3 then
				M.bn = M.bn + 1
				M.bq[M.bn] = { kind = 2, a = p.a, b = p.b }
			end
		end
		if M.BagFreeCount() < M.bn then
			SUI.Print(L("msg.items.bank.full", M.bn))
			M.bn = 0
			return true
		end
		SUI.Print(L("msg.items.bank.fetch", name, M.bn))
	else
		return false                                  -- rien a faire avec la banque : equipement normal
	end
	M.bankBusy = true
	M.bvt, M.bwait = nil, 0
	if M.btask then SUI.Cancel(M.btask) end
	M.btask = SUI.Every(0.3, M.BankStep, "items.bank")
	return true
end

-- Codes de tous les objets des jeux enregistres (pour les autres modules : "cet objet fait partie d'un de mes jeux").
function M.SetCodes()
	local t = {}
	for k = 1, NSETS do
		local s = M.sets[k]
		if s and s.code then
			for sl = 1, 19 do
				if s.code[sl] then t[s.code[sl]] = true end
			end
		end
	end
	return t
end

function M.BankStep()
	if not M.bankBusy then return end
	if not M.IsBankOpen() or UnitIsDeadOrGhost("player") or SUI.InCombat() then
		M.BankStop()
		return
	end
	if CursorHasItem() then
		M.bwait = (M.bwait or 0) + 1
		if M.bwait > 20 then M.BankStop() end
		return
	end
	M.bwait = 0
	if M.bi > M.bn then
		if not M.bvt then
			M.bvt = GetTime() + 0.4
			return
		end
		if GetTime() >= M.bvt then M.BankStop() end
		return
	end
	local q = M.bq[M.bi]
	if q.kind == 1 then
		if IsInventoryItemLocked(q.a) then return end
		PickupInventoryItem(q.a)
		PickupContainerItem(q.b, q.c)
	elseif q.kind == 3 then
		local _, _, lk = GetContainerItemInfo(q.a, q.b)
		if lk then return end
		PickupContainerItem(q.a, q.b)
		PickupContainerItem(q.c, q.d)
	else
		local _, _, locked = GetContainerItemInfo(q.a, q.b)
		if locked then return end
		UseContainerItem(q.a, q.b)                 -- banque ouverte : le clic droit envoie l'objet dans les sacs
	end
	M.bi = M.bi + 1
end

function M.Waiting()
	if SUI.InCombat() then return end
	M.wait = M.wait + 1
	if M.wait > 40 then
		M.Stop()
		SUI.Print(L("msg.items.aborted"))
	end
end

function M.Finish()
	local k = M.curSet
	local mode = M.Mode()
	M.Stop()
	M.CtxSoon()
	if not k then return end
	local name = getSet(k).name or "?"
	local bad = M.CountBad(k, mode)
	if bad > 0 and M.try < 1 and M.deferred == 0 then
		M.try = M.try + 1
		M.Begin(k, M.quiet)
		return
	end
	if bad > 0 or M.missing > 0 then
		SUI.Print(L("msg.items.partial", name, bad > M.missing and bad or M.missing))
	elseif C.Get("items.announce") and not M.quiet then
		SUI.Print(L("msg.items.done", name))
	end
	if k == PREV and M.deferred == 0 then M.MountDone() end       -- stuff precedent remis (ou impossible a remettre : message deja dit)
	local nx = M.nextSet
	M.nextSet = nil
	if nx then
		M.try = 0
		M.Begin(nx, false)
	end
end

function M.Step()
	if not M.busy then return end
	if SpellIsTargeting() then return end
	if M.hk > 0 then
		if CursorHasItem() then
			if M.hk == 1 then PickupContainerItem(M.hb, M.hs) else PickupInventoryItem(M.hs) end
		end
		M.hk = 0
		return
	end
	if CursorHasItem() then
		M.Waiting()
		return
	end
	if M.qi > M.nq then
		if not M.vt then
			M.vt = GetTime() + 0.5
			return
		end
		if GetTime() >= M.vt then M.Finish() end
		return
	end
	local s = M.qs[M.qi]
	if SUI.InCombat() and not WEAPON[s] then return end
	if UnitIsDeadOrGhost("player") then return end
	if M.qk[M.qi] == 1 then
		local bag, bs = M.qb[M.qi], M.qc[M.qi]
		local _, _, locked = GetContainerItemInfo(bag, bs)
		if locked or IsInventoryItemLocked(s) then
			M.Waiting()
			return
		end
		PickupContainerItem(bag, bs)
		PickupInventoryItem(s)
		M.hk, M.hb, M.hs = 1, bag, bs
	else
		local o = M.qb[M.qi]
		if IsInventoryItemLocked(s) or IsInventoryItemLocked(o) then
			M.Waiting()
			return
		end
		PickupInventoryItem(o)
		PickupInventoryItem(s)
		M.hk, M.hs = 2, o
	end
	M.qi = M.qi + 1
	M.wait = 0
end

-- ---------------------------------------------------------------- evenements automatiques
function M.Auto(key)
	local v = tonumber(C.Get("items.auto." .. key))
	if v and M.sets[v] and M.sets[v].name then M.Equip(v, true) end
end

function M.OnCombatStart()
	if M.mountSwapped then M.MountOff() end        -- le stuff d'avant la monture revient AVANT le combat (armes seulement tant que dure le combat)
	M.Auto("combat")
end

function M.OnCombatEnd()
	if M.pending then
		local p = M.pending
		M.pending = nil
		M.Equip(p, true)
	elseif M.restorePending then
		M.MountRestore()
	else
		M.Auto("rest")
	end
	M.dirty = true
	if M.mountEv then M.MountSoon() end
	if M.specDirty then
		M.specDirty = false
		M.SpecSoon()
	end
end

function M.OnAlive()
	if M.pending and not SUI.InCombat() then
		local p = M.pending
		M.pending = nil
		M.Equip(p, true)
	elseif M.restorePending and not SUI.InCombat() then
		M.MountRestore()
	end
end

function M.ZoneKind()
	-- IsInInstance n'existe pas dans le client 1.12 d'origine : sans garde, l'activation du module plantait. Repli : tout est "monde".
	local fn = getglobal("IsInInstance")
	if type(fn) ~= "function" then return "world" end
	local ok, inst, typ = pcall(fn)
	if ok and inst then
		if typ == "raid" then return "raid" end
		if typ == "party" then return "party" end
		if typ == "pvp" or typ == "arena" then return "pvp" end
	end
	return "world"
end

function M.OnZone()
	local kind = M.ZoneKind()
	if M.zone == nil then
		M.zone = kind
		return
	end
	if kind ~= M.zone then
		M.zone = kind
		M.Auto(kind)
	end
end

function M.OnDirty(ev, unit)
	if ev == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
	M.dirty = true
	M.CtxSoon()
end

-- ---------------------------------------------------------------- barre de bijoux
function M.SlotCooldown(slot)
	local start, dur, enable = GetInventoryItemCooldown("player", slot)
	if start and dur and start > 0 and dur > 1.5 and enable ~= 0 then
		local left = start + dur - GetTime()
		if left > 0 then return left end
	end
	return 0
end

local function cdText(left)
	if left <= 0 then return "" end
	if left >= 60 then return sformat("%dm", math.ceil(left / 60)) end
	return sformat("%d", math.ceil(left))
end

function M.RefreshWorn()
	local f = M.frame
	if not f then return end
	for i = 1, 2 do
		local b = f.worn[i]
		local link = GetInventoryItemLink("player", b.slot)
		if b.link ~= (link or false) then
			b.link = link or false
			if link then
				b.icon:SetTexture(GetInventoryItemTexture("player", b.slot))
				b.icon:SetVertexColor(1, 1, 1, 1)  -- style:ok
			else
				b.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket")      -- emplacement vide : silhouette du slot, estompee
				b.icon:SetVertexColor(0.55, 0.55, 0.55, 0.7)  -- style:ok
			end
			b.icon:Show()
		end
	end
end

function M.ScanTrinkets()
	local n = 0
	local max = C.Get("items.menumax")
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag)
		for slot = 1, size do
			local link = GetContainerItemLink(bag, slot)
			if link and n < max then
				local _, id = M.Code(link)
				local _, _, _, _, _, _, _, loc = GetItemInfo(id)
				if loc == "INVTYPE_TRINKET" then
					n = n + 1
					M.tb[n], M.ts[n], M.tl[n] = bag, slot, link
				end
			end
		end
	end
	M.nt = n
end

function M.RefreshMenu()
	local f = M.frame
	if not f then return end
	local menu = f.menu
	if not M.menuOpen then
		menu:Hide()
		return
	end
	M.ScanTrinkets()
	local sz = C.Get("items.size")
	for i = 1, MAXMENU do
		local e = menu.rows[i]
		if i <= M.nt then
			local tex = GetContainerItemInfo(M.tb[i], M.ts[i])
			e.icon:SetTexture(tex)
			local _, _, name = sfind(M.tl[i], "%[(.-)%]")
			setText(e.name, name or "?")
			e.bag, e.slotn = M.tb[i], M.ts[i]
			local start, dur = GetContainerItemCooldown(M.tb[i], M.ts[i])
			local left = 0
			if start and start > 0 and dur and dur > 1.5 then left = start + dur - GetTime() end
			setText(e.cd, cdText(left))
			e:Show()
		else
			e:Hide()
		end
	end
	menu:SetHeight(8 + M.nt * (sz + 2) + 18)
	if M.nt > 0 then menu:Show() else menu:Hide() end
	M.dirty = false
end

function M.ToggleMenu(slot)
	if SUI.InCombat() and not M.menuOpen then
		SUI.Print(L("msg.items.combat"))
		return
	end
	if M.menuOpen and M.menuSlot == slot then
		M.menuOpen = false
	else
		M.menuOpen = true
		M.menuSlot = slot
	end
	M.RefreshMenu()
end

-- Echange direct d'un bijou de sac vers un emplacement porte (13 ou 14).
function M.SwapTrinket(bag, bs, slot)
	if SUI.InCombat() or UnitIsDeadOrGhost("player") then
		SUI.Print(L("msg.items.combat"))
		return false
	end
	if M.busy then return false end
	M.curSet = nil
	M.nq, M.qi, M.hk, M.wait, M.vt = 0, 1, 0, 0, nil
	addStep(1, slot, bag, bs)
	M.nq = 1
	M.busy = true
	M.missing, M.deferred = 0, 0
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(0.25, M.Step, "items.swap")
	return true
end

function M.CdTick()
	local f = M.frame
	if not f or not f:IsShown() then return end
	if M.dirty then
		M.RefreshWorn()
		if M.menuOpen then M.RefreshMenu() end
		M.dirty = false
	end
	if C.Get("items.cooldowns") then
		for i = 1, 2 do setText(f.worn[i].cd, cdText(M.SlotCooldown(f.worn[i].slot))) end
		if M.menuOpen then
			for i = 1, M.nt do
				local e = f.menu.rows[i]
				local start, dur = GetContainerItemCooldown(M.tb[i], M.ts[i])
				local left = 0
				if start and start > 0 and dur and dur > 1.5 then left = start + dur - GetTime() end
				setText(e.cd, cdText(left))
			end
		end
	end
end

local function tipWorn()
	if GameTooltip then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetInventoryItem("player", this.slot)
		GameTooltip:Show()
	end
end

local function tipBag()
	if GameTooltip then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(this.bag, this.slotn)
		GameTooltip:Show()
	end
end

local function tipHide()
	if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- monture : jeu de vitesse puis retour du stuff precedent
-- Le client 1.12 n'a pas IsMounted : la monture se reconnait a l'icone d'une aura du joueur (UnitBuff). Les evenements d'aura ne font que
-- demander un controle dans 0,3 s (une seule minuterie, SUI.After) ; rien n'est lu en combat. Evenements allumes SEULEMENT si items.auto.mount
-- pointe un jeu existant.
function M.ReadExtra()
	local raw = slower(C.Get("items.mount.extra") or "")
	M.nextra = 0
	for frag in string.gfind(raw, "[^,]+") do
		local f = string.gsub(frag, "^%s+", "")
		f = string.gsub(f, "%s+$", "")
		if f ~= "" and M.nextra < 12 then
			M.nextra = M.nextra + 1
			M.extra[M.nextra] = f
		end
	end
end

-- Vrai si une aura du joueur a une icone de monture (fragments livres + fragments de l'utilisateur).
function M.MountScan()
	local fn = getglobal("UnitBuff")
	if type(fn) ~= "function" then return false end
	for i = 1, 32 do
		local tex = fn("player", i)
		if not tex then return false end
		if type(tex) == "string" then
			for j = 1, getn(MOUNT_ICONS) do
				if sfind(tex, MOUNT_ICONS[j], 1, true) then return true end
			end
			if M.nextra > 0 then
				local low = slower(tex)
				for j = 1, M.nextra do
					if sfind(low, M.extra[j], 1, true) then return true end
				end
			end
		end
	end
	return false
end

function M.MountSoon()
	if not M.mountTask then M.mountTask = SUI.After(0.3, M.MountTick, "items.mount") end
end

function M.MountTick()
	M.mountTask = nil
	M.MountCheck()
end

function M.OnAura(ev, unit)
	if ev == "UNIT_AURA" and unit ~= "player" then return end
	if SUI.InCombat() then return end
	M.MountSoon()
end

function M.MountSeed()
	if SUI.InCombat() then return end
	M.mounted = M.MountScan()
end

function M.MountCheck()
	if not M.on or not M.mountEv then return end
	if SUI.InCombat() or UnitIsDeadOrGhost("player") then return end
	if M.busy then
		M.MountSoon()                    -- un echange tourne : on regarde de nouveau juste apres
		return
	end
	local m = M.MountScan()
	if m ~= M.mounted then
		M.mounted = m
		M.CtxSoon()
		if m then M.MountOn() else M.MountOff() end
	elseif not m and M.restorePending then
		M.MountRestore()
	end
end

-- Monte : memorise ce que le jeu de monture va remplacer, puis l'equipe.
function M.MountOn()
	local k = tonumber(C.Get("items.auto.mount"))
	local set = k and M.sets[k]
	if not set or not set.name then return end
	M.restorePending = false
	if M.pending == PREV then M.pending = nil end
	if not M.mountSwapped then
		local n = 0
		for sl = 1, 19 do
			M.prev.code[sl] = nil
			local want = set.code[sl]
			if want then
				local cur = M.Code(GetInventoryItemLink("player", sl))
				if cur and cur ~= want then
					M.prev.code[sl] = cur
					n = n + 1
				end
			end
		end
		if n > 0 then
			M.prev.name = L("choice.items.prev")
			M.mountSwapped = true
		end
	end
	local last = M.lastSet
	M.inMount = true
	M.Equip(k, true)
	M.inMount = false
	M.lastSet = last
	if C.Get("items.announce") then SUI.Print(L("msg.items.mount.on", set.name)) end
end

-- Descend (ou entre en combat) : remet le stuff memorise ; en combat seules les armes passent, le reste attend la sortie du combat.
function M.MountOff()
	if not M.mountSwapped then return end
	M.restorePending = true
	if C.Get("items.announce") then SUI.Print(L("msg.items.mount.off")) end
	M.MountRestore()
end

function M.MountRestore()
	if not M.restorePending then return end
	if not M.mountSwapped then
		M.restorePending = false
		return
	end
	if UnitIsDeadOrGhost("player") then return end
	M.inMount = true
	M.Equip(PREV, true)
	M.inMount = false
	if not M.busy and M.deferred == 0 then M.MountDone() end
end

function M.MountDone()
	M.mountSwapped = false
	M.restorePending = false
	M.prev.name = nil
	for sl = 1, 19 do M.prev.code[sl] = nil end
	if M.pending == PREV then M.pending = nil end
end

function M.UpdateMountEvents()
	local k = tonumber(C.Get("items.auto.mount"))
	local want = (M.on and k and M.sets[k] and M.sets[k].name) and true or false
	if want and not M.mountEv then
		M.mountEv = true
		SUI.On("PLAYER_AURAS_CHANGED", M.OnAura)
		SUI.On("UNIT_AURA", M.OnAura)
		SUI.On("PLAYER_ENTERING_WORLD", M.MountSeed)
		M.MountSeed()
	elseif not want and M.mountEv then
		M.mountEv = false
		SUI.Off("PLAYER_AURAS_CHANGED", M.OnAura)
		SUI.Off("UNIT_AURA", M.OnAura)
		SUI.Off("PLAYER_ENTERING_WORLD", M.MountSeed)
		if M.mountTask then
			SUI.Cancel(M.mountTask)
			M.mountTask = nil
		end
		if M.mountSwapped and M.on then M.MountOff() end
	end
end

-- ---------------------------------------------------------------- jeu par specialisation (lien avec Mod_Specs : SUI.Specs.Scan)
function M.SpecSoon()
	if M.specTask then SUI.Cancel(M.specTask) end
	M.specTask = SUI.After(3, M.SpecCheck, "items.spec")
end

function M.OnSpecEvent()
	if SUI.InCombat() then
		M.specDirty = true
		return
	end
	M.SpecSoon()
end

function M.SpecCheck()
	M.specTask = nil
	if not M.on or not M.specEv then return end
	if SUI.InCombat() then
		M.specDirty = true
		return
	end
	local Sp = SUI.Specs
	if not Sp or type(Sp.Scan) ~= "function" then return end
	local sc = Sp.Scan()
	if not sc then return end
	local last = M.lastSpec
	M.lastSpec = sc.id
	if last == nil or last == sc.id then return end
	local v = tonumber(C.Get("items.spec" .. sc.id))
	if v and M.sets[v] and M.sets[v].name then M.Equip(v, false) end
end

function M.UpdateSpecEvents()
	local want = false
	if M.on then
		for id = 0, 3 do
			if tonumber(C.Get("items.spec" .. id)) then want = true end
		end
	end
	if want and not M.specEv then
		M.specEv = true
		SUI.On("CHARACTER_POINTS_CHANGED", M.OnSpecEvent)
		SUI.On("SPELLS_CHANGED", M.OnSpecEvent)
		local Sp = SUI.Specs
		if M.lastSpec == nil and Sp and type(Sp.Scan) == "function" then
			local sc = Sp.Scan()
			if sc then M.lastSpec = sc.id end
		end
	elseif not want and M.specEv then
		M.specEv = false
		SUI.Off("CHARACTER_POINTS_CHANGED", M.OnSpecEvent)
		SUI.Off("SPELLS_CHANGED", M.OnSpecEvent)
		if M.specTask then
			SUI.Cancel(M.specTask)
			M.specTask = nil
		end
	end
end

-- ---------------------------------------------------------------- jeu suivant
function M.Next()
	local cur = M.lastSet
	if not (cur and M.sets[cur] and M.sets[cur].name) then
		cur = nil
		for k = 1, NSETS do
			if M.sets[k].name and M.Count(k) > 0 and M.CountBad(k, 0) == 0 then
				cur = k
				break
			end
		end
	end
	local base = cur or 0
	for step = 1, NSETS do
		local k = base + step
		if k > NSETS then k = k - NSETS end
		if M.sets[k].name then return M.Equip(k) end
	end
	SUI.Print(L("msg.items.list.none"))
	return false
end

-- ---------------------------------------------------------------- boutons-relais des raccourcis (un par jeu + "suivant")
-- Les raccourcis passent par le service SUI.Bind : une touche posee sur un bouton de jeu devient "CLICK ShikiUIItemsSet<n>:LeftButton" ; le client
-- appelle le OnClick de ce bouton-relais (1x1, sans souris). Crees une fois, hors combat.
function M.BuildProxies()
	if M.proxy then return end
	M.proxy = {}
	for k = 1, NSETS + 2 do
		local nm = "ShikiUIItemsSet" .. k
		if k == NSETS + 1 then nm = "ShikiUIItemsNext" elseif k == NSETS + 2 then nm = "ShikiUIItemsQuick" end
		local b = CreateFrame("Button", nm, UIParent)
		b:SetWidth(1)
		b:SetHeight(1)
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
		b:EnableMouse(false)
		b.relayN = k
		b:SetScript("OnClick", function()
			local btn = this
			if not M.on then return end
				if btn.relayN == NSETS + 2 then M.QuickToggle(nil, false) elseif btn.relayN > NSETS then M.Next() else M.Equip(btn.relayN) end
		end)
		M.proxy[k] = b
	end
end

SUI.Bind.AddResolver(function(f)
	local k = f.itemsSet
	if k then
		local s = M.sets[k]
		return "CLICK ShikiUIItemsSet" .. k .. ":LeftButton", L("mod.items.bind.set", (s and s.name) or tostring(k))
	end
	if f.itemsNext then return "CLICK ShikiUIItemsNext:LeftButton", L("mod.items.bind.next") end
	if f.itemsQuick then return "CLICK ShikiUIItemsQuick:LeftButton", L("mod.items.bind.quick") end
	return nil
end)

-- ---------------------------------------------------------------- jeux : creer, copier, partager, comparer
function M.FreeSlot()
	for i = 1, NSETS do
		if not M.sets[i].name then return i end
	end
	return nil
end

-- Nom valide et libre derive de base : base, puis base2, base3... (12 caracteres au plus).
function M.UniqueName(base)
	base = string.gsub(tostring(base or ""), "[^%w_]", "")
	if base == "" then base = "Jeu" end
	if string.len(base) > 12 then base = ssub(base, 1, 12) end
	if not M.NameIndex(base) then return base end
	for i = 2, 99 do
		local suf = tostring(i)
		local cand = ssub(base, 1, 12 - string.len(suf)) .. suf
		if not M.NameIndex(cand) then return cand end
	end
	return nil
end

-- Numero du jeu nomme suivant (dir = 1) ou precedent (dir = -1) a partir de "from", en sautant "skip" ; nil s'il n'y en a pas.
function M.NextNamed(from, dir, skip)
	local k = from or 0
	for step = 1, NSETS do
		k = k + dir
		if k > NSETS then k = 1 elseif k < 1 then k = NSETS end
		if k ~= skip and M.sets[k].name then return k end
	end
	return nil
end

-- Valeur de reglage suivante/precedente dans la suite : "none", jeux nommes... (pour les boutons de choix du menu rapide).
function M.CycleChoice(cur, dir)
	local k = tonumber(cur) or 0
	if k > 0 and not (M.sets[k] and M.sets[k].name) then k = 0 end
	for step = 1, NSETS + 1 do
		k = k + dir
		if k > NSETS then k = 0 elseif k < 0 then k = NSETS end
		if k == 0 or M.sets[k].name then break end
	end
	if k == 0 then return "none" end
	return tostring(k)
end

-- Copie le jeu k dans un emplacement libre (nom base, ou nom + chiffre). Renvoie le nouveau numero, ou false.
function M.Duplicate(k, base)
	local s = k and M.sets[k]
	if not s or not s.name then SUI.Print(L("msg.items.notfound", tostring(k))) return false end
	local free = M.FreeSlot()
	if not free then SUI.Print(L("msg.items.full")) return false end
	local name
	if base and base ~= "" then
		if not validName(base) then SUI.Print(L("msg.items.badname")) return false end
		if M.NameIndex(base) then SUI.Print(L("msg.items.nameused", base)) return false end
		name = base
	else
		name = M.UniqueName(s.name)
	end
	if not name then SUI.Print(L("msg.items.full")) return false end
	local d = M.sets[free]
	for sl = 1, 19 do d.code[sl] = s.code[sl] end
	M.Write(free, name)
	SUI.Print(L("msg.items.duplicated", s.name, name, free))
	return free
end

-- Specialisation id (0 = aucune dominante, 1 a 3) -> jeu k (nil : aucun).
function M.SpecSet(id, k)
	if type(id) ~= "number" or id < 0 or id > 3 then return false end
	if k and not (M.sets[k] and M.sets[k].name) then SUI.Print(L("msg.items.notfound", tostring(k))) return false end
	C.Set("items.spec" .. id, k and tostring(k) or "none")
	if k then SUI.Print(L("msg.items.spec.set", id, M.sets[k].name)) else SUI.Print(L("msg.items.spec.none", id)) end
	return true
end

-- Copie le jeu k puis range la copie sur la specialisation id : on peut ensuite retoucher la copie sans changer l'original.
function M.CopyToSpec(k, id)
	local s = k and M.sets[k]
	if not s or not s.name then SUI.Print(L("msg.items.notfound", tostring(k))) return false end
	if type(id) ~= "number" or id < 0 or id > 3 then return false end
	local n = M.Duplicate(k, M.UniqueName(ssub(s.name, 1, 10) .. "S" .. id))
	if not n then return false end
	M.SpecSet(id, n)
	return n
end

-- Texte court d'un jeu : "SB1!Nom!emplacement=objet[:suffixe],..." (le suffixe 0 est omis).
function M.Export(k)
	local s = k and M.sets[k]
	if not s or not s.name then return nil end
	local list = ""
	for sl = 1, 19 do
		local code = s.code[sl]
		if code then
			local _, _, id, suf = sfind(code, "^(%d+):(%-?%d+)$")
			local part = sl .. "=" .. code
			if id then
				if suf == "0" then part = sl .. "=" .. id else part = sl .. "=" .. id .. ":" .. suf end
			end
			if list ~= "" then list = list .. "," end
			list = list .. part
		end
	end
	return "SB1!" .. s.name .. "!" .. list
end

-- Lit un texte de jeu ; le range dans le premier emplacement libre (nom rendu unique). Renvoie le numero ou false.
function M.Import(txt)
	txt = string.gsub(tostring(txt or ""), "^%s+", "")
	txt = string.gsub(txt, "%s+$", "")
	local _, _, name, list = sfind(txt, "^SB1!([%w_]+)!(.*)$")
	if not name then SUI.Print(L("msg.items.badcode")) return false end
	local free = M.FreeSlot()
	if not free then SUI.Print(L("msg.items.full")) return false end
	if string.len(name) > 12 then name = ssub(name, 1, 12) end
	name = M.UniqueName(name)
	if not name then SUI.Print(L("msg.items.full")) return false end
	local d = M.sets[free]
	for sl = 1, 19 do d.code[sl] = nil end
	local n = 0
	for sl, id, suf in string.gfind(list, "(%d+)=(%d+):?(%-?%d*)") do
		local slot = tonumber(sl)
		if slot and slot >= 1 and slot <= 19 and not d.code[slot] and string.len(id) <= 7 then
			if suf == "" or suf == "-" then suf = "0" end
			d.code[slot] = id .. ":" .. suf
			n = n + 1
		end
	end
	if n == 0 then SUI.Print(L("msg.items.badcode")) return false end
	M.Write(free, name)
	SUI.Print(L("msg.items.imported", name, free, n))
	return free
end

-- Differences entre deux jeux : M.dN emplacements differents (M.dS emplacement, M.dA / M.dB codes ou false), M.dSame identiques.
M.dN, M.dSame = 0, 0
M.dS, M.dA, M.dB = {}, {}, {}
function M.Compare(a, b)
	local sa, sb = M.sets[a], M.sets[b]
	M.dN, M.dSame = 0, 0
	if not (sa and sa.name and sb and sb.name) then return 0 end
	for sl = 1, 19 do
		local ca, cb = sa.code[sl], sb.code[sl]
		if ca ~= cb then
			M.dN = M.dN + 1
			M.dS[M.dN], M.dA[M.dN], M.dB[M.dN] = sl, ca or false, cb or false
		elseif ca then
			M.dSame = M.dSame + 1
		end
	end
	return M.dN
end

-- Nom lisible d'un objet d'un jeu ("#id" tant que le client ne le connait pas).
function M.CodeName(code)
	if not code then return "-" end
	local _, _, id, suf = sfind(code, "^(%d+):(%-?%d+)")
	if not id then return code end
	local name = GetItemInfo(tonumber(id))
	if type(name) ~= "string" then name = "#" .. id end
	if suf ~= "0" then name = name .. " (" .. suf .. ")" end
	return name
end

-- Objets que le joueur possede (portes ou dans les sacs) : M.have[code] = true. La banque n'est pas lue (hors de portee en jeu).
M.have = {}
function M.ScanHave()
	local h = M.have
	for key in pairs(h) do h[key] = nil end
	for sl = 1, 19 do
		local c = M.Code(GetInventoryItemLink("player", sl))
		if c then h[c] = true end
	end
	for bag = 0, 4 do
		local size = GetContainerNumSlots(bag)
		for slot = 1, size do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local c = M.Code(link)
				if c then h[c] = true end
			end
		end
	end
end

-- Nombre d'objets du jeu k que le joueur n'a ni sur lui ni dans ses sacs (apres M.ScanHave).
function M.MissingIn(k)
	local s = M.sets[k]
	local n = 0
	if not s or not s.name then return 0 end
	for sl = 1, 19 do
		local code = s.code[sl]
		if code and not M.have[code] then n = n + 1 end
	end
	return n
end

-- Jeu actuellement porte en entier (le dernier equipe d'abord) ; nil si aucun.
function M.CurrentSet()
	local l = M.lastSet
	if l and M.sets[l] and M.sets[l].name and M.Count(l) > 0 and M.CountBad(l, 0) == 0 then return l end
	for k = 1, NSETS do
		if M.sets[k].name and M.Count(k) > 0 and M.CountBad(k, 0) == 0 then return k end
	end
	return nil
end

-- ---------------------------------------------------------------- aides d'interface (niveaux, infobulles)
-- Le client 1.12 change le niveau d'un cadre apres sa construction : les controles crees a l'ancien niveau passent SOUS le cadre qui capte la
-- souris. Tous les controles d'une fenetre sont donc ENFANTS du cadre et ranges dans owner.kids ; M.Raise les recale (a l'affichage, puis 0,2 s
-- apres, et au survol du bouton de contexte). Voir Menu.SyncLevel et /sui menudiag.
function M.Kid(owner, obj)
	owner.nkids = owner.nkids + 1
	owner.kids[owner.nkids] = obj
	return obj
end

function M.Raise(owner)
	local lv = owner:GetFrameLevel()
	if type(lv) ~= "number" then return end
	for i = 1, owner.nkids do
		local k = owner.kids[i]
		k:SetFrameLevel(lv + 2)
		if k.nkids then M.Raise(k) end
	end
end

function M.RaiseSoon(owner)
	M.Raise(owner)
	if not owner.raiseTask then owner.raiseTask = SUI.After(0.2, owner.raiseFn, "items.lvl") end
end

function M.NewOwner(f)
	f.kids, f.nkids = {}, 0
	f.raiseFn = function()
		f.raiseTask = nil
		M.Raise(f)
	end
	return f
end

local function tipLine(text, c)
	GameTooltip:AddLine(text, c[1], c[2], c[3], 1)
end

local function tipShow()
	local b = this
	if not GameTooltip then return end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	if b.tipFn then
		b.tipFn(b)
	elseif b.tipTitle then
		GameTooltip:AddLine(L(b.tipTitle))
		if b.tipText then tipLine(L(b.tipText), T.c.dim) end
	end
	GameTooltip:Show()
end

-- Infobulle (titre + aide courte, ou fonction) sur un controle, sans perdre le survol du theme.
function M.Tip(b, title, text, fn)
	b.tipTitle, b.tipText, b.tipFn = title, text, fn
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oe then oe() end
		tipShow()
	end)
	b:SetScript("OnLeave", function()
		if ol then ol() end
		tipHide()
	end)
end

-- Infobulle d'un jeu : objets (en rouge ceux qu'on n'a pas) et gestes.
function M.TipSet(b)
	local k = b.itemsSet or b.setn
	local s = k and M.sets[k]
	if not s then return end
	if not s.name then
		tipLine(L("mod.items.q.freetip"), T.c.dim)
		return
	end
	M.ScanHave()
	GameTooltip:AddLine(k .. ". " .. s.name)
	for sl = 1, 19 do
		local code = s.code[sl]
		if code then
			local c = M.have[code] and T.c.text or T.c.bad
			GameTooltip:AddLine(M.SlotName(sl) .. " : " .. M.CodeName(code), c[1], c[2], c[3])
		end
	end
	if b.quickRow then tipLine(L("mod.items.q.rowtip"), T.c.dim) else tipLine(L("mod.items.q.bartip"), T.c.dim) end
end

-- ---------------------------------------------------------------- fenetre Builds
function M.SlotName(sl)
	local n = getglobal(SLOTNAMES[sl])
	if type(n) == "string" then return n end
	return "#" .. sl
end

function M.CodeTexture(code, sl)
	local _, _, id = sfind(code, "^(%d+)")
	if id then
		local _, _, _, _, _, _, _, _, tex = GetItemInfo(tonumber(id))
		if tex then return tex end
	end
	if M.Code(GetInventoryItemLink("player", sl)) == code then return GetInventoryItemTexture("player", sl) end
	return nil
end

local function codeColor(code)
	if not code then return T.c.dim end
	if M.have[code] then return T.c.text end
	return T.c.bad
end

-- Comparaison de deux jeux : A = jeu choisi dans la fenetre, B = jeu a comparer (bouton de choix).
function M.CmpRefresh()
	local w = M.win
	if not w or not w.cmp or not w.cmp:IsShown() then return end
	local cmp = w.cmp
	local a = M.winSel
	local b = M.cmpWith
	if not (b and b ~= a and M.sets[b] and M.sets[b].name) then
		b = M.NextNamed(a, 1, a)
		M.cmpWith = b
	end
	for i = 1, 19 do
		cmp.lines[i].slot:SetText("")
		cmp.lines[i].a:SetText("")
		cmp.lines[i].b:SetText("")
	end
	if not (M.sets[a].name and b) then
		setText(cmp.head, L("mod.items.cmp.need"))
		setText(cmp.foot, "")
		T.SetButtonText(cmp.pick, "-")
		return
	end
	M.ScanHave()
	setText(cmp.head, M.sets[a].name .. "  /  " .. M.sets[b].name)
	T.SetButtonText(cmp.pick, "B : " .. M.sets[b].name)
	M.Compare(a, b)
	for i = 1, M.dN do
		local ln = cmp.lines[i]
		ln.slot:SetText(M.SlotName(M.dS[i]))
		ln.a:SetText(M.CodeName(M.dA[i]))
		ln.b:SetText(M.CodeName(M.dB[i]))
		local ca, cb = codeColor(M.dA[i]), codeColor(M.dB[i])
		ln.a:SetTextColor(ca[1], ca[2], ca[3], 1)
		ln.b:SetTextColor(cb[1], cb[2], cb[3], 1)
	end
	if M.dN == 0 then setText(cmp.foot, L("mod.items.cmp.same")) else setText(cmp.foot, L("mod.items.cmp.foot", M.dN, M.dSame)) end
end

function M.WinRefresh()
	local w = M.win
	if not w or not w:IsShown() then return end
	local sel = M.winSel
	M.ScanHave()
	for k = 1, NSETS do
		local r = w.rows[k]
		local s = M.sets[k]
		if s.name then
			setText(r.label, k .. ". " .. s.name .. " (" .. M.Count(k) .. ")")
			local miss = M.MissingIn(k)
			setText(r.warn, miss > 0 and ("!" .. miss) or "")
		else
			setText(r.label, k .. ". " .. L("choice.items.free"))
			setText(r.warn, "")
		end
		T.SetSelected(r, k == sel)
	end
	local s = M.sets[sel]
	if w.editFor ~= sel then
		w.editFor = sel
		w.edit:SetText(s.name or "")
	end
	local lostN = 0
	for i = 1, 19 do
		local c = w.cells[i]
		local code = s.name and s.code[i]
		local lost = code and not M.have[code]
		if lost then lostN = lostN + 1 end
		local tex = code and M.CodeTexture(code, i)
		if tex then
			c.icon:SetTexture(tex)
			c.icon:Show()
			setText(c.q, lost and "!" or "")
		else
			c.icon:Hide()
			setText(c.q, code and (lost and "!" or "?") or tostring(i))
		end
		if (lost and true or false) ~= c.lost then
			c.lost = lost and true or false
			local bc = c.lost and T.c.bad or T.c.border
			c:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
			local qc = c.lost and T.c.bad or T.c.dim
			c.q:SetTextColor(qc[1], qc[2], qc[3], 1)
			c.icon:SetAlpha(c.lost and 0.45 or 1)
		end
	end
	if lostN > 0 then
		setText(w.miss, L("mod.items.win.missing", lostN))
		if w.missState ~= 1 then
			w.missState = 1
			w.miss:SetTextColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 1)
		end
	else
		setText(w.miss, (s.name and M.Count(sel) > 0) and L("mod.items.win.allthere") or "")
		if w.missState ~= 2 then
			w.missState = 2
			w.miss:SetTextColor(T.c.good[1], T.c.good[2], T.c.good[3], 1)
		end
	end
	local cur = M.CurrentSet()
	setText(w.state, cur and L("mod.items.q.worn", M.sets[cur].name) or L("mod.items.q.wornnone"))
	for id = 0, 3 do
		T.SetSelected(w.spec[id], (s.name and tonumber(C.Get("items.spec" .. id)) == sel) and true or false)
	end
	M.CmpRefresh()
end

function M.WinPick(k)
	M.winSel = k
	if M.win then M.win.editFor = nil end
	M.WinRefresh()
end

local function winName()
	local t = M.win and M.win.edit:GetText() or ""
	t = string.gsub(t, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	return t
end

function M.WinSave()
	local name = winName()
	if name == "" then name = M.sets[M.winSel].name or "" end
	if M.SaveAt(M.winSel, name) then M.WinPick(M.winSel) end
end

function M.WinRename()
	if M.Rename(M.winSel, winName()) then M.WinPick(M.winSel) end
end

function M.WinDelete()
	if M.Delete(M.winSel) then M.WinPick(M.winSel) end
end

function M.WinDuplicate()
	local n = M.Duplicate(M.winSel, nil)
	if n then M.WinPick(n) end
end

-- clic : donne la specialisation au jeu choisi (reclic : la retire) ; clic droit : copie le jeu puis range la COPIE sur la specialisation.
function M.WinSpec(id, copy)
	local sel = M.winSel
	if not M.sets[sel].name then SUI.Print(L("msg.items.pickfirst")) return end
	if copy then
		local n = M.CopyToSpec(sel, id)
		if n then M.WinPick(n) end
		return
	end
	if tonumber(C.Get("items.spec" .. id)) == sel then M.SpecSet(id, nil) else M.SpecSet(id, sel) end
	M.WinRefresh()
end

function M.WinExport()
	local code = M.Export(M.winSel)
	if not code then SUI.Print(L("msg.items.pickfirst")) return end
	local e = M.win.share
	e:SetText(code)
	e:SetFocus()
	e:HighlightText()
end

function M.WinImport()
	local n = M.Import(M.win.share:GetText())
	if n then
		M.win.share:SetText("")
		M.win.share:ClearFocus()
		M.WinPick(n)
	end
end

function M.WinCompare()
	local cmp = M.win.cmp
	if cmp:IsShown() then
		cmp:Hide()
	else
		cmp:Show()
		M.RaiseSoon(M.win)
	end
	M.CmpRefresh()
end

-- clic gauche : prend ce que le personnage porte dans cet emplacement ; clic droit : retire l'emplacement du jeu.
function M.WinCell(sl, retire)
	local s = M.sets[M.winSel]
	if not s.name then
		SUI.Print(L("msg.items.pickfirst"))
		return
	end
	if retire then
		M.SetSlot(M.winSel, sl, nil)
	else
		local code = M.Code(GetInventoryItemLink("player", sl))
		if not code then
			SUI.Print(L("msg.items.slotempty", M.SlotName(sl)))
			return
		end
		M.SetSlot(M.winSel, sl, code)
	end
	M.WinRefresh()
end

local function tipCell()
	local c = this
	if not GameTooltip then return end
	GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
	local s = M.sets[M.winSel]
	local code = s and s.name and s.code[c.slotn]
	local _, _, id, suf = sfind(code or "", "^(%d+):(%-?%d+)")
	if id then
		pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id .. ":0:" .. suf .. ":0")   -- pcall : un addon tiers (AtlasLoot) intercepte et peut lever
		if c.lost then tipLine(L("mod.items.win.losttip"), T.c.bad) end
	else
		GameTooltip:AddLine(M.SlotName(c.slotn))
	end
	GameTooltip:AddLine(L("mod.items.win.celltip"))
	GameTooltip:Show()
end

-- Infobulle des boutons de specialisation de la fenetre.
function M.TipSpec(b)
	local id = b.specId
	GameTooltip:AddLine(L("mod.items.win.spectip", id))
	local k = tonumber(C.Get("items.spec" .. id))
	local cur = (k and M.sets[k] and M.sets[k].name) or L("choice.items.none")
	tipLine(L("mod.items.win.specnow", cur), T.c.text)
	tipLine(L("mod.items.win.spechelp"), T.c.dim)
end

function M.BuildCmp(w)
	local cmp = CreateFrame("Frame", nil, w)
	cmp:SetWidth(340)
	cmp:SetHeight(360)
	T.Backdrop(cmp, T.c.panel, T.c.border)
	cmp:SetPoint("TOPLEFT", w, "TOPRIGHT", 4, 0)
	cmp:EnableMouse(true)
	M.NewOwner(cmp)
	local t = T.Text(cmp, 12, T.c.text, "LEFT")
	t:SetPoint("TOPLEFT", cmp, "TOPLEFT", 10, -10)
	t:SetText(L("mod.items.cmp.title"))
	cmp.head = T.Text(cmp, 11, T.c.dim, "LEFT")
	cmp.head:SetPoint("TOPLEFT", cmp, "TOPLEFT", 10, -28)
	cmp.head:SetWidth(200)
	cmp.pick = M.Kid(cmp, T.Button(cmp, "-", 110, 18, function()
		M.cmpWith = M.NextNamed(M.cmpWith or M.winSel, 1, M.winSel)
		M.CmpRefresh()
	end))
	cmp.pick:SetPoint("TOPRIGHT", cmp, "TOPRIGHT", -8, -26)
	M.Tip(cmp.pick, "mod.items.cmp.picktip", "mod.items.cmp.pickhelp")
	cmp.lines = {}
	for i = 1, 19 do
		local ln = {}
		local y = -52 - (i - 1) * 15
		ln.slot = T.Text(cmp, 10, T.c.dim, "LEFT")
		ln.slot:SetPoint("TOPLEFT", cmp, "TOPLEFT", 10, y)
		ln.slot:SetWidth(70)
		ln.a = T.Text(cmp, 10, T.c.text, "LEFT")
		ln.a:SetPoint("TOPLEFT", cmp, "TOPLEFT", 84, y)
		ln.a:SetWidth(120)
		ln.b = T.Text(cmp, 10, T.c.text, "LEFT")
		ln.b:SetPoint("TOPLEFT", cmp, "TOPLEFT", 210, y)
		ln.b:SetWidth(120)
		cmp.lines[i] = ln
	end
	cmp.foot = T.Text(cmp, 10, T.c.dim, "LEFT")
	cmp.foot:SetPoint("BOTTOMLEFT", cmp, "BOTTOMLEFT", 10, 8)
	cmp.foot:SetWidth(320)
	cmp:Hide()
	w.cmp = M.Kid(w, cmp)
end

function M.BuildWin()
	if M.win then return end
	local w = CreateFrame("Frame", "ShikiUIBuilds", UIParent)
	w:SetWidth(462)
	w:SetHeight(334)
	T.Backdrop(w, T.c.panel, T.c.border)
	w:SetFrameStrata("DIALOG")
	w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	w:EnableMouse(true)
	w:SetMovable(true)
	w:SetClampedToScreen(true)
	w:RegisterForDrag("LeftButton")
	w:SetScript("OnDragStart", function() this:StartMoving() end)
	w:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	M.NewOwner(w)
	w:SetScript("OnShow", function()
		M.RaiseSoon(this)
		M.WinRefresh()
	end)
	w.title = T.Text(w, 13, T.c.text, "LEFT")
	w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -10)
	w.title:SetText(L("mod.items.win.title"))
	w.state = T.Text(w, 10, T.c.dim, "LEFT")
	w.state:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -12)
	w.state:SetWidth(270)
	local close = M.Kid(w, T.Button(w, "x", 20, 20, function() M.win:Hide() end))
	close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -6)
	w.rows = {}
	for k = 1, NSETS do
		local r = M.Kid(w, T.Button(w, "", 134, 20, function(btn) M.WinPick(btn.itemsSet) end))
		r.itemsSet = k
		r.label:SetWidth(126)
		r.warn = T.Text(r, 10, T.c.bad, "RIGHT")
		r.warn:SetPoint("RIGHT", r, "RIGHT", -3, 0)
		r:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -34 - (k - 1) * 22)
		M.Tip(r, nil, nil, M.TipSet)
		w.rows[k] = r
	end
	w.next = M.Kid(w, T.Button(w, L("mod.items.win.next"), 134, 20, function() M.Next() end))
	w.next.itemsNext = true
	w.next:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -258)
	M.Tip(w.next, "mod.items.win.next", "mod.items.win.nexttip")
	w.quickb = M.Kid(w, T.Button(w, L("mod.items.win.quick"), 134, 20, function() M.QuickToggle(M.win, false) end))
	w.quickb:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -282)
	w.quickb.itemsQuick = true
	M.Tip(w.quickb, "mod.items.win.quick", "mod.items.win.quicktip")
	w.edit = M.Kid(w, T.Edit(w, 150, 20))
	w.edit:SetMaxLetters(12)
	w.edit:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -34)
	M.Tip(w.edit, "mod.items.win.nametip", "mod.items.win.namehelp")
	w.rename = M.Kid(w, T.Button(w, L("mod.items.win.rename"), 70, 20, function() M.WinRename() end))
	w.rename:SetPoint("TOPLEFT", w, "TOPLEFT", 306, -34)
	M.Tip(w.rename, "mod.items.win.rename", "mod.items.win.renametip")
	w.del = M.Kid(w, T.Button(w, L("mod.items.win.delete"), 72, 20, function() M.WinDelete() end))
	w.del:SetPoint("TOPLEFT", w, "TOPLEFT", 380, -34)
	M.Tip(w.del, "mod.items.win.delete", "mod.items.win.deltip")
	w.save = M.Kid(w, T.Button(w, L("mod.items.win.save"), 196, 22, function() M.WinSave() end))
	w.save:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -60)
	M.Tip(w.save, "mod.items.win.save", "mod.items.win.savetip")
	w.equip = M.Kid(w, T.Button(w, L("mod.items.win.equip"), 100, 22, function() M.Equip(M.winSel) end))
	w.equip:SetPoint("TOPLEFT", w, "TOPLEFT", 352, -60)
	M.Tip(w.equip, "mod.items.win.equip", "mod.items.win.equiptip")
	w.cells = {}
	for i = 1, 19 do
		local c = CreateFrame("Button", nil, w)
		c.slotn = i
		c:SetWidth(38)
		c:SetHeight(38)
		local col = i - 1
		local row = 0
		while col >= 7 do
			col = col - 7
			row = row + 1
		end
		c:SetPoint("TOPLEFT", w, "TOPLEFT", 150 + col * 43, -92 - row * 43)
		T.Backdrop(c, T.c.inset, T.c.border)
		c.icon = c:CreateTexture(nil, "ARTWORK")
		c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
		c.icon:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
		c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		c.q = T.Text(c, 10, T.c.dim, "CENTER")
		c.q:SetPoint("CENTER", c, "CENTER", 0, 0)
		c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		c:SetScript("OnClick", function()
			local btn = this
			M.WinCell(btn.slotn, arg1 == "RightButton")
		end)
		c:SetScript("OnEnter", tipCell)
		c:SetScript("OnLeave", tipHide)
		M.Kid(w, c)
		w.cells[i] = c
	end
	w.miss = T.Text(w, 10, T.c.bad, "LEFT")
	w.miss:SetWidth(300)
	w.miss:SetHeight(12)
	w.miss:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -222)
	w.hint = T.Text(w, 10, T.c.dim, "LEFT")
	w.hint:SetWidth(300)
	w.hint:SetHeight(36)
	w.hint:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -238)
	w.hint:SetText(L("mod.items.win.hint"))
	w.dup = M.Kid(w, T.Button(w, L("mod.items.win.dup"), 68, 20, function() M.WinDuplicate() end))
	w.dup:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -278)
	M.Tip(w.dup, "mod.items.win.dup", "mod.items.win.duptip")
	w.cmpb = M.Kid(w, T.Button(w, L("mod.items.win.compare"), 68, 20, function() M.WinCompare() end))
	w.cmpb:SetPoint("TOPLEFT", w, "TOPLEFT", 221, -278)
	M.Tip(w.cmpb, "mod.items.win.compare", "mod.items.win.cmptip")
	w.spec = {}
	for id = 0, 3 do
		local b = M.Kid(w, T.Button(w, L("mod.items.win.spec", id), 38, 20, function(btn, mouse) M.WinSpec(btn.specId, mouse == "RightButton") end))
		b.specId = id
		b:SetPoint("TOPLEFT", w, "TOPLEFT", 292 + (id == 0 and 3 or (id - 1)) * 41, -278)
		M.Tip(b, nil, nil, M.TipSpec)
		w.spec[id] = b
	end
	w.share = M.Kid(w, T.Edit(w, 200, 20))
	w.share:SetMaxLetters(600)
	w.share:SetPoint("TOPLEFT", w, "TOPLEFT", 150, -304)
	M.Tip(w.share, "mod.items.win.sharetip", "mod.items.win.sharehelp")
	w.exp = M.Kid(w, T.Button(w, L("mod.items.win.export"), 48, 20, function() M.WinExport() end))
	w.exp:SetPoint("TOPLEFT", w, "TOPLEFT", 354, -304)
	M.Tip(w.exp, "mod.items.win.export", "mod.items.win.exptip")
	w.imp = M.Kid(w, T.Button(w, L("mod.items.win.import"), 48, 20, function() M.WinImport() end))
	w.imp:SetPoint("TOPLEFT", w, "TOPLEFT", 404, -304)
	M.Tip(w.imp, "mod.items.win.import", "mod.items.win.imptip")
	M.BuildCmp(w)
	w:Hide()
	tinsert(UISpecialFrames, "ShikiUIBuilds")
	M.win = w
end

function M.OpenBuilds()
	if not M.on then
		SUI.Print(L("msg.items.off"))
		return false
	end
	if not M.win then
		if SUI.InCombat() then
			SUI.Print(L("msg.items.combat"))
			return false
		end
		M.BuildWin()
	end
	if M.win:IsShown() then
		M.win:Hide()
		return true
	end
	if not (M.sets[M.winSel] and M.sets[M.winSel].name) then
		for k = 1, NSETS do
			if M.sets[k].name then
				M.winSel = k
				break
			end
		end
	end
	M.win.editFor = nil
	M.win:Show()
	return true
end

-- ---------------------------------------------------------------- menu rapide des jeux (acces en contexte)
-- Ouvert depuis : le bouton Builds de la fenetre du personnage, la barre (clic droit sur "Jeux"), le menu des bijoux, la fenetre Builds ou
-- /sui builds menu. Il ne depend d'aucune autre fenetre : il reste utilisable quand la fenetre du personnage est cachee ou rangee.
-- Clic = equiper ; clic droit = enregistrer ce qu'on porte ici (double clic droit sur un jeu existant) ; case "Jeu monture auto" ; un jeu par spe.
function M.CtxTick()
	M.ctxTask = nil
	M.CtxRefresh()
end

-- Coupe les minuteries d'interface (module coupe : rien ne tourne).
function M.CancelUi()
	if M.ctxTask then SUI.Cancel(M.ctxTask) M.ctxTask = nil end
	if M.cLvlTask then SUI.Cancel(M.cLvlTask) M.cLvlTask = nil end
	if M.armTask then SUI.Cancel(M.armTask) M.armTask = nil end
	local o = M.win
	if o and o.raiseTask then SUI.Cancel(o.raiseTask) o.raiseTask = nil end
	o = M.quick
	if o and o.raiseTask then SUI.Cancel(o.raiseTask) o.raiseTask = nil end
end

function M.CtxSoon()
	local b, q, w = M.cbtn, M.quick, M.win
	if not ((b and b:IsVisible()) or (q and q:IsShown()) or (w and w:IsShown())) then return end
	if not M.ctxTask then M.ctxTask = SUI.After(0.4, M.CtxTick, "items.ctx") end
end

function M.CtxRefresh()
	M.CharLabel()
	M.QuickRefresh()
	M.WinRefresh()
end

-- Active ou coupe le jeu de monture automatique depuis la case du menu rapide (le jeu retenu est memorise pour la prochaine fois).
function M.MountAuto(on)
	if on then
		local k = M.mountPick
		if not (k and M.sets[k] and M.sets[k].name) then
			local cur = M.CurrentSet()
			k = M.NextNamed(cur or 0, 1, cur)
			if not k then k = M.NextNamed(0, 1, nil) end
		end
		if not k then
			SUI.Print(L("msg.items.mount.noset"))
			M.CtxRefresh()
			return false
		end
		M.mountPick = k
		C.Set("items.auto.mount", tostring(k))
		SUI.Print(L("msg.items.mount.auto", M.sets[k].name))
	else
		local k = tonumber(C.Get("items.auto.mount"))
		if k then M.mountPick = k end
		C.Set("items.auto.mount", "none")
		SUI.Print(L("msg.items.mount.autooff"))
	end
	M.CtxRefresh()
	return true
end

-- Bouton du jeu de monture : active l'option s'il est coupe, sinon passe au jeu suivant (dir = 1) ou precedent (dir = -1).
function M.QuickMountPick(dir)
	local k = tonumber(C.Get("items.auto.mount"))
	if not (k and M.sets[k] and M.sets[k].name) then
		M.MountAuto(true)
		return
	end
	local n = M.NextNamed(k, dir, nil)
	if n and n ~= k then
		M.mountPick = n
		C.Set("items.auto.mount", tostring(n))
	end
end

function M.SpecCycle(id, dir)
	C.Set("items.spec" .. id, M.CycleChoice(C.Get("items.spec" .. id), dir))
end

-- Enregistre ce qu'on porte dans le jeu k. Emplacement libre : tout de suite (nom "Jeu<k>", renommable dans la fenetre) ; jeu existant : le
-- 2e clic droit dans les 4 s confirme (le jeu est ecrase).
function M.QuickSave(k)
	if SUI.InCombat() then
		SUI.Print(L("msg.items.combat"))
		return false
	end
	local s = M.sets[k]
	if not s then return false end
	local ok
	if not s.name then
		ok = M.SaveAt(k, M.UniqueName("Jeu" .. k))
	else
		if M.armed ~= k or GetTime() > M.armT then
			M.armed = k
			M.armT = GetTime() + 4
			SUI.Print(L("msg.items.quick.confirm", s.name))
			M.QuickRefresh()
			if M.armTask then SUI.Cancel(M.armTask) end
			M.armTask = SUI.After(4.1, M.QuickRefresh, "items.arm")
			return false
		end
		M.armed = nil
		ok = M.SaveAt(k, s.name)
	end
	M.CtxRefresh()
	return ok
end

function M.QuickRow(k, right)
	local s = M.sets[k]
	if not s then return end
	if right then
		M.QuickSave(k)
		return
	end
	if not s.name then
		SUI.Print(L("msg.items.quick.freehint"))
		return
	end
	M.Equip(k)
	if C.Get("items.quickclose") and M.quick then M.quick:Hide() end
end

local function put(o, q, x, y)
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", q, "TOPLEFT", x, -y)
end

function M.QuickRefresh()
	local q = M.quick
	if not q or not q:IsShown() then return end
	M.ScanHave()
	local cur = M.CurrentSet()
	setText(q.state, cur and L("mod.items.q.worn", M.sets[cur].name) or L("mod.items.q.wornnone"))
	local free = M.FreeSlot()
	local armed = M.armed and GetTime() <= M.armT
	local n = 0
	for k = 1, NSETS do
		local s = M.sets[k]
		if s.name or k == free then
			n = n + 1
			local r = q.rows[n]
			r.itemsSet = k
			put(r, q, 8, 40 + (n - 1) * 21)
			if s.name then
				if armed and M.armed == k then setText(r.label, L("mod.items.q.confirm")) else setText(r.label, k .. ". " .. s.name) end
				local miss = M.MissingIn(k)
				setText(r.warn, miss > 0 and ("!" .. miss) or (M.Count(k) .. ""))
				if miss > 0 then
					if r.warnState ~= 1 then
						r.warnState = 1
						r.warn:SetTextColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 1)
					end
				elseif r.warnState ~= 2 then
					r.warnState = 2
					r.warn:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
				end
			else
				setText(r.label, L("mod.items.q.new"))
				setText(r.warn, "")
			end
			T.SetSelected(r, cur == k)
			r:Show()
		end
	end
	for i = n + 1, NSETS do q.rows[i]:Hide() end
	local y = 40 + n * 21 + 6
	if n == 0 then
		y = 40
	end
	if C.Get("items.quickmount") then
		put(q.mlab, q, 10, y)
		put(q.mchk, q, 10, y + 14)
		put(q.mtog, q, 30, y + 14)
		put(q.mpick, q, 8, y + 34)
		put(q.mstate, q, 10, y + 56)
		local k = tonumber(C.Get("items.auto.mount"))
		local has = (k and M.sets[k] and M.sets[k].name) and true or false
		T.SetCheck(q.mchk, has)
		T.SetButtonText(q.mpick, has and L("mod.items.q.mountset", k .. ". " .. M.sets[k].name) or L("mod.items.q.mountpick"))
		local st
		if not has then
			st = L("mod.items.q.mountoff")
		else
			st = M.mounted and L("mod.items.q.mounted") or L("mod.items.q.onfoot")
			if M.mountSwapped then st = st .. " - " .. L("mod.items.q.remember") end
		end
		setText(q.mstate, st)
		q.mlab:Show() q.mchk:Show() q.mtog:Show() q.mpick:Show() q.mstate:Show()
		y = y + 72
	else
		q.mlab:Hide() q.mchk:Hide() q.mtog:Hide() q.mpick:Hide() q.mstate:Hide()
	end
	if C.Get("items.quickspec") then
		put(q.slab, q, 10, y)
		for id = 1, 3 do
			local b = q.spec[id]
			put(b, q, 8 + (id - 1) * 67, y + 14)
			local v = tonumber(C.Get("items.spec" .. id))
			local nm = (v and M.sets[v] and M.sets[v].name) and ssub(M.sets[v].name, 1, 6) or "-"
			T.SetButtonText(b, L("mod.items.q.specbtn", id, nm))
			b:Show()
		end
		q.slab:Show()
		y = y + 40
	else
		q.slab:Hide()
		for id = 1, 3 do q.spec[id]:Hide() end
	end
	put(q.bwin, q, 8, y)
	put(q.bnext, q, 108, y)
	q:SetHeight(y + 30)
end

function M.BuildQuick()
	if M.quick then return end
	local q = CreateFrame("Frame", "ShikiUIBuildsQuick", UIParent)
	q:SetWidth(214)
	q:SetHeight(300)
	T.Backdrop(q, T.c.panel, T.c.border)
	q:SetFrameStrata("DIALOG")
	q:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	q:EnableMouse(true)
	q:SetMovable(true)
	q:SetClampedToScreen(true)
	q:RegisterForDrag("LeftButton")
	q:SetScript("OnDragStart", function() this:StartMoving() end)
	q:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	M.NewOwner(q)
	q:SetScript("OnShow", function() M.RaiseSoon(this) end)
	q.title = T.Text(q, 12, T.c.text, "LEFT")
	q.title:SetPoint("TOPLEFT", q, "TOPLEFT", 10, -8)
	q.title:SetText(L("mod.items.win.title"))
	q.state = T.Text(q, 10, T.c.dim, "LEFT")
	q.state:SetPoint("TOPLEFT", q, "TOPLEFT", 10, -24)
	q.state:SetWidth(180)
	local close = M.Kid(q, T.Button(q, "x", 16, 16, function() M.quick:Hide() end))
	close:SetPoint("TOPRIGHT", q, "TOPRIGHT", -5, -5)
	q.rows = {}
	for i = 1, NSETS do
		local r = M.Kid(q, T.Button(q, "", 198, 20, function(btn, mouse) M.QuickRow(btn.itemsSet, mouse == "RightButton") end))
		r.quickRow = true
		r.itemsSet = i
		r.label:ClearAllPoints()
		r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
		r.label:SetJustifyH("LEFT")
		r.label:SetWidth(150)
		r.warn = T.Text(r, 10, T.c.dim, "RIGHT")
		r.warn:SetPoint("RIGHT", r, "RIGHT", -5, 0)
		M.Tip(r, nil, nil, M.TipSet)
		r:Hide()
		q.rows[i] = r
	end
	q.mlab = T.Text(q, 10, T.c.dim, "LEFT")
	q.mlab:SetText(L("mod.items.q.mountsec"))
	q.mchk = M.Kid(q, T.Check(q, function(on) M.MountAuto(on) end))
	M.Tip(q.mchk, "mod.items.q.mountauto", "mod.items.q.mounttip")
	q.mtog = CreateFrame("Button", nil, q)
	q.mtog:SetWidth(170)
	q.mtog:SetHeight(16)
	q.mtog.label = T.Text(q.mtog, 11, T.c.text, "LEFT")
	q.mtog.label:SetPoint("LEFT", q.mtog, "LEFT", 0, 0)
	q.mtog.label:SetText(L("mod.items.q.mountauto"))
	q.mtog:SetScript("OnClick", function()
		local k = tonumber(C.Get("items.auto.mount"))
		M.MountAuto(not (k and M.sets[k] and M.sets[k].name))
	end)
	M.Kid(q, q.mtog)
	M.Tip(q.mtog, "mod.items.q.mountauto", "mod.items.q.mounttip")
	q.mpick = M.Kid(q, T.Button(q, "", 198, 18, function(btn, mouse) M.QuickMountPick(mouse == "RightButton" and -1 or 1) end))
	M.Tip(q.mpick, "mod.items.q.mountpicktip", "mod.items.q.mountpickhelp")
	q.mstate = T.Text(q, 10, T.c.dim, "LEFT")
	q.mstate:SetWidth(196)
	q.slab = T.Text(q, 10, T.c.dim, "LEFT")
	q.slab:SetText(L("mod.items.q.specsec"))
	q.spec = {}
	for id = 1, 3 do
		local b = M.Kid(q, T.Button(q, "", 64, 18, function(btn, mouse) M.SpecCycle(btn.specId, mouse == "RightButton" and -1 or 1) end))
		b.specId = id
		M.Tip(b, nil, nil, M.TipSpecQuick)
		q.spec[id] = b
	end
	q.bwin = M.Kid(q, T.Button(q, L("mod.items.q.window"), 98, 20, function() M.OpenBuildsOnly() end))
	M.Tip(q.bwin, "mod.items.q.window", "mod.items.q.windowtip")
	q.bnext = M.Kid(q, T.Button(q, L("mod.items.win.next"), 98, 20, function() M.Next() end))
	q.bnext.itemsNext = true
	M.Tip(q.bnext, "mod.items.win.next", "mod.items.win.nexttip")
	q:Hide()
	tinsert(UISpecialFrames, "ShikiUIBuildsQuick")
	M.quick = q
end

function M.TipSpecQuick(b)
	local id = b.specId
	GameTooltip:AddLine(L("mod.items.win.spectip", id))
	local k = tonumber(C.Get("items.spec" .. id))
	local cur = (k and M.sets[k] and M.sets[k].name) or L("choice.items.none")
	tipLine(L("mod.items.win.specnow", cur), T.c.text)
	tipLine(L("mod.items.q.spechelp"), T.c.dim)
end

-- Ouvre la fenetre Builds sans jamais la refermer (le bouton du menu rapide ne bascule pas).
function M.OpenBuildsOnly()
	if M.win and M.win:IsShown() then return true end
	return M.OpenBuilds()
end

-- anchor : cadre sous lequel poser le menu (ou nil : il reste ou il est) ; up : l'ouvrir au-dessus de l'ancre.
function M.QuickOpen(anchor, up)
	if not M.on then
		SUI.Print(L("msg.items.off"))
		return false
	end
	if not M.quick then
		if SUI.InCombat() then
			SUI.Print(L("msg.items.combat"))
			return false
		end
		M.BuildQuick()
	end
	local q = M.quick
	if anchor then
		q:ClearAllPoints()
		if up then q:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2) else q:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2) end
	end
	q:Show()
	M.QuickRefresh()
	return true
end

function M.QuickToggle(anchor, up)
	if M.quick and M.quick:IsShown() then
		M.quick:Hide()
		return true
	end
	return M.QuickOpen(anchor, up)
end

-- ---------------------------------------------------------------- bouton de contexte sur la fenetre du personnage
-- Cree par ce module (rien dans Mod_Skin) : enfant de l'onglet Personnage (PaperDollFrame, sinon CharacterFrame), ancre au cadre Blizzard.
-- Clic = menu rapide ; clic droit = fenetre Builds. Son niveau est recale a l'affichage et au survol (le client le change apres coup).
M.CHARPOS = {
	top = { "TOPRIGHT", "TOPRIGHT", -112, -14 },
	bottom = { "BOTTOMLEFT", "BOTTOMLEFT", 24, 84 },
	side = { "TOPLEFT", "TOPRIGHT", -2, -150 },
}
M.CHARW = { label = 54, current = 78, compact = 26 }

function M.CharLevel()
	local b = M.cbtn
	if not b or not M.cpar then return end
	local lv = M.cpar:GetFrameLevel()
	if type(lv) == "number" then b:SetFrameLevel(lv + 8) end
end

function M.CharLevelTick()
	M.cLvlTask = nil
	M.CharLevel()
end

function M.CharLabel()
	local b = M.cbtn
	if not b or not b:IsVisible() then return end
	local style = C.Get("items.charstyle")
	local cur = M.CurrentSet()
	local text
	if style == "compact" then
		text = L("mod.items.char.compact")
	elseif style == "current" and cur then
		text = M.sets[cur].name
	else
		text = L("mod.items.char.label")
	end
	if b.txt ~= text then
		b.txt = text
		T.SetButtonText(b, text)
	end
	T.SetSelected(b, cur ~= nil)
end

function M.TipChar(b)
	M.CharLevel()
	GameTooltip:AddLine(L("mod.items.char.tiptitle"))
	local cur = M.CurrentSet()
	tipLine(cur and L("mod.items.q.worn", M.sets[cur].name) or L("mod.items.q.wornnone"), T.c.text)
	tipLine(L("mod.items.char.tipbody"), T.c.dim)
end

function M.CharClick(mouse)
	if mouse == "RightButton" then
		M.OpenBuilds()
	else
		M.QuickToggle(M.cbtn, false)
	end
end

function M.BuildChar()
	if M.cbtn then return end
	local cf = getglobal("CharacterFrame")
	if not cf then return end                    -- pas d'interface Blizzard (hors jeu) : pas de bouton de contexte
	local par = getglobal("PaperDollFrame") or cf
	M.cf, M.cpar = cf, par
	local b = T.Button(par, L("mod.items.char.label"), M.CHARW.label, 16, function(btn, mouse) M.CharClick(mouse) end)
	b.ctxChar = true
	b.itemsQuick = true
	M.cbtn = b
	b:SetScript("OnShow", function()
		M.CharLevel()
		M.CharLabel()
		if not M.cLvlTask then M.cLvlTask = SUI.After(0.2, M.CharLevelTick, "items.lvl") end
	end)
	M.Tip(b, nil, nil, M.TipChar)
	M.CharApply()
end

function M.CharApply()
	if not M.cbtn then
		if not (M.on and C.Get("items.charbtn")) or not getglobal("CharacterFrame") then return end
		SUI.WhenSafe(M.BuildChar)
		return
	end
	local b = M.cbtn
	local pos = M.CHARPOS[C.Get("items.charpos")] or M.CHARPOS.top
	b:ClearAllPoints()
	b:SetPoint(pos[1], M.cf, pos[2], pos[3], pos[4])
	b:SetWidth(M.CHARW[C.Get("items.charstyle")] or M.CHARW.label)
	b.txt = nil
	M.CharLevel()
	if M.on and C.Get("items.charbtn") then b:Show() else b:Hide() end
	M.CharLabel()
end

-- /sui builds diag : etat du bouton de contexte et du menu rapide (niveau recale, parent, visibilite).
function M.Diag()
	local function lv(f) return f and tostring(f:GetFrameLevel()) or "-" end
	SUI.Print(L("msg.items.diag.char", tostring(getglobal("CharacterFrame") ~= nil), tostring(M.cbtn ~= nil),
		tostring(M.cbtn and M.cbtn:IsVisible() or false), lv(M.cbtn) .. "/" .. lv(M.cpar)))
	SUI.Print(L("msg.items.diag.quick", tostring(M.quick ~= nil), tostring(M.quick and M.quick:IsShown() or false), lv(M.quick),
		tostring(M.win and M.win:IsShown() or false)))
end

function M.ApplyOptions()
	M.CharApply()
	local f = M.frame
	if not f then return end
	local sz = C.Get("items.size")
	local showT = C.Get("items.trinkets")
	local showS = C.Get("items.showsets")
	local showB = C.Get("items.buildbtn")
	for i = 1, 2 do
		local b = f.worn[i]
		b:SetWidth(sz)
		b:SetHeight(sz)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + (i - 1) * (sz + 3), -4)
		if showT then b:Show() else b:Hide() end
	end
	f.toggle:SetHeight(sz)
	f.toggle:ClearAllPoints()
	f.toggle:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + 2 * (sz + 3), -4)
	if showT then f.toggle:Show() else f.toggle:Hide() end
	local bx = showT and (4 + 2 * (sz + 3) + 19) or 4
	f.builds:SetHeight(sz)
	f.builds:ClearAllPoints()
	f.builds:SetPoint("TOPLEFT", f, "TOPLEFT", bx, -4)
	if showB then f.builds:Show() else f.builds:Hide() end
	local top = (showT or showB) and (sz + 8) or 4
	local rows = 0
	local shown = 0
	for k = 1, NSETS do
		local b = f.sets[k]
		local s = M.sets[k]
		if showS and s and s.name then
			local idx = shown
			shown = shown + 1
			local r = math.floor(idx / 5)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + (idx - r * 5) * 46, -(top + r * 18))
			setText(b.label, s.name)
			b:Show()
			if r + 1 > rows then rows = r + 1 end
		else
			b:Hide()
		end
	end
	local w = showT and (8 + 2 * (sz + 3) + 22) or 8
	if showB then
		w = bx + 48
		if not showT and w < 60 then w = 60 end
	end
	local setw = 8 + (shown > 5 and 5 or shown) * 46
	local hov = C.Get("items.hover") and shown > 0 and (showT or showB)
	if not hov and shown > 0 and setw > w then w = setw end
	if not showB and not showT and w < 60 then w = 60 end
	f:SetWidth(w)
	-- survol : les lignes de builds ne s'affichent que sous la souris (le cadre ne garde que la rangee des bijoux)
	M.hoverOn = C.Get("items.hover") and shown > 0 and (showT or showB)
	if M.hoverOn then
		f:SetHeight(top)
		f.setbg:ClearAllPoints()
		f.setbg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 1)
		f.setbg:SetWidth(setw)
		f.setbg:SetHeight(rows * 18 + 6)
	else
		f:SetHeight(top + rows * 18 + 4)
	end
	f:SetAlpha(C.Get("items.alpha"))
	if not C.Get("items.cooldowns") then            -- temps de recharge coupes : les chiffres deja affiches disparaissent tout de suite
		for i = 1, 2 do setText(f.worn[i].cd, "") end
		for i = 1, MAXMENU do setText(f.menu.rows[i].cd, "") end
	end
	f.menu:ClearAllPoints()
	if C.Get("items.growup") then
		f.menu:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
	else
		f.menu:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
	end
	f.menu:SetWidth(150)
	for i = 1, MAXMENU do
		local e = f.menu.rows[i]
		e:SetWidth(142)
		e:SetHeight(sz)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", f.menu, "TOPLEFT", 4, -(4 + (i - 1) * (sz + 2)))
		e.icon:SetWidth(sz - 2)
		e.icon:SetHeight(sz - 2)
	end
	if C.Get("items.bar") and (showT or showB or shown > 0) then
		f:Show()
		if not M.cdTask then M.cdTask = SUI.Every(C.Get("items.tick"), M.CdTick, "items.cd", true) end
	else
		f:Hide()
		f.menu:Hide()
		M.menuOpen = false
		if M.cdTask then
			SUI.Cancel(M.cdTask)
			M.cdTask = nil
		end
	end
	if M.hoverOn then
		if not M.hoverTask then M.hoverTask = SUI.Every(0.15, M.HoverTick, "items.hover", true) end
	elseif M.hoverTask then
		SUI.Cancel(M.hoverTask)
		M.hoverTask = nil
	end
	M.hoverShown = nil
	M.HoverTick()
	M.dirty = true
end

-- Affiche les builds seulement quand la souris est sur la barre (ou sur leur cadre) ; sans l'option, ils restent toujours visibles.
function M.HoverTick()
	local f = M.frame
	if not f or not f.setbg then return end
	local want = true
	if M.hoverOn then
		want = false
		if MouseIsOver then
			if MouseIsOver(f) then want = true end
			if not want and M.hoverShown and MouseIsOver(f.setbg) then want = true end
		else
			want = true
		end
	end
	if M.hoverShown == want then return end
	M.hoverShown = want
	for k = 1, NSETS do
		local b = f.sets[k]
		local s = M.sets[k]
		if want and C.Get("items.showsets") and s and s.name then b:Show() else b:Hide() end
	end
	if M.hoverOn and want then f.setbg:Show() else f.setbg:Hide() end
end

function M.Build()
	if M.frame then return end
	local f = T.Panel(UIParent, 120, 60)
	f:SetFrameStrata("MEDIUM")
	f.worn = {}
	for i = 1, 2 do
		local b = CreateFrame("Button", nil, f)
		b.slot = 12 + i
		b.link = nil
		T.Backdrop(b, T.c.inset, T.c.border)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		b.cd = T.Text(b, 12, T.c.warn, "CENTER", true)
		b.cd:SetPoint("CENTER", b, "CENTER", 0, 0)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function()
			local btn = this
			if arg1 == "RightButton" then
				M.ToggleMenu(btn.slot)
			else
				UseInventoryItem(btn.slot)
			end
		end)
		b:SetScript("OnEnter", tipWorn)
		b:SetScript("OnLeave", tipHide)
		f.worn[i] = b
	end
	f.toggle = T.Button(f, "v", 16, 30, function() M.ToggleMenu(M.menuSlot) end)
	M.Tip(f.toggle, "mod.items.bar.toggletip", "mod.items.bar.togglehelp")
	f.builds = T.Button(f, L("mod.items.bar.builds"), 44, 30, function(btn, mouse)
		if mouse == "RightButton" then M.QuickToggle(M.frame.builds, C.Get("items.growup")) else M.OpenBuilds() end
	end)
	f.builds.itemsQuick = true
	M.Tip(f.builds, "mod.items.bar.buildstip", "mod.items.bar.buildshelp")
	f.setbg = T.Panel(f, 100, 20)
	f.setbg:SetFrameLevel(f:GetFrameLevel() + 1)
	f.setbg:Hide()
	f.sets = {}
	for k = 1, NSETS do
		local b = T.Button(f, "", 44, 16, function(btn, mouse) M.Equip(btn.setn) end)
		b.setn = k
		b:SetFrameLevel(f.setbg:GetFrameLevel() + 2)
		b.itemsSet = k
		b.label:SetWidth(40)
		M.Tip(b, nil, nil, M.TipSet)
		f.sets[k] = b
	end
	local menu = T.Panel(f, 150, 60)
	menu:SetFrameStrata("DIALOG")
	menu:Hide()
	menu.rows = {}
	for i = 1, MAXMENU do
		local e = CreateFrame("Button", nil, menu)
		T.Backdrop(e, T.c.inset, T.c.border)
		e.icon = e:CreateTexture(nil, "ARTWORK")
		e.icon:SetPoint("LEFT", e, "LEFT", 1, 0)
		e.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		e.name = T.Text(e, 11, T.c.text, "LEFT")
		e.name:SetPoint("LEFT", e, "LEFT", 28, 0)
		e.name:SetWidth(90)
		e.cd = T.Text(e, 11, T.c.warn, "RIGHT")
		e.cd:SetPoint("RIGHT", e, "RIGHT", -3, 0)
		e:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		e:SetScript("OnClick", function()
			local btn = this
			local slot = (arg1 == "RightButton") and 14 or 13
			if M.SwapTrinket(btn.bag, btn.slotn, slot) then
				M.menuOpen = false
				M.RefreshMenu()
			end
		end)
		e:SetScript("OnEnter", tipBag)
		e:SetScript("OnLeave", tipHide)
		e:Hide()
		menu.rows[i] = e
	end
	menu.link = T.Button(menu, L("mod.items.bar.link"), 142, 14, function() M.QuickToggle(M.frame.menu, false) end)
	menu.link:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 4, 4)
	M.Tip(menu.link, "mod.items.bar.link", "mod.items.bar.linktip")
	f.menu = menu
	M.frame = f
	M.BuildProxies()
	SUI.Layout.Register(f, "items", "CENTER", 0, -260)
	T.OnAccent(function() if M.frame then M.dirty = true end end)
	M.ApplyOptions()
	M.RefreshWorn()
end

-- ---------------------------------------------------------------- reglages et cycle de vie
function M.OnKey(key, value)
	if not M.on then return end
	if key == nil or string.sub(key, 1, 9) == "items.set" and string.len(key) <= 11 then M.ReadSets() end
	if key == nil or key == "items.mount.extra" then M.ReadExtra() end
	if key == nil or sfind(key, "^items%.set%d") or key == "items.auto.mount" then M.UpdateMountEvents() end
	if key == nil or sfind(key, "^items%.spec%d") then M.UpdateSpecEvents() end
	M.ApplyOptions()
	M.CtxRefresh()
	if M.cdTask and (key == nil or key == "items.tick") then
		SUI.Cancel(M.cdTask)
		M.cdTask = nil
		M.ApplyOptions()
	end
end

function M.Enable()
	M.on = true
	M.ReadSets()
	M.ReadExtra()
	SUI.WhenSafe(M.Build)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombatStart)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	SUI.On("PLAYER_ALIVE", M.OnAlive)
	SUI.On("PLAYER_UNGHOST", M.OnAlive)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnZone)
	SUI.On("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.On("BAG_UPDATE", M.OnDirty)
	SUI.On("UNIT_INVENTORY_CHANGED", M.OnDirty)
	SUI.On("BANKFRAME_OPENED", M.OnBank)
	SUI.On("BANKFRAME_CLOSED", M.OnBank)
	M.zone = M.ZoneKind()
	M.UpdateMountEvents()
	M.UpdateSpecEvents()
	if not M.watching then
		M.watching = true
		C.Watch("items.", M.OnKey)
		C.Watch("ui.scale", function() if M.frame then M.dirty = true end end)
	end
	if M.frame then M.ApplyOptions() end
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombatStart)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	SUI.Off("PLAYER_ALIVE", M.OnAlive)
	SUI.Off("PLAYER_UNGHOST", M.OnAlive)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnZone)
	SUI.Off("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.Off("BAG_UPDATE", M.OnDirty)
	SUI.Off("UNIT_INVENTORY_CHANGED", M.OnDirty)
	SUI.Off("BANKFRAME_OPENED", M.OnBank)
	SUI.Off("BANKFRAME_CLOSED", M.OnBank)
	M.BankStop()
	M.bankOpen = false
	M.Stop()
	M.pending, M.nextSet = nil, nil
	M.UpdateMountEvents()                 -- M.on est faux : coupe les evenements d'aura
	M.UpdateSpecEvents()
	M.MountDone()
	M.mounted = false
	M.restorePending = false
	if M.win then M.win:Hide() end
	if M.quick then M.quick:Hide() end
	if M.cbtn then M.cbtn:Hide() end
	M.CancelUi()
	if M.cdTask then
		SUI.Cancel(M.cdTask)
		M.cdTask = nil
	end
	M.menuOpen = false
	if M.frame then
		M.frame:Hide()
		M.frame.menu:Hide()
	end
end

-- ---------------------------------------------------------------- commandes
-- /sui items mount [add <fragment> | clear | list] : fragments d'icone d'aura reconnus comme monture ; "list" montre les icones des auras du joueur.
function M.MountCommand(arg)
	local word, rest = arg, ""
	local sp = sfind(arg, " ", 1, true)
	if sp then
		word = ssub(arg, 1, sp - 1)
		rest = ssub(arg, sp + 1)
	end
	word = slower(word)
	if word == "add" and rest ~= "" then
		local cur = C.Get("items.mount.extra") or ""
		if cur ~= "" then cur = cur .. "," end
		C.SetBase("items.mount.extra", cur .. rest)
		SUI.Print(L("msg.items.mount.added", rest))
	elseif word == "clear" then
		C.SetBase("items.mount.extra", "")
		SUI.Print(L("msg.items.mount.cleared"))
	elseif word == "list" then
		local fn = getglobal("UnitBuff")
		local n = 0
		if type(fn) == "function" then
			for i = 1, 32 do
				local tex = fn("player", i)
				if not tex then break end
				n = n + 1
				SUI.Print(i .. " : " .. tostring(tex))
			end
		end
		if n == 0 then SUI.Print(L("msg.items.mount.noaura")) end
	else
		local k = tonumber(C.Get("items.auto.mount"))
		SUI.Print(L("msg.items.mount.status", (k and M.sets[k] and M.sets[k].name) or "-", M.mounted and 1 or 0, M.mountSwapped and 1 or 0,
			C.Get("items.mount.extra") or ""))
	end
end

local function nextWord(s)
	local _, _, w, rest = sfind(s or "", "^%s*(%S+)%s*(.*)$")
	return w, rest
end

-- /sui builds compare <a> [<b>] : liste les emplacements qui different (b : le jeu choisi dans la fenetre si absent).
function M.CompareCommand(arg)
	local ra, rest = nextWord(arg)
	local rb = nextWord(rest)
	local a = ra and M.Find(ra)
	local b = rb and M.Find(rb) or M.NextNamed(a or 0, 1, a)
	if not (a and b and a ~= b) then
		SUI.Print(L("mod.items.cmp.need"))
		return
	end
	local n = M.Compare(a, b)
	SUI.Print(L("msg.items.cmp.head", M.sets[a].name, M.sets[b].name, n))
	if n == 0 then return end
	for i = 1, n do
		SUI.Print(L("msg.items.cmp.line", M.SlotName(M.dS[i]), M.CodeName(M.dA[i]), M.CodeName(M.dB[i])))
	end
end

-- /sui builds spec <1|2|3|0> <jeu|none> [copy] : jeu equipe quand la specialisation change ; copy : range une COPIE du jeu.
function M.SpecCommand(arg)
	local rid, rest = nextWord(arg)
	local rj, rest2 = nextWord(rest)
	local id = tonumber(rid)
	if not id or id < 0 or id > 3 or not rj then
		SUI.Print(L("help.items.spec"))
		return
	end
	if slower(rj) == "none" then
		M.SpecSet(id, nil)
		return
	end
	local k = M.Find(rj)
	if not k then
		SUI.Print(L("msg.items.notfound", rj))
		return
	end
	local flag = nextWord(rest2)
	if flag and slower(flag) == "copy" then M.CopyToSpec(k, id) else M.SpecSet(id, k) end
end

function M.Command(rest)
	if not M.on then
		SUI.Print(L("msg.items.off"))
		return
	end
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = ssub(rest, sp + 1)
	end
	word = slower(word)
	if word == "save" then
		M.Save(arg)
	elseif word == "equip" or word == "use" then
		M.Equip(arg)
	elseif word == "del" or word == "delete" then
		M.Delete(arg)
	elseif word == "next" then
		M.Next()
	elseif word == "rename" then
		local sp2 = sfind(arg, " ", 1, true)
		if sp2 then
			local k = M.Find(ssub(arg, 1, sp2 - 1))
			if k then M.Rename(k, ssub(arg, sp2 + 1)) else SUI.Print(L("msg.items.notfound", ssub(arg, 1, sp2 - 1))) end
		else
			SUI.Print(L("help.items.builds"))
		end
	elseif word == "builds" or word == "open" or word == "win" then
		M.OpenBuilds()
	elseif word == "menu" or word == "quick" then
		M.QuickToggle(nil, false)
	elseif word == "diag" then
		M.Diag()
	elseif word == "dup" or word == "copy" then
		local ref, nm = nextWord(arg)
		local k = ref and M.Find(ref)
		if k then M.Duplicate(k, nm) else SUI.Print(L("msg.items.notfound", tostring(ref))) end
	elseif word == "export" then
		local k = M.Find(arg)
		local code = k and M.Export(k)
		if code then SUI.Print(L("msg.items.exported", M.sets[k].name, code)) else SUI.Print(L("msg.items.notfound", arg)) end
	elseif word == "import" then
		M.Import(arg)
	elseif word == "compare" or word == "cmp" then
		M.CompareCommand(arg)
	elseif word == "spec" then
		M.SpecCommand(arg)
	elseif word == "mount" then
		M.MountCommand(arg)
	elseif word == "list" then
		local n = 0
		for k = 1, NSETS do
			if M.sets[k].name then
				n = n + 1
				SUI.Print(L("msg.items.list.line", k, M.sets[k].name, M.Count(k)))
			end
		end
		if n == 0 then SUI.Print(L("msg.items.list.none")) end
	else
		SUI.Print(L("msg.items.status", M.busy and 1 or 0, M.pending and getSet(M.pending).name or "-"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("items", 29)

local function opt(key, typ, order, def, extra)
	local o = { key = "items." .. key, type = typ, cat = "items", label = "opt.items." .. key, tip = "tip.items." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function setText2(o, v)
	if v == "none" then return L("choice.items.none") end
	local s = M.sets[tonumber(v)]
	if s and s.name then return v .. " : " .. s.name end
	return v .. " : " .. L("choice.items.free")
end

SUI.RegisterModule("items", {
	default = false,
	cost = "medium",
	options = {
		opt("bar", "bool", 10, true, { simple = true }),
		opt("trinkets", "bool", 20, true, { simple = true }),
		opt("showsets", "bool", 30, true, { simple = true }),
		opt("size", "number", 40, 30, { min = 20, max = 48, step = 2, simple = true }),
		opt("cooldowns", "bool", 50, true),
		opt("growup", "bool", 60, false),
		opt("hover", "bool", 65, false, { simple = true }),
		opt("menumax", "number", 70, 6, { min = 2, max = 8, step = 1 }),
		opt("alpha", "number", 80, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("tick", "number", 90, 0.5, { min = 0.2, max = 1, step = 0.1 }),
		opt("queue", "bool", 100, true),
		opt("bank", "bool", 105, true),
		opt("announce", "bool", 110, true),
		opt("auto.combat", "choice", 120, "none", { choices = M.choices, choiceText = setText2, simple = true }),
		opt("auto.rest", "choice", 130, "none", { choices = M.choices, choiceText = setText2, simple = true }),
		opt("auto.raid", "choice", 140, "none", { choices = M.choices, choiceText = setText2 }),
		opt("auto.party", "choice", 150, "none", { choices = M.choices, choiceText = setText2 }),
		opt("auto.pvp", "choice", 160, "none", { choices = M.choices, choiceText = setText2 }),
		opt("auto.world", "choice", 170, "none", { choices = M.choices, choiceText = setText2 }),
		opt("auto.mount", "choice", 175, "none", { choices = M.choices, choiceText = setText2, simple = true }),
		opt("spec1", "choice", 180, "none", { choices = M.choices, choiceText = setText2 }),
		opt("spec2", "choice", 181, "none", { choices = M.choices, choiceText = setText2 }),
		opt("spec3", "choice", 182, "none", { choices = M.choices, choiceText = setText2 }),
		opt("spec0", "choice", 183, "none", { choices = M.choices, choiceText = setText2 }),
		opt("buildbtn", "bool", 35, true),
		opt("charbtn", "bool", 36, true, { simple = true }),
		opt("charpos", "choice", 37, "top", { choices = { "top", "bottom", "side" } }),
		opt("charstyle", "choice", 38, "label", { choices = { "label", "current", "compact" } }),
		opt("quickmount", "bool", 39, true),
		opt("quickspec", "bool", 41, true),
		opt("quickclose", "bool", 42, true),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : les 10 jeux, ecrits par /sui items save.
do
	local defs = {}
	for k = 1, NSETS do defs["items.set" .. k] = "" end
	defs["items.mount.extra"] = ""
	SUI.Config.Register(defs)
end

-- Equivalent pfUI : module "equipmentmanager" (releve dans pfUI\modules) ; ShikiUI attend tant que pfUI le fait tourner.
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.items then SUI.Migrate.MAP.items = { "equipmentmanager" } end

-- Mode Raid : barre rafraichie moins souvent.
SUI.Config.AddPreset("raid", "*", { ["items.tick"] = 1 })

SUI.RegisterCommand("items", function(rest) M.Command(rest or "") end, "help.items")

-- /sui builds : ouvre la fenetre ; /sui builds equip <n|nom> | next | save <nom> | list | del <n|nom> | rename <n|nom> <nouveau>
SUI.RegisterCommand("builds", function(rest)
	rest = rest or ""
	if rest == "" or sfind(rest, "^%s*$") then
		M.OpenBuilds()
	else
		M.Command(rest)
	end
end, "help.items.builds")

-- Page du menu : bouton d'ouverture de la fenetre Builds (au-dessus des reglages de la categorie).
function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "items" and Mn.GridBtn then
			Mn.Section(L("mod.items.sec.builds"), "")
			Mn.Para(L("mod.items.help.items.builds"), 34)
			Mn.GridBtn(L("mod.items.win.open"), 3, 208, 24, function() M.OpenBuilds() end, false)
			Mn.GridBtn(L("mod.items.q.open"), 3, 208, 24, function() M.QuickToggle(nil, false) end, false)
		end
		orig()
	end
end

M.HookMenu()
