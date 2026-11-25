-- ShikiUI Map : carte du monde (options, a chaud) : coordonnees du joueur ET du curseur, echelle, opacite (fixe, a la molette,
-- plus faible en marchant a la Mapster), pastilles de groupe / raid (taille, couleur de classe, noms), echelle de l'infobulle.
-- Le DEPLACEMENT de la carte reste le module "windows" ; ici on lit GetPlayerMapPosition / GetCursorPosition quand la carte est ouverte
-- et on ajuste le cadre Blizzard (SetScale / SetAlpha, valeurs d'origine rendues a la coupure).
-- Reveil du brouillard : ECARTE (en 1.12 le brouillard est un calque du client, sans fonction pour savoir quelles zones sont connues ;
-- le lever demanderait de livrer les textures de toutes les zones : pas propre, pas fait).
-- NON VERIFIE en jeu : noms des pastilles du client (WorldMapParty1..4, WorldMapRaid1..40 et leur texture "<nom>Icon"), WorldMapTooltip,
-- molette recue par WorldMapFrame (le fond de carte WorldMapButton peut l'avaler), IsControlKeyDown / IsShiftKeyDown.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local C = SUI.Config

local floor = math.floor
local sformat = string.format
local getn = table.getn

local M = {}
SUI.Map = M

local NPARTY, NRAID = 4, 40
local CURSOR_TICK = 0.1

M.active = false
M.appliedScale = nil     -- echelle posee par nous (restore a la coupure)
M.origAlpha = nil        -- opacite d'origine du cadre (restore a la coupure)
M.curAlpha = nil         -- derniere opacite posee
M.moving = false
M.lastX, M.lastY = nil, nil
M.dots = nil             -- pastilles du client : { f, icon, unit, ow, oh, sized, tinted, nm, lastName }
M.tipScale = nil         -- echelle d'origine de l'infobulle de carte
M.tipSet = false
M.wheelOn = false

local function frame()
	return getglobal("WorldMapFrame")
end

local function scale()
	local sc = (C.Get("map.scale") or 100) / 100
	if sc <= 0 then sc = 1 end
	return sc
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function M.ApplyScale()
	local f = frame()
	if not f then return end
	if not M.active then
		if M.appliedScale then f:SetScale(1) M.appliedScale = nil end
		return
	end
	local sc = scale()
	f:SetScale(sc)
	M.appliedScale = sc
end

-- ---------------------------------------------------------------- opacite (fixe, plus faible en marchant)
function M.WantedAlpha()
	local a = C.Get("map.alpha") or 1
	local ma = C.Get("map.movealpha") or 1
	if M.moving and ma < a then a = ma end
	return a
end

function M.ApplyAlpha()
	local f = frame()
	if not f then return end
	if not M.active then
		if M.curAlpha then f:SetAlpha(M.origAlpha or 1) M.curAlpha = nil end
		return
	end
	if not M.origAlpha then M.origAlpha = f:GetAlpha() or 1 end
	local a = M.WantedAlpha()
	if a ~= M.curAlpha then
		M.curAlpha = a
		f:SetAlpha(a)
	end
end

-- Detecte la marche : la position du joueur change d'un tour a l'autre (seulement si l'option est utilisee).
function M.CheckMoving(x, y)
	local was = M.moving
	if x and (x ~= 0 or y ~= 0) and M.lastX then
		M.moving = (x ~= M.lastX or y ~= M.lastY)
	else
		M.moving = false
	end
	M.lastX, M.lastY = x, y
	return was ~= M.moving
end

-- ---------------------------------------------------------------- infobulle de la carte
function M.ApplyTip()
	local tt = getglobal("WorldMapTooltip")
	if not tt or not tt.SetScale then return end
	if not M.active then
		if M.tipSet then tt:SetScale(M.tipScale or 1) M.tipSet = false end
		return
	end
	if not M.tipSet then
		M.tipScale = tt:GetScale() or 1
		M.tipSet = true
	end
	tt:SetScale((C.Get("map.tipscale") or 100) / 100)
end

-- ---------------------------------------------------------------- textes : joueur et curseur
local posText = nil   -- texte x, y du joueur ; M.posText = reference publique (tests/panneau)
local curText = nil   -- texte x, y du curseur ; M.curText
M.placeSig = nil

local function newText(f, w)
	local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	t:SetShadowColor(0, 0, 0, 1) -- style:ok ombre noire de texte du jeu
	t:SetShadowOffset(1, -1)
	t:SetHeight(12)
	t:SetWidth(w)
	return t
end

local function ensureText(f)
	if posText then return posText end
	posText = newText(f, 200)
	M.posText = posText
	M.placeSig = nil
	return posText
end

local function ensureCursor(f)
	if curText then return curText end
	curText = newText(f, 160)
	M.curText = curText
	M.placeSig = nil
	return curText
end

-- Ancre les textes : en bas (defaut) ou en haut ; le joueur reste centre tant que le curseur n'est pas affiche.
function M.PlaceTexts(f)
	local top = (C.Get("map.coordpos") == "top")
	local cur = C.Get("map.cursor") and true or false
	local sig = (top and "t" or "b") .. (cur and "c" or "n") .. (curText and "1" or "0") .. (posText and "1" or "0")
	if sig == M.placeSig then return end
	M.placeSig = sig
	local pt = top and "TOP" or "BOTTOM"
	local oy = top and -4 or 4
	if posText then
		posText:ClearAllPoints()
		posText:SetPoint(pt, f, pt, cur and -90 or 0, oy)
	end
	if curText then
		curText:ClearAllPoints()
		curText:SetPoint(pt, f, pt, 90, oy)
	end
end

local function showPos(f)
	local gp = getglobal("GetPlayerMapPosition")
	if not gp then return false end
	local x, y = gp("player")
	if not x then return false end
	if M.CheckMoving(x, y) then M.ApplyAlpha() end
	x = floor((x or 0) * 100 + 0.5)
	y = floor((y or 0) * 100 + 0.5)
	local t = ensureText(f)
	M.PlaceTexts(f)
	t:SetText(sformat("%d, %d", x, y))
	t:Show()
	return true
end

-- Coordonnees du curseur sur le fond de carte (0 a 100), nil si le curseur est hors de la carte.
function M.CursorXY()
	local gc = getglobal("GetCursorPosition")
	local b = getglobal("WorldMapButton")
	if type(gc) ~= "function" or not b then return nil end
	local cx, cy = gc()
	local l, tp, w, h = b:GetLeft(), b:GetTop(), b:GetWidth(), b:GetHeight()
	if type(cx) ~= "number" or type(l) ~= "number" or type(tp) ~= "number" or not w or not h or w <= 0 or h <= 0 then return nil end
	local sc = b:GetEffectiveScale()
	if type(sc) ~= "number" or sc <= 0 then sc = 1 end
	local x = (cx / sc - l) / w
	local y = (tp - cy / sc) / h
	if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x * 100, y * 100
end

M.lastCur = nil

function M.CursorTick()
	local f = frame()
	if not f or not M.active or not curText then return end
	if not (f.IsShown and f:IsShown()) or not C.Get("map.cursor") then
		curText:Hide()
		return
	end
	local x, y = M.CursorXY()
	if not x then
		M.lastCur = nil
		curText:Hide()
		return
	end
	x, y = floor(x + 0.5), floor(y + 0.5)
	local key = x * 1000 + y
	if key ~= M.lastCur or not curText:IsShown() then
		M.lastCur = key
		curText:SetText(L("msg.map.cursor", x, y))
		curText:Show()
	end
end

-- La minuterie du curseur n'existe que carte ouverte + option cochee.
function M.SyncCursorTask(want)
	if want and not M.curTask then
		M.curTask = SUI.Every(CURSOR_TICK, M.CursorTick, "map.cursor", false)
	elseif not want and M.curTask then
		SUI.Cancel(M.curTask)
		M.curTask = nil
	end
end

-- ---------------------------------------------------------------- molette (Ctrl = opacite, Maj = taille)
local function keyDown(name)
	local fn = getglobal(name)
	return type(fn) == "function" and fn() and true or false
end

function M.OnWheel()
	if not M.active or not C.Get("map.wheel") then return end
	local d = (arg1 and arg1 > 0) and 1 or -1
	if keyDown("IsControlKeyDown") then
		local a = floor((C.Get("map.alpha") or 1) * 20 + 0.5) / 20 + d * 0.05
		C.Set("map.alpha", clamp(floor(a * 20 + 0.5) / 20, 0.3, 1))
	elseif keyDown("IsShiftKeyDown") then
		C.Set("map.scale", clamp((C.Get("map.scale") or 100) + d * 5, 80, 150))
	end
end

function M.ApplyWheel()
	local f = frame()
	if not f then return end
	local want = M.active and C.Get("map.wheel") and true or false
	if want and not M.wheelOn then
		M.wheelOn = true
		f:EnableMouseWheel(true)
		f:SetScript("OnMouseWheel", M.OnWheel)
	elseif not want and M.wheelOn then
		M.wheelOn = false
		f:SetScript("OnMouseWheel", nil)
		f:EnableMouseWheel(false)
	end
end

-- ---------------------------------------------------------------- pastilles de groupe / raid
function M.CollectDots()
	if not M.dots then M.dots = {} end
	local n = getn(M.dots)
	if n >= NPARTY + NRAID then return end
	for i = n + 1, NPARTY + NRAID do
		local name, unit
		if i <= NPARTY then
			name, unit = "WorldMapParty" .. i, "party" .. i
		else
			name, unit = "WorldMapRaid" .. (i - NPARTY), "raid" .. (i - NPARTY)
		end
		local f = getglobal(name)
		if not f then break end
		M.dots[i] = { f = f, icon = getglobal(name .. "Icon"), unit = unit }
	end
end

local function classRGB(unit)
	local uc = getglobal("UnitClass")
	if type(uc) ~= "function" then return nil end
	local _, class = uc(unit)
	local tab = getglobal("RAID_CLASS_COLORS")
	local col = tab and class and tab[class]
	if col then return col.r, col.g, col.b end
	return nil
end

local function dotName(r, f)
	if r.nm then return r.nm end
	if SUI.InCombat() then return nil end
	local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	t:SetShadowColor(0, 0, 0, 1) -- style:ok ombre noire de texte du jeu
	t:SetShadowOffset(1, -1)
	t:SetPoint("LEFT", f, "RIGHT", 2, 0)
	r.nm = t
	return t
end

-- Une pastille : taille, teinte de classe, nom. Les etats d'origine sont rendus quand l'option est a zero / coupee.
function M.StyleDot(r, size, tint, names)
	local f = r.f
	if size > 0 then
		if not r.ow then r.ow, r.oh = f:GetWidth(), f:GetHeight() end
		if r.sized ~= size then
			r.sized = size
			f:SetWidth(size)
			f:SetHeight(size)
		end
	elseif r.sized then
		r.sized = nil
		if r.ow then f:SetWidth(r.ow) f:SetHeight(r.oh) end
	end
	local shown = f:IsShown()
	local cr, cg, cb
	if (tint or names) and shown then cr, cg, cb = classRGB(r.unit) end
	if r.icon then
		if tint and cr then
			r.tinted = true
			r.icon:SetVertexColor(cr, cg, cb)
		elseif r.tinted then
			r.tinted = nil
			r.icon:SetVertexColor(1, 1, 1) -- style:ok teinte neutre de la texture du jeu
		end
	end
	if names and shown then
		local t = dotName(r, f)
		if t then
			local un = UnitName(r.unit) or ""
			if un ~= r.lastName then
				r.lastName = un
				t:SetText(un)
			end
			if cr then t:SetTextColor(cr, cg, cb, 1) end
			t:Show()
		end
	elseif r.nm then
		r.nm:Hide()
	end
end

function M.ApplyDots()
	local size = C.Get("map.dotsize") or 0
	local tint = C.Get("map.dotclass") and true or false
	local names = C.Get("map.dotnames") and true or false
	local on = M.active and (size > 0 or tint or names)
	if not on and not M.dotsUsed then return end
	M.CollectDots()
	if not M.dots then return end
	if not on then
		size, tint, names = 0, false, false
		M.dotsUsed = false
	else
		M.dotsUsed = true
	end
	for i = 1, getn(M.dots) do M.StyleDot(M.dots[i], size, tint, names) end
end

-- ---------------------------------------------------------------- un tour de minuterie
function M.Tick()
	local f = frame()
	if not f or not M.active then return end
	local vis = f.IsShown and f:IsShown()
	if not vis then
		if posText then posText:Hide() end
		if curText then curText:Hide() end
		M.SyncCursorTask(false)
		M.lastX = nil
		if M.moving then M.moving = false M.ApplyAlpha() end
		return
	end
	local needPos = C.Get("map.coords") or (C.Get("map.movealpha") or 1) < 1
	if needPos then
		local ok = showPos(f)
		if not C.Get("map.coords") or not ok then
			if posText then posText:Hide() end
		end
	elseif posText then
		posText:Hide()
	end
	local cur = C.Get("map.cursor") and true or false
	if cur and not curText and not SUI.InCombat() then ensureCursor(f) end
	if cur and curText then M.PlaceTexts(f) end
	M.SyncCursorTask(cur and curText ~= nil)
	if not cur and curText then curText:Hide() end
	M.ApplyDots()
end

function M.ApplyAll()
	M.ApplyScale()
	M.ApplyAlpha()
	M.ApplyTip()
	M.ApplyWheel()
end

function M.Activate()
	M.active = true
	M.ApplyAll()
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(0.3, M.Tick, "map.tick", true)
	M.Tick()
end

function M.Deactivate()
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	M.SyncCursorTask(false)
	if posText then posText:Hide() end
	if curText then curText:Hide() end
	M.moving = false
	M.lastX = nil
	M.ApplyAll()
	M.ApplyDots()
end

function M.OnKey(key, value)
	M.placeSig = nil
	M.ApplyAll()
	if M.active then M.Tick() end
end

function M.Enable()
	SUI.WhenSafe(M.Activate)
	if not M.watching then
		M.watching = true
		C.Watch("map.", M.OnKey)
	end
end

function M.Disable()
	M.Deactivate()
end

SUI.RegisterCategory("map", 74)

local function opt(key, typ, order, def, extra)
	local o = { key = "map." .. key, type = typ, cat = "map", label = "opt.map." .. key, tip = "tip.map." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("map", {
	default = true,
	cost = "light",
	options = {
		opt("coords", "bool", 10, true, { simple = true }),
		opt("cursor", "bool", 12, true, { simple = true }),
		opt("coordpos", "choice", 14, "bottom", { choices = { "bottom", "top" } }),
		opt("scale", "number", 20, 100, { min = 80, max = 150, step = 5, simple = true }),
		opt("alpha", "number", 25, 1, { min = 0.3, max = 1, step = 0.05 }),
		opt("movealpha", "number", 26, 1, { min = 0.3, max = 1, step = 0.05 }),
		opt("wheel", "bool", 28, false),
		opt("dotsize", "number", 30, 0, { min = 0, max = 32, step = 2 }),
		opt("dotclass", "bool", 31, false),
		opt("dotnames", "bool", 32, false),
		opt("tipscale", "number", 40, 100, { min = 80, max = 150, step = 5 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("mapinfo", function()
	local f = frame()
	if not f or not f.IsShown or not f:IsShown() then SUI.Print(L("msg.map.closed")) return end
	local gp = getglobal("GetPlayerMapPosition")
	if not gp then SUI.Print(L("msg.map.closed")) return end
	local x, y = gp("player")
	x = floor((x or 0) * 100 + 0.5)
	y = floor((y or 0) * 100 + 0.5)
	SUI.Print(sformat("x: %d   y: %d", x, y))
end, "help.map")
