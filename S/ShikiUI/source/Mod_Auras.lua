-- ShikiUI Auras : buffs, debuffs et augmentations d'arme du joueur, buffs et debuffs de la cible (v0.4, module "auras").
-- API 1.12 relevees dans des addons installes (BigWigs Core / SpecialEvents-Aura, pfUI buff.lua) :
--   GetPlayerBuff(i, "HELPFUL" | "HARMFUL") avec i a partir de 0 -> indice, ou -1 quand il n'y en a plus ; second retour = permanent ;
--   GetPlayerBuffTexture(ind), GetPlayerBuffApplications(ind), GetPlayerBuffDispelType(ind), GetPlayerBuffTimeLeft(ind) (secondes),
--   CancelPlayerBuff(ind), GameTooltip:SetPlayerBuff(ind) ; GetWeaponEnchantInfo() -> mainMain?, ms, charges, offMain?, ms, charges ;
--   GetInventoryItemTexture("player", 16 | 17) ; UnitBuff / UnitDebuff("target", i) -> texture, applications (, type) ;
--   cadres du jeu BuffFrame et TemporaryEnchantFrame (masques par pfUI avec Hide + UnregisterAllEvents).
-- Les durees des auras d'une CIBLE n'existent pas en 1.12 : la cible n'a donc pas de minuterie (limite assumee).
-- Cout declare : MEDIUM. Une minuterie partagee (0,25 s, ralentie en urgence) : les durees seules sont relues, le reste
--   seulement apres un evenement ; boutons crees une fois (hors combat) ; textes et textures reecrits seulement s'ils changent.
-- NON VERIFIE en jeu : tout ce qui touche au rendu ; GetPlayerBuff a partir de 0 (confirme par les addons ci-dessus, pas ici) ;
--   16 buffs de cible lus par UnitBuff ; rendre les cadres du jeu (BuffFrame : evenement PLAYER_AURAS_CHANGED) sans /reload ;
--   la table DebuffTypeColor du jeu (couleurs de dissipation).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Auras = M

local getn = table.getn
local floor = math.floor
local strformat = string.format

M.on = false
M.built = false
M.active = false
M.groups = {}
M.order = { "pb", "pw", "pd", "tb", "td" }
M.dirtyP = true
M.dirtyT = true
M.blizzHidden = false
M.cfg = { player = true, target = true, buffs = true, debuffs = true, weapon = true, targetbuffs = true, targetdebuffs = true,
	size = 28, perrow = 8, spacing = 3, grow = "left", timer = true, stacks = true, warn = 10, dispel = true, tsize = 22, tperrow = 8, dsize = 0, tdsize = 0,
	tick = 0.25, maxbuffs = 32, alpha = 1 }

function M.ReadConfig()
	local cfg = M.cfg
	cfg.player = C.Get("auras.player")
	cfg.target = C.Get("auras.target")
	cfg.buffs = C.Get("auras.buffs")
	cfg.debuffs = C.Get("auras.debuffs")
	cfg.weapon = C.Get("auras.weapon")
	cfg.targetbuffs = C.Get("auras.targetbuffs")
	cfg.targetdebuffs = C.Get("auras.targetdebuffs")
	cfg.size = C.Get("auras.size")
	cfg.perrow = C.Get("auras.perrow")
	cfg.spacing = C.Get("auras.spacing")
	cfg.grow = C.Get("auras.grow")
	cfg.timer = C.Get("auras.timer")
	cfg.stacks = C.Get("auras.stacks")
	cfg.warn = C.Get("auras.warn")
	cfg.dispel = C.Get("auras.dispel")
	cfg.tsize = C.Get("auras.tsize")
	cfg.dsize = C.Get("auras.dsize")
	cfg.tdsize = C.Get("auras.tdsize")
	cfg.tperrow = C.Get("auras.tperrow")
	cfg.tick = C.Get("auras.tick")
	cfg.maxbuffs = C.Get("auras.maxbuffs")
	cfg.alpha = C.Get("auras.alpha")
end

-- ---------------------------------------------------------------- mise en forme du temps
-- Retourne une cle numerique (change quand le texte change) : on ne fabrique la chaine que si la cle change.
local function timeKey(t)
	if t >= 3600 then return 3000000 + floor(t / 3600 + 0.5) end
	if t >= 60 then return 2000000 + floor(t / 60 + 0.5) end
	if t >= 10 then return 1000000 + floor(t) end
	return floor(t * 10)
end

local function timeText(key)
	if key >= 3000000 then return strformat("%dh", key - 3000000) end
	if key >= 2000000 then return strformat("%dm", key - 2000000) end
	if key >= 1000000 then return strformat("%d", key - 1000000) end
	return strformat("%.1f", key / 10)
end
M.TimeKey, M.TimeText = timeKey, timeText

-- ---------------------------------------------------------------- un bouton
local function setBorder(b, r, g, bl)
	if b.br ~= r or b.bg2 ~= g or b.bb ~= bl then
		b.br, b.bg2, b.bb = r, g, bl
		b:SetBackdropBorderColor(r, g, bl, 1)
	end
end

local function dispelColor(dtype)
	local tbl = getglobal("DebuffTypeColor")
	local col = tbl and dtype and tbl[dtype]
	if col then return col.r, col.g, col.b end    -- style:ok couleur de dissipation (donnee de jeu)
	return T.c.bad[1], T.c.bad[2], T.c.bad[3]
end

local function plainBorder(b)
	local c = T.c.border
	setBorder(b, c[1], c[2], c[3])
end

local function showTooltip()
	local b = this
	local gt = getglobal("GameTooltip")
	if not gt or not b.kind then return end
	gt:SetOwner(b, "ANCHOR_BOTTOMRIGHT")
	if b.kind == "pb" or b.kind == "pd" then
		gt:SetPlayerBuff(b.idx)
	elseif b.kind == "pw" then
		gt:SetInventoryItem("player", b.slot)
	elseif b.kind == "tb" then
		gt:SetUnitBuff("target", b.idx)
	elseif b.kind == "td" then
		gt:SetUnitDebuff("target", b.idx)
	end
	gt:Show()
end

local function hideTooltip()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

local function clickAura()
	local b = this
	if arg1 == "RightButton" and b.kind == "pb" and b.idx then
		CancelPlayerBuff(b.idx)
		M.dirtyP = true
	end
end

function M.BuildButton(holder, kind, n)
	local b = CreateFrame("Button", nil, holder)
	b.kind = kind
	b:SetWidth(28)
	b:SetHeight(28)
	T.Backdrop(b, T.c.inset, T.c.border)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.timer = T.Text(b, 10, T.c.text, "CENTER", true)
	if SUI.Look then SUI.Look.ApplyText(b.timer, "auras", 10, true) end    -- police et taille des minuteries : auras.font / auras.fontsize
	b.timer:SetPoint("TOP", b, "BOTTOM", 0, -1)
	b.count = T.Text(b, 10, T.c.text, "RIGHT", true)
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b:RegisterForClicks("RightButtonUp")
	b:SetScript("OnEnter", showTooltip)
	b:SetScript("OnLeave", hideTooltip)
	b:SetScript("OnClick", clickAura)
	b.n = n
	b:Hide()
	return b
end

-- Remplit un bouton (texture, pile, bordure, temps) en n'ecrivant que ce qui change.
local function fillButton(b, tex, count, left, perm, dtype, isDebuff)
	if b.lastTex ~= tex then
		b.lastTex = tex
		b.tex:SetTexture(tex)
		b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- recadrage repose : certains clients le reinitialisent avec la texture
	end
	local cnt = (M.cfg.stacks and count and count > 1) and count or 0
	if b.lastCount ~= cnt then
		b.lastCount = cnt
		b.count:SetText(cnt > 0 and strformat("%d", cnt) or "")
	end
	if isDebuff and M.cfg.dispel then
		local r, g, bl = dispelColor(dtype)
		setBorder(b, r, g, bl)
	else
		plainBorder(b)
	end
	if M.cfg.timer and left and not perm and left > 0 then
		local key = timeKey(left)
		if b.lastKey ~= key then
			b.lastKey = key
			b.timer:SetText(timeText(key))
		end
		local warn = (left <= M.cfg.warn)
		if b.lastWarn ~= warn then
			b.lastWarn = warn
			local c = warn and T.c.warn or T.c.text
			b.timer:SetTextColor(c[1], c[2], c[3], 1)
		end
	elseif b.lastKey ~= -1 then
		b.lastKey = -1
		b.timer:SetText("")
	end
	if not b:IsShown() then b:Show() end
end

-- ---------------------------------------------------------------- lecture des auras
function M.RefreshPlayer(g, filter, isDebuff, limit)
	local n = 0
	for i = 0, limit - 1 do
		local idx, perm = GetPlayerBuff(i, filter)
		if not idx or idx < 0 then break end
		n = n + 1
		local b = g.btns[n]
		b.idx = idx
		fillButton(b, GetPlayerBuffTexture(idx), GetPlayerBuffApplications(idx), GetPlayerBuffTimeLeft(idx), perm == 1,
			isDebuff and GetPlayerBuffDispelType(idx) or nil, isDebuff)
	end
	return n
end

function M.RefreshWeapon(g)
	local n = 0
	if M.cfg.weapon then
		local mh, mht, mhc, oh, oht, ohc = GetWeaponEnchantInfo()
		for s = 1, 2 do
			local has, ms, ch, slot
			if s == 1 then has, ms, ch, slot = mh, mht, mhc, 16 else has, ms, ch, slot = oh, oht, ohc, 17 end
			if has then
				n = n + 1
				local b = g.btns[n]
				b.slot = slot
				fillButton(b, GetInventoryItemTexture("player", slot), ch, (ms or 0) / 1000, false, nil, false)
			end
		end
	end
	return n
end

function M.RefreshTarget(g, isDebuff, limit)
	local n = 0
	if UnitExists("target") then
		for i = 1, limit do
			local tex, count, dtype
			if isDebuff then tex, count, dtype = UnitDebuff("target", i) else tex, count = UnitBuff("target", i) end
			if not tex then break end
			n = n + 1
			local b = g.btns[n]
			b.idx = i
			fillButton(b, tex, count, nil, true, dtype, isDebuff)
		end
	end
	return n
end

local function hideFrom(g, n)
	for i = n + 1, g.shown do
		g.btns[i]:Hide()
		g.btns[i].lastTex = nil
	end
	g.shown = n
end

-- Recalcul complet d'un groupe (apres un evenement).
function M.RefreshGroup(key)
	local g = M.groups[key]
	if not g or not g.holder then return end
	local cfg = M.cfg
	local n = 0
	if key == "pb" then
		if cfg.player and cfg.buffs then n = M.RefreshPlayer(g, "HELPFUL", false, cfg.maxbuffs) end
	elseif key == "pd" then
		if cfg.player and cfg.debuffs then n = M.RefreshPlayer(g, "HARMFUL", true, 16) end
	elseif key == "pw" then
		if cfg.player then n = M.RefreshWeapon(g) end
	elseif key == "tb" then
		if cfg.target and cfg.targetbuffs then n = M.RefreshTarget(g, false, 16) end
	elseif key == "td" then
		if cfg.target and cfg.targetdebuffs then n = M.RefreshTarget(g, true, 16) end
	end
	hideFrom(g, n)
	g.shown = n
	g.timed = (key == "pb" or key == "pd" or key == "pw")
	if M.built then M.ResizeGroup(key) end
end

-- Seules les durees bougent entre deux evenements : relecture legere des boutons du joueur.
function M.RefreshTimes(g)
	if not g.timed or g.shown == 0 or not M.cfg.timer then return end
	for i = 1, g.shown do
		local b = g.btns[i]
		local left
		if b.kind == "pw" then
			local mh, mht, _, oh, oht = GetWeaponEnchantInfo()
			if b.slot == 16 then left = mht else left = oht end
			left = left and left / 1000 or nil
		else
			left = GetPlayerBuffTimeLeft(b.idx)
		end
		if left and left > 0 then
			local key = timeKey(left)
			if b.lastKey ~= key then
				b.lastKey = key
				b.timer:SetText(timeText(key))
			end
			local warn = (left <= M.cfg.warn)
			if b.lastWarn ~= warn then
				b.lastWarn = warn
				local c = warn and T.c.warn or T.c.text
				b.timer:SetTextColor(c[1], c[2], c[3], 1)
			end
		end
	end
end

function M.MarkAll()
	M.dirtyP = true
	M.dirtyT = true
end

-- Verification legere a chaque tick : le jeu n'envoie pas toujours PLAYER_AURAS_CHANGED (changement d'aura de paladin, mort,
-- esprit libere). On compare indice + texture de chaque buff / debuff lu a ce qui est affiche ; une difference force la relecture.
function M.PlayerChanged(g, filter, limit)
	if type(getglobal("GetPlayerBuff")) ~= "function" then return false end
	local n = 0
	for i = 0, limit - 1 do
		local idx = GetPlayerBuff(i, filter)
		if not idx or idx < 0 then break end
		n = n + 1
		local b = g.btns[n]
		if n > g.shown or b.idx ~= idx or b.lastTex ~= GetPlayerBuffTexture(idx) then return true end
	end
	return n ~= g.shown
end

function M.Tick()
	if not M.built then return end
	if not M.dirtyP then
		local c = M.cfg
		if c.player and c.buffs and M.PlayerChanged(M.groups.pb, "HELPFUL", c.maxbuffs) then M.dirtyP = true
		elseif c.player and c.debuffs and M.PlayerChanged(M.groups.pd, "HARMFUL", 16) then M.dirtyP = true end
	end
	if M.dirtyP then
		M.dirtyP = false
		M.RefreshGroup("pb")
		M.RefreshGroup("pd")
		M.RefreshGroup("pw")
	else
		M.RefreshTimes(M.groups.pb)
		M.RefreshTimes(M.groups.pd)
		M.RefreshTimes(M.groups.pw)
	end
	if M.dirtyT then
		M.dirtyT = false
		M.RefreshGroup("tb")
		M.RefreshGroup("td")
	end
end

-- ---------------------------------------------------------------- evenements
function M.OnPlayerAuras()
	M.dirtyP = true
end

function M.OnUnitAura(ev, unit)
	if unit == "target" then M.dirtyT = true
	elseif unit == "player" then M.dirtyP = true end
end

-- Mort, resurrection, liberation de l'esprit, entree en jeu : le client retire / remet les auras APRES l'evenement,
-- donc relecture immediate puis deux relectures differees.
function M.OnLife()
	M.MarkAll()
	SUI.After(0.5, function() if M.active then M.MarkAll() end end, "auras.life1")
	SUI.After(1.5, function() if M.active then M.MarkAll() end end, "auras.life2")
end

function M.OnTarget()
	M.dirtyT = true
	M.Tick()
end

function M.OnInventory(ev, unit)
	if unit == "player" then M.dirtyP = true end
end

-- ---------------------------------------------------------------- construction (hors combat)
local DEFAULTS = {
	-- Positions par defaut SANS chevauchement aux reglages par defaut (hauteur d'un groupe = lignes x (taille + espace + 10 de temps)) :
	-- buffs 4 lignes de 41 = 164 (de -12 a -176), armes 1 ligne (de -184 a -225), debuffs 2 lignes (de -234 a -316) ; cible : 2 lignes
	-- de 35 = 70 chacune, centrees a 130 (de 95 a 165) et a 40 (de 5 a 75).
	pb = { "TOPRIGHT", -190, -12, 32 }, pw = { "TOPRIGHT", -190, -184, 2 }, pd = { "TOPRIGHT", -190, -234, 16 },
	tb = { "CENTER", -150, 130, 16 }, td = { "CENTER", -150, 40, 16 },
}

function M.Build()
	if M.built then return end
	for i = 1, getn(M.order) do
		local key = M.order[i]
		local d = DEFAULTS[key]
		local holder = CreateFrame("Frame", "ShikiUI_Auras_" .. key, UIParent)
		holder:SetWidth(100)
		holder:SetHeight(30)
		holder.hint = holder:CreateTexture(nil, "BACKGROUND")
		holder.hint:SetTexture(T.tex.white)
		holder.hint:SetAllPoints(holder)
		holder.hint:SetVertexColor(T.c.panel[1], T.c.panel[2], T.c.panel[3], 0.6)
		holder.hint:Hide()
		local g = { key = key, holder = holder, btns = {}, shown = 0, max = d[4] }
		for n = 1, d[4] do g.btns[n] = M.BuildButton(holder, key, n) end
		M.groups[key] = g
		SUI.Layout.Register(holder, "auras." .. key, d[1], d[2], d[3])
		if SUI.Mover then SUI.Mover.Register("auras." .. key, holder, { sync = function() M.ResizeGroup(key) end }) end
	end
	M.built = true
	T.OnAccent(M.MarkAll)
	M.ApplyOptions()
end

-- Place les boutons d'un groupe selon taille, colonnes, espacement et sens.
-- count (facultatif) = boutons REELLEMENT visibles : le conteneur (et donc la poignee du Mover) epouse le bloc
-- affiche au lieu de la grille maximale, sinon la case de deplacement ne correspond jamais aux buffs visibles.
local function layoutGroup(g, size, perrow, spacing, growLeft, count)
	local step = size + spacing
	-- Taille FIXE (grille complete) : la position enregistree est le coin bas-gauche du conteneur ; un conteneur qui epouse le nombre
	-- d'icones affichees changeait de hauteur / largeur a chaque cible ou buff et les icones sautaient (haut ou bord droit deplaces).
	local cnt = g.max
	local rows = floor((cnt - 1) / perrow) + 1
	local cols = perrow
	if cnt < perrow then cols = cnt end
	g.holder:SetWidth(cols * step)
	g.holder:SetHeight(rows * (step + 10))
	-- groupe lie AU-DESSUS de son parent (cote TOP) : les icones partent du BAS du conteneur et montent, sinon les lignes inutilisees
	-- (la grille est de taille fixe) laissent un grand vide entre les icones et le cadre.
	local lk, side = nil, nil
	if SUI.Layout and SUI.Layout.GetLink then lk, side = SUI.Layout.GetLink("auras." .. tostring(g.key)) end
	local up = (side == "TOP")
	local anchor = (up and "BOTTOM" or "TOP") .. (growLeft and "RIGHT" or "LEFT")
	for n = 1, g.max do
		local b = g.btns[n]
		local col = SUI.Mod(n - 1, perrow)
		local row = floor((n - 1) / perrow)
		b:SetWidth(size)
		b:SetHeight(size)
		b:ClearAllPoints()
		local oy = row * (step + 10)
		b:SetPoint(anchor, g.holder, anchor, growLeft and -col * step or col * step, up and (oy + 10) or -oy)
	end
end

-- Taille du groupe selon ses reglages : debuffs joueur / cible ont leur propre taille (0 = comme les buffs).
local function groupSize(key, c)
	if key == "pd" and (c.dsize or 0) > 0 then return c.dsize end
	if key == "td" and (c.tdsize or 0) > 0 then return c.tdsize end
	if key == "tb" or key == "td" then return c.tsize end
	return c.size
end
local function groupPer(key, c)
	if key == "tb" or key == "td" then return c.tperrow end
	return c.perrow
end
function M.ResizeGroup(key)
	local g = M.groups[key]
	if not g then return end
	local c = M.cfg
	layoutGroup(g, groupSize(key, c), groupPer(key, c), c.spacing, c.grow == "left" and key ~= "tb" and key ~= "td", g.shown > 0 and g.shown or nil)
end
function M.ApplyOptions()
	if not M.built then return end
	local c = M.cfg
	local gl = (c.grow == "left")
	layoutGroup(M.groups.pb, c.size, c.perrow, c.spacing, gl, M.groups.pb.shown > 0 and M.groups.pb.shown or nil)
	layoutGroup(M.groups.pw, c.size, c.perrow, c.spacing, gl, M.groups.pw.shown > 0 and M.groups.pw.shown or nil)
	layoutGroup(M.groups.pd, groupSize("pd", c), c.perrow, c.spacing, gl, M.groups.pd.shown > 0 and M.groups.pd.shown or nil)
	layoutGroup(M.groups.tb, c.tsize, c.tperrow, c.spacing, false, M.groups.tb.shown > 0 and M.groups.tb.shown or nil)
	layoutGroup(M.groups.td, groupSize("td", c), c.tperrow, c.spacing, false, M.groups.td.shown > 0 and M.groups.td.shown or nil)
	for i = 1, getn(M.order) do
		local g = M.groups[M.order[i]]
		if SUI.Visibility and SUI.Visibility.byFrame[g.holder] then
			SUI.Visibility.SetBase(g.holder, c.alpha)       -- l'opacite pleine passe par le service (fondu de visibilite)
		else
			g.holder:SetAlpha(c.alpha)
		end
		if not c.timer then
			for n = 1, g.max do g.btns[n].timer:SetText("") g.btns[n].lastKey = nil end
		end
	end
	M.ApplyLock()
	M.HideBlizzard()
	if M.active then
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(c.tick, M.Tick, "auras.tick", true)
	end
	M.MarkAll()
	-- relecture immediate : le reglage se voit tout de suite, sans attendre la prochaine minuterie
	if M.active then M.Tick() end
end

-- Le deplacement est assure par le service Mover (poignee nommee, voir Mover.lua) : plus de fond ni de souris sur le cadre lui-meme
-- (un fond sans nom etait le "carre noir" vu en deverrouillant).
function M.ApplyLock()
	if not M.built then return end
	for i = 1, getn(M.order) do
		local h = M.groups[M.order[i]].holder
		h:EnableMouse(false)
		h.hint:Hide()
	end
end

-- ---------------------------------------------------------------- cadres du jeu
function M.HideBlizzard()
	local bf, tf = getglobal("BuffFrame"), getglobal("TemporaryEnchantFrame")
	local want = M.on and M.cfg.player and C.Get("auras.hideblizz")
	if want and SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("buff") then want = false end
	if want and not M.blizzHidden then
		M.blizzHidden = true
		if bf then bf:UnregisterAllEvents() bf:Hide() end
		if tf then tf:UnregisterAllEvents() tf:Hide() end
	elseif (not want) and M.blizzHidden then
		M.blizzHidden = false
		if bf then
			bf:RegisterEvent("PLAYER_AURAS_CHANGED")
			bf:Show()
		end
		if tf then tf:Show() end
	end
end

-- Visibilite commune (auras.vis / auras.fade) : opacite seule, les cadres restent affiches (aucun conflit avec la logique du module).
function M.AttachVisibility()
	if not (SUI.Visibility and M.built) then return end
	for i = 1, getn(M.order) do
		SUI.Visibility.Add(M.groups[M.order[i]].holder, "auras", { mode = "alpha", module = "auras", alpha = M.cfg.alpha, cat = "auras" })
	end
end

function M.DetachVisibility()
	if not (SUI.Visibility and M.built) then return end
	-- differe : la coupure arrive depuis un observateur de Config (Remove peut en detacher un pendant sa boucle) ; rallume entre-temps : rien
	SUI.After(0, function()
		if M.on then return end
		for i = 1, getn(M.order) do SUI.Visibility.Remove(M.groups[M.order[i]].holder) end
	end, "auras.visoff")
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	if key == "ui.locked" then
		M.ApplyLock()
		return
	end
	M.ReadConfig()
	M.ApplyOptions()
end

function M.OnStyle()
	M.MarkAll()
end

function M.Activate()
	if M.active then return end
	M.active = true
	SUI.On("PLAYER_AURAS_CHANGED", M.OnPlayerAuras)
	SUI.On("UNIT_AURA", M.OnUnitAura)
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("UNIT_INVENTORY_CHANGED", M.OnInventory)
	SUI.On("PLAYER_DEAD", M.OnLife)
	SUI.On("PLAYER_ALIVE", M.OnLife)
	SUI.On("PLAYER_UNGHOST", M.OnLife)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnLife)
	M.task = SUI.Every(M.cfg.tick, M.Tick, "auras.tick", true)
	M.MarkAll()
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Off("PLAYER_AURAS_CHANGED", M.OnPlayerAuras)
	SUI.Off("UNIT_AURA", M.OnUnitAura)
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("UNIT_INVENTORY_CHANGED", M.OnInventory)
	SUI.Off("PLAYER_DEAD", M.OnLife)
	SUI.Off("PLAYER_ALIVE", M.OnLife)
	SUI.Off("PLAYER_UNGHOST", M.OnLife)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnLife)
	SUI.Cancel(M.task)
	M.task = nil
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	if not M.watching then
		M.watching = true
		C.Watch("auras.", M.OnKey)
		C.Watch("ui.locked", M.OnKey)
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		for i = 1, getn(M.order) do M.groups[M.order[i]].holder:Show() end
		M.Activate()
		M.ApplyOptions()
		M.AttachVisibility()
		M.Tick()
	end)
end

function M.Disable()
	M.on = false
	M.Deactivate()
	M.DetachVisibility()
	if M.built then
		for i = 1, getn(M.order) do
			local g = M.groups[M.order[i]]
			g.holder:Hide()
			g.holder:EnableMouse(false)
		end
	end
	M.HideBlizzard()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("auras", 26)

local function opt(key, typ, order, def, extra)
	local o = { key = "auras." .. key, type = typ, cat = "auras", label = "opt.auras." .. key, tip = "tip.auras." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local AU_OPTIONS = {
		opt("player", "bool", 10, true, { simple = true }),
		opt("target", "bool", 20, true, { simple = true }),
		opt("size", "number", 30, 28, { min = 16, max = 40, step = 2, simple = true }),
		opt("dsize", "number", 32, 0, { min = 0, max = 40, step = 2 }),
		opt("timer", "bool", 40, true, { simple = true }),
		opt("buffs", "bool", 50, true),
		opt("debuffs", "bool", 60, true),
		opt("weapon", "bool", 70, true),
		opt("perrow", "number", 80, 8, { min = 4, max = 16, step = 1 }),
		opt("spacing", "number", 90, 3, { min = 0, max = 10, step = 1 }),
		opt("grow", "choice", 100, "left", { choices = { "left", "right" } }),
		opt("stacks", "bool", 110, true),
		opt("warn", "number", 120, 10, { min = 0, max = 60, step = 5 }),
		opt("dispel", "bool", 130, true),
		opt("maxbuffs", "number", 140, 32, { min = 8, max = 32, step = 4 }),
		opt("targetbuffs", "bool", 150, true),
		opt("targetdebuffs", "bool", 160, true),
		opt("tsize", "number", 170, 22, { min = 14, max = 36, step = 2 }),
		opt("tdsize", "number", 175, 0, { min = 0, max = 36, step = 2 }),
		opt("tperrow", "number", 180, 8, { min = 4, max = 16, step = 1 }),
		opt("alpha", "number", 190, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("tick", "number", 200, 0.25, { min = 0.1, max = 1, step = 0.05 }),
		opt("hideblizz", "bool", 210, true, { reload = true }),
}
-- Options communes du socle : visibilite conditionnelle (auras.vis / .fade) et police des minuteries (auras.font / .fontsize).
local function addAll(list)
	for i = 1, getn(list) do table.insert(AU_OPTIONS, list[i]) end
end
if SUI.Visibility then addAll(SUI.Visibility.Options("auras", { cat = "auras", order = 800 })) end
if SUI.Look then addAll(SUI.Look.Options("auras", { font = true, cat = "auras", order = 820 })) end

SUI.RegisterModule("auras", {
	default = false,
	cost = "medium",
	options = AU_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalents pfUI : "buff" (buffs / debuffs du joueur) ; "buffwatch" reste a part.
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.auras then SUI.Migrate.MAP.auras = { "buff" } end

-- Mode Raid : relecture plus lente, buffs de la cible masques (moins de cadres a redessiner).
SUI.Config.AddPreset("raid", "*", { ["auras.tick"] = 0.5, ["auras.targetbuffs"] = false })

SUI.RegisterCommand("auras", function(rest)
	if not M.built then SUI.Print(L("msg.auras.notready")) return end
	local g = M.groups
	SUI.Print(L("msg.auras.info", g.pb.shown, g.pd.shown, g.pw.shown, g.tb.shown + g.td.shown))
end, "help.auras")
