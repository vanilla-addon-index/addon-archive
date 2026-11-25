-- ShikiUI Bind : mode RACCOURCIS generalise (/sui bind, boutons "Raccourcis" du menu). Survole un bouton d'action / d'objet / de macro / de sort du
-- grimoire (barres ShikiUI, barres Blizzard, sacs), appuie sur une touche : le raccourci est pose. Echap ou clic droit sur le bouton = effacer ;
-- conflit = question (Remplacer / Garder l'ancien / Annuler) ; annuler / retablir pendant la session ; SaveBindings seulement a la sortie ;
-- interdit en combat (sortie automatique si le combat commence). Un module declare ses boutons avec SUI.Bind.AddResolver(fn(frame) -> cmd, label).
-- Perf : la seule minuterie (0,1 s, survol) n'existe que pendant le mode.
-- AUDIT "certaines touches ne marchent pas" : (1) Echap sur un bouton survole = effacer, mais le client ferme AUSSI le bandeau (UISpecialFrames) donc le
--  mode se terminait : le bandeau est maintenant rouvert tant qu'un bouton est survole / une question ouverte ; (2) molette et boutons 4 / 5 : seule la
--  plaque de survol les voit (molette ajoutee) ; (3) touches que Windows / le client ne transmettent jamais (Alt-F4, Alt-Tab...) : refusees avec un
--  message ; (4) aucun bouton survole : un message le dit au lieu de ne rien faire ; (5) rien n'etait enregistre si on quittait le jeu / rechargeait
--  l'interface sans cliquer "Terminer" : enregistrement a PLAYER_LOGOUT. /sui bind check liste les liaisons mortes (bouton / sort / macro disparus,
--  module coupe) et les avertissements ; /sui bind clean retire les mortes. Les liaisons sont celles du CLIENT (jeu compte ou personnage) : ShikiUI ne
--  les change jamais en dehors de ce mode, ni au changement de profil ni de specialisation.
-- NON VERIFIE EN JEU : GetMouseFocus, EnableKeyboard (les touches sont-elles consommees ?), SetBinding / GetBindingAction / SaveBindings /
-- GetCurrentBindingSet, les noms de commandes MULTIACTIONBARnBUTTON / SHAPESHIFTBUTTON / BONUSACTIONBUTTON des barres Blizzard, et les commandes
-- "SPELL <nom>" / "MACRO <nom>" / "ITEM <nom>" (la pose est verifiee par GetBindingAction : si le client les refuse, un message le dit).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert

local M = {}
SUI.Bind = M

M.active = false
M.resolvers = {}
M.watchers = {}
M.ops = {}          -- historique : liste de lots { { key, old, new }, ... }
M.n = 0             -- nombre de lots appliques (le reste est retablissable)
M.MODKEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
M.MOUSEKEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
-- Combinaisons que Windows ou le client gardent pour eux : elles n'arrivent jamais aux raccourcis (ordre des modificateurs : ALT-CTRL-SHIFT-).
M.OSKEYS = { ["ALT-F4"] = true, ["ALT-TAB"] = true, ["ALT-CTRL-DELETE"] = true, ["ALT-ESCAPE"] = true, ["CTRL-ESCAPE"] = true,
	["ALT-SPACE"] = true, ["ALT-CTRL-ESCAPE"] = true }
M.MULTI = { MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON", MultiBarBottomRightButton = "MULTIACTIONBAR2BUTTON",
	MultiBarRightButton = "MULTIACTIONBAR3BUTTON", MultiBarLeftButton = "MULTIACTIONBAR4BUTTON" }

function M.AddResolver(fn)
	if type(fn) == "function" then tinsert(M.resolvers, fn) end
end

-- fn(on) est appelee quand le mode s'ouvre ou se ferme.
function M.Watch(fn)
	if type(fn) == "function" then tinsert(M.watchers, fn) end
end

local function notify(on)
	for i = 1, getn(M.watchers) do
		local ok, err = pcall(M.watchers[i], on)
		if not ok then SUI.Report("bind watch", err) end
	end
end

-- ---------------------------------------------------------------- reconnaissance des boutons
local function bindingName(cmd)
	local s = getglobal("BINDING_NAME_" .. cmd)
	if type(s) == "string" and s ~= "" then return s end
	return cmd
end

local function itemName(link)
	if type(link) ~= "string" then return nil end
	local _, _, name = string.find(link, "%[(.-)%]")
	return name
end

-- Boutons Blizzard et des fenetres du jeu (d'apres leur nom). Retourne cmd, libelle ou nil.
function M.Builtin(f)
	local name = f.GetName and f:GetName()
	if type(name) ~= "string" then
		-- boutons de sac ShikiUI (champs bag / slot poses par Mod_Bags)
		if f.bag ~= nil and f.slot ~= nil and f.win ~= nil and getglobal("GetContainerItemLink") then
			local n = itemName(getglobal("GetContainerItemLink")(f.bag, f.slot))
			if n then return "ITEM " .. n, n end
		end
		return nil
	end
	local _, _, n = string.find(name, "^ActionButton(%d+)$")
	if n then return "ACTIONBUTTON" .. n, bindingName("ACTIONBUTTON" .. n) end
	_, _, n = string.find(name, "^ShapeshiftButton(%d+)$")
	if n then return "SHAPESHIFTBUTTON" .. n, bindingName("SHAPESHIFTBUTTON" .. n) end
	_, _, n = string.find(name, "^PetActionButton(%d+)$")
	if n then return "BONUSACTIONBUTTON" .. n, bindingName("BONUSACTIONBUTTON" .. n) end
	for prefix, cmd in pairs(M.MULTI) do
		_, _, n = string.find(name, "^" .. prefix .. "(%d+)$")
		if n then return cmd .. n, bindingName(cmd .. n) end
	end
	-- grimoire : SpellButton1..12 -> nom du sort
	_, _, n = string.find(name, "^SpellButton(%d+)$")
	if n and getglobal("GetSpellName") and f.GetID then
		local sb = getglobal("SpellBookFrame")
		local pet = getglobal("BOOKTYPE_PET")
		if pet and sb and sb.bookType == pet then return nil end      -- sorts du familier : pas de commande "SPELL nom"
		local id = f:GetID()
		local conv = getglobal("SpellBook_GetSpellID")
		if conv then id = conv(id) end
		local sname = getglobal("GetSpellName")(id, getglobal("BOOKTYPE_SPELL") or "spell")
		if sname then return "SPELL " .. sname, sname end
		return nil
	end
	-- macros : MacroButton1..18
	_, _, n = string.find(name, "^MacroButton(%d+)$")
	if n and getglobal("GetMacroInfo") and f.GetID then
		local base = 0
		local mf = getglobal("MacroFrame")
		if mf and mf.macroBase then base = mf.macroBase end
		local mname = getglobal("GetMacroInfo")(f:GetID() + base)
		if mname then return "MACRO " .. mname, mname end
		return nil
	end
	-- banque : BankFrameItemN (sac -1)
	_, _, n = string.find(name, "^BankFrameItem(%d+)$")
	if n and getglobal("GetContainerItemLink") then
		local bname = itemName(getglobal("GetContainerItemLink")(-1, tonumber(n)))
		if bname then return "ITEM " .. bname, bname end
		return nil
	end
	-- sacs du jeu : ContainerFrameNItemM
	if string.find(name, "^ContainerFrame%d+Item%d+$") and getglobal("GetContainerItemLink") and f.GetParent then
		local p = f:GetParent()
		if p and p.GetID then
			local iname = itemName(getglobal("GetContainerItemLink")(p:GetID(), f:GetID()))
			if iname then return "ITEM " .. iname, iname end
		end
	end
	return nil
end

-- Remonte jusqu'a 3 parents a la recherche d'un bouton reconnu. Retourne cmd, libelle, cadre.
function M.Resolve(frame)
	local f = frame
	for depth = 1, 3 do
		if not f or f == M.plate then return nil end
		for i = 1, getn(M.resolvers) do
			local ok, cmd, label = pcall(M.resolvers[i], f)
			if ok and cmd then return cmd, label or bindingName(cmd), f end
		end
		local cmd, label = M.Builtin(f)
		if cmd then return cmd, label, f end
		f = f.GetParent and f:GetParent() or nil
	end
	return nil
end

-- ---------------------------------------------------------------- touches et historique
local function curAction(key)
	local a = GetBindingAction(key)
	if a == "" then a = nil end
	return a
end

function M.KeyName(key)
	local p = ""
	if IsAltKeyDown() then p = p .. "ALT-" end
	if IsControlKeyDown() then p = p .. "CTRL-" end
	if IsShiftKeyDown() then p = p .. "SHIFT-" end
	return p .. key
end

-- Applique SetBinding(key, cmd) (cmd nil = effacer) et le note dans le lot ops.
local function setKey(ops, key, cmd)
	local old = curAction(key)
	SetBinding(key, cmd)
	tinsert(ops, { key, old, cmd })
end

local function push(ops)
	if getn(ops) == 0 then return end
	for i = getn(M.ops), M.n + 1, -1 do table.remove(M.ops, i) end      -- une nouvelle action annule le "retablir"
	tinsert(M.ops, ops)
	M.n = getn(M.ops)
end

function M.Count()
	return M.n
end

-- Pose key sur cmd (retire d'abord la plus ancienne des deux touches si cmd en a deja deux).
function M.DoBind(key, cmd)
	local ops = {}
	local k1, k2 = GetBindingKey(cmd)
	if k1 and k2 then setKey(ops, k1, nil) end
	setKey(ops, key, cmd)
	if curAction(key) ~= cmd then
		-- le client a refuse (commande inconnue ?) : on remet tout comme avant
		for i = getn(ops), 1, -1 do SetBinding(ops[i][1], ops[i][2]) end
		SUI.Print(L("msg.bind.refused", key, bindingName(cmd)))
		return false
	end
	push(ops)
	SUI.Print(L("msg.bind.bound", key, bindingName(cmd)))
	M.Update()
	return true
end

function M.ClearCmd(cmd)
	local ops = {}
	local k1, k2 = GetBindingKey(cmd)
	if k1 then setKey(ops, k1, nil) end
	if k2 then setKey(ops, k2, nil) end
	if getn(ops) == 0 then return false end
	push(ops)
	SUI.Print(L("msg.bind.cleared", bindingName(cmd)))
	M.Update()
	return true
end

function M.Undo()
	if M.n < 1 then return false end
	local ops = M.ops[M.n]
	for i = getn(ops), 1, -1 do SetBinding(ops[i][1], ops[i][2]) end
	M.n = M.n - 1
	M.Update()
	return true
end

function M.Redo()
	if M.n >= getn(M.ops) then return false end
	M.n = M.n + 1
	local ops = M.ops[M.n]
	for i = 1, getn(ops) do SetBinding(ops[i][1], ops[i][3]) end
	M.Update()
	return true
end

-- Une touche est pressee sur la cible survolee.
function M.Press(key)
	local cmd = M.cmd
	if not M.active or not cmd or M.ask then return false end
	if M.OSKEYS[key] then
		SUI.Print(L("msg.bind.oskey", key))
		return false
	end
	local existing = curAction(key)
	if existing == cmd then
		SUI.Print(L("msg.bind.same", key))
		return false
	end
	if existing then
		M.AskConflict(key, existing, cmd)
		return false
	end
	return M.DoBind(key, cmd)
end

-- ---------------------------------------------------------------- interface (plaque de survol, bandeau, question de conflit)
function M.Update()
	local bn = M.banner
	if not bn then return end
	bn.count:SetText(L("mod.bind.count", M.n))
	local cmd = M.cmd
	if cmd and M.plate and M.plate:IsShown() then M.ShowPlate(M.target, cmd, M.label) end
end

function M.ShowPlate(target, cmd, label)
	local p = M.plate
	M.target, M.cmd, M.label = target, cmd, label
	p:ClearAllPoints()
	p:SetAllPoints(target)
	local k1, k2 = GetBindingKey(cmd)
	local keys = k1 or L("mod.bind.none")
	if k2 then keys = keys .. ", " .. k2 end
	p.text:SetText(label .. "\n" .. keys)
	local r, g, b = T.Accent()
	p:SetBackdropBorderColor(r, g, b, 1)
	p:Show()
end

function M.NoTarget()
	M.target, M.cmd, M.label = nil, nil, nil
	if M.plate and M.plate:IsShown() then M.plate:Hide() end
end

function M.Poll()
	if not M.active or M.ask then return end
	local f = GetMouseFocus()
	if f == M.plate then return end
	local cmd, label, target = M.Resolve(f)
	if cmd then
		if target ~= M.target or cmd ~= M.cmd then M.ShowPlate(target, cmd, label) end
	else
		M.NoTarget()
	end
end

function M.AskConflict(key, existing, cmd)
	local q = M.question
	M.ask = { key = key, cmd = cmd }
	q.text:SetText(L("msg.bind.conflict", key, bindingName(existing), bindingName(cmd)))
	q:Show()
end

function M.AnswerConflict(what)
	local a = M.ask
	M.ask = nil
	M.question:Hide()
	if not a then return end
	if what == "replace" then
		M.DoBind(a.key, a.cmd)
	elseif what == "keep" then
		SUI.Print(L("msg.bind.kept", a.key))
	end
end

local function plateDown()
	local b = arg1
	if b == "RightButton" then
		if M.cmd then M.ClearCmd(M.cmd) end
	elseif M.MOUSEKEYS[b] then
		M.Press(M.KeyName(M.MOUSEKEYS[b]))
	end
end

-- Molette sur la plaque : MOUSEWHEELUP / MOUSEWHEELDOWN (avec Maj / Ctrl / Alt).
local function plateWheel()
	local d = arg1
	if not d or d == 0 then return end
	M.Press(M.KeyName(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
end

-- Le client ferme le bandeau avec Echap (UISpecialFrames) EN PLUS de notre OnKeyDown : si un bouton est survole ou une question ouverte, Echap
-- veut dire "effacer" / "annuler", pas "terminer" : on fait ce geste (si OnKeyDown ne l'a pas deja fait) puis on rouvre le bandeau.
function M.EscAction()
	M.escAt = GetTime()
	if M.ask then
		M.AnswerConflict("cancel")
	elseif M.cmd then
		M.ClearCmd(M.cmd)
	end
end

function M.Reopen()
	if M.active and M.banner and not M.banner:IsShown() then M.banner:Show() end
end

function M.OnBannerHide()
	if not M.active or M.closing then return end
	local recent = M.escAt and GetTime() - M.escAt < 0.5
	M.escAt = nil
	if recent or M.ask or M.cmd then
		if not recent then
			M.EscAction()
			M.escAt = nil
		end
		SUI.After(0.05, M.Reopen, "bind.reopen")
		return
	end
	M.Exit(true)
end

function M.OnKeyDown()
	local k = arg1
	if not k or M.MODKEYS[k] then return end
	if M.ask then
		if k == "ESCAPE" then M.EscAction() end
		return
	end
	if k == "ESCAPE" then
		if M.cmd then M.EscAction() else M.Exit(true) end
		return
	end
	if not M.cmd then
		local now = GetTime()
		if not M.hintAt or now - M.hintAt > 3 then
			M.hintAt = now
			SUI.Print(L("msg.bind.nobutton"))
		end
		return
	end
	M.Press(M.KeyName(k))
end

-- Deconnexion / rechargement de l'interface pendant le mode : ce qui a ete pose est enregistre (sinon perdu au /reload).
function M.OnLogout()
	if M.active and M.n > 0 then SaveBindings(GetCurrentBindingSet()) end
end

function M.OnCombat()
	if M.active then
		SUI.Print(L("msg.bind.combatexit"))
		M.Exit(true)
	end
end

-- Infobulle d'un bouton du bandeau (garde l'effet de survol du Theme).
function M.Tip(b, key)
	local oldIn, oldOut = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	b:SetScript("OnEnter", function()
		if oldIn then oldIn() end
		local g = getglobal("GameTooltip")
		if g then
			g:SetOwner(this, "ANCHOR_BOTTOM")
			g:SetText(L(key), nil, nil, nil, nil, 1)
			g:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		if oldOut then oldOut() end
		local g = getglobal("GameTooltip")
		if g then g:Hide() end
	end)
end

function M.Build()
	if M.keys then return end
	local k = CreateFrame("Frame", "ShikiUI_BindKeys", UIParent)
	M.keys = k
	k:SetWidth(1)
	k:SetHeight(1)
	k:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	k:EnableKeyboard(true)
	k:SetScript("OnKeyDown", M.OnKeyDown)
	k:Hide()
	local p = CreateFrame("Button", "ShikiUI_BindPlate", UIParent)
	M.plate = p
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:EnableMouse(true)
	p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	T.Backdrop(p, T.c.bg, T.c.border)
	p:SetBackdropColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 0.8)
	p.text = T.Text(p, 10, T.c.text, "CENTER", true)
	p.text:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.text:SetWidth(120)
	p.text:SetHeight(28)
	p:SetScript("OnMouseDown", plateDown)
	p:EnableMouseWheel(true)
	p:SetScript("OnMouseWheel", plateWheel)
	p:Hide()
	local bn = CreateFrame("Frame", "ShikiUI_BindBanner", UIParent)
	M.banner = bn
	bn:SetWidth(760)
	bn:SetHeight(86)
	bn:SetFrameStrata("FULLSCREEN_DIALOG")
	bn:SetPoint("TOP", UIParent, "TOP", 0, -8)
	bn:EnableMouse(true)
	T.Backdrop(bn, T.c.bg, T.c.border)
	bn.title = T.Text(bn, 14, T.c.text, "LEFT")
	bn.title:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -8)
	bn.title:SetWidth(300)
	bn.title:SetHeight(18)
	bn.count = T.Text(bn, 10, T.c.dim, "RIGHT")
	bn.count:SetPoint("TOPRIGHT", bn, "TOPRIGHT", -12, -10)
	bn.count:SetWidth(200)
	bn.count:SetHeight(14)
	bn.hint = T.Text(bn, 10, T.c.dim, "LEFT")
	bn.hint:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -58)
	bn.hint:SetWidth(736)
	bn.hint:SetHeight(26)
	bn.hint:SetJustifyV("TOP")
	bn.done = T.Button(bn, "", 150, 22, function() M.Exit(true) end)
	bn.done:SetPoint("TOPLEFT", bn, "TOPLEFT", 12, -30)
	bn.undo = T.Button(bn, "", 120, 22, function() M.Undo() end)
	bn.undo:SetPoint("LEFT", bn.done, "RIGHT", 6, 0)
	bn.redo = T.Button(bn, "", 110, 22, function() M.Redo() end)
	bn.redo:SetPoint("LEFT", bn.undo, "RIGHT", 6, 0)
	bn.abort = T.Button(bn, "", 150, 22, function() M.Exit(false) end)
	bn.abort:SetPoint("LEFT", bn.redo, "RIGHT", 6, 0)
	bn.check = T.Button(bn, "", 130, 22, function() M.Check() end)
	bn.check:SetPoint("LEFT", bn.abort, "RIGHT", 6, 0)
	M.Tip(bn.done, "tip.bind.done")
	M.Tip(bn.undo, "tip.bind.undo")
	M.Tip(bn.redo, "tip.bind.redo")
	M.Tip(bn.abort, "tip.bind.abort")
	M.Tip(bn.check, "tip.bind.check")
	bn:SetScript("OnHide", M.OnBannerHide)
	bn:Hide()
	tinsert(UISpecialFrames, "ShikiUI_BindBanner")
	local q = CreateFrame("Frame", "ShikiUI_BindAsk", UIParent)
	M.question = q
	q:SetWidth(420)
	q:SetHeight(100)
	q:SetFrameStrata("FULLSCREEN_DIALOG")
	q:SetFrameLevel(bn:GetFrameLevel() + 20)
	q:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	q:EnableMouse(true)
	T.Backdrop(q, T.c.bg, T.c.border)
	q.text = T.Text(q, 12, T.c.text, "LEFT")
	q.text:SetPoint("TOPLEFT", q, "TOPLEFT", 14, -12)
	q.text:SetWidth(392)
	q.text:SetHeight(44)
	q.text:SetJustifyV("TOP")
	q.replace = T.Button(q, "", 120, 22, function() M.AnswerConflict("replace") end)
	q.replace:SetPoint("BOTTOMLEFT", q, "BOTTOMLEFT", 14, 12)
	q.keep = T.Button(q, "", 140, 22, function() M.AnswerConflict("keep") end)
	q.keep:SetPoint("LEFT", q.replace, "RIGHT", 6, 0)
	q.cancel = T.Button(q, "", 100, 22, function() M.AnswerConflict("cancel") end)
	q.cancel:SetPoint("LEFT", q.keep, "RIGHT", 6, 0)
	q:Hide()
end

function M.Translate()
	local bn = M.banner
	if not bn then return end
	bn.title:SetText(L("mod.bind.title"))
	bn.hint:SetText(L("mod.bind.hint"))
	T.SetButtonText(bn.done, L("mod.bind.done"))
	T.SetButtonText(bn.undo, L("mod.bind.undo"))
	T.SetButtonText(bn.redo, L("mod.bind.redo"))
	T.SetButtonText(bn.abort, L("mod.bind.abort"))
	T.SetButtonText(bn.check, L("mod.bind.check"))
	T.SetButtonText(M.question.replace, L("mod.bind.replace"))
	T.SetButtonText(M.question.keep, L("mod.bind.keep"))
	T.SetButtonText(M.question.cancel, L("mod.bind.cancel"))
end

-- ---------------------------------------------------------------- verification (/sui bind check | clean)
-- Releve toutes les liaisons : GetNumBindings / GetBinding quand le client les donne, plus un balayage des touches usuelles (avec leurs
-- modificateurs) par GetBindingAction. Une liaison est MORTE quand ce qu'elle appelle n'existe plus (bouton CLICK, sort, macro) ; AVERTISSEMENT
-- pour le reste (objet absent des sacs, commande inconnue, touche que Windows garde, Alt = lancer sur soi). Rien n'est modifie par "check".
local MODS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local SPECIAL = { "SPACE", "TAB", "ENTER", "BACKSPACE", "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT",
	"NUMPADPLUS", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADDIVIDE", "NUMPADDECIMAL", "BUTTON3", "BUTTON4", "BUTTON5", "MOUSEWHEELUP",
	"MOUSEWHEELDOWN", "`", "-", "=", "[", "]", ";", ",", ".", "/" }

local function baseKeys()
	if M.base then return M.base end
	local b = {}
	for i = 0, 25 do tinsert(b, string.char(65 + i)) end
	for i = 0, 9 do
		tinsert(b, tostring(i))
		tinsert(b, "NUMPAD" .. i)
	end
	for i = 1, 12 do tinsert(b, "F" .. i) end
	for i = 1, getn(SPECIAL) do tinsert(b, SPECIAL[i]) end
	M.base = b
	return b
end

-- Retourne la liste { key, cmd } de toutes les liaisons connues, sans doublon de touche.
function M.Scan()
	local out, seen = {}, {}
	local function add(key, cmd)
		if type(key) == "string" and key ~= "" and type(cmd) == "string" and cmd ~= "" and not seen[key] then
			seen[key] = true
			tinsert(out, { key = key, cmd = cmd })
		end
	end
	local gnb, gb = getglobal("GetNumBindings"), getglobal("GetBinding")
	if type(gnb) == "function" and type(gb) == "function" then
		local ok, n = pcall(gnb)
		if ok and type(n) == "number" then
			for i = 1, n do
				local ok2, cmd, k1, k2 = pcall(gb, i)
				if ok2 and cmd then
					add(k1, cmd)
					add(k2, cmd)
				end
			end
		end
	end
	local base = baseKeys()
	for i = 1, getn(base) do
		for m = 1, getn(MODS) do
			local key = MODS[m] .. base[i]
			if not seen[key] then
				local a = curAction(key)
				if a then add(key, a) end
			end
		end
	end
	return out
end

local function lowerSetOf(names)
	local set = {}
	for i = 1, getn(names) do set[string.lower(names[i])] = true end
	return set
end

-- Noms des sorts du grimoire (nil si le client ne donne pas l'API : on ne juge pas).
local function spellNames()
	local gs, nt, ti = getglobal("GetSpellName"), getglobal("GetNumSpellTabs"), getglobal("GetSpellTabInfo")
	if not (gs and nt and ti) then return nil end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	local total = 0
	for t = 1, nt() do
		local _, _, off, num = ti(t)
		total = (off or 0) + (num or 0)
	end
	local names = {}
	for i = 1, total do
		local n = gs(i, book)
		if not n then break end
		tinsert(names, n)
	end
	return lowerSetOf(names)
end

local function macroNames()
	local gm = getglobal("GetMacroInfo")
	if not gm then return nil end
	local names = {}
	for i = 1, 36 do
		local n = gm(i)
		if n then tinsert(names, n) end
	end
	return lowerSetOf(names)
end

local function itemNames()
	local gl, gn = getglobal("GetContainerItemLink"), getglobal("GetContainerNumSlots")
	if not (gl and gn) then return nil end
	local names = {}
	for bag = 0, 4 do
		for slot = 1, gn(bag) or 0 do
			local n = itemName(gl(bag, slot))
			if n then tinsert(names, n) end
		end
	end
	local gi = getglobal("GetInventoryItemLink")
	if gi then
		for slot = 1, 19 do
			local n = itemName(gi("player", slot))
			if n then tinsert(names, n) end
		end
	end
	return lowerSetOf(names)
end

-- Commandes du jeu qui existent toujours, meme sans texte de binding : jamais "inconnues".
local function knownCommands()
	local k = {}
	for i = 1, 12 do
		k["ACTIONBUTTON" .. i] = true
		k["BONUSACTIONBUTTON" .. i] = true
		k["SHAPESHIFTBUTTON" .. i] = true
	end
	for bar = 1, 4 do
		for i = 1, 12 do k["MULTIACTIONBAR" .. bar .. "BUTTON" .. i] = true end
	end
	return k
end

-- Verdict sur une liaison : nil (saine) ou "dead" / "warn" + cle du motif (+ argument).
function M.Judge(key, cmd, ctx)
	if M.OSKEYS[key] then return "warn", "msg.bind.why.os" end
	local _, _, kind, rest = string.find(cmd, "^(%u+) (.+)$")
	if kind == "CLICK" then
		local _, _, fname = string.find(rest, "^(.-):")
		fname = fname or rest
		local fr = getglobal(fname)
		if type(fr) ~= "table" then return "dead", "msg.bind.why.noclick", fname end
		return nil
	elseif kind == "SPELL" then
		if ctx.spells then
			local _, _, base = string.find(rest, "^(.-)%s*%(")
			if not ctx.spells[string.lower(base or rest)] then return "dead", "msg.bind.why.nospell" end
		end
		return nil
	elseif kind == "MACRO" then
		if ctx.macros and not ctx.macros[string.lower(rest)] then return "dead", "msg.bind.why.nomacro" end
		return nil
	elseif kind == "ITEM" then
		if ctx.items and not ctx.items[string.lower(rest)] then return "warn", "msg.bind.why.noitem" end
		return nil
	end
	local g = getglobal("BINDING_NAME_" .. cmd)
	if not (type(g) == "string" and g ~= "") and not ctx.known[cmd] then return "warn", "msg.bind.why.unknown" end
	if ctx.selfcast and string.find(key, "ALT-", 1, true) and (string.find(cmd, "^ACTIONBUTTON") or string.find(cmd, "^MULTIACTIONBAR")) then
		return "warn", "msg.bind.why.selfcast"
	end
	return nil
end

-- Analyse complete : { total, dead = { { key, cmd, why, arg } }, warn = { ... }, set }.
function M.Analyse()
	local res = { total = 0, dead = {}, warn = {}, set = GetCurrentBindingSet and GetCurrentBindingSet() or 1 }
	local list = M.Scan()
	local ctx = { spells = spellNames(), macros = macroNames(), items = itemNames(), known = knownCommands() }
	local gc = getglobal("GetCVar")
	ctx.selfcast = (gc and gc("autoSelfCast") == "1") and true or false
	res.total = getn(list)
	for i = 1, getn(list) do
		local e = list[i]
		local kind, why, arg = M.Judge(e.key, e.cmd, ctx)
		if kind == "dead" then
			tinsert(res.dead, { key = e.key, cmd = e.cmd, why = why, arg = arg })
		elseif kind == "warn" then
			tinsert(res.warn, { key = e.key, cmd = e.cmd, why = why, arg = arg })
		end
	end
	return res
end

local MAXLINES = 12

-- /sui bind check : liste les liaisons mortes et les avertissements. Refuse en combat (balayage et tables).
function M.Check()
	if SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return nil
	end
	local res = M.Analyse()
	M.lastCheck = res
	SUI.Print(L("msg.bind.check.head", L(res.set == 2 and "msg.bind.set.char" or "msg.bind.set.account"), res.total, getn(res.dead), getn(res.warn)))
	local function lines(list, key)
		for i = 1, getn(list) do
			if i > MAXLINES then
				SUI.Print(L("msg.bind.check.more", getn(list) - MAXLINES))
				break
			end
			local e = list[i]
			SUI.Print(L(key, e.key, bindingName(e.cmd), L(e.why, e.arg)))
		end
	end
	lines(res.dead, "msg.bind.check.dead")
	lines(res.warn, "msg.bind.check.warn")
	if getn(res.dead) == 0 and getn(res.warn) == 0 then SUI.Print(L("msg.bind.check.ok")) end
	if getn(res.dead) > 0 then SUI.Print(L("msg.bind.check.hint")) end
	return res
end

-- /sui bind clean : retire les liaisons MORTES (jamais les avertissements) et enregistre. Refuse en combat.
function M.Clean()
	if SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return 0
	end
	local res = M.Analyse()
	local n = 0
	for i = 1, getn(res.dead) do
		SetBinding(res.dead[i].key, nil)
		n = n + 1
	end
	if n > 0 then
		SaveBindings(GetCurrentBindingSet())
		SUI.Print(L("msg.bind.clean.done", n))
	else
		SUI.Print(L("msg.bind.clean.none"))
	end
	return n
end

-- ---------------------------------------------------------------- entree / sortie
function M.Enter()
	if M.active then return true end
	if SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return false
	end
	if SUI.Mover and SUI.Mover.active then SUI.Mover.Exit(true) end
	M.Build()
	M.ops, M.n = {}, 0
	M.ask = nil
	M.escAt = nil
	M.active = true
	M.reopenMenu = false
	local mn = SUI.Menu
	if mn and mn.frame and mn.frame:IsShown() then
		M.reopenMenu = true
		mn.Hide()
	end
	M.Translate()
	M.Update()
	M.keys:Show()
	M.banner:Show()
	M.poll = SUI.Every(0.1, M.Poll, "bind.poll")
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.On("PLAYER_LOGOUT", M.OnLogout)
	notify(true)
	if mn and mn.OnMoveMode then mn.OnMoveMode(false) end
	SUI.Print(L("msg.bind.on"))
	return true
end

-- keep = false : annule tout ce qui a ete fait pendant la session (aucune sauvegarde). Sinon SaveBindings (s'il y a eu des changements).
function M.Exit(keep)
	if not M.active then return false end
	M.closing = true
	M.active = false
	SUI.Cancel(M.poll)
	M.poll = nil
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.Off("PLAYER_LOGOUT", M.OnLogout)
	local changed = M.n > 0
	if keep == false then
		while M.n > 0 do M.Undo() end
	elseif changed then
		SaveBindings(GetCurrentBindingSet())
	end
	M.ask = nil
	M.NoTarget()
	M.keys:Hide()
	M.question:Hide()
	M.banner:Hide()
	M.closing = false
	notify(false)
	if keep == false then SUI.Print(L("msg.bind.aborted")) else SUI.Print(L(changed and "msg.bind.saved" or "msg.bind.off")) end
	local mn = SUI.Menu
	if mn and mn.OnMoveMode then mn.OnMoveMode(false) end
	if M.reopenMenu then
		M.reopenMenu = false
		mn.Show()
	end
	return true
end

function M.Toggle()
	if M.active then M.Exit(true) else M.Enter() end
end

SUI.RegisterCommand("bind", function(rest)
	local _, _, sub = string.find(rest or "", "^%s*(%S*)")
	sub = string.lower(sub or "")
	if sub == "off" then M.Exit(true)
	elseif sub == "abort" then M.Exit(false)
	elseif sub == "check" then M.Check()
	elseif sub == "clean" then M.Clean()
	else M.Toggle() end
end, "help.bind")
