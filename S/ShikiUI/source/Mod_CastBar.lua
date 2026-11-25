-- ShikiUI CastBar : barres d'incantation du joueur, de la cible et du "focus" au style choisi (v0.4, module "castbar").
-- Joueur : evenements 1.12 SPELLCAST_START / STOP / FAILED / INTERRUPTED / DELAYED / CHANNEL_START / CHANNEL_UPDATE / CHANNEL_STOP
--   (arguments relus dans BigWigs\Libs\SpellStatusV2 et OctoManaSwap : START(nom, duree ms), CHANNEL_START(duree ms, nom),
--   DELAYED(retard ms), CHANNEL_UPDATE(restant ms)). Zone de latence = 3e retour de GetNetStats().
-- Cible / focus : SuperWoW UNIT_CASTEVENT(lanceur, cible, type, sortId, duree ms), types START / CAST / FAIL / CHANNEL (releve dans
--   BigWigs\Core.lua et HandGuard), icone et nom via SpellInfo(sortId) (3e retour = texture, releve dans NampowerSettings). Nampower en
--   complement : SPELL_START_OTHER(objet, sort, lanceur, cible, drapeaux, tempsIncantation, duree, type), SPELL_GO_OTHER(objet, sort,
--   lanceur, ...), SPELL_FAILED_OTHER(lanceur, sort) (releves dans ChronicleCompanion ; demandent les CVar NP_EnableSpellStartEvents /
--   NP_EnableSpellGoEvents). Sans SuperWoW ni Nampower le 1.12 n'offre AUCUN moyen fiable de lire l'incantation d'un autre : les barres
--   cible / focus restent alors cachees (limite assumee).
-- Barre de Blizzard : CastingBarFrame est masquee (UnregisterAllEvents + Hide) sauf si pfUI s'en charge ; la rendre = les 8 evenements
--   SPELLCAST_* sont re-enregistres (a verifier en jeu, /reload sinon).
-- Cout declare : MEDIUM. Une minuterie partagee a 0,05 s (sortie immediate si aucune barre active), aucun OnUpdate, aucune frame
--   creee en combat (construction hors combat), aucune table creee pendant une incantation, textes reecrits seulement s'ils changent.
-- NON VERIFIE en jeu : tous les evenements ci-dessus, l'ordre des arguments de SPELLCAST_CHANNEL_START, GetNetStats()[3] en ms,
--   le nom "CastingBarFrame" et ses 8 evenements, les arguments Nampower (CVar a activer par l'utilisateur), SpellInfo(sortId).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.CastBar = M

local getn = table.getn
local floor, abs = math.floor, math.abs
local strformat = string.format

local TICK = 0.05
local TESTICON = "Interface\\Icons\\INV_Misc_QuestionMark"   -- style:ok donnee de jeu (icone de l'essai)
local NAMES = { "player", "target", "focus" }
local BLIZZ_EVENTS = { "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "SPELLCAST_DELAYED",
	"SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_UPDATE", "SPELLCAST_CHANNEL_STOP" }

M.on = false
M.built = false
M.bars = {}
M.nActive = 0
M.icons = {}              -- nom du sort -> texture (grimoire, construit hors combat)
M.targetGuid = nil
M.focusGuid = nil
M.focusName = nil
M.blizzHidden = false
M.origOnShow = nil
M.cfg = { player = true, target = true, focus = true, width = 220, owidth = 180, height = 16, icon = true, name = true, timer = true,
	decimals = 1, lag = true, spark = true, drain = true, fade = 0.5, np = true, failtext = true, alpha = 1, classcolor = false }

function M.ReadConfig()
	local cfg = M.cfg
	cfg.player = C.Get("castbar.player")
	cfg.target = C.Get("castbar.target")
	cfg.focus = C.Get("castbar.focus")
	cfg.width = C.Get("castbar.width")
	cfg.owidth = C.Get("castbar.owidth")
	cfg.height = C.Get("castbar.height")
	cfg.icon = C.Get("castbar.icon")
	cfg.name = C.Get("castbar.name")
	cfg.timer = C.Get("castbar.timer")
	cfg.decimals = C.Get("castbar.decimals")
	cfg.lag = C.Get("castbar.lag")
	cfg.spark = C.Get("castbar.spark")
	cfg.drain = (C.Get("castbar.channeldir") == "drain")
	cfg.fade = C.Get("castbar.fade")
	cfg.np = C.Get("castbar.np")
	cfg.failtext = C.Get("castbar.failtext")
	cfg.alpha = C.Get("castbar.alpha")
	cfg.classcolor = C.Get("castbar.classcolor")
end

-- ---------------------------------------------------------------- noms et icones des sorts
-- Nom (et icone) d'un sort a partir de son identifiant : SuperWoW SpellInfo, sinon Nampower. Rien d'invente : nil si impossible.
function M.SpellData(id)
	if not id then return nil, nil end
	local name, tex
	local si = getglobal("SpellInfo")
	if si then
		local ok, n, _, t = pcall(si, id)
		if ok then name, tex = n, t end
	end
	if not name then
		local rec = getglobal("GetSpellRecField")
		if rec then
			local ok, n = pcall(rec, id, "name")
			if ok and type(n) == "string" and n ~= "" then name = n end
			if not tex then
				local gi = getglobal("GetSpellIconTexture")
				local okI, iconId = pcall(rec, id, "spellIconID")
				if gi and okI and iconId then
					local okT, t = pcall(gi, iconId)
					if okT then tex = t end
				end
			end
		end
	end
	if name and not tex then tex = M.icons[name] end
	return name, tex
end

-- Grimoire : nom -> texture (une seule passe, hors combat, relancee a l'apprentissage d'un sort).
function M.ScanBook()
	if SUI.InCombat() then
		M.bookPending = true
		return
	end
	M.bookPending = false
	local gn, gt = getglobal("GetSpellName"), getglobal("GetSpellTexture")
	if not gn or not gt then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 1000 do
		local name = gn(i, book)
		if not name then break end
		M.icons[name] = gt(i, book)
	end
end

-- ---------------------------------------------------------------- etat d'une barre
local function setColor(f, kind)
	local r, g, b
	if kind == "fail" then
		r, g, b = T.c.bad[1], T.c.bad[2], T.c.bad[3]
	elseif kind == "channel" then
		r, g, b = T.c.good[1], T.c.good[2], T.c.good[3]
	elseif f.key == "player" and M.cfg.classcolor and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then r, g, b = col.r, col.g, col.b end    -- style:ok couleur de classe (donnee de jeu)
	end
	if not r then r, g, b = T.Accent() end
	f.sb:SetStatusBarColor(r, g, b, 1)
end

local function setName(f, txt)
	if f.lastName ~= txt then
		f.lastName = txt
		f.nameFs:SetText(txt)
	end
end

local function setTimer(f, txt)
	if f.lastTimer ~= txt then
		f.lastTimer = txt
		f.timeFs:SetText(txt)
	end
end

local function setSpark(f, ratio)
	local x = floor(ratio * f.sbw + 0.5)
	if f.sparkX ~= x then
		f.sparkX = x
		f.spark:ClearAllPoints()
		f.spark:SetPoint("CENTER", f.sb, "LEFT", x, 0)
	end
end

-- Icone du sort en cours selon l'option "icon" (le recadrage est repose apres chaque SetTexture : certains clients le reinitialisent).
function M.ShowIcon(f)
	if not f.icon then return end
	if M.cfg.icon and f.iconTex then
		f.icon:SetTexture(f.iconTex)
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icon:Show()
	else
		f.icon:Hide()
	end
end

-- Visibilite commune (castbar.cond.vis / .fade) : un cadre mandataire (jamais affiche) porte l'etat et l'opacite du service ; les barres
-- suivent cette opacite (multipliee a la leur) et une incantation qui commence pendant que la regle les cache n'ouvre pas de barre.
local function visMul()
	local p = M.visProxy
	if p and SUI.Visibility and SUI.Visibility.byFrame[p] then return p:GetAlpha() end
	return 1
end

local function visAllowed()
	local p = M.visProxy
	if p and SUI.Visibility then return SUI.Visibility.Allowed(p) end
	return true
end

function M.AttachVisibility()
	if not (SUI.Visibility and M.built) then return end
	if not M.visProxy then M.visProxy = CreateFrame("Frame", nil, UIParent) end
	SUI.Visibility.Add(M.visProxy, "castbar.cond", { mode = "alpha", module = "castbar", alpha = 1, cat = "castbar" })
end

function M.DetachVisibility()
	if not (SUI.Visibility and M.visProxy) then return end
	-- differe : la coupure arrive depuis un observateur de Config (Remove peut en detacher un pendant sa boucle) ; rallume entre-temps : rien
	SUI.After(0, function()
		if M.on then return end
		SUI.Visibility.Remove(M.visProxy)
	end, "castbar.visoff")
end

-- Demarre une incantation (chan = canalisee). t0 / t1 : secondes (GetTime).
function M.Start(f, name, icon, t0, t1, chan, spellId)
	if not f.active and not visAllowed() then return end
	local was = f.active
	f.active = true
	f.failed = false
	f.fadeAt = nil
	f.chan = chan and true or false
	f.t0, f.t1 = t0, t1
	f.spellId = spellId
	f.iconTex, f.nameTxt = icon, name
	if not was then M.nActive = M.nActive + 1 end
	f.visA = visMul()
	f:SetAlpha(M.cfg.alpha * f.visA)
	setColor(f, chan and "channel" or "cast")
	M.ShowIcon(f)
	setName(f, M.cfg.name and name or "")
	f.sparkX = nil
	if M.cfg.spark then f.spark:Show() else f.spark:Hide() end
	f.lag:Hide()
	if f.key == "player" and M.cfg.lag and not chan then
		local _, _, ms = GetNetStats()
		local dur = t1 - t0
		if ms and ms > 0 and dur > 0 then
			local w = (ms / 1000) / dur
			if w > 0.5 then w = 0.5 end
			f.lag:ClearAllPoints()
			f.lag:SetPoint("TOPRIGHT", f.sb, "TOPRIGHT", 0, 0)
			f.lag:SetPoint("BOTTOMRIGHT", f.sb, "BOTTOMRIGHT", 0, 0)
			f.lag:SetWidth(floor(w * f.sbw + 0.5) + 1)
			f.lag:Show()
		end
	end
	f.sb:SetMinMaxValues(0, 1)
	f.sb:SetValue(chan and (M.cfg.drain and 1 or 0) or 0)
	f.lastV = nil
	f:Show()
	M.Update(f, GetTime())
end

-- Fin : ok = incantation terminee normalement ; sinon echec / interruption (barre rouge, texte).
function M.Finish(f, ok, reason)
	if not f.active then return end
	f.active = false
	M.nActive = M.nActive - 1
	if ok then
		f.sb:SetValue(1)
		f.lastV = nil
		setTimer(f, "")
	else
		f.failed = true
		setColor(f, "fail")
		f.sb:SetValue(1)
		f.lastV = nil
		if M.cfg.failtext and reason then setName(f, reason) end
		setTimer(f, "")
	end
	f.lag:Hide()
	f.spark:Hide()
	if M.cfg.fade <= 0 then
		f:Hide()
		f.fadeAt = nil
	else
		f.fadeAt = GetTime()
	end
end

function M.Hide(f)
	if f.active then
		f.active = false
		M.nActive = M.nActive - 1
	end
	f.fadeAt = nil
	f:Hide()
end

function M.Update(f, now)
	if f.active then
		local dur = f.t1 - f.t0
		if dur <= 0 then dur = 0.001 end
		local ratio
		if f.chan then
			ratio = (f.t1 - now) / dur
			if not M.cfg.drain then ratio = 1 - ratio end
		else
			ratio = (now - f.t0) / dur
		end
		if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
		local v = floor(ratio * 1000)
		if f.lastV ~= v then
			f.lastV = v
			f.sb:SetValue(ratio)
		end
		if M.cfg.spark then setSpark(f, ratio) end
		if M.cfg.timer then
			local remain = f.t1 - now
			if remain < 0 then remain = 0 end
			if M.cfg.decimals == 0 then
				setTimer(f, strformat("%d", floor(remain + 0.5)))
			elseif M.cfg.decimals == 1 then
				setTimer(f, strformat("%.1f", remain))
			else
				setTimer(f, strformat("%.2f", remain))
			end
		else
			setTimer(f, "")
		end
		local va = visMul()
		if f.visA ~= va then                                  -- la regle de visibilite fond la barre (seulement si l'opacite a change)
			f.visA = va
			f:SetAlpha(M.cfg.alpha * va)
		end
		if now >= f.t1 + 0.3 then M.Finish(f, true) end    -- evenement de fin perdu : on termine quand meme
	elseif f.fadeAt then
		local fade = M.cfg.fade
		local a = 1 - (now - f.fadeAt) / (fade > 0 and fade or 0.001)
		if a <= 0 then
			f.fadeAt = nil
			f:Hide()
		else
			f:SetAlpha(a * M.cfg.alpha * visMul())
		end
	end
end

-- Minuterie partagee : ne fait rien tant qu'aucune barre n'est active ou en fondu.
function M.Tick()
	if not M.built then return end
	local now = GetTime()
	for i = 1, 3 do
		local f = M.bars[NAMES[i]]
		if f and (f.active or f.fadeAt) then M.Update(f, now) end
	end
end

-- ---------------------------------------------------------------- joueur : evenements SPELLCAST_*
function M.OnPlayerEvent(ev, a1, a2)
	local f = M.bars.player
	if not f or not M.cfg.player then return end
	local now = GetTime()
	if ev == "SPELLCAST_START" then
		local ms = tonumber(a2) or 0
		M.Start(f, a1 or "", M.icons[a1 or ""], now, now + ms / 1000, false, nil)
	elseif ev == "SPELLCAST_CHANNEL_START" then
		local ms = tonumber(a1) or 0
		M.Start(f, a2 or "", M.icons[a2 or ""], now, now + ms / 1000, true, nil)
	elseif ev == "SPELLCAST_STOP" then
		if f.active and not f.chan then M.Finish(f, true) end
	elseif ev == "SPELLCAST_CHANNEL_STOP" then
		if f.active and f.chan then M.Finish(f, true) end
	elseif ev == "SPELLCAST_FAILED" then
		if f.active then M.Finish(f, false, L("msg.castbar.failed")) end
	elseif ev == "SPELLCAST_INTERRUPTED" then
		if f.active then M.Finish(f, false, L("msg.castbar.interrupted")) end
	elseif ev == "SPELLCAST_DELAYED" then
		if f.active and not f.chan then
			local d = (tonumber(a1) or 0) / 1000
			f.t0, f.t1 = f.t0 + d, f.t1 + d
		end
	elseif ev == "SPELLCAST_CHANNEL_UPDATE" then
		if f.active and f.chan then
			local dur = f.t1 - f.t0
			f.t1 = now + (tonumber(a1) or 0) / 1000
			f.t0 = f.t1 - dur
		end
	end
end

-- ---------------------------------------------------------------- cible / focus : UNIT_CASTEVENT (SuperWoW) et evenements Nampower
-- Une incantation d'un autre : kind = "start" | "channel" | "cast" | "fail" ; ms = duree en millisecondes.
function M.OtherCast(guid, kind, spellId, ms)
	local now = GetTime()
	local t = M.bars.target
	local fo = M.bars.focus
	-- la cible ET le focus peuvent etre le meme lanceur : les deux barres suivent
	for i = 1, 2 do
		local f = (i == 1) and t or fo
		local ok = false
		if i == 1 then ok = (guid == M.targetGuid and M.cfg.target and f) else ok = (guid == M.focusGuid and M.cfg.focus and f) end
		if ok then
			if kind == "start" or kind == "channel" then
				if not (f.active and f.spellId == spellId and abs(now - f.t0) < 0.3) then
					local name, tex = M.SpellData(spellId)
					M.Start(f, name or "", tex, now, now + (tonumber(ms) or 0) / 1000, kind == "channel", spellId)
				end
			elseif kind == "cast" then
				if f.active and not f.chan then M.Finish(f, true) end
			elseif kind == "fail" then
				if f.active then M.Finish(f, false, L("msg.castbar.interrupted")) end
			end
		end
	end
end

function M.OnCastEvent(ev, a1, a2, a3, a4)
	-- UNIT_CASTEVENT : a1 lanceur, a2 cible, a3 type, a4 sort ; la duree est le 5e argument (global arg5)
	if a1 == M.targetGuid or a1 == M.focusGuid then
		if a3 == "START" then M.OtherCast(a1, "start", a4, getglobal("arg5"))
		elseif a3 == "CHANNEL" then M.OtherCast(a1, "channel", a4, getglobal("arg5"))
		elseif a3 == "CAST" then M.OtherCast(a1, "cast", a4, 0)
		elseif a3 == "FAIL" then M.OtherCast(a1, "fail", a4, 0)
		end
	end
end

function M.OnNampower(ev, a1, a2, a3)
	if not M.cfg.np then return end
	if ev == "SPELL_START_OTHER" then
		-- (objet, sort, lanceur, cible, drapeaux, tempsIncantation, duree, type) : type 1 = canalisation
		local caster = a3
		if caster ~= M.targetGuid and caster ~= M.focusGuid then return end
		local stype = tonumber(getglobal("arg8")) or 0
		if stype == 1 then M.OtherCast(caster, "channel", a2, getglobal("arg7")) else M.OtherCast(caster, "start", a2, getglobal("arg6")) end
	elseif ev == "SPELL_GO_OTHER" then
		if a3 == M.targetGuid or a3 == M.focusGuid then M.OtherCast(a3, "cast", a2, 0) end
	elseif ev == "SPELL_FAILED_OTHER" then
		if a1 == M.targetGuid or a1 == M.focusGuid then M.OtherCast(a1, "fail", a2, 0) end
	end
end

-- ---------------------------------------------------------------- cible et focus : qui suit-on ?
function M.OnTarget()
	local g = nil
	if UnitExists("target") then g = SUI.Target.GUID("target") end
	M.targetGuid = g
	local f = M.bars.target
	if f then
		f.guid = g
		if f.active or f.fadeAt then M.Hide(f) end
	end
end

function M.SetFocus()
	if not UnitExists("target") then
		SUI.Print(L("msg.castbar.nofocus"))
		return false
	end
	local g = SUI.Target.GUID("target")
	if not g then
		SUI.Print(L("msg.castbar.needguid"))
		return false
	end
	M.focusGuid = g
	M.focusName = UnitName("target")
	local f = M.bars.focus
	if f then
		f.guid = g
		if f.active or f.fadeAt then M.Hide(f) end
	end
	SUI.Print(L("msg.castbar.focusset", M.focusName or "?"))
	return true
end

function M.ClearFocus()
	M.focusGuid, M.focusName = nil, nil
	local f = M.bars.focus
	if f then
		f.guid = nil
		M.Hide(f)
	end
	SUI.Print(L("msg.castbar.focuscleared"))
end

-- Demonstration (placement des barres, essai de style) : une incantation fictive sur chaque barre.
function M.Test()
	if not M.built then SUI.Print(L("msg.castbar.notready")) return end
	local now = GetTime()
	local ic = M.icons["?"] or TESTICON
	if not visAllowed() then SUI.Print(L("msg.castbar.hidden")) end
	for i = 1, 3 do
		local f = M.bars[NAMES[i]]
		if f then M.Start(f, L("msg.castbar.test"), ic, now, now + 3, (i == 3), nil) end
	end
end

-- ---------------------------------------------------------------- construction (hors combat)
function M.BuildBar(key, defX, defY)
	local f = CreateFrame("Frame", "ShikiUI_CastBar_" .. key, UIParent)
	f.key = key
	f:SetWidth(220)
	f:SetHeight(16)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.sb = T.Bar(f)
	f.nameFs = T.Text(f.sb, 10, T.c.text, "LEFT", true)
	f.timeFs = T.Text(f.sb, 10, T.c.text, "RIGHT", true)
	if SUI.Look then
		SUI.Look.ApplyText(f.nameFs, "castbar", 10, true)    -- police et taille : castbar.font / castbar.fontsize
		SUI.Look.ApplyText(f.timeFs, "castbar", 10, true)
	end
	f.lag = f.sb:CreateTexture(nil, "OVERLAY")
	f.lag:SetTexture(T.tex.white)
	f.lag:SetVertexColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.5)
	f.lag:Hide()
	f.spark = f.sb:CreateTexture(nil, "OVERLAY")
	f.spark:SetTexture(T.tex.white)
	f.spark:SetWidth(2)
	f.spark:SetVertexColor(T.c.text[1], T.c.text[2], T.c.text[3], 0.9)
	f.spark:Hide()
	f.active, f.chan, f.failed = false, false, false
	f.sbw = 100
	f:Hide()
	M.bars[key] = f
	SUI.Layout.Register(f, "castbar." .. key, "CENTER", defX, defY)
	return f
end

function M.Build()
	if M.built then return end
	M.BuildBar("player", 0, -220)
	M.BuildBar("target", 0, -250)
	M.BuildBar("focus", 0, -280)
	M.built = true
	M.ApplyOptions()
end

-- Applique les reglages a la geometrie des barres.
function M.ApplyOptions()
	if not M.built then return end
	local c = M.cfg
	for i = 1, 3 do
		local f = M.bars[NAMES[i]]
		local w = (i == 1) and c.width or c.owidth
		local h = c.height
		f:SetWidth(w)
		f:SetHeight(h)
		local iconW = 0
		f.icon:ClearAllPoints()
		if c.icon then
			iconW = h - 2
			f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
			f.icon:SetWidth(iconW)
			f.icon:SetHeight(iconW)
		end
		-- barre ancree par UN point + taille explicite (et non deux coins) : la forme "fine" peut alors changer sa hauteur, centree
		f.sbw = w - 2 - iconW - (c.icon and 1 or 0)
		f.sb:ClearAllPoints()
		f.sb:SetPoint("LEFT", f, "LEFT", 1 + iconW + (c.icon and 1 or 0), 0)
		f.sb:SetWidth(f.sbw)
		f.sb:SetHeight(h - 2)
		if SUI.Look then SUI.Look.ApplyBar(f.sb, "castbar", { height = h - 2, thin = 4, segments = 10 }) end
		f.spark:SetHeight(h + 4)
		f.nameFs:ClearAllPoints()
		f.nameFs:SetPoint("LEFT", f.sb, "LEFT", 3, 0)
		-- le nom ne passe jamais sous le temps restant (barres etroites, noms de sorts longs)
		local nw = f.sbw - 6 - (c.timer and 38 or 0)
		if nw < 10 then nw = 10 end
		f.nameFs:SetWidth(nw)
		f.nameFs:SetHeight(12)
		f.timeFs:ClearAllPoints()
		f.timeFs:SetPoint("RIGHT", f.sb, "RIGHT", -3, 0)
		f.sparkX = nil
		-- une incantation en cours (ou l'essai) reflete tout de suite les reglages d'apparence
		M.ShowIcon(f)
		if not c.timer then setTimer(f, "") end
		if f.active then
			setName(f, c.name and f.nameTxt or "")
			if c.spark then f.spark:Show() else f.spark:Hide() end
			f.sparkX = nil
			f.visA = visMul()
			f:SetAlpha(c.alpha * f.visA)
			if not c.lag then f.lag:Hide() end
			setColor(f, f.chan and "channel" or "cast")
			f.lastV = nil
			M.Update(f, GetTime())
		elseif not c.name and not f.failed then
			setName(f, "")
		end
		if i == 2 then f.enabledKey = c.target elseif i == 3 then f.enabledKey = c.focus else f.enabledKey = c.player end
		if not f.enabledKey and (f.active or f.fadeAt) then M.Hide(f) end
	end
	M.HideBlizzard()
end

-- ---------------------------------------------------------------- barre de Blizzard
function M.HideBlizzard()
	local cbf = getglobal("CastingBarFrame")
	if not cbf then return end
	local want = M.on and M.cfg.player and C.Get("castbar.hideblizz")
	if want and SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("castbar") then want = false end
	if want and not M.blizzHidden then
		M.blizzHidden = true
		M.origOnShow = cbf:GetScript("OnShow")
		cbf:UnregisterAllEvents()
		cbf:SetScript("OnShow", function() this:Hide() end)
		cbf:Hide()
	elseif (not want) and M.blizzHidden then
		M.blizzHidden = false
		for i = 1, getn(BLIZZ_EVENTS) do cbf:RegisterEvent(BLIZZ_EVENTS[i]) end
		cbf:SetScript("OnShow", M.origOnShow)
	end
end

-- ---------------------------------------------------------------- cycle de vie
-- Applique le choix dessus / dessous : (re)ecrit les liens conseilles explicites vers les cadres joueur et cible.
-- Dessous = defaut du moteur (lien conseille, sans entree) ; dessus = lien explicite TOP. Detachable a tout moment
-- via le Mover (Accroche a -> Detacher).
local function relinkSide(side)
	local L = SUI.Layout
	if not (L and L.WriteLink and L.items and L.items["unit.player"] and L.items["unit.target"]) then return end
	local s = (side == "over") and "TOP" or "BOTTOM"
	if L.ResetLink then
		L.ResetLink("castbar.player")
		L.ResetLink("castbar.target")
	end
	local gx, gy = L.GapOffsets(s)
	L.WriteLink("castbar.player", "unit.player", s, gx, gy)
	L.WriteLink("castbar.target", "unit.target", s, gx, gy)
end

function M.OnKey(key, value)
	if key == "castbar.side" then relinkSide(value) end
	M.ReadConfig()
	M.ApplyOptions()
end

function M.OnRegen()
	if M.bookPending then M.ScanBook() end
end

function M.Activate()
	if M.active then return end
	M.active = true
	for i = 1, getn(BLIZZ_EVENTS) do SUI.On(BLIZZ_EVENTS[i], M.OnPlayerEvent) end
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("LEARNED_SPELL_IN_TAB", M.ScanBook)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnTarget)
	if SUI.Api.superwow then SUI.On("UNIT_CASTEVENT", M.OnCastEvent) end
	if SUI.Api.nampower then
		SUI.On("SPELL_START_OTHER", M.OnNampower)
		SUI.On("SPELL_GO_OTHER", M.OnNampower)
		SUI.On("SPELL_FAILED_OTHER", M.OnNampower)
	end
	M.task = SUI.Every(TICK, M.Tick, "castbar.tick", true)
	M.OnTarget()
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	for i = 1, getn(BLIZZ_EVENTS) do SUI.Off(BLIZZ_EVENTS[i], M.OnPlayerEvent) end
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("LEARNED_SPELL_IN_TAB", M.ScanBook)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnTarget)
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Off("SPELL_START_OTHER", M.OnNampower)
	SUI.Off("SPELL_GO_OTHER", M.OnNampower)
	SUI.Off("SPELL_FAILED_OTHER", M.OnNampower)
	SUI.Cancel(M.task)
	M.task = nil
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	if not M.watching then
		M.watching = true
		C.Watch("castbar.", M.OnKey)
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.ScanBook()
		M.Activate()
		M.ApplyOptions()
		M.AttachVisibility()       -- idempotent : repose le cadre mandataire apres une coupure
	end)
end

function M.Disable()
	M.on = false
	M.Deactivate()
	M.DetachVisibility()
	if M.built then
		for i = 1, 3 do M.Hide(M.bars[NAMES[i]]) end
	end
	M.HideBlizzard()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("castbar", 25)

local function opt(key, typ, order, def, extra)
	local o = { key = "castbar." .. key, type = typ, cat = "castbar", label = "opt.castbar." .. key, tip = "tip.castbar." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local CB_OPTIONS = {
		opt("player", "bool", 10, true, { simple = true }),
		opt("target", "bool", 20, true, { simple = true }),
		opt("focus", "bool", 30, true, { simple = true }),
		opt("side", "choice", 35, "under", { choices = { "under", "over" }, simple = true }),
		opt("width", "number", 40, 220, { min = 100, max = 400, step = 10, simple = true }),
		opt("owidth", "number", 50, 180, { min = 80, max = 300, step = 10 }),
		opt("height", "number", 60, 16, { min = 8, max = 32, step = 1, simple = true }),
		opt("icon", "bool", 70, true),
		opt("name", "bool", 80, true),
		opt("timer", "bool", 90, true, { simple = true }),
		opt("decimals", "number", 100, 1, { min = 0, max = 2, step = 1 }),
		opt("lag", "bool", 110, true),
		opt("spark", "bool", 120, true),
		opt("channeldir", "choice", 130, "drain", { choices = { "drain", "fill" } }),
		opt("fade", "number", 140, 0.5, { min = 0, max = 2, step = 0.1 }),
		opt("alpha", "number", 150, 1, { min = 0.3, max = 1, step = 0.1 }),
		opt("failtext", "bool", 160, true),
		opt("classcolor", "bool", 170, false),
		opt("np", "bool", 180, true),
		opt("hideblizz", "bool", 190, true, { reload = true }),
}
-- Options communes du socle : visibilite (castbar.cond.vis / .fade : "castbar.fade" existe deja, c'est le fondu de fin d'incantation) et
-- aspect (texture, forme, police, taille du texte).
local function addAll(list)
	for i = 1, getn(list) do table.insert(CB_OPTIONS, list[i]) end
end
if SUI.Visibility then addAll(SUI.Visibility.Options("castbar.cond", { cat = "castbar", order = 800 })) end
if SUI.Look then addAll(SUI.Look.Options("castbar", { bar = true, shape = true, font = true, cat = "castbar", order = 820 })) end

-- Adaptation de taille (Mover, bouton "Accrocher + taille") : la castbar epouse la largeur du cadre
-- joueur ou cible auquel elle est accrochee (castbar.width pour le joueur, castbar.owidth pour la cible).
local function fitWidthTo(parentKey)
	local it = SUI.Layout and SUI.Layout.items and SUI.Layout.items[parentKey]
	if not it or not it.frame or not it.frame.GetWidth then return false end
	local w = it.frame:GetWidth()
	if not w or w < 60 then return false end
	w = floor(w + 0.5)
	if parentKey == "unit.player" then
		C.Set("castbar.width", w)
	elseif parentKey == "unit.target" then
		C.Set("castbar.owidth", w)
	else
		return false
	end
	return true
end
if SUI.Mover and SUI.Mover.RegisterSizeFit then
	SUI.Mover.RegisterSizeFit("castbar.player", function(pk) return fitWidthTo(pk) end)
	SUI.Mover.RegisterSizeFit("castbar.target", function(pk) return fitWidthTo(pk) end)
end

SUI.RegisterModule("castbar", {
	default = false,
	cost = "medium",
	options = CB_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : le module "castbar".
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.castbar then SUI.Migrate.MAP.castbar = { "castbar" } end

-- Mode Raid : moins de decimales, pas d'etincelle (moins de mises a jour de position).
SUI.Config.AddPreset("raid", "*", { ["castbar.decimals"] = 0, ["castbar.spark"] = false })

SUI.RegisterCommand("castbar", function(rest)
	if rest == "focus" then
		M.SetFocus()
	elseif rest == "clearfocus" then
		M.ClearFocus()
	elseif rest == "test" then
		M.Test()
	else
		SUI.Print(L("msg.castbar.info", M.nActive, M.focusName or "-", SUI.Api.superwow and "SuperWoW" or (SUI.Api.nampower and "Nampower" or "1.12")))
	end
end, "help.castbar")
