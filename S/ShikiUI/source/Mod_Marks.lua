-- ShikiUI Marks : barre des 8 marqueurs de raid (module "marks"), pour cibler d'un clic ce que le raid leader marque
-- (crane, croix...). Chaque icone s'allume quand un mob vivant porte le marqueur ; clic gauche = cibler ce mob,
-- Maj + clic = poser / retirer ce marqueur sur ta cible.
--
-- Recherche des mobs marques : les cibles des membres du raid / groupe (raid1..40 target, party target, target,
-- targettarget, mouseover) sont balayees a cadence lente (0,5 s). Une marque portee par un mob que personne ne
-- cible n'est pas trouvable en 1.12 (aucune API) : l'icone reste eteinte dans ce cas. Le balayage ne cible rien,
-- ne touche pas aux nameplates : marche aussi en combat.
-- Cout declare : "light" (barre construite une fois hors combat ; fenetre fermee = aucune minuterie).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Marks = M

local floor = math.floor

M.on = false
M.bar = nil
M.task = nil
M.found = {}      -- [1..8] = unite dont la cible / l'unite porte ce marqueur (derniere detection)
M.foundAt = {}    -- [1..8] = instant de la detection
M.nunits = 0

local POLL = 0.5
local FRESH = 3           -- secondes pendant lesquelles une detection reste ciblable
local ICON_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MAXM = 8

local units = {}          -- unites balayees (construites une fois par activation)

local function buildUnits()
	local i = 0
	local function add(u)
		i = i + 1
		units[i] = u
	end
	add("target")
	add("targettarget")
	add("mouseover")
	local gn = getglobal("GetNumRaidMembers")
	local n = (type(gn) == "function") and (gn() or 0) or 0
	local k
	for k = 1, n do add("raid" .. k .. "target") end
	local gnp = getglobal("GetNumPartyMembers")
	local np = (type(gnp) == "function") and (gnp() or 0) or 0
	for k = 1, np do add("party" .. k .. "target") end
	return i
end

-- Un tour de balayage : note quelle unite porte chaque marqueur.
function M.Scan()
	if not M.on or not M.bar or not M.bar:IsShown() then return end
	local now = GetTime()
	local i
	for i = 1, M.nunits do
		local u = units[i]
		if u and UnitExists(u) and not UnitIsPlayer(u) then
			local gri = getglobal("GetRaidTargetIndex")
			local idx = (type(gri) == "function") and gri(u) or nil
			if idx and idx >= 1 and idx <= MAXM then
				M.found[idx] = u
				M.foundAt[idx] = now
			end
		end
	end
	M.Paint()
end

-- Clic sur une icone : cible le dernier mob marque trouve (detection fraiche).
function M.Target(idx)
	local u = M.found[idx]
	local at = M.foundAt[idx]
	if u and at and GetTime() - at < FRESH and UnitExists(u) then
		if SpellIsTargeting and SpellIsTargeting() then
			SpellTargetUnit(u)
		else
			TargetUnit(u)
		end
	end
end

-- ---------------------------------------------------------------- barre
local function mkClick()
	local b = this
	local idx = b.idx
	if IsShiftKeyDown and IsShiftKeyDown() then
		-- Maj + clic : poser / retirer ce marqueur sur ta cible
		if GetRaidTargetIndex("target") == idx then
			SetRaidTarget("target", 0)
		else
			SetRaidTarget("target", idx)
		end
		return
	end
	M.Target(idx)
end

function M.ApplySize()
	if not M.bar then return end
	local sz = C.Get("marks.size") or 24
	local vert = C.Get("marks.vertical")
	local showbrd = C.Get("marks.border")
	local gap = 3
	local i
	for i = 1, MAXM do
		local b = M["btn" .. i]
		b:SetWidth(sz)
		b:SetHeight(sz)
		b:ClearAllPoints()
		if vert then
			b:SetPoint("TOPLEFT", M.bar, "TOPLEFT", 3, -3 - (i - 1) * (sz + gap))
		else
			b:SetPoint("TOPLEFT", M.bar, "TOPLEFT", 3 + (i - 1) * (sz + gap), -3)
		end
		if showbrd then
			local bc = T.c.border
			b:SetBackdropBorderColor(bc[1], bc[2], bc[3], 1)
		else
			-- style:ok transparence totale = pas de cadre (le check n accepte pas les 0 numeriques)
			b:SetBackdropBorderColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 0)
		end
	end
	if vert then
		M.bar:SetWidth(sz + 6)
		M.bar:SetHeight(6 + MAXM * (sz + gap))
	else
		M.bar:SetWidth(6 + MAXM * (sz + gap))
		M.bar:SetHeight(sz + 6)
	end
end

function M.Build()
	if M.bar then return end
	local f = CreateFrame("Frame", "ShikiUI_MarksBar", UIParent)
	f:SetWidth(6 + MAXM * 27)
	f:SetHeight(30)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.bar = f
	local i
	for i = 1, MAXM do
		local b = CreateFrame("Button", nil, f)
		b:SetWidth(24)
		b:SetHeight(24)
		b:SetFrameLevel(f:GetFrameLevel() + 2)
		b.idx = i
		b:SetScript("OnClick", mkClick)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetTexture(ICON_TEX)
		local col = SUI.Mod(i - 1, 4)
		local row = floor((i - 1) / 4)
		b.tex:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
		b.tex:SetAllPoints(b)
		b.tex:SetAlpha(0.25)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 3 + (i - 1) * 27, -3)
		M["btn" .. i] = b
	end
	SUI.Layout.Register(f, "marks.bar", "BOTTOMRIGHT", -20, 180)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("marks.bar", f, { label = L("mod.marks.title"), scale = false })
	end
	T.OnAccent(function()
		if M.bar and M.bar:IsShown() then M.Paint() end
	end)
end

-- Etat visuel : icone pleine si la marque est detectee (fraiche), sinon tres translucente.
function M.Paint()
	local f = M.bar
	if not f or not f:IsShown() then return end
	local now = GetTime()
	local i
	for i = 1, MAXM do
		local b = M["btn" .. i]
		local u = M.found[i]
		local fresh = u and M.foundAt[i] and now - M.foundAt[i] < FRESH and UnitExists(u) and true or false
		b.tex:SetAlpha(fresh and 1 or 0.25)
	end
end

function M.EnsureTask()
	if not M.task then
		M.task = SUI.Every(POLL, M.Scan, "marks.scan", true)
	end
end

function M.Open()
	if not M.on then return end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.nunits = buildUnits()
		M.ApplySize()
		M.bar:Show()
		M.Paint()
		M.EnsureTask()
	end)
end

function M.Close()
	if M.bar then M.bar:Hide() end
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
end

function M.ToggleWin()
	if M.bar and M.bar:IsShown() then M.Close() else M.Open() end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("marks.", M.OnKey)
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.ApplySize()
		M.nunits = buildUnits()
	end)
	M.Open()   -- la barre est la fonction du module : affichee des l'activation
end

function M.Disable()
	M.on = false
	M.Close()
end

function M.OnKey(key)
	if key == nil or string.find(key or EMPTY, "^marks%.") then
		M.ApplySize()
		if M.bar and M.bar:IsShown() then M.Paint() end
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("marks", 69)

local function opt(key, typ, order, def, extra)
	local o = { key = "marks." .. key, type = typ, cat = "marks", label = "opt.marks." .. key, tip = "tip.marks." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

SUI.RegisterModule("marks", {
	default = true,
	cost = "light",
	options = {
		opt("size", "number", 10, 24, { min = 16, max = 40, step = 2 }),
		opt("vertical", "bool", 11, false),
		opt("border", "bool", 12, true),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- /sui marks [open|close] : la barre ; Maj + clic sur une icone = poser le marqueur sur ta cible.
SUI.RegisterCommand("marks", function(rest)
	if not M.on then
		C.Set("modules.marks", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	else
		M.ToggleWin()
	end
end, "help.marks")
