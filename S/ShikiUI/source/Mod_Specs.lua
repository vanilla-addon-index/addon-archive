-- ShikiUI Specs : detection de la specialisation (points de talents) et jeux de reglages appliques automatiquement au changement de spe.
-- API 1.12 utilisee (toutes gardees par type()/pcall) : GetNumTalentTabs, GetTalentTabInfo(onglet) -> nom, icone, points depenses, fond ;
-- evenements CHARACTER_POINTS_CHANGED, SPELLS_CHANGED, PLAYER_ENTERING_WORLD, PLAYER_REGEN_ENABLED ; pour les barres (optionnelles) :
-- HasAction, GetActionText, GameTooltip:SetAction, GetSpellName, PickupSpell, PickupMacro, GetMacroInfo, PickupContainerItem, PlaceAction, ClearCursor.
-- Serveur : Turtle WoW (1.12). Un changement de spe passe par le Goblin Brainwashing Device (double spe), un PNJ de reinitialisation ou
-- l'ecran des talents : dans tous les cas les points par arbre changent et le client envoie CHARACTER_POINTS_CHANGED / SPELLS_CHANGED.
-- Simple Action Sets (SAS) ne reagit, lui, qu'au PNJ Brainwasher (fermeture de la fenetre de dialogue) : ce module le complete sans le remplacer.
--
-- Vocabulaire : "spe" = arbre de talents dominant (1, 2 ou 3 = ordre des onglets du client ; 0 = aucune dominante : moins de
-- specs.minpoints points ou egalite). "jeu" (preset) = ensemble NOMME et OPTIONNEL de reglages : profil ShikiUI a activer, role, mise en page
-- (Layout), mode Normal / Raid, barres d'action (hors SAS), jeu SAS a charger. Une spe est LIEE a un jeu ; au changement de spe, le jeu lie
-- est applique (hors combat ; en combat il attend la fin).
-- DONNEES : ShikiUIDB.global.specs["Nom-Royaume"] = { last = spe, assign = { [0..3] = nomDuJeu }, presets = { nom = {...} } }
-- (via SUI.Config.GetGlobal / SetGlobal, uniquement chaines / nombres / tables ; jamais de fonction ni de frame).
-- BOUTON "Jeux ShikiUI" : cree par ce module (rien dans Mod_Skin), enfant de TalentFrame (fenetre a chargement a la demande :
-- ADDON_LOADED Blizzard_TalentUI). Clic = petit menu (appliquer un jeu, enregistrer ici, page Specs, Builds si SUI.Items) ; clic droit =
-- page Specs. Son niveau (et celui du menu) est recale a l'affichage et au survol : le client change le niveau du contenu apres coup.
-- NON VERIFIE EN JEU : tout (aucun client n'a ete lance pour ecrire ce module) - voir le rapport.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert

local M = {}
SUI.Specs = M

M.on = false
M.NSLOT = 120               -- emplacements d'action du joueur (6 pages de 12 x 2 + barres bonus)
M.MAXPRESETS = 12
M.cur = nil                 -- dernier balayage : { n, id, total, pts = {}, names = {} }

-- ---------------------------------------------------------------- petits outils
local function announceBars() return C.Get("specs.announce") end

local function say(key, a, b, c)
	if key then SUI.Print(L(key, a, b, c)) end
end

-- sayr(ok, cle, a, b) : affiche directement le resultat d'une fonction qui retourne ok, cle, a, b
local function sayr(ok, key, a, b)
	if key then SUI.Print(L(key, a, b)) end
end

local function validName(name)
	if type(name) ~= "string" then return false end
	local len = string.len(name)
	if len < 1 or len > 24 then return false end
	return string.find(name, "^[%w_%-]+$") ~= nil
end

local function lower(s)
	return string.lower(tostring(s or ""))
end

local function words(s)
	local out = {}
	local rest = s or ""
	while true do
		local a, b, w = string.find(rest, "^%s*(%S+)")
		if not a then break end
		tinsert(out, w)
		rest = string.sub(rest, b + 1)
	end
	return out
end

local function inList(list, v)
	for i = 1, getn(list) do
		if list[i] == v then return true end
	end
	return false
end

-- element suivant de list apres v (retour au debut ; "" si v inconnu -> premier)
local function nextIn(list, v)
	for i = 1, getn(list) do
		if list[i] == v then return list[i + 1] end
	end
	return list[1]
end

-- ---------------------------------------------------------------- detection de la specialisation
-- Lit les points de talents par arbre. Retourne nil si l'API est absente / illisible (jamais d'erreur).
-- id : arbre dominant (strictement le plus de points, au moins specs.minpoints points depenses au total) ; sinon 0.
function M.Scan()
	local fnum, finfo = getglobal("GetNumTalentTabs"), getglobal("GetTalentTabInfo")
	if type(fnum) ~= "function" or type(finfo) ~= "function" then return nil end
	local ok, n = pcall(fnum)
	if not ok or type(n) ~= "number" or n < 1 then return nil end
	if n > 3 then n = 3 end
	local s = { n = n, id = 0, total = 0, pts = {}, names = {} }
	local best, bestPts, second = 0, 0, 0
	for i = 1, n do
		local ok2, name, _, pts = pcall(finfo, i)
		if not ok2 then return nil end
		pts = tonumber(pts) or 0
		s.pts[i] = pts
		s.names[i] = (type(name) == "string" and name ~= "") and name or ("#" .. i)
		s.total = s.total + pts
		if pts > bestPts then
			second = bestPts
			best, bestPts = i, pts
		elseif pts > second then
			second = pts
		end
	end
	local minpts = C.Get("specs.minpoints") or 0
	if best > 0 and bestPts > second and s.total >= minpts and bestPts > 0 then s.id = best end
	return s
end

-- Nom lisible d'une spe (0 = "aucune dominante").
function M.SpecName(id)
	if id == 0 or id == nil then return L("mod.specs.hybrid") end
	local s = M.cur
	if s and s.names[id] then return s.names[id] end
	return L("mod.specs.tab", id)
end

-- "31/20/0"
function M.Signature(s)
	s = s or M.cur
	if not s then return "-" end
	local t = {}
	for i = 1, s.n do tinsert(t, tostring(s.pts[i])) end
	return table.concat(t, "/")
end

-- ---------------------------------------------------------------- donnees (par personnage)
local function store(create)
	if not C.db then return nil end
	local g = C.GetGlobal("specs")
	if type(g) ~= "table" then
		if not create then return nil end
		g = {}
		C.SetGlobal("specs", g)
		if C.GetGlobal("specs") ~= g then return nil end
	end
	local key = C.CharKey()
	local c = g[key]
	if type(c) ~= "table" then
		if not create then return nil end
		c = {}
		g[key] = c
	end
	if type(c.presets) ~= "table" then
		if not create then return c end
		c.presets = {}
	end
	if type(c.assign) ~= "table" then
		if not create then return c end
		c.assign = {}
	end
	return c
end
M.Store = store

function M.PresetNames()
	local t = {}
	local c = store(false)
	if c and type(c.presets) == "table" then
		for name, _ in pairs(c.presets) do tinsert(t, name) end
	end
	table.sort(t)
	return t
end

function M.GetPreset(name)
	local c = store(false)
	return c and c.presets and c.presets[name] or nil
end

function M.Assigned(id)
	local c = store(false)
	local nm = c and c.assign and c.assign[id]
	if nm and c.presets and c.presets[nm] then return nm end
	return nil
end

-- ---------------------------------------------------------------- Simple Action Sets (coexistence)
function M.HasSAS()
	return type(getglobal("SAS_SwapSet")) == "function"
end

-- Noms des jeux de SAS du personnage (liste triee ; vide si SAS absent / illisible).
function M.SASSets()
	local t = {}
	if not M.HasSAS() then return t end
	local saved, plr = getglobal("SAS_Saved"), getglobal("PlrName")
	local mine = type(saved) == "table" and type(plr) == "string" and saved[plr]
	local sets = type(mine) == "table" and mine["s"]
	if type(sets) == "table" then
		for name, _ in pairs(sets) do
			if type(name) == "string" then tinsert(t, name) end
		end
	end
	table.sort(t)
	return t
end

function M.OpenSAS()
	if not M.HasSAS() then return false, "msg.specs.nosas" end
	local f = getglobal("SASMain_Toggle")
	if type(f) ~= "function" then return false, "msg.specs.nosas" end
	local ok = pcall(f)
	if not ok then return false, "msg.specs.sasfail" end
	return true
end

-- Charge un jeu de SAS (c'est SAS qui range les barres). Hors combat seulement.
function M.SwapSAS(set)
	if not M.HasSAS() then return false, "msg.specs.nosas" end
	if SUI.InCombat() then return false, "msg.combat.locked" end
	local exists = getglobal("SAS_SetExists")
	if type(set) ~= "string" or set == "" then return false, "msg.specs.sasunknown" end
	if type(exists) == "function" then
		local ok, e = pcall(exists, set)
		if not ok or not e then return false, "msg.specs.sasunknown" end
	end
	local ok2 = pcall(getglobal("SAS_SwapSet"), set)
	if not ok2 then return false, "msg.specs.sasfail" end
	return true, "msg.specs.sasdone"
end

-- ---------------------------------------------------------------- barres d'action (seulement SANS Simple Action Sets)
function M.BarsOK()
	if M.HasSAS() then return false, "msg.specs.sasbars" end
	if type(getglobal("HasAction")) ~= "function" or type(getglobal("PlaceAction")) ~= "function" then return false, "msg.specs.nobars" end
	return true
end

local function rankNum(txt)
	if type(txt) ~= "string" then return 0 end
	local _, _, n = string.find(txt, "(%d+)")
	return tonumber(n) or 0
end

-- nom -> { byRank = { [rang] = index }, top = index du plus haut rang } pour tout le livre de sorts
function M.SpellIndex()
	local idx = {}
	local gsn = getglobal("GetSpellName")
	if type(gsn) ~= "function" then return idx end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 1024 do
		local ok, name, rank = pcall(gsn, i, book)
		if not ok or not name then break end
		local e = idx[name]
		if not e then
			e = { byRank = {} }
			idx[name] = e
		end
		e.byRank[rankNum(rank)] = i
		e.top = i
	end
	return idx
end

-- Ligne 1 (gauche, droite) de l'infobulle d'un emplacement (hors combat seulement : cree des chaines).
function M.ScanTip(slot)
	local tip = M.tip
	if not tip then
		local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_SpecsTip", nil, "GameTooltipTemplate")
		if ok and t then
			M.tip = t
			tip = t
		end
	end
	if not tip or type(tip.SetAction) ~= "function" then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:SetAction(slot)
	local l, r = getglobal("ShikiUI_SpecsTipTextLeft1"), getglobal("ShikiUI_SpecsTipTextRight1")
	local a = l and l:GetText()
	local b = r and r:GetText()
	tip:Hide()
	return a, b
end

-- Code d'un emplacement : "m:NomDeMacro" | "s:NomDuSort:rang" | "i:NomDObjet" | nil (vide / illisible).
function M.SlotCode(slot, idx)
	if not HasAction(slot) then return nil end
	local txt = GetActionText(slot)
	if type(txt) == "string" and txt ~= "" then return "m:" .. txt end
	local name, rtxt = M.ScanTip(slot)
	if type(name) ~= "string" or name == "" then return nil end
	if idx[name] then return "s:" .. name .. ":" .. rankNum(rtxt) end
	return "i:" .. name
end

-- Instantane des barres : { [emplacement] = code }. Retourne tableau, nombre d'emplacements lus, nombre illisibles.
function M.BarsSnapshot()
	local ok, why = M.BarsOK()
	if not ok then return nil, why end
	if SUI.InCombat() then return nil, "msg.combat.locked" end
	local idx = M.SpellIndex()
	local snap = {}
	local n, bad = 0, 0
	for slot = 1, M.NSLOT do
		if HasAction(slot) then
			local code = M.SlotCode(slot, idx)
			if code then
				snap[slot] = code
				n = n + 1
			else
				bad = bad + 1
			end
		end
	end
	return snap, n, bad
end

local function findMacro(name)
	local gmi = getglobal("GetMacroInfo")
	if type(gmi) ~= "function" then return nil end
	for i = 1, 36 do
		local ok, mname = pcall(gmi, i)
		if ok and mname == name then return i end
	end
	return nil
end

local function findItem(name)
	local gl, gn = getglobal("GetContainerItemLink"), getglobal("GetContainerNumSlots")
	if type(gl) ~= "function" or type(gn) ~= "function" then return nil end
	for bag = 0, 4 do
		local ns = gn(bag) or 0
		for s = 1, ns do
			local link = gl(bag, s)
			if link then
				local _, _, iname = string.find(link, "%[(.-)%]")
				if iname == name then return bag, s end
			end
		end
	end
	return nil
end

local function clearCursor()
	local cc = getglobal("ClearCursor")
	if type(cc) == "function" then cc() end
	M.holding = false
end

-- Le curseur porte-t-il deja quelque chose (objet, sort, macro) ou un sort attend-il sa cible ? Alors on ne touche pas aux barres :
-- ClearCursor() jetterait ce que le joueur tient, et PlaceAction() le poserait a la place de notre sort.
function M.CursorBusy()
	local names = { "CursorHasItem", "CursorHasSpell", "CursorHasMacro", "SpellIsTargeting" }
	for i = 1, getn(names) do
		local f = getglobal(names[i])
		if type(f) == "function" then
			local ok, v = pcall(f)
			if ok and v then return true end
		end
	end
	return false
end

-- Dans une etape de barres, le curseur porte NOTRE sort (M.holding). Si une erreur interrompt l'etape, il le garderait : tous les boutons
-- d'action se mettraient alors a "poser" ce sort au lieu de le lancer (plus aucun clic ne marche jusqu'au /reload). DoApply le vide donc
-- toujours, mais seulement quand c'est nous qui le tenons.
function M.ReleaseCursor()
	if M.holding then clearCursor() end
end

-- Met le code a l'emplacement. Retourne true si l'action a ete posee.
local function placeCode(slot, code, idx)
	local kind = string.sub(code, 1, 1)
	local rest = string.sub(code, 3)
	local picked = false
	if kind == "s" then
		local _, _, name, rank = string.find(rest, "^(.*):(%d+)$")
		local e = name and idx[name]
		if e then
			local i = e.byRank[tonumber(rank) or 0] or e.top
			local pk = getglobal("PickupSpell")
			if type(pk) == "function" and i then
				M.holding = true
				pk(i, getglobal("BOOKTYPE_SPELL") or "spell")
				picked = true
			end
		end
	elseif kind == "m" then
		local i = findMacro(rest)
		local pk = getglobal("PickupMacro")
		if i and type(pk) == "function" then
			M.holding = true
			pk(i)
			picked = true
		end
	elseif kind == "i" then
		local bag, s = findItem(rest)
		local pk = getglobal("PickupContainerItem")
		if bag and type(pk) == "function" then
			M.holding = true
			pk(bag, s)
			picked = true
		end
	end
	if picked then
		M.holding = true
		local ok = pcall(PlaceAction, slot)
		clearCursor()
		if not ok then return false end
	end
	return picked
end

-- Remet les barres d'un instantane : ne touche qu'aux emplacements qui different ; un emplacement dont le sort / la macro / l'objet
-- est introuvable n'est PAS modifie (compte "manquants"). specs.bars.clear : vide aussi les emplacements vides dans l'instantane.
-- Retourne ok, nb poses, nb manquants, nb identiques.
function M.BarsRestore(snap)
	local ok, why = M.BarsOK()
	if not ok then return false, why end
	if SUI.InCombat() then return false, "msg.combat.locked" end
	if type(snap) ~= "table" then return false, "msg.specs.nosnap" end
	if M.CursorBusy() then return false, "msg.specs.cursorbusy" end
	local idx = M.SpellIndex()
	local clear = C.Get("specs.bars.clear")
	local placed, missing, same = 0, 0, 0
	clearCursor()
	for slot = 1, M.NSLOT do
		local want = snap[slot]
		if want then
			if M.SlotCode(slot, idx) == want then
				same = same + 1
			elseif placeCode(slot, want, idx) then
				placed = placed + 1
			else
				missing = missing + 1
			end
		elseif clear and HasAction(slot) then
			M.holding = true
			pcall(PickupAction, slot)
			clearCursor()
		end
	end
	clearCursor()
	return true, placed, missing, same
end

-- ---------------------------------------------------------------- jeux (presets)
local FIELDS = { profile = true, role = true, layout = true, mode = true, sas = true }
M.FIELDS = FIELDS

local function barCount(p)
	local n = 0
	if type(p.bars) == "table" then
		for _, _ in pairs(p.bars) do n = n + 1 end
	end
	return n
end

-- Texte court d'un jeu pour l'affichage.
function M.Summary(p)
	if type(p) ~= "table" then return "-" end
	local t = {}
	if p.profile and p.profile ~= "" then tinsert(t, L("mod.specs.f.profile") .. " " .. p.profile) end
	if p.role and p.role ~= "" then tinsert(t, L("mod.specs.f.role") .. " " .. p.role) end
	if p.layout and p.layout ~= "" then tinsert(t, L("mod.specs.f.layout") .. " " .. p.layout) end
	if p.mode and p.mode ~= "" then tinsert(t, L("mod.specs.f.mode") .. " " .. p.mode) end
	if p.sas and p.sas ~= "" then tinsert(t, "SAS " .. p.sas) end
	local nb = barCount(p)
	if nb > 0 then tinsert(t, L("mod.specs.f.bars") .. " " .. nb) end
	if getn(t) == 0 then return L("mod.specs.empty") end
	return table.concat(t, ", ")
end

-- Capture l'etat ACTUEL dans le jeu `name` (cree ou ecrase) : profil actif, role, mise en page, barres (si specs.bars et SAS absent).
-- Le mode et le jeu SAS d'un jeu existant sont conserves (ils ne se capturent pas : le mode suit le groupe, SAS a ses propres jeux).
-- Retourne ok, cle de message, nom.
function M.Capture(name)
	if not validName(name) then return false, "msg.specs.badname" end
	local c = store(true)
	if not c then return false, "msg.specs.nostore" end
	local old = c.presets[name]
	if not old and M.CountPresets(c) >= M.MAXPRESETS then return false, "msg.specs.full" end
	local p = { profile = C.curName, role = C.GetRole(), layout = C.cur and C.cur.layout or nil,
		mode = old and old.mode or nil, sas = old and old.sas or nil }
	if C.Get("specs.bars") and M.BarsOK() and not SUI.InCombat() then
		local snap, n = M.BarsSnapshot()
		if snap then p.bars = snap end
	end
	c.presets[name] = p
	return true, old and "msg.specs.updated" or "msg.specs.saved", name
end

function M.CountPresets(c)
	local n = 0
	c = c or store(false)
	if c and type(c.presets) == "table" then
		for _, _ in pairs(c.presets) do n = n + 1 end
	end
	return n
end

function M.Delete(name)
	local c = store(false)
	if not c or not c.presets or not c.presets[name] then return false, "msg.specs.unknown" end
	c.presets[name] = nil
	if c.applied == name then c.applied = nil end
	if M.lastName == name then M.lastName = nil end
	if c.assign then
		for id = 0, 3 do
			if c.assign[id] == name then c.assign[id] = nil end
		end
	end
	return true, "msg.specs.deleted", name
end

-- Lie la spe `id` (0..3) au jeu `name` (nil ou "-" : delie).
function M.Link(id, name)
	if type(id) ~= "number" or id < 0 or id > 3 then return false, "msg.specs.badspec" end
	if name == nil or name == "-" or name == "" then
		local c = store(false)
		if c and c.assign then c.assign[id] = nil end
		return true, "msg.specs.unlinked", M.SpecName(id)
	end
	local c = store(false)
	if not c or not c.presets or not c.presets[name] then return false, "msg.specs.unknown" end
	c.assign[id] = name
	return true, "msg.specs.linked", M.SpecName(id), name
end

-- Modifie un champ d'un jeu. field : profile | role | layout | mode | sas ; value "" ou "-" : retire le champ.
function M.SetField(name, field, value)
	local p = M.GetPreset(name)
	if not p then return false, "msg.specs.unknown" end
	if not FIELDS[field] then return false, "msg.specs.badfield" end
	if value == "-" then value = "" end
	if value == nil then value = "" end
	if value ~= "" then
		if field == "profile" then
			if not (C.db and C.db.profiles[value]) then return false, "msg.specs.badvalue" end
		elseif field == "role" then
			if not C.roles[value] then return false, "msg.specs.badvalue" end
		elseif field == "layout" then
			if not SUI.layouts[value] then return false, "msg.specs.badvalue" end
		elseif field == "mode" then
			if not C.IsMode(value) then return false, "msg.specs.badvalue" end
		elseif field == "sas" then
			if string.len(value) > 48 then return false, "msg.specs.badvalue" end
		end
		p[field] = value
	else
		p[field] = nil
	end
	return true, "msg.specs.fieldset", name
end

-- Applique le jeu maintenant (ou des la sortie de combat). Retourne ok, cle de message, [texte].
function M.Apply(name, why)
	local p = M.GetPreset(name)
	if not p then return false, "msg.specs.unknown" end
	if SUI.InCombat() then
		M.queued, M.queuedWhy = name, why
		SUI.WhenSafe(M.RunQueued)
		return true, "msg.specs.queued", name
	end
	return M.DoApply(name, p, why)
end

function M.RunQueued()
	local name, why = M.queued, M.queuedWhy
	M.queued, M.queuedWhy = nil, nil
	if not name or not M.on then return end
	local ok, key, a, b = M.Apply(name, why)
	if key then say(key, a or name, b) end
end

-- Etapes : profil -> role -> mise en page -> mode -> barres -> SAS. Chaque champ vide / identique est saute.
function M.DoApply(name, p, why)
	if M.applying then return false, "msg.specs.busy" end
	M.applying = true
	-- une erreur dans une etape ne doit jamais laisser le verrou ferme
	local ok, r1, r2, r3, r4 = pcall(M.RunApply, name, p, why)
	M.applying = false
	M.ReleaseCursor()
	if not ok then
		SUI.Report("specs.apply", r1)
		return false, "msg.specs.fail"
	end
	M.BtnRefresh()
	return r1, r2, r3, r4
end

function M.RunApply(name, p, why)
	local parts = {}
	-- profil ShikiUI
	if p.profile and p.profile ~= "" and p.profile ~= C.curName then
		if C.db and C.db.profiles[p.profile] then
			local ok = C.UseProfile(p.profile)
			if ok then tinsert(parts, L("mod.specs.f.profile") .. " " .. p.profile) end
		else
			tinsert(parts, L("msg.specs.missingprofile", p.profile))
		end
	end
	-- role / mise en page : ecrivent dans le profil -> un instantane de securite avant
	local roleNew = p.role and p.role ~= "" and C.roles[p.role] and C.GetRole() ~= p.role
	local layNew = p.layout and p.layout ~= "" and SUI.layouts[p.layout] and C.cur.layout ~= p.layout and SUI.Layout
	if (roleNew or layNew) and SUI.Backup and SUI.Backup.Create then
		SUI.Backup.Create("update", "specs " .. name)
	end
	if roleNew and C.ApplyRole(p.role) then tinsert(parts, L("mod.specs.f.role") .. " " .. p.role) end
	if layNew then
		local ok = SUI.Layout.ApplyPreset(p.layout)
		if ok then tinsert(parts, L("mod.specs.f.layout") .. " " .. p.layout) end
	end
	-- mode Normal / Raid (explicite seulement)
	if p.mode and p.mode ~= "" and C.IsMode(p.mode) and C.mode ~= p.mode and SUI.Mode then
		local ok = SUI.Mode.Set(p.mode, "manual")
		if ok then tinsert(parts, L("mod.specs.f.mode") .. " " .. p.mode) end
	end
	-- barres d'action : jamais si SAS est charge
	if type(p.bars) == "table" and C.Get("specs.bars") then
		local ok, placed, missing = M.BarsRestore(p.bars)
		if ok then
			local txt = L("mod.specs.f.bars") .. " " .. placed
			if missing > 0 then txt = txt .. " (" .. L("msg.specs.missing", missing) .. ")" end
			tinsert(parts, txt)
		elseif placed == "msg.specs.sasbars" then
			tinsert(parts, L("msg.specs.sasbars"))
		elseif placed == "msg.specs.cursorbusy" then
			tinsert(parts, L("msg.specs.cursorbusy"))
		end
	end
	-- jeu de Simple Action Sets (choix explicite de l'utilisateur)
	if p.sas and p.sas ~= "" then
		local ok, key = M.SwapSAS(p.sas)
		if ok then
			tinsert(parts, "SAS " .. p.sas)
		elseif key then
			tinsert(parts, L(key))
		end
	end
	M.applied = (M.applied or 0) + 1
	M.lastName = name
	local sc = store(true)
	if sc then sc.applied = name end           -- survit au /reload : le bouton de la fenetre des talents affiche le jeu en vigueur
	local text = getn(parts) > 0 and table.concat(parts, ", ") or L("mod.specs.nochange")
	C.Notify("specs.applied", name)
	return true, "msg.specs.applied", name, text
end

-- ---------------------------------------------------------------- suivi automatique
-- Un balayage (apres le delai de stabilisation) : compare a la derniere spe connue, applique le jeu lie.
function M.Check(force)
	M.task = nil
	if not M.on then return end
	if SUI.InCombat() then
		M.dirty = true
		return
	end
	local s = M.Scan()
	if not s then return end
	M.cur = s
	M.dirty = false
	local c = store(false)
	local last = c and c.last
	if last ~= s.id then
		c = store(true)
		if c then
			c.last = s.id
			if last ~= nil then
				-- reglages lus AVANT l'application : un jeu peut changer de profil, donc de valeurs
				local announce, auto = C.Get("specs.announce"), C.Get("specs.auto")
				if announce then
					say("msg.specs.changed", M.SpecName(last), M.SpecName(s.id), M.Signature(s))
					-- pastille a l'ecran (module Messages) : le nom de la nouvelle spe reste visible quelques secondes
					if SUI.Messages and SUI.Messages.Toast then
						SUI.Messages.Toast("e", "specs", nil, L("msg.specs.changed", M.SpecName(last), M.SpecName(s.id), M.Signature(s)))
					end
				end
				if auto then
					local nm = M.Assigned(s.id)
					if nm then
						local ok, key, a, b = M.Apply(nm, "auto")
						if announce and key then say(key, a or nm, b) end
					end
					local pr = nm and M.GetPreset(nm)
					if not (pr and type(pr.bars) == "table" and C.Get("specs.bars")) then M.RestoreAuto(s.id) end
				end
			end
		end
	end
	M.Refresh()
end

-- ---------------------------------------------------------------- barres par spe (automatique)
-- specs.autobars : les barres d'action de la spe en cours sont gardees en continu (store.autobars[spe]) ; au changement de spe (Goblin
-- Brainwashing Device, PNJ, talents) celles de la nouvelle spe sont remises, sauf si son jeu lie contient deja ses propres barres.
-- Jamais pendant la transition (balayage en attente : le client vide alors les emplacements dont le sort n'est plus connu), ni en combat.
function M.AutoSave()
	M.autoTask = nil
	if not M.on or not C.Get("specs.autobars") or M.task or M.holding or SUI.InCombat() then return end
	if not M.BarsOK() or M.CursorBusy() then return end
	local c = store(false)
	local id = c and c.last
	if not id then return end
	local snap, n = M.BarsSnapshot()
	if not snap or not n or n < 1 then return end
	c = store(true)
	if not c then return end
	if type(c.autobars) ~= "table" then c.autobars = {} end
	c.autobars[id] = snap
	M.autoSaved = (M.autoSaved or 0) + 1
end

function M.OnSlot()
	if not M.on or not C.Get("specs.autobars") then return end
	if M.autoTask then SUI.Cancel(M.autoTask) end
	M.autoTask = SUI.After(8, M.AutoSave, "specs.autosave")
end

function M.RestoreAuto(id)
	if not C.Get("specs.autobars") then return end
	local c = store(false)
	local snap = c and type(c.autobars) == "table" and c.autobars[id]
	if type(snap) ~= "table" then return end
	local ok, placed, missing = M.BarsRestore(snap)
	if ok and announceBars() then
		local txt = L("mod.specs.f.bars") .. " " .. placed
		if missing > 0 then txt = txt .. " (" .. L("msg.specs.missing", missing) .. ")" end
		say("msg.specs.autobars", txt)
	end
end

-- Programme un balayage dans specs.delay secondes (les rafales d'evenements d'un changement de spe n'en font qu'un).
function M.Schedule()
	if not M.on then return end
	if SUI.InCombat() then
		M.dirty = true
		return
	end
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.After(C.Get("specs.delay") or 3, M.Check, "specs.check")
end

function M.OnEvent(ev)
	if ev == "PLAYER_REGEN_ENABLED" then
		if M.dirty then M.Schedule() end
		return
	end
	M.Schedule()
end

-- Redessine la page du menu si elle est ouverte.
function M.Refresh()
	M.BtnRefresh()
	local Mn = SUI.Menu
	if Mn and Mn.frame and Mn.frame:IsShown() and Mn.page == "cat" and Mn.cat == "specs" and Mn.Render then Mn.Render() end
end

-- fn(cle, valeur) ; cle == nil : tout a pu changer (profil, mode, import).
function M.OnKey(key, value)
	if not M.on then return end
	if key == "specs.minpoints" or key == "specs.auto" then M.Schedule() end
	if key == nil then M.Schedule() end
	if key == nil or key == "specs.btn" or key == "specs.btnpos" or key == "specs.btnstyle" then M.BtnApply() end
end

-- ---------------------------------------------------------------- page du menu (sections ajoutees a la page de la categorie "specs")
local function btn(cols, w, label, fn, selected)
	local Mn = SUI.Menu
	return Mn.GridBtn(label, cols, w, 24, fn, selected)
end

local function specLine(id)
	local nm = M.Assigned(id)
	local pts = ""
	if id > 0 and M.cur and M.cur.pts[id] then pts = " (" .. M.cur.pts[id] .. ")" end
	local mark = (M.cur and M.cur.id == id) and "> " or "  "
	return mark .. M.SpecName(id) .. pts .. "   ->   " .. (nm or L("mod.specs.none"))
end

function M.Page()
	local Mn = SUI.Menu
	local T = SUI.Theme
	local mod = SUI.modules.specs
	if not mod or not mod.enabled then
		Mn.Para(L("mod.specs.disabled"), 34, T.c.warn)
		return
	end
	M.cur = M.Scan() or M.cur
	-- etat
	Mn.Section(L("mod.specs.sec.state"), M.cur and M.Signature() or "")
	if M.cur then
		Mn.Para(L("mod.specs.now", M.SpecName(M.cur.id), M.Signature(), M.cur.total), 20, T.c.text)
	else
		Mn.Para(L("mod.specs.noapi"), 34, T.c.warn)
	end
	if M.HasSAS() then
		Mn.Para(L("mod.specs.sas.on"), 48)
		btn(3, 208, L("mod.specs.sas.open"), function() local ok, key = M.OpenSAS(); if key then say(key) end end, false)
	else
		Mn.Para(L("mod.specs.sas.off"), 48)
	end
	-- spe -> jeu
	Mn.Section(L("mod.specs.sec.link"), "")
	Mn.Para(L("mod.specs.help.link"), 34)
	local names = M.PresetNames()
	local ids = { 1, 2, 3, 0 }
	for k = 1, getn(ids) do
		local id = ids[k]
		if id == 0 or (M.cur and id <= M.cur.n) then
			Mn.Para(specLine(id), 16, (M.cur and M.cur.id == id) and T.c.text or T.c.dim)
			btn(3, 208, L("mod.specs.btn.save"), function()
				local nm = M.SpecName(id)
				nm = string.gsub(nm, "[^%w_%-]", "")
				if nm == "" or string.len(nm) > 24 then nm = "Spe" .. id end
				local ok, key, a = M.Capture(nm)
				if ok then M.Link(id, nm) end
				say(key, a or nm)
				Mn.Render()
			end, false)
			btn(3, 208, L("mod.specs.btn.pick"), function()
				local cyc = {}
				local list = M.PresetNames()
				for i = 1, getn(list) do tinsert(cyc, list[i]) end
				local cur = M.Assigned(id)
				local nxt = nextIn(cyc, cur)
				if cur == nil then nxt = cyc[1] end
				if cur ~= nil and nxt == nil then nxt = "-" end
				local ok, key, a, b = M.Link(id, nxt)
				say(key, a, b)
				Mn.Render()
			end, false)
			btn(3, 208, L("mod.specs.btn.apply"), function()
				local nm = M.Assigned(id)
				if not nm then say("msg.specs.nolink", M.SpecName(id)) return end
				local ok, key, a, b = M.Apply(nm, "manual")
				say(key, a or nm, b)
				Mn.Render()
			end, false)
		end
	end
	-- jeux
	Mn.Section(L("mod.specs.sec.sets"), tostring(getn(names)))
	if getn(names) == 0 then
		Mn.Para(L("mod.specs.help.nosets"), 34)
	else
		Mn.Para(L("mod.specs.help.sets"), 34)
	end
	for k = 1, getn(names) do
		local name = names[k]
		local p = M.GetPreset(name)
		if p then
			Mn.Para(name .. " : " .. M.Summary(p), 30, T.c.text)
			btn(4, 153, L("mod.specs.f.profile") .. ": " .. (p.profile or "-"), function()
				local list = C.ListProfiles()
				tinsert(list, 1, "-")
				local nxt = nextIn(list, (p.profile and p.profile ~= "") and p.profile or "-")
				sayr(M.SetField(name, "profile", nxt))
				Mn.Render()
			end, false)
			btn(4, 153, L("mod.specs.f.role") .. ": " .. ((p.role and p.role ~= "") and p.role or "-"), function()
				local list = { "-", "tank", "heal", "dps", "pvp" }
				local nxt = nextIn(list, (p.role and p.role ~= "") and p.role or "-")
				sayr(M.SetField(name, "role", nxt))
				Mn.Render()
			end, false)
			btn(4, 153, L("mod.specs.f.layout") .. ": " .. ((p.layout and p.layout ~= "") and p.layout or "-"), function()
				local list = { "-" }
				for i = 1, getn(SUI.layoutOrder) do tinsert(list, SUI.layoutOrder[i]) end
				local nxt = nextIn(list, (p.layout and p.layout ~= "") and p.layout or "-")
				sayr(M.SetField(name, "layout", nxt))
				Mn.Render()
			end, false)
			btn(4, 153, L("mod.specs.f.mode") .. ": " .. ((p.mode and p.mode ~= "") and p.mode or "-"), function()
				local list = { "-", "normal", "raid" }
				local nxt = nextIn(list, (p.mode and p.mode ~= "") and p.mode or "-")
				sayr(M.SetField(name, "mode", nxt))
				Mn.Render()
			end, false)
			btn(3, 208, L("mod.specs.btn.apply"), function()
				local ok, key, a, b = M.Apply(name, "manual")
				say(key, a or name, b)
				Mn.Render()
			end, false)
			btn(3, 208, L("mod.specs.btn.resave"), function()
				local ok, key, a = M.Capture(name)
				say(key, a or name)
				Mn.Render()
			end, false)
			local del = btn(3, 208, L("mod.specs.btn.delete"), nil, false)
			if del then
				del.fn = function(b)
					Mn.ConfirmClick(b, "spdel" .. name, L("mod.specs.btn.delete"), function()
						local ok, key, a = M.Delete(name)
						say(key, a or name)
						Mn.Render()
					end)
				end
			end
		end
	end
	Mn.Section(L("mod.specs.sec.opts"), "")
end

function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "specs" then M.Page() end
		orig()
	end
	for i = 1, getn(Mn.FAMILIES) do
		local fam = Mn.FAMILIES[i]
		if fam.id == "general" then
			local have = false
			for j = 1, getn(fam.cats) do
				if fam.cats[j] == "specs" then have = true end
			end
			if not have then tinsert(fam.cats, "specs") end
		end
	end
end

-- ---------------------------------------------------------------- bouton "Jeux ShikiUI" sur la fenetre des talents
-- Cree par ce module, enfant de TalentFrame (jamais en combat : SUI.WhenSafe). Texte = spe courante + jeu en vigueur (option btnstyle).
M.BTNPOS = {
	bottom = { "BOTTOMRIGHT", "BOTTOMRIGHT", -40, 80 },
	top = { "TOPRIGHT", "TOPRIGHT", -62, -34 },
	side = { "TOPLEFT", "TOPRIGHT", -2, -150 },
}
M.BTNW = { full = 160, label = 92, compact = 34 }
M.MENUW = 220

local function tipLine(text, c)
	if GameTooltip then GameTooltip:AddLine(text, c[1], c[2], c[3], 1) end
end

-- Infobulle (fn(bouton) remplit GameTooltip) ajoutee sans perdre le survol du theme.
local function tipOn(b, fn, pre)
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oe then oe() end
		if pre then pre() end
		if not GameTooltip then return end
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		fn(b)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if ol then ol() end
		if GameTooltip then GameTooltip:Hide() end
	end)
end

local function clip(s, n)
	s = tostring(s or "")
	if string.len(s) > n then return string.sub(s, 1, n - 1) .. "." end
	return s
end

-- Spe detectee (id, nom) ; nil si l'API des talents est illisible.
function M.SpecNow()
	local s = M.cur
	if not s then
		s = M.Scan()
		if s then M.cur = s end
	end
	if not s then return nil, nil end
	return s.id, M.SpecName(s.id)
end

-- Jeu en vigueur : le dernier applique (cette session, sinon celui qui est retenu dans les donnees du personnage) s'il existe encore.
function M.AppliedName()
	local nm = M.lastName
	if nm and M.GetPreset(nm) then return nm end
	local c = store(false)
	nm = c and c.applied
	if nm and c.presets and c.presets[nm] then return nm end
	return nil
end

-- "S1 S3" : les spes liees au jeu (chaine vide si aucune).
function M.LinkedTo(name)
	local c = store(false)
	local t = {}
	if c and c.assign then
		for id = 0, 3 do
			if c.assign[id] == name then tinsert(t, id == 0 and L("mod.specs.q.s0") or L("mod.specs.q.s", id)) end
		end
	end
	return table.concat(t, " ")
end

function M.BtnLevel()
	local b, par = M.btn, M.tpar
	if not b or not par then return end
	local lv = par:GetFrameLevel()
	if type(lv) ~= "number" then return end
	b:SetFrameLevel(lv + 8)
	M.MenuLevel()
end

function M.BtnLevelTick()
	M.btnTask = nil
	M.BtnLevel()
end

function M.BtnLabel()
	local b = M.btn
	if not b then return end
	local style = C.Get("specs.btnstyle")
	local id, nm = M.SpecNow()
	local text
	if style == "compact" then
		text = L("mod.specs.btn.compact")
	elseif style == "full" and id then
		local set = M.AppliedName()
		text = L("mod.specs.btn.full", clip(nm, 16), set and clip(set, 14) or L("mod.specs.btn.noset"))
	else
		text = L("mod.specs.btn.label")
	end
	if b.txt ~= text then
		b.txt = text
		T.SetButtonText(b, text)
	end
	local linked = id and M.Assigned(id)
	T.SetSelected(b, (linked and linked == M.AppliedName()) and true or false)
end

function M.BtnRefresh()
	if M.btn then M.BtnLabel() end
	if M.menu and M.menu:IsShown() then M.MenuRefresh() end
end

function M.TipBtn(b)
	M.BtnLevel()
	GameTooltip:AddLine(L("mod.specs.btn.tiptitle"))
	local id, nm = M.SpecNow()
	if id then
		tipLine(L("mod.specs.q.spec", nm, M.Signature()), T.c.text)
		local linked = M.Assigned(id)
		tipLine(linked and L("mod.specs.q.linked", linked) or L("mod.specs.q.nolink"), T.c.dim)
	else
		tipLine(L("mod.specs.q.noapi"), T.c.dim)
	end
	local set = M.AppliedName()
	tipLine(set and L("mod.specs.q.applied", set) or L("mod.specs.q.noapplied"), T.c.dim)
	tipLine(L("mod.specs.btn.tipbody"), T.c.dim)
end

function M.BtnClick(mouse)
	if mouse == "RightButton" then
		M.MenuClose()
		M.OpenPage()
	else
		M.MenuToggle()
	end
end

function M.OpenPage()
	if SUI.Menu and SUI.Menu.Show then SUI.Menu.Show("specs") end
end

function M.BuildBtn()
	if M.btn then return end
	local tf = getglobal("TalentFrame")
	if not tf then return end                    -- pas d'interface talents (pas encore chargee / hors jeu) : pas de bouton
	M.tpar = tf
	local b = T.Button(tf, L("mod.specs.btn.label"), M.BTNW.full, 16, function(btn, mouse) M.BtnClick(mouse) end)
	b.specsBtn = true
	M.btn = b
	b:SetScript("OnShow", function()
		M.BtnLevel()
		M.cur = M.Scan() or M.cur
		M.BtnLabel()
		if not M.btnTask then M.btnTask = SUI.After(0.2, M.BtnLevelTick, "specs.lvl") end
	end)
	tipOn(b, M.TipBtn, M.BtnLevel)           -- le niveau est recale au survol meme sans infobulle
	M.BtnApply()
end

function M.BtnApply()
	if not M.btn then
		if not (M.on and C.Get("specs.btn")) or not getglobal("TalentFrame") then return end
		SUI.WhenSafe(M.BuildBtn)
		return
	end
	local b = M.btn
	local pos = M.BTNPOS[C.Get("specs.btnpos")] or M.BTNPOS.bottom
	b:ClearAllPoints()
	b:SetPoint(pos[1], M.tpar, pos[2], pos[3], pos[4])
	b:SetWidth(M.BTNW[C.Get("specs.btnstyle")] or M.BTNW.full)
	b.txt = nil
	M.BtnLevel()
	if M.on and C.Get("specs.btn") then
		b:Show()
	else
		b:Hide()
		M.MenuClose()
	end
	M.BtnLabel()
end

-- ADDON_LOADED : la fenetre des talents est chargee a la demande (Blizzard_TalentUI).
function M.OnAddon(ev, name)
	if M.on and not M.btn and getglobal("TalentFrame") then M.BtnApply() end
end

-- ---------------------------------------------------------------- petit menu des jeux
-- Corps : etat (spe detectee, jeu lie, jeu en vigueur), un bouton par jeu (clic = appliquer, clic droit = lier / delier la spe
-- detectee), Enregistrer ici, page Specs, et si le module Builds est la : son menu rapide et sa fenetre.
function M.MenuLevel()
	local q = M.menu
	if not q or not M.tpar then return end
	local lv = M.tpar:GetFrameLevel()
	if type(lv) ~= "number" then return end
	q:SetFrameLevel(lv + 20)
	for i = 1, getn(M.mkids) do M.mkids[i]:SetFrameLevel(lv + 22) end
end

function M.MenuClose()
	if M.menu and M.menu:IsShown() then M.menu:Hide() end
end

-- Nom de jeu propose pour la spe `id` : son nom, nettoye (lettres, chiffres, _ et -), 24 caracteres au plus.
function M.AutoName(id)
	local base
	if id and id > 0 then base = M.SpecName(id) else base = L("mod.specs.q.hybridname") end
	base = string.gsub(tostring(base or ""), "[^%w_%-]", "_")
	base = string.sub(base, 1, 24)
	if base == "" or base == "_" then base = "Spe" .. tostring(id or 0) end
	return base
end

-- Enregistre l'etat actuel dans le jeu lie a la spe detectee (sinon cree un jeu au nom de la spe et le lie). Retourne ok, nom.
function M.SaveHere()
	local id = M.SpecNow()
	id = id or 0
	local name = M.Assigned(id)
	local fresh = not name
	if fresh then name = M.AutoName(id) end
	local ok, key, a = M.Capture(name)
	say(key, a or name)
	if not ok then return false end
	if fresh then
		local ok2, key2, a2, b2 = M.Link(id, name)
		say(key2, a2, b2)
	end
	local c = store(true)
	if c then c.applied = name end            -- ce qui vient d'etre enregistre est, par definition, ce qui est en vigueur
	M.lastName = name
	M.BtnRefresh()
	return true, name
end

function M.RowClick(r, mouse)
	local name = r.preset
	if not name then return end
	if mouse == "RightButton" then
		local id = M.SpecNow() or 0
		local ok, key, a, b
		if M.Assigned(id) == name then
			ok, key, a, b = M.Link(id, nil)
		else
			ok, key, a, b = M.Link(id, name)
		end
		say(key, a, b)
		M.BtnRefresh()
		return
	end
	local ok, key, a, b = M.Apply(name, "manual")
	say(key, a or name, b)
	M.MenuClose()
	M.BtnRefresh()
end

function M.TipRow(r)
	local name = r.preset
	if not name then return end
	GameTooltip:AddLine(name)
	tipLine(M.Summary(M.GetPreset(name)), T.c.text)
	local lk = M.LinkedTo(name)
	tipLine(lk ~= "" and L("mod.specs.q.rowlinked", lk) or L("mod.specs.q.rownolink"), T.c.dim)
	local _, nm = M.SpecNow()
	tipLine(L("mod.specs.q.rowhelp", nm or "?"), T.c.dim)
end

function M.TipSave(b)
	local id, nm = M.SpecNow()
	GameTooltip:AddLine(L("mod.specs.q.save"))
	local linked = M.Assigned(id or 0)
	tipLine(linked and L("mod.specs.q.savehas", linked) or L("mod.specs.q.savenew", M.AutoName(id or 0)), T.c.text)
	tipLine(L("mod.specs.q.savebody"), T.c.dim)
end

function M.BuildMenu()
	if M.menu or not M.tpar then return end
	local q = CreateFrame("Frame", "ShikiUISpecsMenu", M.tpar)
	q:SetWidth(M.MENUW)
	q:SetHeight(200)
	T.Backdrop(q, T.c.panel, T.c.border)
	q:SetFrameStrata("DIALOG")
	q:EnableMouse(true)
	q:SetClampedToScreen(true)
	q:Hide()
	M.menu = q
	M.mkids = {}
	local function kid(f)
		tinsert(M.mkids, f)
		return f
	end
	q.title = T.Text(q, 12, T.c.text, "LEFT")
	q.title:SetText(L("mod.specs.q.title"))
	q.s1 = T.Text(q, 10, T.c.dim, "LEFT")
	q.s2 = T.Text(q, 10, T.c.dim, "LEFT")
	q.s3 = T.Text(q, 10, T.c.dim, "LEFT")
	q.sec = T.Text(q, 10, T.c.dim, "LEFT")
	q.sec:SetText(L("mod.specs.q.apply"))
	q.empty = T.Text(q, 10, T.c.dim, "LEFT")
	q.empty:SetText(L("mod.specs.q.empty"))
	for _, fs in ipairs({ q.s1, q.s2, q.s3, q.sec, q.empty }) do fs:SetWidth(M.MENUW - 16) end
	q.close = kid(T.Button(q, "x", 16, 16, function() M.MenuClose() end))
	q.rows = {}
	for i = 1, M.MAXPRESETS do
		local r = kid(T.Button(q, "", M.MENUW - 16, 20, function(btn, mouse) M.RowClick(btn, mouse) end))
		r.label:ClearAllPoints()
		r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
		r.label:SetJustifyH("LEFT")
		r.label:SetWidth(M.MENUW - 70)
		r.tag = T.Text(r, 10, T.c.dim, "RIGHT")
		r.tag:SetPoint("RIGHT", r, "RIGHT", -5, 0)
		tipOn(r, M.TipRow)
		r:Hide()
		q.rows[i] = r
	end
	q.save = kid(T.Button(q, L("mod.specs.q.save"), M.MENUW - 16, 22, function() M.SaveHere() end))
	tipOn(q.save, M.TipSave)
	q.page = kid(T.Button(q, L("mod.specs.q.page"), M.MENUW - 16, 22, function()
		M.MenuClose()
		M.OpenPage()
	end))
	tipOn(q.page, function()
		GameTooltip:AddLine(L("mod.specs.q.page"))
		tipLine(L("mod.specs.q.pagebody"), T.c.dim)
	end)
	q.bq = kid(T.Button(q, L("mod.specs.q.builds"), (M.MENUW - 20) / 2, 22, function()
		local I = SUI.Items
		M.MenuClose()
		if I and I.QuickOpen then I.QuickOpen(M.btn, M.BTNPOS[C.Get("specs.btnpos")] == M.BTNPOS.bottom) end
	end))
	tipOn(q.bq, function()
		GameTooltip:AddLine(L("mod.specs.q.builds"))
		tipLine(L("mod.specs.q.buildsbody"), T.c.dim)
	end)
	q.bw = kid(T.Button(q, L("mod.specs.q.buildswin"), (M.MENUW - 20) / 2, 22, function()
		local I = SUI.Items
		M.MenuClose()
		if I and I.OpenBuilds then I.OpenBuilds() end
	end))
	tipOn(q.bw, function()
		GameTooltip:AddLine(L("mod.specs.q.buildswin"))
		tipLine(L("mod.specs.q.buildswinbody"), T.c.dim)
	end)
	q:SetScript("OnShow", function() M.MenuLevel() end)
	M.MenuLevel()
end

local function put(f, x, y)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", M.menu, "TOPLEFT", x, y)
end

function M.MenuRefresh()
	local q = M.menu
	if not q then return end
	local id, nm = M.SpecNow()
	put(q.title, 8, -8)
	q.close:ClearAllPoints()
	q.close:SetPoint("TOPRIGHT", q, "TOPRIGHT", -5, -5)
	if id then
		q.s1:SetText(L("mod.specs.q.spec", nm, M.Signature()))
		local linked = M.Assigned(id)
		q.s2:SetText(linked and L("mod.specs.q.linked", linked) or L("mod.specs.q.nolink"))
	else
		q.s1:SetText(L("mod.specs.q.noapi"))
		q.s2:SetText("")
	end
	local set = M.AppliedName()
	q.s3:SetText(set and L("mod.specs.q.applied", set) or L("mod.specs.q.noapplied"))
	put(q.s1, 8, -26)
	put(q.s2, 8, -39)
	put(q.s3, 8, -52)
	put(q.sec, 8, -70)
	local y = -84
	local names = M.PresetNames()
	for i = 1, M.MAXPRESETS do
		local r = q.rows[i]
		local n = names[i]
		if n then
			r.preset = n
			T.SetButtonText(r, n)
			local lk = M.LinkedTo(n)
			r.tag:SetText(lk)
			T.SetSelected(r, n == set)
			put(r, 8, y)
			r:Show()
			y = y - 22
		else
			r.preset = nil
			r:Hide()
		end
	end
	if getn(names) == 0 then
		put(q.empty, 8, y)
		q.empty:Show()
		y = y - 18
	else
		q.empty:Hide()
	end
	y = y - 6
	put(q.save, 8, y)
	y = y - 24
	put(q.page, 8, y)
	y = y - 24
	local I = SUI.Items
	if I and I.on and I.QuickOpen then
		put(q.bq, 8, y)
		q.bw:ClearAllPoints()
		q.bw:SetPoint("LEFT", q.bq, "RIGHT", 4, 0)
		q.bq:Show()
		q.bw:Show()
		y = y - 24
	else
		q.bq:Hide()
		q.bw:Hide()
	end
	q:SetHeight(-y + 6)
end

function M.MenuToggle()
	if M.menu and M.menu:IsShown() then
		M.menu:Hide()
		return true
	end
	if not M.on or not M.btn then return false end
	if not M.menu then
		if SUI.InCombat() then
			SUI.Print(L("msg.combat.locked"))
			return false
		end
		M.BuildMenu()
	end
	local q = M.menu
	local b = M.btn
	q:ClearAllPoints()
	local posName = C.Get("specs.btnpos")
	if posName == "bottom" then
		q:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 2)
	elseif posName == "side" then
		q:SetPoint("TOPLEFT", b, "TOPRIGHT", 2, 0)
	else
		q:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
	end
	M.cur = M.Scan() or M.cur
	q:Show()
	M.MenuRefresh()
	M.MenuLevel()
	return true
end

-- ---------------------------------------------------------------- cycle de vie
M.EVENTS ={ "PLAYER_ENTERING_WORLD", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }

function M.Enable()
	M.on = true
	for i = 1, getn(M.EVENTS) do SUI.On(M.EVENTS[i], M.OnEvent) end
	if not M.watching then
		M.watching = true
		C.Watch("specs.", M.OnKey)
	end
	M.cur = M.Scan() or M.cur
	SUI.On("ADDON_LOADED", M.OnAddon)
	SUI.On("ACTIONBAR_SLOT_CHANGED", M.OnSlot)
	M.OnSlot()
	M.BtnApply()
	M.Schedule()
end

function M.Disable()
	M.on = false
	SUI.Off("ADDON_LOADED", M.OnAddon)
	SUI.Off("ACTIONBAR_SLOT_CHANGED", M.OnSlot)
	if M.autoTask then SUI.Cancel(M.autoTask) end
	M.autoTask = nil
	if M.btnTask then SUI.Cancel(M.btnTask) end
	M.btnTask = nil
	M.MenuClose()
	if M.btn then M.btn:Hide() end
	for i = 1, getn(M.EVENTS) do SUI.Off(M.EVENTS[i], M.OnEvent) end
	SUI.Cancel(M.task)
	M.task = nil
	M.queued, M.queuedWhy = nil, nil
	M.dirty = false
end

-- ---------------------------------------------------------------- commande /sui specs
local function parseSpec(w)
	if w == nil then return nil end
	local n = tonumber(w)
	if n and n >= 0 and n <= 3 and n == math.floor(n) then return n end
	local lw = lower(w)
	if lw == "auto" or lw == "now" or lw == "actuelle" or lw == "current" or lw == "." then
		return M.cur and M.cur.id or 0
	end
	if lw == "hybride" or lw == "hybrid" or lw == "none" or lw == "aucune" then return 0 end
	if M.cur then
		for i = 1, M.cur.n do
			if lower(M.cur.names[i]) == lw then return i end
		end
	end
	return nil
end

function M.Status()
	M.cur = M.Scan() or M.cur
	if not M.cur then
		say("mod.specs.noapi")
		return
	end
	say("mod.specs.now", M.SpecName(M.cur.id), M.Signature(), M.cur.total)
	local ids = { 1, 2, 3, 0 }
	for k = 1, getn(ids) do
		local id = ids[k]
		if id == 0 or id <= M.cur.n then SUI.Print(specLine(id)) end
	end
	if M.HasSAS() then say("mod.specs.sas.on") else say("mod.specs.sas.off") end
end

function M.List()
	local names = M.PresetNames()
	if getn(names) == 0 then
		say("mod.specs.help.nosets")
		return
	end
	for i = 1, getn(names) do SUI.Print(names[i] .. " : " .. M.Summary(M.GetPreset(names[i]))) end
end

function M.Command(rest)
	local w = words(rest)
	local cmd = lower(w[1])
	local mod = SUI.modules.specs
	if cmd ~= "" and cmd ~= "etat" and cmd ~= "status" and cmd ~= "menu" and mod and not mod.enabled then
		say("mod.specs.disabled")
		return
	end
	if cmd == "" or cmd == "etat" or cmd == "status" then
		M.Status()
	elseif cmd == "menu" then
		if SUI.Menu and SUI.Menu.Show then SUI.Menu.Show("specs") end
	elseif cmd == "liste" or cmd == "list" then
		M.List()
	elseif cmd == "sauver" or cmd == "save" then
		local ok, key, a = M.Capture(w[2])
		say(key, a or w[2])
	elseif cmd == "appliquer" or cmd == "apply" then
		local ok, key, a, b = M.Apply(w[2], "manual")
		say(key, a or w[2], b)
	elseif cmd == "lier" or cmd == "link" then
		local id = parseSpec(w[2])
		if not id then
			say("msg.specs.badspec")
		else
			local ok, key, a, b = M.Link(id, w[3])
			say(key, a, b)
		end
	elseif cmd == "oublier" or cmd == "forget" or cmd == "supprimer" or cmd == "delete" then
		local ok, key, a = M.Delete(w[2])
		say(key, a or w[2])
	elseif cmd == "regler" or cmd == "set" then
		local ok, key, a = M.SetField(w[2], lower(w[3]), w[4])
		say(key, a or w[2])
	elseif cmd == "sas" then
		if w[2] then
			local ok, key = M.SwapSAS(w[2])
			if key then say(key) end
		else
			local ok, key = M.OpenSAS()
			if key then say(key) end
		end
	else
		say("help.specs.full")
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("specs", 45)

local function opt(key, typ, order, def, extra)
	local o = { key = "specs." .. key, type = typ, cat = "specs", label = "opt.specs." .. key, tip = "tip.specs." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

SUI.RegisterModule("specs", {
	default = true,
	cost = "light",
	options = {
		-- reglages GLOBAUX (hors profil) : un jeu change de profil, il ne doit pas changer ces reglages en route
		opt("auto", "bool", 10, true, { simple = true, global = true }),
		opt("announce", "bool", 11, true, { simple = true, global = true }),
		opt("delay", "number", 12, 3, { min = 1, max = 10, step = 1, global = true }),
		opt("minpoints", "number", 13, 5, { min = 0, max = 20, step = 1, global = true }),
		opt("autobars", "bool", 19, true, { simple = true, global = true }),
		opt("bars", "bool", 20, true, { simple = true, global = true }),
		opt("bars.clear", "bool", 21, false, { global = true }),
		opt("btn", "bool", 30, true, { simple = true, global = true }),
		opt("btnpos", "choice", 31, "bottom", { choices = { "bottom", "top", "side" }, global = true }),
		opt("btnstyle", "choice", 32, "full", { choices = { "full", "label", "compact" }, global = true }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

M.HookMenu()

SUI.RegisterCommand("specs", function(rest) M.Command(rest) end, "help.specs")
