-- ShikiUI GroupPets : cadres compacts des FAMILIERS des membres du groupe (partypet1-4) et du raid (raidpet1-40).
-- Un seul bloc deplacable (Mover, cle "grouppets", position propre au mode Normal / Raid) ; les petits cadres sont construits UNE fois, hors
-- combat (40 boutons), puis seulement montres / places. Aucune frame, aucune table creee en combat ; evenements UNIT_HEALTH / UNIT_MAXHEALTH
-- (un seul cadre touche), UNIT_PET et mouvements du groupe (reorganisation), plus un tour lent (1 s) ; chaque valeur n'est ecrite que si elle change.
-- Le familier du joueur garde son cadre (Units, "pet") : il n'apparait pas ici. NON VERIFIE EN JEU : jetons partypetN / raidpetN, evenements.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local floor = math.floor
local ssub = string.sub

local M = {}
SUI.GroupPets = M

local MAXSLOT = 40
local GAP = 2
local TICK = 1.0

M.on = false
M.slots = {}
M.slotOf = {}        -- jeton du familier -> cadre
M.count = 0          -- familiers affiches
M.kind = nil         -- "party" | "raid" | nil
M.cfg = {}

function M.ReadConfig()
	local c = M.cfg
	c.party = C.Get("grouppets.party")
	c.raid = C.Get("grouppets.raid")
	c.width = C.Get("grouppets.width")
	c.height = C.Get("grouppets.height")
	c.cols = C.Get("grouppets.cols")
	c.name = C.Get("grouppets.name")
	c.hide = C.Get("grouppets.hide")
	c.scale = C.Get("grouppets.scale")
end

-- Couleur de sante (meme degrade que les cadres d'unites).
local function hpColor(ratio)
	local a, b, t
	if ratio < 0.5 then
		a, b, t = T.c.bad, T.c.warn, ratio * 2
	else
		a, b, t = T.c.warn, T.c.good, (ratio - 0.5) * 2
	end
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- ---------------------------------------------------------------- clic, infobulle
local function onClick()
	local unit = this.unit
	if not unit then return end
	if SpellIsTargeting() then
		SpellTargetUnit(unit)
	elseif arg1 ~= "RightButton" then
		TargetUnit(unit)
	end
end

local function onEnter()
	local unit = this.unit
	if not unit or not UnitExists(unit) then return end
	if SUI.Api and SUI.Api.SetMouseover then SUI.Api.SetMouseover(unit) end
	if GameTooltip then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetUnit(unit)
		GameTooltip:Show()
	end
end

local function onLeave()
	if SUI.Api and SUI.Api.SetMouseover then SUI.Api.SetMouseover(nil) end
	if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- construction (hors combat)
local function newSlot(i)
	local f = CreateFrame("Button", "ShikiUI_GroupPet" .. i, M.holder)
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	f:SetScript("OnClick", onClick)
	f:SetScript("OnEnter", onEnter)
	f:SetScript("OnLeave", onLeave)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.hp = T.Bar(f)
	f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.hp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.text = T.Text(f.hp, 9, T.c.text, "LEFT", true)
	f.text:SetPoint("LEFT", f.hp, "LEFT", 2, 0)
	f.text:SetPoint("RIGHT", f.hp, "RIGHT", -2, 0)
	f:Hide()
	return f
end

function M.Build()
	if M.holder then return end
	local h = CreateFrame("Frame", "ShikiUI_GroupPets", UIParent)
	h:SetWidth(60)
	h:SetHeight(14)
	h:SetFrameStrata("LOW")
	M.holder = h
	for i = 1, MAXSLOT do M.slots[i] = newSlot(i) end
	SUI.Layout.Register(h, "grouppets", "TOPLEFT", 20, -420)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("grouppets", h, { label = L("mod.grouppets.title"), scale = false })
	end
	M.ReadConfig()
	M.Refresh()
end

-- ---------------------------------------------------------------- affichage
function M.Paint(s)
	local unit = s.unit
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	local dead = UnitIsDeadOrGhost(unit) and true or false
	local ratio = (max and max > 0) and (hp / max) or 0
	if dead then ratio = 0 end
	if ratio ~= s.lratio then
		s.lratio = ratio
		s.hp:SetMinMaxValues(0, 1)
		s.hp:SetValue(ratio)
		local r, g, b = hpColor(ratio)
		s.hp:SetStatusBarColor(r, g, b, 1)
	end
	if dead ~= s.ldead then
		s.ldead = dead
		local col = dead and T.c.dim or T.c.text
		s.text:SetTextColor(col[1], col[2], col[3], col[4] or 1)
	end
	local nm = ""
	if M.cfg.name then
		nm = UnitName(unit) or ""
		local maxc = floor(M.cfg.width / 5.5)
		if maxc < 3 then maxc = 3 end
		if string.len(nm) > maxc then nm = ssub(nm, 1, maxc) end
	end
	if nm ~= s.lname then
		s.lname = nm
		s.text:SetText(nm)
	end
end

-- Le familier est-il a montrer ? (cache si son maitre est hors ligne / mort : option "hide")
local function petOk(pet, owner)
	if not UnitExists(pet) then return false end
	if M.cfg.hide and (not UnitIsConnected(owner) or UnitIsDeadOrGhost(owner)) then return false end
	return true
end

-- Recalcule la liste des familiers a montrer et replace les cadres (n'ecrit que ce qui change).
function M.Refresh()
	if not M.holder then return end
	local cfg = M.cfg
	local kind, n = nil, 0
	local nr, np = GetNumRaidMembers(), GetNumPartyMembers()
	if nr > 0 then
		if cfg.raid then kind, n = "raid", nr end
	elseif np > 0 then
		if cfg.party then kind, n = "party", np end
	end
	if n > MAXSLOT then n = MAXSLOT end
	local shown = 0
	for k in pairs(M.slotOf) do M.slotOf[k] = nil end
	if kind then
		for i = 1, n do
			local owner = kind .. i
			local pet = kind .. "pet" .. i
			if not UnitIsUnit(owner, "player") and petOk(pet, owner) then
				shown = shown + 1
				local s = M.slots[shown]
				if s.unit ~= pet then
					s.unit = pet
					s.lratio, s.lname, s.ldead = nil, nil, nil
				end
				M.slotOf[pet] = s
				if not s:IsShown() then s:Show() end
				M.Paint(s)
			end
		end
	end
	for i = shown + 1, MAXSLOT do
		local s = M.slots[i]
		if s.unit then
			s.unit = nil
			s.lratio, s.lname, s.ldead = nil, nil, nil
		end
		if s:IsShown() then s:Hide() end
	end
	M.kind, M.count = kind, shown
	M.Place(shown)
end

-- Geometrie (colonnes x lignes) ; reecrite seulement si les reglages ou le nombre changent.
function M.Place(shown)
	local cfg = M.cfg
	local key = shown .. ":" .. cfg.width .. ":" .. cfg.height .. ":" .. cfg.cols .. ":" .. cfg.scale
	if key == M.placeKey then return end
	M.placeKey = key
	local w, h, cols = cfg.width, cfg.height, cfg.cols
	for i = 1, MAXSLOT do
		local s = M.slots[i]
		s:SetWidth(w)
		s:SetHeight(h)
		s:ClearAllPoints()
		local row = floor((i - 1) / cols)
		local col = (i - 1) - row * cols
		s:SetPoint("TOPLEFT", M.holder, "TOPLEFT", col * (w + GAP), -row * (h + GAP))
	end
	local usedCols = (shown < cols) and shown or cols
	if usedCols < 1 then usedCols = 1 end
	-- Hauteur FIXE (une ligne) : le coin bas-gauche enregistre ne bouge pas, les lignes suivantes pendent sous le cadre (ancrage TOPLEFT).
	-- Une hauteur suivant le nombre de lignes faisait SAUTER le premier familier a chaque arrivee / depart d'un membre.
	M.holder:SetWidth(usedCols * (w + GAP) - GAP)
	M.holder:SetHeight(h)
	M.holder:SetScale(cfg.scale / 100)
end

function M.ApplyOptions()
	if not M.holder then return end
	M.ReadConfig()
	M.placeKey = nil
	for i = 1, MAXSLOT do M.slots[i].lname = nil end
	M.Refresh()
	if M.on then M.holder:Show() else M.holder:Hide() end
end

-- ---------------------------------------------------------------- evenements
function M.OnHealth(ev, a1)
	local s = a1 and M.slotOf[a1]
	if s then M.Paint(s) end
end

function M.OnRoster()
	if M.on then M.Refresh() end
end

function M.Tick()
	if not M.holder then return end
	M.Refresh()
end

-- fn(cle, valeur) ; cle == nil : tout a pu changer (profil, mode Normal / Raid, import).
function M.OnKey(key, value)
	if not M.on then return end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.ApplyOptions()
	end)
	SUI.On("UNIT_HEALTH", M.OnHealth)
	SUI.On("UNIT_MAXHEALTH", M.OnHealth)
	SUI.On("UNIT_PET", M.OnRoster)
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	M.task = SUI.Every(TICK, M.Tick, "grouppets.tick", true)
	if not M.watching then
		M.watching = true
		C.Watch("grouppets.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Off("UNIT_HEALTH", M.OnHealth)
	SUI.Off("UNIT_MAXHEALTH", M.OnHealth)
	SUI.Off("UNIT_PET", M.OnRoster)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	if M.holder then M.holder:Hide() end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("grouppets", 77)

local function opt(key, typ, order, def, extra)
	local o = { key = "grouppets." .. key, type = typ, cat = "grouppets", label = "opt.grouppets." .. key, tip = "tip.grouppets." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("grouppets", {
	default = true,
	cost = "light",
	options = {
		opt("party", "bool", 10, true, { simple = true }),
		opt("raid", "bool", 20, true, { simple = true }),
		opt("hide", "bool", 30, true),
		opt("name", "bool", 40, true),
		opt("width", "number", 50, 70, { min = 30, max = 160, step = 5 }),
		opt("height", "number", 60, 14, { min = 6, max = 30, step = 1 }),
		opt("cols", "number", 70, 1, { min = 1, max = 8, step = 1 }),
		opt("scale", "number", 80, 100, { min = 60, max = 160, step = 5 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Raid : petits cadres sur plusieurs colonnes.
SUI.Config.AddPreset("raid", "*", { ["grouppets.width"] = 55, ["grouppets.height"] = 12, ["grouppets.cols"] = 4 })

SUI.RegisterCommand("grouppets", function(rest)
	SUI.Print(L("msg.grouppets.count", M.count))
end, "help.grouppets")
