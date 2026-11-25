-- ShikiUI Backup : instantanes (sauvegardes) du profil, manuels et automatiques, rotation, restauration. Regle : on n'ecrase JAMAIS un profil
-- sans avoir pris un instantane juste avant (reinitialisation, suppression, import pfUI, assistant, restauration).
-- Stockage : ShikiUIDB.backups = liste (du plus ancien au plus recent) de { id, t, reason, label, profile, role, layout, v, pos, mm, g, n }.
--   reason : manual (jamais tourne sauf plafond B.MAXMANUAL) | wizard | import | reset | delete | restore | update | periodic | logout.
--   g : reglages GLOBAUX (hors profil : langue...) au moment de l'instantane.
-- Reglages (globaux) : backup.auto (interrupteur des instantanes automatiques periodiques / deconnexion / mise a jour), backup.keep (nombre
-- d'instantanes automatiques gardes, rotation), backup.hours (periodicite, 0 = jamais), backup.logout (a la deconnexion).
-- Les instantanes de securite (reset, delete, restore, import, wizard) sont pris meme si backup.auto est coupe : ce sont des garde-fous.
-- NON VERIFIE EN JEU : l'evenement PLAYER_LOGOUT (le noyau detache ses evenements au meme moment : l'ordre n'est pas garanti), time() et
-- date() du client 1.12.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local B = {}
SUI.Backup = B

local getn, tinsert, tremove = table.getn, table.insert, table.remove

B.MAXMANUAL = 30
B.SAFE = { wizard = true, reset = true, delete = true, restore = true }

local function copyT(t)
	local c = {}
	if type(t) ~= "table" then return c end
	for k, v in pairs(t) do
		if type(v) == "table" then c[k] = copyT(v) else c[k] = v end
	end
	return c
end

local function now()
	local tf = getglobal("time")
	if tf then
		local ok, t = pcall(tf)
		if ok and type(t) == "number" then return t end
	end
	return 0
end

function B.Stamp(t)
	local df = getglobal("date")
	if type(t) == "number" and t > 0 and df then
		local ok, s = pcall(df, "%Y-%m-%d %H:%M", t)
		if ok and type(s) == "string" then return s end
	end
	return "-"
end

local function countKeys(t)
	local n = 0
	if type(t) == "table" then
		for _, _ in pairs(t) do n = n + 1 end
	end
	return n
end

-- Signature texte du contenu d'un profil ou d'un instantane (sert a ne pas empiler deux copies identiques).
local function sig(p)
	if not SUI.Serial then return nil end
	local ok, s = pcall(SUI.Serial.Pack, { v = p.v, pos = p.pos, mm = p.mm, role = p.role or "", layout = p.layout or "" })
	if ok and type(s) == "string" then return s end
	return nil
end

function B.List()
	local t = {}
	local db = C.db
	if not db then return t end
	for i = getn(db.backups), 1, -1 do tinsert(t, db.backups[i]) end
	return t
end

function B.Find(id)
	local db = C.db
	if not db then return nil end
	id = tonumber(id)
	for i = 1, getn(db.backups) do
		if db.backups[i].id == id then return db.backups[i], i end
	end
	return nil
end

function B.Rotate()
	local db = C.db
	if not db then return end
	local list = db.backups
	local keep = C.Get("backup.keep") or 6
	local n, m = 0, 0
	for i = getn(list), 1, -1 do
		if list[i].reason == "manual" then
			m = m + 1
			if m > B.MAXMANUAL then tremove(list, i) end
		else
			n = n + 1
			if n > keep then tremove(list, i) end
		end
	end
end

-- Cree un instantane du profil donne (le profil actif par defaut). Retourne l'identifiant, ou nil.
function B.Create(reason, label, name)
	local db = C.db
	if not db then return nil end
	name = name or C.curName
	local p = db.profiles[name]
	if type(p) ~= "table" then return nil end
	db.global.backupSeq = (tonumber(db.global.backupSeq) or 0) + 1
	local rec = { id = db.global.backupSeq, t = now(), reason = reason or "manual", label = label, profile = name,
		role = p.role, layout = p.layout, v = copyT(p.v), pos = copyT(p.pos), mm = copyT(p.mm), g = {} }
	for k, m in pairs(C.meta) do
		if m.global and db.global[k] ~= nil then rec.g[k] = db.global[k] end
	end
	rec.n = countKeys(rec.v)
	tinsert(db.backups, rec)
	B.Rotate()
	return rec.id
end

-- Instantane automatique (periodique, deconnexion, mise a jour) : respecte backup.auto et saute une copie identique a la derniere.
function B.AutoCreate(reason, label)
	if not C.db or not C.Get("backup.auto") then return nil end
	local p = C.db.profiles[C.curName]
	if type(p) ~= "table" then return nil end
	local list = C.db.backups
	for i = getn(list), 1, -1 do
		if list[i].profile == C.curName then
			if sig(list[i]) ~= nil and sig(list[i]) == sig(p) then return nil end
			break
		end
	end
	local id = B.Create(reason, label)
	if id then C.db.global.lastAuto = now() end
	return id
end

function B.Delete(id)
	local rec, i = B.Find(id)
	if not rec then return false, "msg.menu.bk.unknown" end
	tremove(C.db.backups, i)
	return true, "msg.menu.bk.deleted"
end

function B.Summary(rec)
	local L = SUI.L
	return L("mod.menu.bk.sum", rec.n or countKeys(rec.v), countKeys(rec.pos), rec.role or "-")
end

function B.Reason(rec)
	local L = SUI.L
	local key = "mod.menu.bk.reason." .. tostring(rec.reason)
	local txt = L(key)
	if txt == key then return tostring(rec.reason) end
	return txt
end

-- Restaure un instantane dans le profil d'ou il vient (recree s'il a ete supprime) ; un instantane de securite est pris AVANT.
-- Retourne ok, cle de message, nom du profil.
function B.Restore(id)
	local rec = B.Find(id)
	if not rec then return false, "msg.menu.bk.unknown" end
	if SUI.InCombat() then return false, "msg.combat.locked" end
	local db = C.db
	local name = rec.profile
	if type(db.profiles[name]) == "table" then B.Create("restore", nil, name) end
	local p = db.profiles[name]
	if type(p) ~= "table" then
		p = { v = {}, pos = {}, mm = {} }
		db.profiles[name] = p
	end
	p.v, p.pos, p.mm = copyT(rec.v), copyT(rec.pos), copyT(rec.mm)
	p.role, p.layout = rec.role, rec.layout
	for k, v in pairs(rec.g or {}) do db.global[k] = v end
	C.SelectProfile(name)
	if SUI.SetLocale then SUI.SetLocale(C.Get("ui.locale")) end
	if SUI.Layout and SUI.Layout.ApplyAll then SUI.Layout.ApplyAll() end
	return true, "msg.menu.bk.restored", name
end

-- ---------------------------------------------------------------- evenements
function B.OnLogin()
	local db = C.db
	if not db then return end
	local first = C.GetGlobal("firstRun")
	local last = db.global.lastVersion
	if not first and last and last ~= SUI.VERSION then B.AutoCreate("update", tostring(last) .. " > " .. tostring(SUI.VERSION)) end
	db.global.lastVersion = SUI.VERSION
	local hours = C.Get("backup.hours") or 0
	if not first and hours > 0 then
		local t = now()
		if t > 0 and (t - (tonumber(db.global.lastAuto) or 0)) >= hours * 3600 then B.AutoCreate("periodic") end
	end
end

function B.OnLogout()
	if C.db and C.Get("backup.logout") then B.AutoCreate("logout") end
end

SUI.On("PLAYER_LOGIN", B.OnLogin)
SUI.On("PLAYER_LOGOUT", B.OnLogout)

-- ---------------------------------------------------------------- reglages
SUI.RegisterOption({ key = "backup.auto", type = "bool", cat = "general", label = "opt.menu.backup.auto", tip = "tip.menu.backup.auto",
	default = true, global = true, order = 60 })
SUI.RegisterOption({ key = "backup.keep", type = "number", cat = "general", label = "opt.menu.backup.keep", tip = "tip.menu.backup.keep",
	default = 6, min = 1, max = 20, step = 1, global = true, order = 61 })
SUI.RegisterOption({ key = "backup.hours", type = "number", cat = "general", label = "opt.menu.backup.hours", tip = "tip.menu.backup.hours",
	default = 24, min = 0, max = 168, step = 6, global = true, order = 62 })
SUI.RegisterOption({ key = "backup.logout", type = "bool", cat = "general", label = "opt.menu.backup.logout", tip = "tip.menu.backup.logout",
	default = true, global = true, order = 63 })

-- ---------------------------------------------------------------- commande  /sui backup [now [nom] | list | restore <id> | delete <id>]
local function out(msg)
	SUI.Print(msg)
end

SUI.RegisterCommand("backup", function(rest)
	local L = SUI.L
	local _, _, sub, arg = string.find(rest or "", "^%s*(%S*)%s*(.-)%s*$")
	sub = string.lower(sub or "")
	if sub == "now" then
		local id = B.Create("manual", arg ~= "" and string.sub(arg, 1, 24) or nil)
		if id then out(L("msg.menu.bk.created", id)) end
	elseif sub == "restore" then
		local ok, key, name = B.Restore(arg)
		if ok then out(L(key, name)) else out(L(key)) end
	elseif sub == "delete" then
		local ok, key = B.Delete(arg)
		out(L(key))
	else
		local list = B.List()
		if getn(list) == 0 then out(L("msg.menu.bk.none")) end
		for i = 1, getn(list) do
			local r = list[i]
			out(L("msg.menu.bk.line", r.id, B.Stamp(r.t) .. "  " .. B.Reason(r), r.label or r.profile, B.Summary(r)))
		end
		out(L("mod.menu.bk.usage"))
	end
end, "mod.menu.bk.help")
