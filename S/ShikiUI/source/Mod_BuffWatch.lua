-- ShikiUI BuffWatch : suivi des buffs ENTRETENUS (ceux qu'on doit relancer soi-meme) : icone grise = absent,
-- icone vive + duree = present. Complement de auras (ce qui EST la) et powerauras (alertes) : ici ce qui MANQUE.
--  * liste par classe, matching par NOM du buff (infobulle cachee, EN + FR, la langue du client est utilisee),
--    l'icone affichee = celle du buff lu (sans lien avec la langue), sinon l'icone de reference quand absent.
--  * duree lue a la ligne 2 de la meme infobulle (1.12 : pas d'API de duree).
--  * fenetre unique deplaceable (Mover, cle "buffwatch.win"), hors combat seulement (WhenSafe).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local getn, tinsert = table.getn, table.insert
local floor, max = math.floor, math.max
local slower, sformat, sfind = string.lower, string.format, string.find

local M = {}
SUI.BuffWatch = M

M.on = false
M.built = false
M.win = nil
M.icons = {}
M.state = {}            -- key -> { found = true/false, left = secondes, tex = texture lue }
M.tip = nil

-- Liste surveillable : key, icone de reference, nom EN, nom FR, par defaut surveille ?
-- Le matching se fait sur le NOM lu dans l'infobulle (EN ou FR selon le client), insensitive a la casse.
M.LIST = {
	{ key = "battleshout",   icon = "Ability_Warrior_BattleShout",    en = "Battle Shout",             fr = "Cri de bataille",                    def = true },
	{ key = "fortitude",     icon = "Spell_Holy_WordFortitude",       en = "Power Word: Fortitude",    fr = "Parole de pouvoir : Fortitude",      def = true },
	{ key = "divinespirit",  icon = "Spell_Holy_DivineSpirit",        en = "Divine Spirit",            fr = "Esprit divin",                       def = true },
	{ key = "innerfire",     icon = "Spell_Holy_InnerFire",           en = "Inner Fire",               fr = "Feu interieur",                      def = true },
	{ key = "markofwild",    icon = "Spell_Nature_Regeneration",      en = "Mark of the Wild",         fr = "Marque du fauve",                    def = true },
	{ key = "thorns",        icon = "Spell_Nature_Thorns",            en = "Thorns",                   fr = "Epines",                             def = false },
	{ key = "arcintellect",  icon = "Spell_Holy_MagicalSentry",       en = "Arcane Intellect",         fr = "Intellect arcanique",                def = true },
	{ key = "magearmor",     icon = "Spell_Mage_MageArmor",           en = "Mage Armor",               fr = "Armure du mage",                     def = false },
	{ key = "icebarrier",    icon = "Spell_Ice_Larmor",               en = "Ice Barrier",              fr = "Barriere de glace",                  def = false },
	{ key = "aspecthawk",    icon = "Ability_Hunter_AspectOfTheHawk", en = "Aspect of the Hawk",       fr = "Aspect du faucon",                   def = true },
	{ key = "lightningshield", icon = "Spell_Nature_LightningShield", en = "Lightning Shield",         fr = "Bouclier de foudre",                 def = true },
	{ key = "sealright",     icon = "Spell_Holy_SealOfRighteousness", en = "Seal of Righteousness",    fr = "Sceau de rectitude",                 def = false },
}
M.BYKEY = {}

local cfg = { size = 26, timers = true }

local function fold(s)
	return slower(s or "")
end

-- duree lue dans la ligne 2 de l'infobulle ("2 min", "45 sec", fr equivalents) -> secondes (0 = inconnue)
local function parseLeft(s)
	if not s or s == "" then return 0 end
	local _, _, num = sfind(s, "(%d+)")   -- sfind retourne positions + capture : la valeur est le 3e retour
	if not num then return 0 end
	local n = floor(tonumber(num) or 0)
	if sfind(slower(s), "min") then return n * 60 end
	if n > 0 and n <= 3600 then return n end
	return 0
end

local function ensureTip()
	if M.tip then return M.tip end
	local ex = getglobal("ShikiUI_BWTip")
	if ex then M.tip = ex return M.tip end
	local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_BWTip", UIParent, "GameTooltipTemplate")
	if ok and t then
		t:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip = t
	end
	return M.tip
end

function M.ReadConfig()
	cfg.size = C.Get("buffwatch.size") or 26
	cfg.timers = C.Get("buffwatch.timers") ~= false
end

function M.WatchList()
	local out, n = {}, 0
	for i = 1, getn(M.LIST) do
		local e = M.LIST[i]
		if not C.Get("buffwatch.off." .. e.key) then
			n = n + 1
			out[n] = e
		end
	end
	return out
end

-- Un tour de scan : lit les buffs du joueur (texture + nom + duree), etat par cle surveillee.
function M.Scan()
	local tip = ensureTip()
	local found, nb = {}, 0
	if tip then
		local ub = getglobal("UnitBuff")
		for i = 1, 32 do
			local tex = ub and ub("player", i)
			if not tex then break end
			tip:SetOwner(UIParent, "ANCHOR_NONE")
			tip:SetUnitBuff("player", i)
			local fs1 = getglobal("ShikiUI_BWTipTextLeft1")
			local fs2 = getglobal("ShikiUI_BWTipTextLeft2")
			local nm = fold(fs1 and fs1:GetText())
			local left = parseLeft(fs2 and fs2:GetText())
			nb = nb + 1
			for j = 1, getn(M.LIST) do
				local e = M.LIST[j]
				if nm == fold(e.en) or nm == fold(e.fr) then
					found[e.key] = { left = left, tex = tex }
				end
			end
			if nb >= 32 then break end
		end
	end
	for j = 1, getn(M.LIST) do
		local e = M.LIST[j]
		local f = found[e.key]
		M.state[e.key] = { found = f ~= nil, left = f and f.left or 0, tex = f and f.tex or nil }
	end
	M.Paint()
end

function M.Paint()
	if not M.win then return end
	local list = M.WatchList()
	local size = cfg.size
	local w = max(getn(list), 1) * (size + 4) + 10
	M.win:SetWidth(w)
	local h = size + (cfg.timers and 16 or 0) + 10
	M.win:SetHeight(h)
	for i = 1, getn(list) do
		local e = list[i]
		local b = M.icons[e.key]
		if not b then
			b = CreateFrame("Frame", nil, M.win)
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetAllPoints(b)
			b.timer = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			b.timer:SetPoint("BOTTOM", b, "BOTTOM", 0, -12)
			b:EnableMouse(false)
			M.icons[e.key] = b
		end
		b:SetWidth(size)
		b:SetHeight(size)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", M.win, "TOPLEFT", 6 + (i - 1) * (size + 4), -6)
		local st = M.state[e.key] or {}
		if st.found then
			b.icon:SetVertexColor(1, 1, 1, 1) -- style:ok blanc neutre : texture du jeu non teintee
			b.icon:SetTexture(st.tex or ("Interface\\Icons\\" .. e.icon))
			b.timer:SetText(cfg.timers and st.left > 0 and M.LeftString(st.left) or "")
		else
			b.icon:SetVertexColor(0.3, 0.3, 0.3, 1) -- style:ok icone grisee = teinte neutre de texture du jeu
			b.icon:SetTexture("Interface\\Icons\\" .. e.icon)
			b.timer:SetText("")
		end
		b:Show()
	end
end

function M.LeftString(left)
	if left >= 60 then return sformat("%dm", floor(left / 60 + 0.5)) end
	return sformat("%ds", max(left, 0))
end

function M.Build()
	if M.win then return end
	local f = T.Panel(UIParent, 120, 44)
	f:SetFrameStrata("LOW")
	f:EnableMouse(false)
	f:Hide()
	M.win = f
	SUI.Mover.Register("buffwatch.win", f, { label = L("mod.buffwatch.title"), point = "TOPLEFT", x = 12, y = -180, scale = true })
	M.built = true
	M.ApplyOptions()
end

function M.ApplyOptions()
	if not M.win then return end
	M.ReadConfig()
	M.Paint()
end

function M.Activate()
	M.active = true
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(C.Get("buffwatch.scan") or 0.5, M.Scan, "buffwatch.scan", true)
	M.Scan()
end

function M.Deactivate()
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	if M.win then M.win:Hide() end
end

function M.OnKey(key, value)
	M.ApplyOptions()
	if M.active and key == nil then M.Scan() end
end

function M.Enable()
	SUI.WhenSafe(function()
		M.Build()
		M.Activate()
	end)
	if not M.watching then
		M.watching = true
		C.Watch("buffwatch.", M.OnKey)
	end
end

function M.Disable()
	M.Deactivate()
end

-- Equivalent pfUI : aucun (module neuf).
SUI.RegisterCategory("buffwatch", 67)

local function opt(key, typ, order, def, extra)
	local o = { key = "buffwatch." .. key, type = typ, cat = "buffwatch", label = "opt.buffwatch." .. key, tip = "tip.buffwatch." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local options = {
	opt("on", "bool", 5, true, { simple = true }),
	opt("size", "number", 10, 26, { min = 16, max = 48, step = 2, simple = true }),
	opt("timers", "bool", 20, true, { simple = true }),
	opt("scan", "number", 30, 0.5, { min = 0.2, max = 2, step = 0.1 }),
}
for i = 1, getn(M.LIST) do
	local e = M.LIST[i]
	tinsert(options, { key = "buffwatch.off." .. e.key, type = "bool", cat = "buffwatch", label = "opt.buffwatch.off." .. e.key, tip = "tip.buffwatch.off", default = false, order = 100 + i })
end

SUI.RegisterModule("buffwatch", {
	default = false,
	cost = "light",
	options = options,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- labels des toggles par buff (ecrits directement dans les locales : les fichiers Locale_* n'ont pas acces a SUI)
for i = 1, getn(M.LIST) do
	local e = M.LIST[i]
	SUI.locales.fr["opt.buffwatch.off." .. e.key] = "Masquer : " .. e.fr
	SUI.locales.en["opt.buffwatch.off." .. e.key] = "Hide: " .. e.en
end

SUI.RegisterCommand("buffwatch", function()
	if not C.Get("modules.buffwatch") then C.Set("modules.buffwatch", true) end
	if M.win then
		if M.win:IsShown() then M.win:Hide() else M.win:Show() end
	end
end, "help.buffwatch")

SUI.RegisterCommand("bw", function(rest)
	local w = slower(rest or "")
	if not C.Get("modules.buffwatch") then C.Set("modules.buffwatch", true) end
	if M.win then
		if w == "show" then M.win:Show() elseif w == "hide" then M.win:Hide() elseif M.win:IsShown() then M.win:Hide() else M.win:Show() end
	end
end, "help.buffwatch")
