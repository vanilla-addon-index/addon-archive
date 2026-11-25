-- ShikiUI Cooldowns : temps restant affiche SUR les cadres de recharge de Blizzard (OmniCC-like, code reecrit).
-- Principe : envelopper la fonction globale CooldownFrame_SetTimer (le client y passe pour chaque lancement de
-- recharge) pour memoriser debut + duree de chaque cadre, puis une seule minuterie affiche le temps restant dans
-- un texte pose au centre du cadre. Les barres d'action ShikiUI passent par CooldownFrame_SetTimer pour leur balayage mais
-- ont leur propre chiffre : leur modele est marque suiOwn et ignore ici (sinon 2 timers sur le meme sort). Rien dans le combat : le texte est seulement cache/affiche.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local getn, floor = table.getn, math.floor
local sformat = string.format

local M = {}
SUI.Cooldowns = M

M.active = false
M.watched = {}          -- [frame cooldown] = { start, dur }
M.texts = {}            -- [frame cooldown] = FontString

local cfg = { min = 3, yellow = 10, red = 3 }

local COLOR_NORM = { 1, 1, 1 }
local COLOR_WARN = { 1, 0.75, 0.2 }
local COLOR_HOT = { 1, 0.25, 0.2 }

function M.ReadConfig()
	cfg.min = C.Get("cooldowns.min") or 3
	cfg.yellow = C.Get("cooldowns.yellow") or 10
	cfg.red = C.Get("cooldowns.red") or 3
end

-- enveloppe globale : remplacee UNE fois, restoree a la coupure du module
M.origSetTimer = nil

local function hookedSetTimer(cf, start, dur, enable)
	if M.origSetTimer then M.origSetTimer(cf, start, dur, enable) end
	if not M.active or type(cf) ~= "table" then return end
	if cf.suiOwn then return end      -- balayage des barres ShikiUI : elles affichent deja leur propre chiffre (sinon 2 timers)
	if type(start) == "number" and start > 0 and type(dur) == "number" and dur > 0 then
		M.watched[cf] = { start = start, dur = dur }
	else
		M.watched[cf] = nil          -- recharge finie / annulee / remise a zero par le jeu (ex. Holy Shock par Crusader Strike)
		local t = M.texts[cf]
		if t then t:SetText("") end  -- le chiffre restait affiche : plus aucun tour ne repasse sur un cadre qui n'est plus suivi
	end
end

function M.Wrap()
	if M.origSetTimer then return end
	local cur = getglobal("CooldownFrame_SetTimer")
	if type(cur) ~= "function" then return end
	M.origSetTimer = cur
	setglobal("CooldownFrame_SetTimer", hookedSetTimer)
end

function M.Unwrap()
	if getglobal("CooldownFrame_SetTimer") == hookedSetTimer and M.origSetTimer then
		setglobal("CooldownFrame_SetTimer", M.origSetTimer)
	end
	M.origSetTimer = nil
end

-- texte du temps restant : 45 / 1:15 / 12:05 (mm:ss au-dela d'une heure h:mm:ss)
function M.Format(left)
	if left >= 3600 then
		return sformat("%d:%02d:%02d", floor(left / 3600), floor(SUI.Mod(left, 3600) / 60), SUI.Mod(left, 60))
	end
	if left >= 60 then
		return sformat("%d:%02d", floor(left / 60), SUI.Mod(left, 60))
	end
	return sformat("%d", floor(left + 0.5))
end

function M.ColorOf(left)
	if left <= cfg.red then return COLOR_HOT[1], COLOR_HOT[2], COLOR_HOT[3] end
	if left <= cfg.yellow then return COLOR_WARN[1], COLOR_WARN[2], COLOR_WARN[3] end
	return COLOR_NORM[1], COLOR_NORM[2], COLOR_NORM[3]
end

local function textFor(cf)
	local t = M.texts[cf]
	if not t then
		t = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		t:SetPoint("CENTER", cf, "CENTER", 0, 0)
		t:SetShadowColor(0, 0, 0, 1) -- style:ok ombre noire de texte du jeu
		t:SetShadowOffset(1, -1)
		M.texts[cf] = t
	end
	return t
end

-- un tour : met a jour les textes des cadres suivis, cache les finis
function M.Tick()
	local now = GetTime()
	for cf, w in pairs(M.watched) do
		local left = (w.start + w.dur) - now
		if left <= 0 then
			M.watched[cf] = nil
			local t = M.texts[cf]
			if t then t:SetText("") end
		else
			if w.dur >= cfg.min then
				local t = textFor(cf)
				local r, g, b = M.ColorOf(left)
				t:SetTextColor(r, g, b, 1)
				t:SetText(M.Format(left))
			end
		end
	end
end

function M.ApplyOptions()
	M.ReadConfig()
	M.Tick()
end

function M.Activate()
	M.active = true
	M.Wrap()
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(0.25, M.Tick, "cooldowns.tick", true)
end

function M.Deactivate()
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	for cf, t in pairs(M.texts) do
		if t then t:SetText("") end
	end
	M.watched = {}
	M.Unwrap()
end

function M.OnKey(key, value)
	M.ApplyOptions()
end

function M.Enable()
	SUI.WhenSafe(function()
		M.Activate()
	end)
	if not M.watching then
		M.watching = true
		C.Watch("cooldowns.", M.OnKey)
	end
end

function M.Disable()
	M.Deactivate()
end

SUI.RegisterCategory("cooldowns", 72)

local function opt(key, typ, order, def, extra)
	local o = { key = "cooldowns." .. key, type = typ, cat = "cooldowns", label = "opt.cooldowns." .. key, tip = "tip.cooldowns." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("cooldowns", {
	default = false,
	cost = "light",
	options = {
		opt("min", "number", 10, 3, { min = 1, max = 30, step = 1, simple = true }),
		opt("yellow", "number", 20, 10, { min = 3, max = 60, step = 1 }),
		opt("red", "number", 30, 3, { min = 1, max = 30, step = 1 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("cooldowns", function()
	if not C.Get("modules.cooldowns") then C.Set("modules.cooldowns", true) end
end, "help.cooldowns")
