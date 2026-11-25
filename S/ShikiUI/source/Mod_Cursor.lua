-- Mod_Cursor : reperes visuels. (1) un repere de SOURIS (anneau, etoile, croix, chevrons...) qui suit le curseur ;
-- (2) un repere du PERSONNAGE (centre de l'ecran, deplacable) pour retrouver son personnage en plein dezoom.
-- Aucun OnUpdate personnel : le suivi de la souris passe par SUI.Every (0.02 s) et n'existe que tant que le repere souris est
-- reellement affiche. Les cadres sont construits une seule fois, hors combat (SUI.WhenSafe). Textures du jeu ou T.tex.* seulement.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Cursor = M

local MOUSE_TICK = 0.02

-- Textures du jeu 1.12 (un seul endroit a corriger si l'une d'elles manquait sur un client).
M.TEX = {
	ring = "Interface\\Cooldown\\ping4",
	star = "Interface\\Cooldown\\star4",
}

M.STYLES = { "ring", "ringdot", "star", "cross", "chevrons", "target" }
M.COLORS = { "accent", "class", "good", "warn", "bad", "text" }

-- Elements affiches par style.
local PARTS = {
	ring     = { ring = true },
	ringdot  = { ring = true, dot = true },
	star     = { star = true },
	cross    = { arms = true },
	chevrons = { chev = true },
	target   = { ring = true, arms = true, dot = true },
}

M.on = false
M.combat = false
M.built = false
M.lastX = nil
M.lastY = nil

-- ---------------------------------------------------------------- couleurs
-- Jeton de couleur -> r, g, b. "class" = couleur de classe du joueur (donnee de jeu), repli sur l'accent du style.
function M.RGB(name)
	if name == "class" and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then return col.r, col.g, col.b end    -- style:ok couleur de classe (donnee de jeu)
	end
	local tok = (name and name ~= "accent" and name ~= "class") and T.c[name] or nil
	if tok then return tok[1], tok[2], tok[3] end
	return T.Accent()
end

-- ---------------------------------------------------------------- construction d'un repere
local function newReticle(name, strata)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetFrameStrata(strata)
	f:SetWidth(48)
	f:SetHeight(48)
	f:Hide()
	local r = { frame = f, arms = {}, chev = {} }
	r.ring = f:CreateTexture(nil, "OVERLAY")
	r.ring:SetTexture(M.TEX.ring)
	r.ring:SetBlendMode("ADD")
	r.ring:SetAllPoints(f)
	r.star = f:CreateTexture(nil, "OVERLAY")
	r.star:SetTexture(M.TEX.star)
	r.star:SetBlendMode("ADD")
	r.star:SetAllPoints(f)
	r.dot = f:CreateTexture(nil, "OVERLAY")
	r.dot:SetTexture(T.tex.white)
	r.dot:SetPoint("CENTER", f, "CENTER", 0, 0)
	for i = 1, 4 do
		local a = f:CreateTexture(nil, "OVERLAY")
		a:SetTexture(T.tex.white)
		r.arms[i] = a
		local c = T.Text(f, 14, T.c.text, "CENTER")
		r.chev[i] = c
	end
	return r
end

local CHEV_GLYPH = { "v", "^", ">", "<" }       -- haut, bas, gauche, droite : tous tournes vers le centre

-- Applique style / taille / couleur / opacite a un repere.
local function paint(r, style, size, color, alpha)
	if not r then return end
	local parts = PARTS[style] or PARTS.ring
	local f = r.frame
	f:SetWidth(size)
	f:SetHeight(size)
	f:SetAlpha(alpha / 100)
	local cr, cg, cb = M.RGB(color)
	r.ring:SetVertexColor(cr, cg, cb, 1)
	r.star:SetVertexColor(cr, cg, cb, 1)
	r.dot:SetVertexColor(cr, cg, cb, 1)
	if parts.ring then r.ring:Show() else r.ring:Hide() end
	if parts.star then r.star:Show() else r.star:Hide() end
	local dsz = math.max(3, math.floor(size / 9))
	r.dot:SetWidth(dsz)
	r.dot:SetHeight(dsz)
	if parts.dot or (parts.arms and style == "target") then r.dot:Show() else r.dot:Hide() end
	local th = math.max(2, math.floor(size / 24))
	local len = math.floor(size * 0.3)
	local gap = math.floor(size * 0.1)
	local half = size / 2
	for i = 1, 4 do
		local a = r.arms[i]
		a:ClearAllPoints()
		a:SetVertexColor(cr, cg, cb, 1)
		if i == 1 then
			a:SetPoint("BOTTOM", f, "CENTER", 0, gap); a:SetWidth(th); a:SetHeight(len)
		elseif i == 2 then
			a:SetPoint("TOP", f, "CENTER", 0, -gap); a:SetWidth(th); a:SetHeight(len)
		elseif i == 3 then
			a:SetPoint("RIGHT", f, "CENTER", -gap, 0); a:SetWidth(len); a:SetHeight(th)
		else
			a:SetPoint("LEFT", f, "CENTER", gap, 0); a:SetWidth(len); a:SetHeight(th)
		end
		if parts.arms then a:Show() else a:Hide() end
		local c = r.chev[i]
		c:ClearAllPoints()
		c:SetFont(T.font, math.max(12, math.floor(size / 3)), "OUTLINE")
		c:SetText(CHEV_GLYPH[i])
		c:SetTextColor(cr, cg, cb, 1)
		local ox, oy = 0, 0
		if i == 1 then oy = half * 0.8 elseif i == 2 then oy = -half * 0.8 elseif i == 3 then ox = -half * 0.8 else ox = half * 0.8 end
		c:SetPoint("CENTER", f, "CENTER", ox, oy)
		if parts.chev then c:Show() else c:Hide() end
	end
end

-- ---------------------------------------------------------------- suivi de la souris
function M.MouseTick()
	local r = M.mouse
	if not r or not GetCursorPosition then return end
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	if not s or s <= 0 then s = 1 end
	if x == M.lastX and y == M.lastY and s == M.lastS then return end
	M.lastX = x
	M.lastY = y
	M.lastS = s
	r.frame:ClearAllPoints()
	r.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end

local function wantMouse()
	return M.on and M.built and C.Get("cursor.mouse") and (not C.Get("cursor.mousecombat") or M.combat)
end

local function wantChar()
	return M.on and M.built and C.Get("cursor.char") and (not C.Get("cursor.charcombat") or M.combat)
end

-- Montre / cache les reperes et (de)programme la minuterie : rien ne tourne tant que le repere souris est cache.
function M.Sync()
	if not M.built then return end
	if wantMouse() then
		M.mouse.frame:Show()
		M.lastX = nil
		M.MouseTick()
		if not M.task then M.task = SUI.Every(MOUSE_TICK, M.MouseTick, "cursor.mouse") end
	else
		M.mouse.frame:Hide()
		if M.task then
			SUI.Cancel(M.task)
			M.task = nil
		end
	end
	if wantChar() then M.char.frame:Show() else M.char.frame:Hide() end
end

-- Relit tous les reglages "cursor.*" (aspect) puis synchronise l'affichage.
function M.ApplyOptions()
	if not M.built then return end
	paint(M.mouse, C.Get("cursor.mousestyle"), C.Get("cursor.mousesize"), C.Get("cursor.mousecolor"), C.Get("cursor.mousealpha"))
	paint(M.char, C.Get("cursor.charstyle"), C.Get("cursor.charsize"), C.Get("cursor.charcolor"), C.Get("cursor.charalpha"))
	M.Sync()
end

function M.Build()
	if M.built then
		M.ApplyOptions()
		return
	end
	M.mouse = newReticle("ShikiUI_CursorMouse", "TOOLTIP")
	M.char = newReticle("ShikiUI_CursorChar", "FULLSCREEN_DIALOG")
	SUI.Layout.Register(M.char.frame, "cursor.char", "CENTER", 0, 0)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("cursor.char", M.char.frame, { label = "mod.cursor.mover", scale = false, always = true })
	end
	T.OnAccent(M.OnStyle)
	M.built = true
	M.ApplyOptions()
end

function M.OnStyle()
	if M.built and M.on then M.ApplyOptions() end
end

-- ---------------------------------------------------------------- evenements, reglages
function M.OnCombat(event)
	if event == "PLAYER_REGEN_DISABLED" then M.combat = true else M.combat = false end
	M.Sync()
end

function M.OnKey(key, value)
	M.ApplyOptions()
end

function M.Enable()
	M.on = true
	M.combat = SUI.InCombat()
	SUI.WhenSafe(M.Build)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombat)
	if not M.watching then
		M.watching = true
		C.Watch("cursor.", M.OnKey)
	end
	M.ApplyOptions()
end

function M.Disable()
	M.on = false
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombat)
	if M.built then
		M.mouse.frame:Hide()
		M.char.frame:Hide()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("cursor", 75)

local function opt(key, typ, order, def, extra)
	local o = { key = "cursor." .. key, type = typ, cat = "cursor", label = "opt.cursor." .. key, tip = "tip.cursor." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function styleText(o, v) return L("choice.cursor.style." .. v) end
local function colorText(o, v) return L("choice.cursor.color." .. v) end

SUI.RegisterModule("cursor", {
	default = false,
	cost = "light",
	options = {
		opt("mouse", "bool", 10, true, { simple = true }),
		opt("mousestyle", "choice", 20, "ring", { choices = M.STYLES, choiceText = styleText }),
		opt("mousesize", "number", 30, 56, { min = 24, max = 160, step = 4 }),
		opt("mousecolor", "choice", 40, "accent", { choices = M.COLORS, choiceText = colorText }),
		opt("mousealpha", "number", 50, 80, { min = 20, max = 100, step = 5 }),
		opt("mousecombat", "bool", 60, false),
		opt("char", "bool", 110, true, { simple = true }),
		opt("charstyle", "choice", 120, "target", { choices = M.STYLES, choiceText = styleText }),
		opt("charsize", "number", 130, 48, { min = 24, max = 160, step = 4 }),
		opt("charcolor", "choice", 140, "class", { choices = M.COLORS, choiceText = colorText }),
		opt("charalpha", "number", 150, 70, { min = 20, max = 100, step = 5 }),
		opt("charcombat", "bool", 160, false),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- /sui cursor [mouse|char] : bascule le repere, sans argument affiche l'etat.
SUI.RegisterCommand("cursor", function(rest)
	local arg = string.lower(rest or "")
	if arg == "mouse" then
		C.Set("cursor.mouse", not C.Get("cursor.mouse"))
	elseif arg == "char" then
		C.Set("cursor.char", not C.Get("cursor.char"))
	end
	local onw, offw = L("msg.cursor.on"), L("msg.cursor.off")
	SUI.Print(L("msg.cursor.status", C.Get("cursor.mouse") and onw or offw, C.Get("cursor.char") and onw or offw))
end, "help.cursor")
