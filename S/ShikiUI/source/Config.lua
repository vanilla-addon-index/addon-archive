-- ShikiUI Config : reglages a cles plates ("units.width"), profils, roles, positions, export / import sur.
-- Un profil ne stocke que les ecarts par rapport aux valeurs par defaut (export compact, evolutions sans casse).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local Cfg = {}
SUI.Config = Cfg

local getn, tinsert = table.getn, table.insert
local DB_VERSION = 2   -- 2 : db.backups (sauvegardes, Backup.lua)

Cfg.defaults = {}
Cfg.meta = {}
Cfg.watchers = {}
Cfg.cur = { v = {}, pos = {}, mm = {} }
Cfg.curName = "Default"
Cfg.db = nil

-- Modes de jeu (voir Mode.lua) : "normal" = le profil tel quel ; les autres modes ajoutent par-dessus des presets livres
-- (module par module) et les ecarts de l'utilisateur (profil.mm[mode]). Valeur effective, de la plus a la moins prioritaire :
--   ecart utilisateur du mode > preset role+classe > preset classe > preset role > preset generique > valeur du profil > defaut.
Cfg.modeOrder = { "normal", "raid" }
Cfg.mode = "normal"
Cfg.class = nil            -- jeton de classe du joueur (UnitClass), lu a la selection du profil
Cfg.presetDefs = {}        -- mode -> { star = {}, role = {}, class = {}, rc = {} } : valeurs brutes de AddPreset
Cfg.presets = {}           -- mode -> { cle = valeur } : presets fusionnes pour le role / la classe du joueur (cache de lecture)
Cfg.presetBad = {}         -- "mode:cle" -> true : presets ignores (cle inconnue, type invalide, cle globale)
Cfg.CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true,
	WARLOCK = true, DRUID = true }

function Cfg.IsMode(mode)
	for i = 1, getn(Cfg.modeOrder) do
		if Cfg.modeOrder[i] == mode then return true end
	end
	return false
end

SUI.options = {}
SUI.categories = {}

-- ---------------------------------------------------------------- enregistrement des reglages
function Cfg.Register(defs)
	for k, v in pairs(defs) do Cfg.defaults[k] = v end
end

function SUI.RegisterCategory(key, order)
	SUI.categories[key] = order
end

-- Boutons d action d une page de module (en-tete de la page) : SUI.RegisterAction(cat, cle de traduction, fonction, largeur).
SUI.actions = {}
function SUI.RegisterAction(cat, label, fn, w)
	SUI.actions[cat] = SUI.actions[cat] or {}
	tinsert(SUI.actions[cat], { label = label, fn = fn, w = w or 130 })
end

-- opt : { key, type = bool | number | choice | header, cat, label, tip, min, max, step, choices, default,
--         simple = true (visible en mode Simple), order, global = true (hors profil), reload = true }
function SUI.RegisterOption(opt)
	for i = 1, getn(SUI.options) do
		if SUI.options[i].key == opt.key then
			opt.idx = SUI.options[i].idx
			SUI.options[i] = opt
			if opt.default ~= nil then Cfg.defaults[opt.key] = opt.default end
			Cfg.meta[opt.key] = opt
			return
		end
	end
	opt.idx = getn(SUI.options) + 1
	tinsert(SUI.options, opt)
	if opt.default ~= nil then Cfg.defaults[opt.key] = opt.default end
	if opt.type ~= "header" then Cfg.meta[opt.key] = opt end
end

-- ---------------------------------------------------------------- validation et acces
function Cfg.Validate(key, value)
	local def = Cfg.defaults[key]
	if def == nil then return false end
	local t = type(def)
	if type(value) ~= t then
		if t == "number" and type(value) == "string" then value = tonumber(value) end
		if t == "boolean" and (value == 1 or value == 0) then value = (value == 1) end
		if type(value) ~= t then return false end
	end
	local m = Cfg.meta[key]
	if t == "number" then
		if value ~= value then return false end
		if m then
			if m.min and value < m.min then value = m.min end
			if m.max and value > m.max then value = m.max end
			if m.step and m.step > 0 then
				local base = m.min or 0
				value = base + math.floor((value - base) / m.step + 0.5) * m.step
				value = SUI.Round(value, 4)
			end
		end
	elseif t == "string" and m and m.type == "color" then
		-- couleur : "" (pas de surcharge) ou RRGGBB / RRGGBBAA en hexadecimal, rangee en majuscules
		if value ~= "" then
			if not (string.find(value, "^%x%x%x%x%x%x$") or string.find(value, "^%x%x%x%x%x%x%x%x$")) then return false end
			value = string.upper(value)
		end
	elseif t == "string" and m and m.choices then
		local found = false
		for i = 1, getn(m.choices) do
			if m.choices[i] == value then found = true end
		end
		if not found then return false end
	end
	return true, value
end

function Cfg.Get(key)
	local m = Cfg.meta[key]
	if m and m.global and Cfg.db then
		local g = Cfg.db.global[key]
		if g == nil then return Cfg.defaults[key] end
		return g
	end
	local mode = Cfg.mode
	if mode ~= "normal" then
		local o = Cfg.cur.mm
		o = o and o[mode]
		local x = o and o[key]
		if x ~= nil then return x end
		local p = Cfg.presets[mode]
		x = p and p[key]
		if x ~= nil then return x end
	end
	local v = Cfg.cur.v[key]
	if v == nil then return Cfg.defaults[key] end
	return v
end

-- Valeur SANS l'ecart de l'utilisateur pour ce mode (preset > profil > defaut) : sert a ne stocker que de vrais ecarts.
local function below(mode, key)
	if mode ~= "normal" then
		local p = Cfg.presets[mode]
		local x = p and p[key]
		if x ~= nil then return x end
	end
	local v = Cfg.cur.v[key]
	if v == nil then return Cfg.defaults[key] end
	return v
end

-- Valeur d'une cle DANS un mode donne, sans changer de mode (sert a comparer Normal et Raid).
function Cfg.GetIn(mode, key)
	local m = Cfg.meta[key]
	if (m and m.global) or not Cfg.IsMode(mode) then return Cfg.Get(key) end
	if mode ~= "normal" then
		local o = Cfg.cur.mm
		o = o and o[mode]
		local x = o and o[key]
		if x ~= nil then return x end
	end
	return below(mode, key)
end

-- D'ou vient la valeur effective : "override" | "preset" | "profile" | "default" | "global".
function Cfg.Source(key)
	local m = Cfg.meta[key]
	if m and m.global then return "global" end
	local mode = Cfg.mode
	if mode ~= "normal" then
		local o = Cfg.cur.mm
		o = o and o[mode]
		if o and o[key] ~= nil then return "override" end
		local p = Cfg.presets[mode]
		if p and p[key] ~= nil then return "preset" end
	end
	if Cfg.cur.v[key] ~= nil then return "profile" end
	return "default"
end

-- Ecrit dans la couche du mode donne : "normal" = le profil lui-meme (ecarts au defaut) ; un autre mode = ses ecarts propres.
function Cfg.SetIn(mode, key, value)
	local ok, v = Cfg.Validate(key, value)
	if not ok or not Cfg.IsMode(mode) then
		if SUI.LogOpt then SUI.LogOpt("REFUSE " .. tostring(mode) .. " " .. tostring(key) .. " = " .. tostring(value)) end
		return false
	end
	local old = Cfg.Get(key)
	local m = Cfg.meta[key]
	if m and m.global and Cfg.db then
		Cfg.db.global[key] = v
	elseif mode == "normal" then
		if v == Cfg.defaults[key] then
			Cfg.cur.v[key] = nil
		else
			Cfg.cur.v[key] = v
		end
	else
		if type(Cfg.cur.mm) ~= "table" then Cfg.cur.mm = {} end
		local o = Cfg.cur.mm[mode]
		if type(o) ~= "table" then
			o = {}
			Cfg.cur.mm[mode] = o
		end
		if v == below(mode, key) then
			o[key] = nil
		else
			o[key] = v
		end
	end
	local new = Cfg.Get(key)
	if SUI.LogOpt then SUI.LogOpt(tostring(mode) .. " " .. tostring(key) .. " " .. tostring(old) .. " -> " .. tostring(new)) end
	if old ~= new then Cfg.Notify(key, new) end
	return true
end

-- Cfg.Set ecrit dans le mode COURANT (en mode Raid, un reglage change reste propre au mode Raid) ; Cfg.SetBase ecrit toujours
-- dans le profil de base (modeles de role, import).
function Cfg.Set(key, value)
	return Cfg.SetIn(Cfg.mode, key, value)
end

function Cfg.SetBase(key, value)
	return Cfg.SetIn("normal", key, value)
end

-- Le reglage a-t-il une valeur propre a la couche courante (profil en Normal, ecart en Raid) ? Sert au bouton "reinitialiser".
function Cfg.IsModified(key)
	local m = Cfg.meta[key]
	if m and m.global then
		local g = Cfg.db and Cfg.db.global[key]
		return g ~= nil and g ~= Cfg.defaults[key]
	end
	if Cfg.mode ~= "normal" then
		local o = Cfg.cur.mm
		o = o and o[Cfg.mode]
		return (o and o[key] ~= nil) and true or false
	end
	return Cfg.cur.v[key] ~= nil
end

-- Reinitialise UN reglage dans la couche courante : en Normal retour a la valeur par defaut, dans un autre mode retrait de
-- l'ecart de l'utilisateur (on retombe sur le preset livre, ou sur le profil). Retourne true si quelque chose a change.
function Cfg.Reset(key)
	local m = Cfg.meta[key]
	if not m then return false end
	local old = Cfg.Get(key)
	if m.global and Cfg.db then
		Cfg.db.global[key] = nil
	elseif Cfg.mode ~= "normal" then
		local o = Cfg.cur.mm
		o = o and o[Cfg.mode]
		if o then o[key] = nil end
	else
		Cfg.cur.v[key] = nil
	end
	local new = Cfg.Get(key)
	if old ~= new then Cfg.Notify(key, new) end
	return old ~= new
end

-- Efface les ecarts de l'utilisateur pour un mode (retour aux presets livres).
function Cfg.ResetMode(mode)
	if mode == "normal" or not Cfg.IsMode(mode) then return false end
	if type(Cfg.cur.mm) == "table" then Cfg.cur.mm[mode] = nil end
	Cfg.Notify(nil, nil)
	return true
end

function Cfg.GetGlobal(k)
	if Cfg.db then return Cfg.db.global[k] end
	return nil
end

function Cfg.SetGlobal(k, v)
	if Cfg.db then Cfg.db.global[k] = v end
end

-- ---------------------------------------------------------------- observateurs
-- fn(key, value) ; key == nil : tout a pu changer (changement de profil, reinitialisation, import).
function Cfg.Watch(prefix, fn)
	tinsert(Cfg.watchers, { prefix = prefix, len = string.len(prefix), fn = fn })
end

function Cfg.Unwatch(fn)
	for i = getn(Cfg.watchers), 1, -1 do
		if Cfg.watchers[i].fn == fn then table.remove(Cfg.watchers, i) end
	end
end

-- Garde anti-recursion : un watcher qui re-ecrit (Set -> Notify) ne redelclenche pas une chaine infinie.
Cfg.notifyDepth = 0
function Cfg.Notify(key, value)
	if Cfg.notifyDepth >= 4 then return end   -- 4 niveaux de cascade max (au-dela : bug de code, on coupe)
	Cfg.notifyDepth = Cfg.notifyDepth + 1
	local okAll = true
	local i
	for i = 1, getn(Cfg.watchers) do
		local w = Cfg.watchers[i]
		if key == nil or string.sub(key, 1, w.len) == w.prefix then
			local ok, err = pcall(w.fn, key, value)
			if not ok then SUI.Report("watch " .. w.prefix, err) end
		end
	end
	Cfg.notifyDepth = Cfg.notifyDepth - 1
end

-- ---------------------------------------------------------------- base de donnees et profils
local function newProfile()
	return { v = {}, pos = {}, mm = {} }
end

-- Garde seulement les valeurs valides et non globales de t (nettoie en place).
local function cleanValues(t)
	for k, val in pairs(t) do
		local ok, cv = Cfg.Validate(k, val)
		if not ok or (Cfg.meta[k] and Cfg.meta[k].global) then
			t[k] = nil
		elseif cv ~= val then
			t[k] = cv
		end
	end
end

local function sanitizeProfile(p)
	if type(p.v) ~= "table" then p.v = {} end
	if type(p.pos) ~= "table" then p.pos = {} end
	if type(p.mm) ~= "table" then p.mm = {} end
	if type(p.layout) ~= "string" or not string.find(p.layout, "^[a-z][a-z0-9]+$") or string.len(p.layout) > 24 then p.layout = nil end
	cleanValues(p.v)
	for mode, o in pairs(p.mm) do
		if mode == "normal" or not Cfg.IsMode(mode) or type(o) ~= "table" then
			p.mm[mode] = nil
		else
			cleanValues(o)
			if next(o) == nil then p.mm[mode] = nil end
		end
	end
end

function Cfg.Init()
	if type(ShikiUIDB) ~= "table" then ShikiUIDB = {} end
	local db = ShikiUIDB
	if type(db.profiles) ~= "table" then db.profiles = {} end
	if type(db.chars) ~= "table" then db.chars = {} end
	if type(db.global) ~= "table" then db.global = {} end
	if db.global.locale == nil then db.global.locale = "fr" end
	if db.global.firstRun == nil then db.global.firstRun = true end
	if db.global.menuMode == nil then db.global.menuMode = "simple" end
	if type(db.global.coexist) ~= "table" then db.global.coexist = {} end
	if type(db.backups) ~= "table" then db.backups = {} end
	for name, p in pairs(db.profiles) do
		if type(p) ~= "table" or type(name) ~= "string" then db.profiles[name] = nil end
	end
	if type(db.profiles.Default) ~= "table" then db.profiles.Default = newProfile() end
	db.v = DB_VERSION
	Cfg.db = db
	Cfg.cur = db.profiles.Default
	Cfg.curName = "Default"
end

function Cfg.CharKey()
	local n = UnitName("player") or "?"
	local r = GetRealmName and GetRealmName() or "?"
	return n .. "-" .. r
end

function Cfg.SelectProfile(name)
	if not Cfg.db then Cfg.Init() end
	local db = Cfg.db
	local key = Cfg.CharKey()
	if not name then name = db.chars[key] end
	if not name or type(db.profiles[name]) ~= "table" then
		name = "Default"
		if type(db.profiles.Default) ~= "table" then db.profiles.Default = newProfile() end
	end
	db.chars[key] = name
	Cfg.cur = db.profiles[name]
	Cfg.curName = name
	sanitizeProfile(Cfg.cur)
	if UnitClass then
		local _, token = UnitClass("player")
		if Cfg.CLASSES[token] then Cfg.class = token end
	end
	Cfg.RebuildPresets()
	Cfg.Notify(nil, nil)
	return name
end

function Cfg.ListProfiles()
	local t = {}
	if Cfg.db then
		for name, _ in pairs(Cfg.db.profiles) do tinsert(t, name) end
	end
	table.sort(t)
	return t
end

local function validName(name)
	if type(name) ~= "string" then return false end
	local len = string.len(name)
	if len < 1 or len > 24 then return false end
	return string.find(name, "^[%w_%-]+$") ~= nil
end

local function copyTable(t)
	local c = {}
	for k, v in pairs(t) do
		if type(v) == "table" then c[k] = copyTable(v) else c[k] = v end
	end
	return c
end

-- Retourne ok, cle de message.
function Cfg.NewProfile(name, copyFrom)
	if not validName(name) then return false, "msg.profile.badname" end
	if Cfg.db.profiles[name] then return false, "msg.profile.exists" end
	if copyFrom then
		local src = Cfg.db.profiles[copyFrom]
		if not src then return false, "msg.profile.unknown" end
		Cfg.db.profiles[name] = copyTable(src)
	else
		Cfg.db.profiles[name] = newProfile()
	end
	return true, "msg.profile.created"
end

function Cfg.DeleteProfile(name)
	if not Cfg.db.profiles[name] then return false, "msg.profile.unknown" end
	if name == Cfg.curName then return false, "msg.profile.current" end
	if getn(Cfg.ListProfiles()) <= 1 then return false, "msg.profile.last" end
	if SUI.Backup then SUI.Backup.Create("delete", nil, name) end   -- jamais de suppression sans instantane
	Cfg.db.profiles[name] = nil
	return true, "msg.profile.deleted"
end

-- Renomme un profil (les personnages qui l'utilisent le suivent). Retourne ok, cle de message.
function Cfg.RenameProfile(old, new)
	if not Cfg.db.profiles[old] then return false, "msg.profile.unknown" end
	if not validName(new) then return false, "msg.profile.badname" end
	if Cfg.db.profiles[new] then return false, "msg.profile.exists" end
	Cfg.db.profiles[new] = Cfg.db.profiles[old]
	Cfg.db.profiles[old] = nil
	for k, v in pairs(Cfg.db.chars) do
		if v == old then Cfg.db.chars[k] = new end
	end
	for i = 1, getn(Cfg.db.backups) do
		if Cfg.db.backups[i].profile == old then Cfg.db.backups[i].profile = new end
	end
	if Cfg.curName == old then Cfg.curName = new end
	return true, "msg.menu.prof.renamed"
end

function Cfg.UseProfile(name)
	if not Cfg.db.profiles[name] then return false, "msg.profile.unknown" end
	Cfg.SelectProfile(name)
	return true, "msg.profile.switched"
end

function Cfg.ResetProfile()
	if SUI.Backup then SUI.Backup.Create("reset") end   -- jamais d'ecrasement sans instantane
	Cfg.cur.v = {}
	Cfg.cur.pos = {}
	Cfg.cur.mm = {}
	Cfg.cur.role = nil
	Cfg.cur.layout = nil
	Cfg.RebuildPresets()
	Cfg.Notify(nil, nil)
end

-- ---------------------------------------------------------------- roles (profils de depart)
-- Seules des cles ShikiUI existantes ; ce sont des choix d'interface, pas des donnees de jeu.
Cfg.roleOrder = { "tank", "heal", "dps", "pvp" }
Cfg.roles = {
	tank = { ["units.tot.enabled"] = true,  ["units.hptext"] = "both",    ["units.range"] = true,  ["units.smooth"] = true,  ["units.classcolor"] = true },
	heal = { ["units.tot.enabled"] = false, ["units.hptext"] = "percent", ["units.range"] = true,  ["units.smooth"] = true,  ["units.classcolor"] = true },
	dps  = { ["units.tot.enabled"] = true,  ["units.hptext"] = "percent", ["units.range"] = true,  ["units.smooth"] = true,  ["units.classcolor"] = true },
	pvp  = { ["units.tot.enabled"] = true,  ["units.hptext"] = "percent", ["units.range"] = true,  ["units.smooth"] = false, ["units.classcolor"] = true },
}

function Cfg.ApplyRole(role)
	local preset = Cfg.roles[role]
	if not preset then return false end
	for k, v in pairs(preset) do Cfg.SetBase(k, v) end
	Cfg.cur.role = role
	Cfg.RebuildPresets()
	Cfg.Notify("role", role)
	return true
end

function Cfg.GetRole()
	return Cfg.cur.role
end

-- ---------------------------------------------------------------- presets de mode (livres par ShikiUI et par les modules)
-- Cfg.AddPreset(mode, spec, { ["cle"] = valeur, ... }) ; spec : "*" (tous), un role ("tank"), une classe ("PALADIN") ou
-- "role/CLASSE" ("heal/PALADIN"). Le mode "normal" n'a pas de preset (c'est le profil). Un module peut aussi se declarer
-- 'raid = "off"' dans RegisterModule : il est alors coupe en mode Raid (couche la plus basse, les presets et l'utilisateur gagnent).
-- Les cles inconnues ou de type invalide sont ignorees (voir Cfg.presetBad) ; rien n'est ecrit dans le profil.
function Cfg.AddPreset(mode, spec, tbl)
	if type(mode) ~= "string" or mode == "normal" or not Cfg.IsMode(mode) or type(spec) ~= "string" or type(tbl) ~= "table" then
		return false
	end
	local slot, name
	if spec == "*" then
		slot = "star"
	else
		local _, _, a, b = string.find(spec, "^(%a+)/(%a+)$")
		if a then
			if not Cfg.roles[a] or not Cfg.CLASSES[b] then return false end
			slot, name = "rc", spec
		elseif Cfg.roles[spec] then
			slot, name = "role", spec
		elseif Cfg.CLASSES[spec] then
			slot, name = "class", spec
		else
			return false
		end
	end
	local d = Cfg.presetDefs[mode]
	if not d then
		d = { star = {}, role = {}, class = {}, rc = {} }
		Cfg.presetDefs[mode] = d
	end
	local target = d[slot]
	if name then
		if type(target[name]) ~= "table" then target[name] = {} end
		target = target[name]
	end
	for k, v in pairs(tbl) do target[k] = v end
	Cfg.RebuildPresets()
	return true
end

local function mergePreset(out, src, mode)
	for k, v in pairs(src) do
		local ok, cv = Cfg.Validate(k, v)
		if ok and not (Cfg.meta[k] and Cfg.meta[k].global) then
			out[k] = cv
		else
			Cfg.presetBad[mode .. ":" .. tostring(k)] = true
		end
	end
end

-- Recalcule les presets fusionnes du joueur (role du profil + classe). Appele a la selection du profil, au changement de role
-- et a chaque AddPreset : hors de ce cas la lecture d'une valeur ne fait que deux acces de table.
function Cfg.RebuildPresets()
	local role = Cfg.cur and Cfg.cur.role
	local class = Cfg.class
	Cfg.presetBad = {}
	local res = {}
	for mi = 1, getn(Cfg.modeOrder) do
		local mode = Cfg.modeOrder[mi]
		if mode ~= "normal" then
			local out = {}
			for i = 1, getn(SUI.moduleOrder) do
				local def = SUI.modules[SUI.moduleOrder[i]]
				if def and def[mode] == "off" then out["modules." .. def.name] = false end
			end
			local d = Cfg.presetDefs[mode]
			if d then
				mergePreset(out, d.star, mode)
				if role and d.role[role] then mergePreset(out, d.role[role], mode) end
				if class and d.class[class] then mergePreset(out, d.class[class], mode) end
				if role and class and d.rc[role .. "/" .. class] then mergePreset(out, d.rc[role .. "/" .. class], mode) end
			end
			res[mode] = out
		end
	end
	Cfg.presets = res
end

-- Change le mode effectif (sans condition : la prudence en combat et la persistance sont dans Mode.lua).
function Cfg.SetMode(mode)
	if not Cfg.IsMode(mode) then return false end
	if Cfg.mode == mode then return true end
	Cfg.mode = mode
	Cfg.Notify(nil, nil)
	return true
end

-- ---------------------------------------------------------------- positions des cadres
function Cfg.GetPos(key)
	local p = Cfg.cur.pos[key]
	if type(p) == "table" and type(p.l) == "number" and type(p.b) == "number" then
		local l = p.l
		-- centre horizontal memorise (preset "c") : le bord gauche suit la largeur ACTUELLE du cadre (barre de formes, etc.)
		if type(p.cx) == "number" and Cfg.cxWidth then
			local base, bar = key, string.find(key, "|", 1, true)
			if bar then base = string.sub(key, 1, bar - 1) end
			local w = Cfg.cxWidth(base)
			if w and w > 1 then l = math.floor(p.cx - w / 2 + 0.5) end
		end
		return l, p.b, (type(p.s) == "number") and p.s or nil
	end
	return nil
end

-- s : facteur d'echelle propre au cadre (service Mover), facultatif ; 1 = pas de facteur
function Cfg.SetPos(key, l, b, s, cx)
	local e = { l = math.floor(l + 0.5), b = math.floor(b + 0.5) }
	if type(cx) == "number" then e.cx = math.floor(cx + 0.5) end
	if type(s) == "number" and s > 0.49 and s < 2.01 and math.abs(s - 1) > 0.001 then e.s = SUI.Round(s, 2) end
	Cfg.cur.pos[key] = e
end

function Cfg.ClearPos(key)
	Cfg.cur.pos[key] = nil
end

-- Efface la position d'un cadre dans tous les modes (cle seule et cle|mode).
function Cfg.ClearPosAll(key)
	Cfg.cur.pos[key] = nil
	for i = 1, getn(Cfg.modeOrder) do
		if Cfg.modeOrder[i] ~= "normal" then Cfg.cur.pos[key .. "|" .. Cfg.modeOrder[i]] = nil end
	end
end

function Cfg.ResetPositions()
	Cfg.cur.pos = {}
	Cfg.Notify("pos", nil)
end

-- ---------------------------------------------------------------- export / import
function Cfg.Export()
	local payload = { v = 1, name = Cfg.curName, role = Cfg.cur.role, layout = Cfg.cur.layout, c = copyTable(Cfg.cur.v), pos = copyTable(Cfg.cur.pos),
		mm = copyTable(Cfg.cur.mm or {}) }
	return SUI.Serial.Pack(payload)
end

-- Retourne true, nomDuProfil, acceptes, ignores  |  false, raison
function Cfg.Import(str, name)
	local p, err = SUI.Serial.Unpack(str)
	if not p then return false, err end
	if type(p) ~= "table" or p.v ~= 1 or type(p.c) ~= "table" then return false, "format" end
	name = name or p.name or "Import"
	if type(name) ~= "string" or not validName(name) then name = "Import" end
	local base, n = name, 1
	while Cfg.db.profiles[name] do
		n = n + 1
		name = base .. n
	end
	local prof = newProfile()
	local accepted, ignored = 0, 0
	for k, val in pairs(p.c) do
		local ok, cv = Cfg.Validate(k, val)
		if ok and not (Cfg.meta[k] and Cfg.meta[k].global) then
			if cv ~= Cfg.defaults[k] then prof.v[k] = cv end
			accepted = accepted + 1
		else
			ignored = ignored + 1
		end
	end
	if type(p.pos) == "table" then
		local npos = 0
		for k, e in pairs(p.pos) do
			if type(k) == "string" and string.len(k) <= 40 and npos < 128 and type(e) == "table"
				and type(e.l) == "number" and type(e.b) == "number"
				and e.l > -3000 and e.l < 8000 and e.b > -3000 and e.b < 8000 then
				prof.pos[k] = { l = math.floor(e.l + 0.5), b = math.floor(e.b + 0.5) }
				if type(e.s) == "number" and e.s > 0.49 and e.s < 2.01 then prof.pos[k].s = SUI.Round(e.s, 2) end
				npos = npos + 1
			else
				ignored = ignored + 1
			end
		end
	end
	if type(p.role) == "string" and Cfg.roles[p.role] then prof.role = p.role end
	if type(p.layout) == "string" and string.find(p.layout, "^[a-z][a-z0-9]+$") and string.len(p.layout) <= 24 then prof.layout = p.layout end
	if type(p.mm) == "table" then
		for mode, o in pairs(p.mm) do
			if type(mode) == "string" and mode ~= "normal" and Cfg.IsMode(mode) and type(o) == "table" then
				local keep = {}
				for k, val in pairs(o) do
					local ok, cv = Cfg.Validate(k, val)
					if ok and not (Cfg.meta[k] and Cfg.meta[k].global) then
						keep[k] = cv
						accepted = accepted + 1
					else
						ignored = ignored + 1
					end
				end
				if next(keep) ~= nil then prof.mm[mode] = keep end
			else
				ignored = ignored + 1
			end
		end
	end
	Cfg.db.profiles[name] = prof
	return true, name, accepted, ignored
end

-- la langue suit le reglage ui.locale
Cfg.Watch("ui.locale", function(key, value)
	if key and type(value) == "string" then SUI.SetLocale(value) end
end)

-- ---------------------------------------------------------------- reglages communs de l'interface
SUI.RegisterCategory("general", 1)
SUI.RegisterCategory("modules", 9)
SUI.RegisterOption({ key = "ui.scale", type = "number", cat = "general", label = "opt.ui.scale", tip = "tip.ui.scale",
	min = 0.7, max = 1.3, step = 0.05, default = 1.0, simple = true, order = 10 })
SUI.RegisterOption({ key = "ui.locked", type = "bool", cat = "general", label = "opt.ui.locked", tip = "tip.ui.locked",
	default = true, simple = true, order = 20 })
SUI.RegisterOption({ key = "ui.accent", type = "choice", cat = "general", label = "opt.ui.accent", tip = "tip.ui.accent",
	choices = { "style", "blue", "green", "orange", "class" }, default = "style", order = 30 })
SUI.RegisterOption({ key = "ui.locale", type = "choice", cat = "general", label = "opt.ui.locale", tip = "tip.ui.locale",
	choices = { "fr", "en" }, default = "fr", global = true, simple = true, order = 5 })
