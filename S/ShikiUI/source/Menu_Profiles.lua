-- ShikiUI Menu_Profiles : page "Profils et sauvegardes" du menu (profils nommes, sauvegardes manuelles / automatiques, restauration,
-- export / import texte). La logique est dans Config.lua (profils) et Backup.lua (instantanes) ; cette page ne fait que les piloter. Aucune couleur en dur : jetons du style (Theme.lua).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local NEW = M.New

local getn, tinsert = table.getn, table.insert
local CW = M.G.CW

M.prof = { name = "", sel = nil }
local KEEPS = { 3, 6, 10, 20 }
local HOURS = { 0, 6, 12, 24, 72 }
local MAXROWS = 12

local function say(key, a, b)
	if key then SUI.Print(L(key, a, b)) end
end

-- champ de saisie du nom de profil
function NEW.pedit()
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 2)
	f.edit = T.Edit(f, CW, 22)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.edit:SetMaxLetters(24)
	f.edit:SetScript("OnTextChanged", function()
		local e = this
		if e.silent then return end
		M.prof.name = e:GetText() or ""
		if e.hint then e.hint:SetText(M.prof.name == "" and L("mod.menu.pr.namehint") or "") end
	end)
	f.edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	f.hint = T.Text(f.edit, 11, T.c.dim, "LEFT")
	f.hint:SetPoint("LEFT", f.edit, "LEFT", 6, 0)
	f.edit.hint = f.hint
	return f
end

local function nextIn(list, v)
	for i = 1, getn(list) do
		if list[i] == v then return list[i + 1] or list[1] end
	end
	return list[1]
end

local function yn(on)
	return on and "[x] " or "[ ] "
end

local function users(name)
	local n = 0
	for _, v in pairs(SUI.Config.db.chars) do
		if v == name then n = n + 1 end
	end
	return n
end

-- ligne d'une sauvegarde : texte + bouton Restaurer (2 clics) + petit bouton de suppression
local function backupRow(rec)
	local B = SUI.Backup
	local n = M.Get("note")
	if not n then return end
	M.Flow(n, 1, CW - 36, 34, 0, 6)
	n.fs:SetWidth(CW - 170)
	n.fs:SetHeight(30)
	n.fs:SetText(B.Stamp(rec.t) .. "  " .. B.Reason(rec) .. "  " .. (rec.label or rec.profile) .. "\n" .. B.Summary(rec))
	T.SetButtonText(n.btn, L("mod.menu.bk.restore"))
	n.btn.fn = function()
		M.ConfirmClick(n.btn, "bkr" .. rec.id, L("mod.menu.bk.restore"), function()
			local ok, key, name = B.Restore(rec.id)
			say(key, name)
			M.Render()
		end)
	end
	local d = M.Get("btn")
	if d then
		d:ClearAllPoints()
		d:SetPoint("TOPLEFT", M.child, "TOPLEFT", CW - 30, -(n.y + 6))
		d:SetWidth(30)
		d:SetHeight(22)
		d:Show()
		T.SetButtonText(d, "x")
		T.SetSelected(d, false)
		d.fn = function()
			local ok, key = B.Delete(rec.id)
			say(key)
			M.Render()
		end
	end
end

-- ---------------------------------------------------------------- profil automatique par contexte (solo / groupe / raid)
-- Memorise par personnage (ShikiUIDB.global.autoProf) ; les evenements de groupe ne sont ecoutes que si au moins un contexte a un profil.
-- Un contexte sans profil ne change rien (le profil courant reste). Le changement attend la fin du combat.
M.Auto = { ctx = { "solo", "party", "raid", "bg" }, events = false, last = nil }
local A = M.Auto
local AEVENTS = { "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED" }

function A.Get(ctx)
	local C = SUI.Config
	local g = C.db and C.db.global
	local t = g and type(g.autoProf) == "table" and g.autoProf[C.CharKey()]
	local v = type(t) == "table" and t[ctx] or nil
	if v and C.db.profiles[v] then return v end
	return nil
end

function A.Set(ctx, name)
	local C = SUI.Config
	if not C.db then return end
	local g = C.db.global
	if type(g.autoProf) ~= "table" then g.autoProf = {} end
	local k = C.CharKey()
	if type(g.autoProf[k]) ~= "table" then g.autoProf[k] = {} end
	g.autoProf[k][ctx] = name
	A.Sync()
	A.Check()
end

function A.Any()
	for i = 1, getn(A.ctx) do
		if A.Get(A.ctx[i]) then return true end
	end
	return false
end

function A.Context()
	local isin = getglobal("IsInInstance")
	if type(isin) == "function" then
		local _, kind = isin()
		if kind == "pvp" then return "bg" end
	end
	if GetNumRaidMembers() > 0 then return "raid" end
	if GetNumPartyMembers() > 0 then return "party" end
	return "solo"
end

function A.Apply()
	local want = A.Get(A.Context())
	if want and want ~= SUI.Config.curName then
		local ok, key = SUI.Config.UseProfile(want)
		if ok then SUI.Print(L("msg.menu.auto.switched", want)) end
	end
end

local function onGroup()
	if A.task then return end
	A.task = SUI.After(2, function()
		A.task = nil
		SUI.WhenSafe(A.Apply)
	end, "menuautoprof")
end

function A.Check()
	if A.Any() then onGroup() end
end

-- Ecoute les evenements seulement si un profil automatique est defini.
function A.Sync()
	local want = A.Any()
	if want == A.events then return end
	A.events = want
	for i = 1, getn(AEVENTS) do
		if want then SUI.On(AEVENTS[i], onGroup) else SUI.Off(AEVENTS[i], onGroup) end
	end
end

SUI.On("PLAYER_LOGIN", function()
	A.Sync()
	A.Check()
end)

function M.Pages.profiles()
	local C = SUI.Config
	local B = SUI.Backup
	local P = M.prof
	if not P.sel or not C.db.profiles[P.sel] then P.sel = C.curName end
	M.SetHead(L("mod.menu.nav.profiles"), L("mod.menu.pr.desc"))
	-- ---- profils nommes
	local list = C.ListProfiles()
	M.Section(L("mod.menu.pr.sec"), tostring(getn(list)))
	M.Para(L("mod.menu.pr.why"), 44)
	for i = 1, getn(list) do
		local name = list[i]
		M.GridBtn(name .. (name == C.curName and "  *" or ""), 3, 208, 26, function()
			P.sel = name
			M.Render()
		end, P.sel == name)
	end
	M.EndRow(8)
	M.Para(L("mod.menu.pr.info", P.sel, users(P.sel), P.sel == C.curName and L("mod.menu.pr.active") or L("mod.menu.pr.inactive")), 30)
	M.GridBtn(L("mod.menu.pr.use"), 4, 153, 26, function()
		local ok, key = C.UseProfile(P.sel)
		say(key, P.sel)
		M.Render()
	end)
	M.GridBtn(L("mod.menu.pr.dup"), 4, 153, 26, function()
		local ok, key = C.NewProfile(P.name, P.sel)
		say(key, P.name)
		M.Render()
	end)
	M.GridBtn(L("mod.menu.pr.rename"), 4, 153, 26, function()
		local ok, key = C.RenameProfile(P.sel, P.name)
		if ok then P.sel = P.name end
		say(key, P.name)
		M.Render()
	end)
	local del = M.GridBtn(L("mod.menu.pr.delete"), 4, 153, 26, nil)
	if del then
		del.fn = function(b)
			M.ConfirmClick(b, "prdel", L("mod.menu.pr.delete"), function()
				local ok, key = C.DeleteProfile(P.sel)
				say(key, P.sel)
				if ok then P.sel = C.curName end
				M.Render()
			end)
		end
	end
	M.EndRow(8)
	local ed = M.Get("pedit")
	if ed then
		M.Flow(ed, 1, CW, 22, 0, 8)
		ed.edit.silent = true
		if (ed.edit:GetText() or "") ~= P.name then ed.edit:SetText(P.name) end
		ed.edit.silent = false
		ed.hint:SetText(P.name == "" and L("mod.menu.pr.namehint") or "")
		M.EndRow(8)
	end
	M.GridBtn(L("mod.menu.pr.new"), 3, 208, 26, function()
		local ok, key = C.NewProfile(P.name)
		say(key, P.name)
		M.Render()
	end)
	M.GridBtn(L("mod.menu.pr.export"), 3, 208, 26, function() M.ShowTransfer("export") end)
	M.GridBtn(L("mod.menu.pr.import"), 3, 208, 26, function() M.ShowTransfer("import") end)
	M.EndRow(8)
	-- ---- profil automatique par contexte
	M.Section(L("mod.menu.auto.sec"))
	M.Para(L("mod.menu.auto.why"), 44)
	for i = 1, getn(A.ctx) do
		local ctx = A.ctx[i]
		local cur = A.Get(ctx)
		M.GridBtn(L("mod.menu.auto." .. ctx, cur or L("mod.menu.auto.none")), 4, 153, 26, function()
			local nxt
			if not cur then
				nxt = list[1]
			else
				nxt = nil
				for j = 1, getn(list) do
					if list[j] == cur then nxt = list[j + 1] end
				end
			end
			A.Set(ctx, nxt)
			M.Render()
		end, cur ~= nil)
	end
	M.EndRow(8)
	-- ---- sauvegardes
	local bl = B.List()
	M.Section(L("mod.menu.bk.sec"), tostring(getn(bl)))
	M.Para(L("mod.menu.bk.why"), 44)
	M.GridBtn(L("mod.menu.bk.now"), 2, 318, 28, function()
		local id = B.Create("manual")
		say("msg.menu.bk.created", id)
		M.Render()
	end)
	M.GridBtn(yn(C.Get("backup.auto")) .. L("mod.menu.bk.auto"), 2, 318, 28, function()
		C.Set("backup.auto", not C.Get("backup.auto"))
		M.Render()
	end, C.Get("backup.auto"))
	M.EndRow(8)
	M.GridBtn(yn(C.Get("backup.logout")) .. L("mod.menu.bk.logout"), 3, 208, 26, function()
		C.Set("backup.logout", not C.Get("backup.logout"))
		M.Render()
	end, C.Get("backup.logout"))
	M.GridBtn(L("mod.menu.bk.keep", C.Get("backup.keep")), 3, 208, 26, function()
		C.Set("backup.keep", nextIn(KEEPS, C.Get("backup.keep")))
		M.Render()
	end)
	local hrs = C.Get("backup.hours")
	M.GridBtn(hrs == 0 and L("mod.menu.bk.hours.off") or L("mod.menu.bk.hours", hrs), 3, 208, 26, function()
		C.Set("backup.hours", nextIn(HOURS, C.Get("backup.hours")))
		M.Render()
	end)
	M.EndRow(10)
	if getn(bl) == 0 then M.Para(L("msg.menu.bk.none"), 18) end
	for i = 1, getn(bl) do
		if i > MAXROWS then break end
		backupRow(bl[i])
	end
	if getn(bl) > MAXROWS then M.Para(L("mod.menu.bk.more", getn(bl) - MAXROWS), 18) end
	-- ---- pfUI
end
