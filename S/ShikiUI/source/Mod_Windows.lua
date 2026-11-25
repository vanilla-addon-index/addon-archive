-- Mod_Windows : deplacer librement les fenetres de Blizzard (personnage, grimoire, talents, quetes, amis, metiers, carte, courrier...).
-- On maintient une touche (Maj / Ctrl / Alt, ou aucune) et on glisse la fenetre a la souris. La position est enregistree par fenetre
-- dans le profil (Cfg.SetPos, cle "windows.<id>") et reappliquee a chaque affichage.
-- Blizzard repositionne ses fenetres via UIPanelWindows / UpdateUIPanelPositions : on laisse ce systeme intact (on ne touche pas a
-- UIPanelWindows), on enveloppe seulement UpdateUIPanelPositions pour remettre NOTRE position juste apres, et on garde l'ancien
-- OnShow de la fenetre (1.12 n'a pas HookScript : chainage de GetScript / SetScript, avec `this` et `arg1` globaux inchanges).
-- Chaque fenetre est declaree dans la table DEFS ci-dessous (liste extensible) ; un cadre absent du jeu est simplement ignore
-- (fenetres a chargement a la demande : on re-parcourt la liste a chaque ADDON_LOADED). Rien n'est fait a un cadre protege en combat :
-- une entree marquee protected = true (aucune en 1.12 : ses fenetres ne sont pas protegees) est differee a la sortie de combat.
-- NON VERIFIE EN JEU : tout (le defaut est donc a verifier : glisser avec Maj sur chaque fenetre, fermer / rouvrir, /sui windows reset).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L

local getn = table.getn

local M = {}
SUI.Windows = M

M.on = false
M.watching = false
M.nhooked = 0

-- id : nom court (commande, textes) ; frame : nom global du cadre ; skip : fonction facultative (true = ne pas gerer ce cadre)
local function bankManaged()
	return SUI.Bags and SUI.Bags.bankHidden and true or false
end

local DEFS = {
	{ id = "character", frame = "CharacterFrame", kids = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame" } },
	{ id = "spellbook", frame = "SpellBookFrame" },
	{ id = "talents", frame = "TalentFrame" },
	{ id = "quests", frame = "QuestLogFrame" },
	{ id = "social", frame = "FriendsFrame", kids = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "GuildFrame", "ChannelFrame" } },
	{ id = "tradeskill", frame = "TradeSkillFrame" },
	{ id = "craft", frame = "CraftFrame" },
	{ id = "map", frame = "WorldMapFrame" },
	{ id = "auction", frame = "AuctionFrame" },
	{ id = "mail", frame = "MailFrame" },
	{ id = "openmail", frame = "OpenMailFrame" },
	{ id = "trade", frame = "TradeFrame" },
	{ id = "merchant", frame = "MerchantFrame" },
	{ id = "bank", frame = "BankFrame", skip = bankManaged },
	{ id = "quest", frame = "QuestFrame" },
	{ id = "gossip", frame = "GossipFrame" },
	{ id = "trainer", frame = "ClassTrainerFrame" },
	{ id = "inspect", frame = "InspectFrame" },
	{ id = "dressup", frame = "DressUpFrame" },
	{ id = "macro", frame = "MacroFrame" },
	{ id = "itemtext", frame = "ItemTextFrame" },
	{ id = "battlefield", frame = "BattlefieldFrame" },
	{ id = "petition", frame = "PetitionFrame" },
	{ id = "tabard", frame = "TabardFrame" },
	{ id = "help", frame = "HelpFrame" },
	{ id = "keybind", frame = "KeyBindingFrame" },
	{ id = "lft", frame = "LFTFrame" },
	{ id = "stable", frame = "PetStableFrame" },
	{ id = "score", frame = "WorldStateScoreFrame" },
	{ id = "options", frame = "OptionsFrame" },
	{ id = "soundoptions", frame = "SoundOptionsFrame" },
	{ id = "uioptions", frame = "UIOptionsFrame" },
	{ id = "repdetail", frame = "ReputationDetailFrame" },
	{ id = "guildinfo", frame = "GuildInfoFrame" },
	{ id = "raidinfo", frame = "RaidInfoFrame" },
	-- sacs du jeu (si l'utilisateur ne remplace pas les sacs par ceux de ShikiUI/pfUI)
	{ id = "bag1", frame = "ContainerFrame1" },
	{ id = "bag2", frame = "ContainerFrame2" },
	{ id = "bag3", frame = "ContainerFrame3" },
	{ id = "bag4", frame = "ContainerFrame4" },
	{ id = "bag5", frame = "ContainerFrame5" },
}
M.DEFS = DEFS

for i = 1, getn(DEFS) do
	local d = DEFS[i]
	d.opt = "windows.w_" .. d.id        -- option "deplacable"
	d.pk = "windows." .. d.id           -- cle de position
end

local KEYS = { "shift", "ctrl", "alt", "none" }

local function find(name)
	if type(name) ~= "string" then return nil end
	name = string.lower(name)
	for i = 1, getn(DEFS) do
		if DEFS[i].id == name or string.lower(DEFS[i].frame) == name then return DEFS[i] end
	end
	return nil
end
M.Find = find

function M.Enabled(d)
	return M.on and C.Get(d.opt) and true or false
end

local function hasPos(d)
	local l = C.GetPos(d.pk)
	return l ~= nil
end

-- d.protected = true : cadre protege (clients posterieurs a 1.12, aucun en 1.12) -> rien en combat, differe a la sortie de combat
local function protectedNow(f)
	local d = f.suiWin
	return (d and d.protected and SUI.InCombat()) and true or false
end

local function modDown(key)
	local fn
	if key == "shift" then fn = getglobal("IsShiftKeyDown")
	elseif key == "ctrl" then fn = getglobal("IsControlKeyDown")
	elseif key == "alt" then fn = getglobal("IsAltKeyDown") end
	if type(fn) ~= "function" then return false end
	return fn() and true or false
end

local function scaleRatio(f)
	local es = f.GetEffectiveScale and f:GetEffectiveScale() or 1
	local ps = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	if type(es) ~= "number" or es <= 0 then es = 1 end
	if type(ps) ~= "number" or ps <= 0 then ps = 1 end
	return es, ps
end

-- ---------------------------------------------------------------- placement
-- Pose le cadre a sa position enregistree (ancre BOTTOMLEFT de UIParent). Position en unites de UIParent.
function M.Place(f)
	local d = f and f.suiWin
	if not d or f.suiWinDrag or not M.Enabled(d) then return end
	if d.skip and d.skip() then return end
	local l, b = C.GetPos(d.pk)
	if not l then return end
	if protectedNow(f) then
		M.pending = true
		return
	end
	if not f.suiWinOrig and f.GetPoint then
		local p, rel, rp, x, y = f:GetPoint(1)
		if p then f.suiWinOrig = { p, rel, rp, x, y } end
	end
	local es, ps = scaleRatio(f)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * ps / es, b * ps / es)
	f.suiWinMoved = true
end

-- Remet la fenetre sous le controle de Blizzard (position d'origine du jeu).
function M.Restore(f)
	if not f or not f.suiWinMoved then return end
	if protectedNow(f) then
		M.pending = true
		return
	end
	f.suiWinMoved = false
	local panels = getglobal("UIPanelWindows")
	local isPanel = type(panels) == "table" and panels[f.suiWin.frame] ~= nil
	local upd = M.origUpdate
	if isPanel and type(upd) == "function" then
		if f:IsShown() then pcall(upd, f) end
	elseif f.suiWinOrig then
		local o = f.suiWinOrig
		f:ClearAllPoints()
		f:SetPoint(o[1], o[2], o[3], o[4], o[5])
	end
end

function M.PlaceAll()
	for i = 1, getn(DEFS) do
		local f = getglobal(DEFS[i].frame)
		if f and f.suiWinHooked and f:IsShown() then M.Place(f) end
	end
end

-- Relit tout : place les fenetres visibles qui ont une position, restitue celles qui n'en ont plus ou ne sont plus deplacables.
function M.Refresh()
	for i = 1, getn(DEFS) do
		local d = DEFS[i]
		local f = getglobal(d.frame)
		if f and f.suiWinHooked then
			if M.Enabled(d) and hasPos(d) and not (d.skip and d.skip()) then
				if f:IsShown() then M.Place(f) end
			elseif f.suiWinMoved then
				M.Restore(f)
			end
		end
	end
end

-- ---------------------------------------------------------------- glisser
function M.DragStart(f, button)
	local d = f.suiWin
	if not d or not M.Enabled(d) or f.suiWinDrag then return end
	if button ~= "LeftButton" then return end
	if d.skip and d.skip() then return end
	local key = C.Get("windows.key")
	if key ~= "none" and not modDown(key) then return end
	if protectedNow(f) then return end
	if not f.suiWinOrig and f.GetPoint then
		local p, rel, rp, x, y = f:GetPoint(1)
		if p then f.suiWinOrig = { p, rel, rp, x, y } end
	end
	f:SetMovable(true)
	if f.SetClampedToScreen then f:SetClampedToScreen(true) end
	f.suiWinDrag = true
	f:StartMoving()
end

function M.DragStop(f)
	if not f or not f.suiWinDrag then return end
	f.suiWinDrag = nil
	f:StopMovingOrSizing()
	local d = f.suiWin
	local left, bottom = f:GetLeft(), f:GetBottom()
	if d and type(left) == "number" and type(bottom) == "number" then
		local es, ps = scaleRatio(f)
		C.SetPos(d.pk, left * es / ps, bottom * es / ps)
		f.suiWinMoved = true
		M.Place(f)
	end
end

-- ---------------------------------------------------------------- chainage des scripts du cadre (this / arg1 globaux)
local function onShow()
	local f = this
	-- anti-boucle : Mod_Skin enveloppe aussi OnShow ; les deux chainent l'ancien script et pouvaient se rappeler sans fin (stack overflow)
	if f.suiWinInShow then return end
	f.suiWinInShow = true
	local o = f.suiWinOS
	if o then pcall(o) end
	f.suiWinInShow = nil
	M.Place(f)
end

local function onDown()
	local o = this.suiWinOD
	if o then o() end
	M.DragStart(this, arg1)
end

local function onUp()
	local o = this.suiWinOU
	if o then o() end
	M.DragStop(this)
end

local function onHide()
	local o = this.suiWinOH
	if o then o() end
	if this.suiWinDrag then M.DragStop(this) end
end

-- Cadres enfants qui couvrent la fenetre et avalent la souris (pages Competences, Reputation...) : ils relaient le glisser au cadre parent.
local function kidDown()
	local p = this.suiWinParent
	local o = this.suiWinKD
	if o then o() end
	if p then M.DragStart(p, arg1) end
end

local function kidUp()
	local p = this.suiWinParent
	local o = this.suiWinKU
	if o then o() end
	if p then M.DragStop(p) end
end

function M.HookKids(d, parent)
	if not d.kids then return end
	for i = 1, getn(d.kids) do
		local k = getglobal(d.kids[i])
		if k and not k.suiWinParent and type(k.GetScript) == "function" and type(k.SetScript) == "function" then
			k.suiWinParent = parent
			k.suiWinKD = k:GetScript("OnMouseDown")
			k.suiWinKU = k:GetScript("OnMouseUp")
			k:SetScript("OnMouseDown", kidDown)
			k:SetScript("OnMouseUp", kidUp)
			k:EnableMouse(true)
		end
	end
end

function M.Hook(d)
	local f = getglobal(d.frame)
	if not f or f.suiWinHooked or type(f.GetScript) ~= "function" or type(f.SetScript) ~= "function" then return false end
	f.suiWin = d
	f.suiWinHooked = true
	f.suiWinOS = f:GetScript("OnShow")
	f.suiWinOD = f:GetScript("OnMouseDown")
	f.suiWinOU = f:GetScript("OnMouseUp")
	f.suiWinOH = f:GetScript("OnHide")
	f:SetScript("OnShow", onShow)
	f:SetScript("OnMouseDown", onDown)
	f:SetScript("OnMouseUp", onUp)
	f:SetScript("OnHide", onHide)
	f:EnableMouse(true)
	M.HookKids(d, f)
	M.nhooked = M.nhooked + 1
	return true
end

function M.Scan()
	for i = 1, getn(DEFS) do
		local d = DEFS[i]
		if M.Hook(d) then
			local f = getglobal(d.frame)
			if f:IsShown() then M.Place(f) end
		end
	end
end

-- ---------------------------------------------------------------- UpdateUIPanelPositions (Blizzard) enveloppee
local function panelUpdate(a)
	local o = M.origUpdate
	if o then o(a) end
	if M.on then M.PlaceAll() end
end

function M.Wrap()
	local cur = getglobal("UpdateUIPanelPositions")
	if type(cur) == "function" and cur ~= panelUpdate then
		M.origUpdate = cur
		setglobal("UpdateUIPanelPositions", panelUpdate)
	end
end

function M.Unwrap()
	if getglobal("UpdateUIPanelPositions") == panelUpdate and M.origUpdate then
		setglobal("UpdateUIPanelPositions", M.origUpdate)
	end
end

-- ---------------------------------------------------------------- reinitialisation
function M.Reset(d)
	C.ClearPosAll(d.pk)
	local f = getglobal(d.frame)
	if f then M.Restore(f) end
end

function M.ResetAll()
	for i = 1, getn(DEFS) do M.Reset(DEFS[i]) end
end

-- ---------------------------------------------------------------- evenements, reglages
function M.OnAddon()
	if arg1 == "ShikiUI" then return end
	M.Scan()
end

-- Un autre addon (pfUI...) peut reposer SES scripts OnMouseDown/OnMouseUp APRES nous (chargement tardif) :
-- notre chainage est alors perdu et le glisser ne marche plus. On reverifie a chaque ENTREE dans le monde
-- (tous les addons sont charges a ce moment) et on se rechaine au-dessus si besoin.
function M.Verify()
	for i = 1, getn(DEFS) do
		local f = getglobal(DEFS[i].frame)
		if f and f.suiWinHooked then
			if f:GetScript("OnMouseDown") ~= onDown then
				f.suiWinOD = f:GetScript("OnMouseDown")
				f:SetScript("OnMouseDown", onDown)
			end
			if f:GetScript("OnMouseUp") ~= onUp then
				f.suiWinOU = f:GetScript("OnMouseUp")
				f:SetScript("OnMouseUp", onUp)
			end
			if f:GetScript("OnShow") ~= onShow then
				f.suiWinOS = f:GetScript("OnShow")
				f:SetScript("OnShow", onShow)
			end
			if f:GetScript("OnHide") ~= onHide then
				f.suiWinOH = f:GetScript("OnHide")
				f:SetScript("OnHide", onHide)
			end
			if f.IsMouseEnabled and not f:IsMouseEnabled() then f:EnableMouse(true) end
		end
	end
end

function M.OnWorld()
	M.Scan()
	M.Verify()
end

function M.OnRegen()
	if M.pending then
		M.pending = false
		M.Refresh()
	end
end

function M.OnKey(key, value)
	if not key then
		M.Refresh()
		return
	end
	if key == "windows.resetall" then
		if value then
			C.Set("windows.resetall", false)
			M.ResetAll()
			SUI.Print(L("msg.windows.resetall"))
		end
		return
	end
	if key == "pos" or string.sub(key, 1, 10) == "windows.w_" then
		M.Refresh()
	end
end

function M.Enable()
	M.on = true
	M.Wrap()
	M.Scan()
	SUI.On("ADDON_LOADED", M.OnAddon)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnWorld)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	if not M.watching then
		M.watching = true
		C.Watch("windows.", M.OnKey)
		C.Watch("pos", M.OnKey)
	end
	M.Refresh()
end

function M.Disable()
	M.on = false
	SUI.Off("ADDON_LOADED", M.OnAddon)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnWorld)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	for i = 1, getn(DEFS) do
		local f = getglobal(DEFS[i].frame)
		if f and f.suiWinHooked then
			if f.suiWinDrag then M.DragStop(f) end
			M.Restore(f)
		end
	end
	M.Unwrap()
end

-- ---------------------------------------------------------------- commande /sui windows [reset [nom]]
local function firstWord(s)
	local a, b, w, rest = string.find(s or "", "^%s*(%S+)%s*(.*)$")
	return w, rest
end

local function listAll()
	local key = C.Get("windows.key")
	SUI.Print(L("msg.windows.hint", L("choice.windows.key." .. key)))
	for i = 1, getn(DEFS) do
		local d = DEFS[i]
		local s = d.id .. " (" .. d.frame .. ") : "
		if C.Get(d.opt) then s = s .. L("msg.windows.on") else s = s .. L("msg.windows.off") end
		if hasPos(d) then s = s .. " - " .. L("msg.windows.saved") end
		if not getglobal(d.frame) then s = s .. " - " .. L("msg.windows.absent") end
		SUI.Print(s)
	end
end

SUI.RegisterCommand("windows", function(rest)
	local w, arg = firstWord(rest)
	if w == "reset" then
		local name = firstWord(arg)
		if not name or name == "all" then
			M.ResetAll()
			SUI.Print(L("msg.windows.resetall"))
			return
		end
		local d = find(name)
		if not d then
			SUI.Print(L("msg.windows.unknown", name))
			return
		end
		M.Reset(d)
		SUI.Print(L("msg.windows.reset", d.id))
		return
	end
	listAll()
end, "help.windows")

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("windows", 52)

local function buildOptions()
	local o = {
		{ key = "windows.hdr.drag", type = "header", cat = "windows", label = "mod.windows.hdr.drag", order = 5 },
		{ key = "windows.key", type = "choice", cat = "windows", label = "opt.windows.key", tip = "tip.windows.key",
			default = "none", choices = KEYS, simple = true, order = 10 },
		{ key = "windows.resetall", type = "bool", cat = "windows", label = "opt.windows.resetall", tip = "tip.windows.resetall",
			default = false, order = 20 },
		{ key = "windows.hdr.list", type = "header", cat = "windows", label = "mod.windows.hdr.list", order = 100 },
	}
	for i = 1, getn(DEFS) do
		local d = DEFS[i]
		table.insert(o, { key = d.opt, type = "bool", cat = "windows", label = "opt." .. d.opt, tip = "tip.windows.window",
			default = true, order = 100 + i })
	end
	return o
end

SUI.RegisterModule("windows", {
	default = true,
	cost = "light",
	options = buildOptions(),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})
