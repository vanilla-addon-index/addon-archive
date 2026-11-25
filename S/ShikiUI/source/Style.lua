-- ShikiUI Style : registre de styles (SUI.RegisterStyle), resolution des jetons, reglages utilisateur, import / export, polices et textures.
-- Un style est une table de DONNEES (jamais de code, jamais de chemin de fichier : seulement des NOMS de ressources connues de Theme.lua) :
--   { label = "style.<id>.label", desc = "style.<id>.desc",            -- cles de traduction (facultatives pour un style importe)
--     c = { bg = "RRGGBB[AA]", panel, inset, border, text, dim, good, warn, bad },   -- couleurs hexadecimales
--     accent = "blue" | "green" | "orange" | "class" | "RRGGBB",
--     font = "arial" | "frizqt", outline = "none" | "outline" | "thick", fontScale = 0.6..1.8,
--     bar = "flat" | "blizzard", panel = "flat" | "tooltip" | "dialog", edge = "none" | "thin" | "thick" | "rounded" | "dialog",
--     button = "flat" | "blizzard", alpha = 0.3..1 }
-- Tout champ absent prend la valeur du style de base (Shiki) : un style partiel ou venu d'ailleurs est toujours complet une fois resolu.
-- Un style se range dans UN fichier ShikiUI\Style_<Nom>.lua (appel SUI.RegisterStyle + SUI.AddStrings), sans toucher au noyau.
-- Valeur effective d'un jeton (de la plus a la moins prioritaire) :
--   reglage utilisateur style.* (priorite des couches habituelles : ecart du mode > preset du mode > profil > defaut) > champ du style choisi > style de base.
-- Les styles importes (chaine partageable) sont stockes dans ShikiUIDB.global.styles et revalides a CHAQUE chargement.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local T = SUI.Theme
local L = SUI.L
local S = {}
SUI.Style = S

local getn, tinsert = table.getn, table.insert

S.DEFAULT = "shiki"
S.styles = {}          -- id -> { name, def, origin = "builtin" | "user" }
S.names = {}           -- ids dans l'ordre d'enregistrement : liste VIVANTE partagee avec les choix de style.name
S.cur = nil            -- jetons resolus appliques
S.sig = ""             -- signature des jetons appliques (pas de repeinture si rien ne change)
S.applied = 0          -- nombre d'applications reelles (pour les tests)
S.missing = {}         -- "famille:nom" -> true : ressource personnalisee dont le fichier semble absent (repli automatique)
local MAX_USER = 24

-- ---------------------------------------------------------------- couleurs
-- "RRGGBB" ou "RRGGBBAA" -> r, g, b, a (0..1) ; nil si invalide.
function S.ParseHex(h)
	if type(h) ~= "string" then return nil end
	local _, _, rr, gg, bb, aa = string.find(h, "^(%x%x)(%x%x)(%x%x)(%x?%x?)$")
	if not rr then return nil end
	if aa ~= "" and string.len(aa) ~= 2 then return nil end
	local a = 255
	if aa ~= "" then a = tonumber(aa, 16) end
	return tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255, a / 255
end

function S.Hex(r, g, b, a)
	local function byte(x) return math.floor(math.max(0, math.min(1, x)) * 255 + 0.5) end
	return string.format("%02X%02X%02X%02X", byte(r), byte(g), byte(b), byte(a or 1))
end

-- Style de base : tout champ absent d'un style vient d'ici (c'est la palette du style "Shiki").
local BASE = {
	c = { bg = "111214F2", panel = "181A1DF2", inset = "0C0C0EFF", border = "33363DFF", text = "E6E8EDFF", dim = "9499A6FF",
		good = "5CCC78FF", warn = "F2C242FF", bad = "E85454FF" },
	accent = "blue", font = "arial", outline = "none", fontScale = 1, bar = "flat", panel = "flat", edge = "thin",
	button = "flat", alpha = 1,
}
S.BASE = BASE

local FAMILIES = { "font", "outline", "bar", "panel", "edge", "button" }
local KNOWN = { c = true, accent = true, font = true, outline = true, fontScale = true, bar = true, panel = true, edge = true,
	button = true, alpha = true, label = true, desc = true }

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function assetOk(fam, name)
	return type(name) == "string" and T.assets[fam] ~= nil and T.assets[fam][name] ~= nil and not S.missing[fam .. ":" .. name]
end

-- Nettoie un style (donnees venues d'un fichier, d'une chaine importee ou de la sauvegarde). Retourne propre, nombre_ignore.
function S.Sanitize(def)
	local clean = { c = {} }
	local bad = 0
	if type(def) ~= "table" then return clean, 1 end
	for k, _ in pairs(def) do
		if not KNOWN[k] then bad = bad + 1 end
	end
	if type(def.c) == "table" then
		for k, h in pairs(def.c) do
			local known = false
			for i = 1, getn(T.colorNames) do
				if T.colorNames[i] == k then known = true end
			end
			if known and S.ParseHex(h) then clean.c[k] = string.upper(h) else bad = bad + 1 end
		end
	elseif def.c ~= nil then
		bad = bad + 1
	end
	for i = 1, getn(FAMILIES) do
		local fam = FAMILIES[i]
		if def[fam] ~= nil then
			if assetOk(fam, def[fam]) then clean[fam] = def[fam] else bad = bad + 1 end
		end
	end
	if def.fontScale ~= nil then
		if type(def.fontScale) == "number" and def.fontScale == def.fontScale then clean.fontScale = clamp(def.fontScale, 0.6, 1.8) else bad = bad + 1 end
	end
	if def.alpha ~= nil then
		if type(def.alpha) == "number" and def.alpha == def.alpha then clean.alpha = clamp(def.alpha, 0.3, 1) else bad = bad + 1 end
	end
	if def.accent ~= nil then
		local a = def.accent
		if type(a) == "string" and (T.accents[a] or a == "class" or string.find(a, "^%x%x%x%x%x%x$")) then
			clean.accent = string.find(a, "^%x%x%x%x%x%x$") and string.upper(a) or a
		else
			bad = bad + 1
		end
	end
	if type(def.label) == "string" and string.find(def.label, "^style%.[a-z0-9]+%.label$") then clean.label = def.label end
	if type(def.desc) == "string" and string.find(def.desc, "^style%.[a-z0-9]+%.desc$") then clean.desc = def.desc end
	return clean, bad
end

-- ---------------------------------------------------------------- registre
local function validId(id)
	return type(id) == "string" and string.find(id, "^[a-z][a-z0-9]+$") ~= nil and string.len(id) <= 24
end

-- SUI.RegisterStyle("monstyle", def) : ajoute un style. Retourne ok, cle de message. Un id ne s'ecrase jamais.
function SUI.RegisterStyle(id, def, origin)
	if not validId(id) then return false, "msg.style.badname" end
	if S.styles[id] then return false, "msg.style.exists" end
	local clean = S.Sanitize(def)
	S.styles[id] = { name = id, def = clean, origin = origin or "builtin" }
	tinsert(S.names, id)
	return true, "msg.style.added"
end

function S.List()
	local t = {}
	for i = 1, getn(S.names) do tinsert(t, S.names[i]) end
	return t
end

-- Nom affichable : traduction du style si elle existe, sinon son id.
function S.Label(id)
	local rec = S.styles[id]
	if not rec then return tostring(id) end
	local key = rec.def.label
	if key and SUI.locales[SUI.locale][key] ~= nil then return L(key) end
	if key and SUI.locales.fr[key] ~= nil then return L(key) end
	return id
end

function S.Desc(id)
	local rec = S.styles[id]
	local key = rec and rec.def.desc
	if key and (SUI.locales[SUI.locale][key] ~= nil or SUI.locales.fr[key] ~= nil) then return L(key) end
	return ""
end

-- ---------------------------------------------------------------- ressources personnalisees (fichiers ajoutes par l'utilisateur)
-- SUI.RegisterAsset("bar", "monbarre", "Interface\\AddOns\\MesMedias\\barre.tga") : ajoute une texture / police choisissable par NOM.
-- kind : font | bar | panel (valeur = chemin) ; edge (valeur = { file, size, ins }). Le nom ne peut pas reprendre une ressource existante.
-- Si le client ne sait pas charger le fichier, la ressource est marquee absente et le rendu retombe sur la ressource de base.
local ASSET_OPTION = { font = "style.font", bar = "style.bartex", panel = "style.panel", edge = "style.edge" }

local probeTex
-- Teste un chemin : true / false / nil (inconnu : pas de sonde possible). NON VERIFIE en jeu : on suppose GetTexture() == nil si absent.
function S.Probe(path)
	if SUI.InCombat() then return nil end
	if not probeTex then
		local f = CreateFrame("Frame", nil, UIParent)
		f:Hide()
		probeTex = f:CreateTexture(nil, "BACKGROUND")
	end
	local ok = pcall(probeTex.SetTexture, probeTex, path)
	if not ok then return false end
	local got = probeTex:GetTexture()
	if got == nil then return false end
	return true
end

function SUI.RegisterAsset(kind, name, value)
	if not ASSET_OPTION[kind] or type(name) ~= "string" or not string.find(name, "^[a-z][a-z0-9]*$") then return false, "msg.style.asset.bad" end
	if T.assets[kind][name] ~= nil or name == "style" then return false, "msg.style.asset.exists" end
	local path = value
	if kind == "edge" then
		if type(value) ~= "table" or type(value.file) ~= "string" or type(value.size) ~= "number" then return false, "msg.style.asset.bad" end
		path = value.file
		T.assets.edge[name] = { file = value.file, size = clamp(value.size, 1, 32), ins = clamp(tonumber(value.ins) or 2, 0, 12) }
	else
		if type(value) ~= "string" or string.len(value) < 3 then return false, "msg.style.asset.bad" end
		T.assets[kind][name] = value
	end
	local meta = C.meta[ASSET_OPTION[kind]]
	if meta then tinsert(meta.choices, name) end
	local probe = S.Probe(path)
	if probe == false then S.missing[kind .. ":" .. name] = true end
	return true, (probe == false) and "msg.style.asset.missing" or "msg.style.asset.added"
end

-- ---------------------------------------------------------------- reglages (couche utilisateur)
SUI.RegisterCategory("style", 5)
local O_FONT = { "style", "arial", "frizqt" }
local O_OUTLINE = { "style", "none", "outline", "thick" }
local O_BAR = { "style", "flat", "blizzard" }
local O_EDGE = { "style", "none", "thin", "thick", "rounded", "dialog" }
local O_PANEL = { "style", "flat", "tooltip", "dialog" }
local O_BUTTON = { "style", "flat", "blizzard" }

local function choiceText(opt, v)
	local key = "choice." .. opt.key .. "." .. tostring(v)
	if SUI.locales.fr[key] ~= nil then return L(key) end
	return tostring(v)
end

SUI.RegisterOption({ key = "style.name", type = "choice", cat = "style", label = "opt.style.name", tip = "tip.style.name",
	choices = S.names, default = S.DEFAULT, simple = true, order = 10, choiceText = function(opt, v) return S.Label(v) end })
SUI.RegisterOption({ key = "style.font", type = "choice", cat = "style", label = "opt.style.font", tip = "tip.style.font",
	choices = O_FONT, default = "style", order = 20, choiceText = choiceText })
SUI.RegisterOption({ key = "style.outline", type = "choice", cat = "style", label = "opt.style.outline", tip = "tip.style.outline",
	choices = O_OUTLINE, default = "style", order = 30, choiceText = choiceText })
SUI.RegisterOption({ key = "style.fontscale", type = "number", cat = "style", label = "opt.style.fontscale", tip = "tip.style.fontscale",
	min = 0.7, max = 1.5, step = 0.05, default = 1.0, order = 40 })
SUI.RegisterOption({ key = "style.bartex", type = "choice", cat = "style", label = "opt.style.bartex", tip = "tip.style.bartex",
	choices = O_BAR, default = "style", order = 50, choiceText = choiceText })
SUI.RegisterOption({ key = "style.edge", type = "choice", cat = "style", label = "opt.style.edge", tip = "tip.style.edge",
	choices = O_EDGE, default = "style", order = 60, choiceText = choiceText })
SUI.RegisterOption({ key = "style.panel", type = "choice", cat = "style", label = "opt.style.panel", tip = "tip.style.panel",
	choices = O_PANEL, default = "style", order = 70, choiceText = choiceText })
SUI.RegisterOption({ key = "style.button", type = "choice", cat = "style", label = "opt.style.button", tip = "tip.style.button",
	choices = O_BUTTON, default = "style", order = 80, choiceText = choiceText })
SUI.RegisterOption({ key = "style.alpha", type = "number", cat = "style", label = "opt.style.alpha", tip = "tip.style.alpha",
	min = 0.3, max = 1, step = 0.05, default = 1.0, order = 90 })
for i = 1, getn(T.colorNames) do
	local n = T.colorNames[i]
	SUI.RegisterOption({ key = "style.c." .. n, type = "color", cat = "style", label = "opt.style.c." .. n, tip = "tip.style.c." .. n,
		default = "", order = 100 + i })
end

-- ---------------------------------------------------------------- resolution des jetons
local function resolvedAsset(fam, name, base)
	if assetOk(fam, name) then return name end
	return base
end

-- Valeurs effectives des reglages style.* (couches du mode comprises).
function S.Overrides()
	local o = { c = {} }
	for i = 1, getn(T.colorNames) do
		local n = T.colorNames[i]
		o.c[n] = C.Get("style.c." .. n)
	end
	o.font, o.outline, o.bar, o.edge, o.panel, o.button = C.Get("style.font"), C.Get("style.outline"), C.Get("style.bartex"),
		C.Get("style.edge"), C.Get("style.panel"), C.Get("style.button")
	o.fontscale, o.alpha = C.Get("style.fontscale"), C.Get("style.alpha")
	return o
end

-- Resout un style en jetons prets pour T.Apply. ov (facultatif) : reglages utilisateur (S.Overrides()) ; sans ov : le style pur.
function S.Resolve(id, ov)
	local rec = S.styles[id] or S.styles[S.DEFAULT]
	local def = rec and rec.def or { c = {} }
	local tok = { c = {}, hex = {}, names = {} }
	for i = 1, getn(T.colorNames) do
		local n = T.colorNames[i]
		local h = (ov and ov.c[n] ~= "" and ov.c[n]) or (def.c and def.c[n]) or BASE.c[n]
		local r, g, b, a = S.ParseHex(h)
		if not r then h = BASE.c[n]; r, g, b, a = S.ParseHex(h) end
		tok.c[n] = { r, g, b, a }
		tok.hex[n] = string.upper(h)
	end
	local acc = def.accent or BASE.accent
	if string.find(acc, "^%x%x%x%x%x%x$") then
		local r, g, b = S.ParseHex(acc)
		tok.accent = { r, g, b }
	else
		tok.accent = acc
	end
	tok.accentName = acc
	local map = { font = "font", outline = "outline", bar = "bar", edge = "edge", panel = "panel", button = "button" }
	for fam, _ in pairs(map) do
		local want = (ov and ov[fam] ~= "style" and ov[fam]) or def[fam] or BASE[fam]
		local name = resolvedAsset(fam, want, resolvedAsset(fam, def[fam] or BASE[fam], BASE[fam]))
		tok.names[fam] = name
		tok[fam] = T.assets[fam][name]
	end
	if tok.outline == nil then tok.outline = "" end
	tok.fontScale = clamp((def.fontScale or 1) * ((ov and ov.fontscale) or 1), 0.6, 1.8)
	tok.alpha = clamp((def.alpha or 1) * ((ov and ov.alpha) or 1), 0.3, 1)
	return tok
end

local function signature(tok)
	local t = {}
	for i = 1, getn(T.colorNames) do tinsert(t, tok.hex[T.colorNames[i]]) end
	tinsert(t, tok.accentName)
	for i = 1, getn(FAMILIES) do tinsert(t, tok.names[FAMILIES[i]]) end
	tinsert(t, string.format("%.2f/%.2f", tok.fontScale, tok.alpha))
	return table.concat(t, ",")
end

-- Recalcule les jetons du style effectif et les applique. La repeinture des widgets existants n'a lieu que si quelque chose a change
-- (et seulement hors combat). Retourne true si les jetons ont change.
function S.Refresh(force)
	local id = C.Get("style.name")
	local tok = S.Resolve(id, S.Overrides())
	local sig = signature(tok)
	if sig == S.sig and not force then return false end
	S.sig = sig
	S.cur = tok
	S.applied = S.applied + 1
	T.Apply(tok)
	SUI.WhenSafe(T.Restyle)
	return true
end

-- A PLAYER_LOGIN, apres le choix du profil et du mode, AVANT le demarrage des modules : ils creent leurs cadres avec le bon style.
function S.Boot()
	S.Refresh(true)
	if not S.watching then
		S.watching = true
		C.Watch("style.", function(key, value) S.Refresh() end)
		C.Watch("ui.accent", function(key, value) T.RefreshAccent() end)
		C.Watch("role", function(key, value) S.Refresh() end)
	end
end

-- Profil, mode, import : tout a pu changer.
C.Watch("", function(key, value)
	if key == nil and S.sig ~= "" then S.Refresh() end
end)

-- ---------------------------------------------------------------- styles de l'utilisateur (importes ou enregistres)
local function userStore()
	local db = C.db
	if not db then return nil end
	if type(db.global.styles) ~= "table" then db.global.styles = {} end
	return db.global.styles
end

-- A ADDON_LOADED (apres Config.Init) : revalide et enregistre les styles de l'utilisateur AVANT la selection du profil.
function S.LoadUser()
	local st = userStore()
	if not st then return 0 end
	local n = 0
	for id, def in pairs(st) do
		if not validId(id) or type(def) ~= "table" or S.styles[id] or n >= MAX_USER then
			st[id] = nil
		else
			local clean = S.Sanitize(def)
			st[id] = clean
			SUI.RegisterStyle(id, clean, "user")
			n = n + 1
		end
	end
	return n
end

local function userCount()
	local st = userStore()
	local n = 0
	if st then for _, _ in pairs(st) do n = n + 1 end end
	return n
end

-- Le look EFFECTIF (style + reglages) sous forme de style partageable (donnees pures).
function S.CurrentDef()
	local tok = S.cur or S.Resolve(C.Get("style.name"), S.Overrides())
	local def = { c = {} }
	for i = 1, getn(T.colorNames) do
		local n = T.colorNames[i]
		def.c[n] = tok.hex[n]
	end
	def.accent = tok.accentName
	for i = 1, getn(FAMILIES) do def[FAMILIES[i]] = tok.names[FAMILIES[i]] end
	def.fontScale = SUI.Round(tok.fontScale, 2)
	def.alpha = SUI.Round(tok.alpha, 2)
	return def
end

-- Chaine partageable (meme format que les profils : SUI1:<somme>:<corps>, aucune evaluation de code a l'import).
function S.Export(id)
	local def
	local name = id or C.Get("style.name")
	if id then
		local rec = S.styles[id]
		if not rec then return nil, "msg.style.unknown" end
		def = rec.def
	else
		def = S.CurrentDef()
	end
	local payload = { kind = "style", v = 1, name = name, def = def }
	return SUI.Serial.Pack(payload)
end

local function freeName(base)
	local name, n = base, 1
	while S.styles[name] do
		n = n + 1
		name = base .. n
	end
	return name
end

local function normalizeId(s)
	s = string.lower(tostring(s or ""))
	s = string.gsub(s, "[^a-z0-9]", "")
	if string.len(s) < 2 then s = "style" .. s end
	if not string.find(s, "^[a-z]") then s = "s" .. s end
	return string.sub(s, 1, 24)
end

-- Importe une chaine : cree un style utilisateur (jamais d'ecrasement). Retourne true, id, acceptes, ignores | false, raison.
function S.Import(str, name)
	local p, err = SUI.Serial.Unpack(str)
	if not p then return false, err end
	if type(p) ~= "table" or p.kind ~= "style" or p.v ~= 1 or type(p.def) ~= "table" then return false, "format" end
	if userCount() >= MAX_USER then return false, "msg.style.full" end
	local clean, bad = S.Sanitize(p.def)
	local accepted = 0
	for _, v in pairs(clean) do
		if type(v) == "table" then
			for _, _ in pairs(v) do accepted = accepted + 1 end
		else
			accepted = accepted + 1
		end
	end
	clean.label, clean.desc = nil, nil          -- un style importe n'emprunte jamais les textes d'un autre
	local id = freeName(normalizeId(name or p.name))
	local st = userStore()
	if not st then return false, "format" end
	st[id] = clean
	SUI.RegisterStyle(id, clean, "user")
	return true, id, accepted, bad
end

-- Enregistre le look effectif sous un nom, le selectionne et efface les reglages individuels (le style devient le point de depart).
function S.SaveCurrent(name)
	if userCount() >= MAX_USER then return false, "msg.style.full" end
	local id = freeName(normalizeId(name))
	if not validId(id) then return false, "msg.style.badname" end
	local def = S.CurrentDef()
	local st = userStore()
	if not st then return false, "msg.style.badname" end
	st[id] = def
	SUI.RegisterStyle(id, def, "user")
	S.ResetOverrides()
	C.Set("style.name", id)
	return true, id
end

function S.Delete(id)
	local rec = S.styles[id]
	if not rec then return false, "msg.style.unknown" end
	if rec.origin ~= "user" then return false, "msg.style.builtin" end
	local st = userStore()
	if st then st[id] = nil end
	S.styles[id] = nil
	for i = getn(S.names), 1, -1 do
		if S.names[i] == id then table.remove(S.names, i) end
	end
	if C.Get("style.name") == id then C.Set("style.name", S.DEFAULT) end
	S.Refresh()
	return true, "msg.style.deleted"
end

-- Efface tous les reglages individuels de style (garde le choix du style).
function S.ResetOverrides()
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.cat == "style" and o.key ~= "style.name" then C.Reset(o.key) end
	end
	S.Refresh()
end

-- ---------------------------------------------------------------- commande /sui style
local function out(msg)
	SUI.Print(msg)
end

local function firstWord(s)
	local _, _, w, rest = string.find(s or "", "^%s*(%S+)%s*(.*)$")
	if not w then return "", "" end
	return string.lower(w), rest or ""
end

function S.Command(rest)
	local sub, arg = firstWord(rest)
	if sub == "" or sub == "list" then
		local cur = C.Get("style.name")
		for i = 1, getn(S.names) do
			local id = S.names[i]
			out(L("msg.style.line", id == cur and "*" or " ", id, S.Label(id), S.styles[id].origin == "user" and L("msg.style.user") or ""))
		end
		out(L("help.style"))
	elseif sub == "pick" then
		if SUI.StylePicker then SUI.StylePicker.Show() end
	elseif sub == "use" then
		local id = string.lower(arg)
		if S.styles[id] then
			C.Set("style.name", id)
			out(L("msg.style.used", S.Label(id)))
		else
			out(L("msg.style.unknown", arg))
		end
	elseif sub == "save" then
		local ok, id = S.SaveCurrent(arg)
		if ok then out(L("msg.style.saved", id)) else out(L(id, arg)) end
	elseif sub == "delete" then
		local ok, key = S.Delete(string.lower(arg))
		out(L(key, arg))
	elseif sub == "reset" then
		S.ResetOverrides()
		out(L("msg.style.reset"))
	elseif sub == "export" then
		local str, key = S.Export(arg ~= "" and string.lower(arg) or nil)
		if str then SUI.Menu.ShowTransfer("export", str) else out(L(key, arg)) end
	elseif sub == "import" then
		if arg == "" then
			SUI.Menu.ShowTransfer("import", nil, "style")
		else
			SUI.Menu.DoImport(arg, "style")
		end
	else
		out(L("help.style"))
	end
end

SUI.RegisterCommand("style", S.Command, "help.style")
