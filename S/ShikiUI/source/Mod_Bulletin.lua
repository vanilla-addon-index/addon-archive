-- ShikiUI Bulletin : integration de DifficultBulletinBoard (DBB, addon tiers de recherche de groupe par messages de canaux, commande /dbb).
-- ShikiUI ne remplace PAS DBB : ce module l'ouvre (/sui dbb, bouton de la page Bulletin du menu), habille sa fenetre principale au style
-- ShikiUI et peut memoriser sa position. Rien de DBB n'est copie : seuls ses noms publics relevees dans l'addon installe sont utilises.
-- Cout declare : LIGHT, et NUL tant que le module est coupe ou que DBB est absent.
--  - DBB absent (ni la table globale DBB2 ni IsAddOnLoaded("DifficultBulletinBoard")) : Enable() ne fait RIEN d'autre que se marquer actif :
--    aucun evenement, aucune minuterie, aucune surveillance de reglage, aucun enveloppement de script. La commande /sui dbb repond "DBB absent".
--  - DBB present mais fenetre pas encore creee (DBB construit sa fenetre a l'initialisation de ses modules) : un seul evenement,
--    PLAYER_ENTERING_WORLD, jusqu'a ce que la fenetre existe, puis il est rendu.
--  - Aucune minuterie, aucun OnUpdate : le travail se fait a l'OnShow / OnHide de la fenetre DBB (scripts ENVELOPPES a la main : l'ancien script
--    est rappele d'abord, puis le notre ; a la coupure l'ancien script est remis si le notre est encore en place).
--  - Aucune creation de cadre : on repeint des cadres que DBB a deja crees (ses "backdrop" enfants).
-- NOMS DE DBB UTILISES (relevees dans DifficultBulletinBoard 2.40) : la table globale DBB2 ; DBB2.gui (cadre principal, nom global
--  "DBB2ConfigGUI", ouvert/ferme par la commande /dbb avec Show / Hide) ; DBB2.gui.backdrop (cadre enfant qui porte le fond et la bordure) ;
--  DBB2.gui.close et DBB2.gui.configBtn (boutons d'en-tete, chacun avec son .backdrop) ; DBB2:CreateBackdrop(cadre, inset, legacy, transp)
--  (utilise pour rendre a DBB son propre aspect quand le skin est coupe). DBB garde lui-meme sa position (DBB2_Config.position) : l'option de
--  memorisation de ShikiUI est un second filet (la position est rappliquee a chaque ouverture) pour qui reinitialise la config de DBB.
-- SKIN : fond (T.c.bg x opacite du style) et bordure (T.c.border) du cadre principal et des deux boutons d'en-tete ; repeint a chaud au
--  changement de style / d'accent. Les onglets et les listes de DBB gardent leurs couleurs (DBB les repeint lui-meme au survol : y toucher
--  reviendrait a se battre avec son code).
-- NON VERIFIE EN JEU : tout. Notamment que DBB2.gui.backdrop est bien un cadre avec SetBackdropColor, l'ordre de chargement (DBB avant
--  ShikiUI), GetPoint sur le cadre de DBB et le rendu du fond repeint.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local floor = math.floor
local sfind = string.find

local M = {}
SUI.Bulletin = M

local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true,
	BOTTOMRIGHT = true }

M.on = false
M.present = false       -- DBB trouve a l'activation
M.skinned = false       -- la fenetre porte actuellement l'habillage ShikiUI
M.wrapped = nil         -- cadre dont on a enveloppe OnShow / OnHide
M.oldShow, M.oldHide = nil, nil

-- ---------------------------------------------------------------- detection
-- Le cadre principal de DBB (ou nil).
function M.Gui()
	local d = getglobal("DBB2")
	if type(d) == "table" and type(d.gui) == "table" and d.gui.IsShown then return d.gui end
	return nil
end

function M.Detect()
	if type(getglobal("DBB2")) == "table" then return true end
	local f = getglobal("IsAddOnLoaded")
	if type(f) == "function" then
		local ok, r = pcall(f, "DifficultBulletinBoard")
		return (ok and r) and true or false
	end
	return false
end

-- ---------------------------------------------------------------- ouverture
-- mode : "toggle" (defaut) | "open" | "close". Fonctionne meme module coupe (comme /dbb), tant que DBB est la.
function M.Open(mode)
	local gui = M.Gui()
	if not gui then
		SUI.Print(L(M.Detect() and "msg.bulletin.nowindow" or "msg.bulletin.absent"))
		return false
	end
	local shown = gui:IsShown()
	if mode == "open" then
		if not shown then gui:Show() end
	elseif mode == "close" then
		if shown then gui:Hide() end
	elseif shown then
		gui:Hide()
	else
		gui:Show()
	end
	return true
end

-- ---------------------------------------------------------------- habillage
local function paint(f)
	local b = f and f.backdrop
	if not b or not b.SetBackdropColor then return end
	local bg, bd = T.c.bg, T.c.border
	b:SetBackdropColor(bg[1], bg[2], bg[3], (bg[4] or 1) * (T.alpha or 1))
	b:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 1)
end

function M.Skin()
	if not M.on or not C.Get("bulletin.skin") then return end
	local gui = M.Gui()
	if not gui then return end
	paint(gui)
	paint(gui.close)
	paint(gui.configBtn)
	M.skinned = true
end

-- Rend a DBB son propre aspect (il relit sa configuration de couleurs).
function M.Unskin()
	if not M.skinned then return end
	M.skinned = false
	local gui = M.Gui()
	local d = getglobal("DBB2")
	if not gui or type(d) ~= "table" or type(d.CreateBackdrop) ~= "function" then return end
	pcall(d.CreateBackdrop, d, gui, nil, nil, 0.85)
	if gui.close and gui.close.backdrop then pcall(d.CreateBackdrop, d, gui.close) end
	if gui.configBtn and gui.configBtn.backdrop then pcall(d.CreateBackdrop, d, gui.configBtn) end
end

-- Style ou accent change : repeint si la fenetre est habillee.
function M.Repaint()
	if M.on and M.skinned then M.Skin() end
end

-- ---------------------------------------------------------------- position
function M.SavePos()
	if not C.Get("bulletin.rememberpos") then return end
	local gui = M.Gui()
	if not gui then return end
	local p, rel, rp, x, y = gui:GetPoint()
	if not p or type(x) ~= "number" or type(y) ~= "number" then return end
	if rel and rel ~= UIParent then return end
	C.SetBase("bulletin.pos", p .. "|" .. (rp or p) .. "|" .. floor(x + 0.5) .. "|" .. floor(y + 0.5))
end

function M.RestorePos()
	if not C.Get("bulletin.rememberpos") then return end
	local gui = M.Gui()
	local v = C.Get("bulletin.pos")
	if not gui or type(v) ~= "string" or v == "" then return end
	local _, _, p, rp, x, y = sfind(v, "^(%a+)|(%a+)|(%-?%d+)|(%-?%d+)$")
	if not p or not ANCHORS[p] or not ANCHORS[rp] then return end
	gui:ClearAllPoints()
	gui:SetPoint(p, UIParent, rp, tonumber(x), tonumber(y))
end

-- ---------------------------------------------------------------- scripts envelopes
function M.OnShow()
	if M.oldShow then M.oldShow() end
	if not M.on then return end
	M.RestorePos()
	M.Skin()
end

function M.OnHide()
	if M.oldHide then M.oldHide() end
	if M.on then M.SavePos() end
end

function M.Wrap(gui)
	if M.wrapped == gui then return end
	M.oldShow, M.oldHide = gui:GetScript("OnShow"), gui:GetScript("OnHide")
	gui:SetScript("OnShow", M.OnShow)
	gui:SetScript("OnHide", M.OnHide)
	M.wrapped = gui
end

-- Remet les scripts d'origine si les notres sont encore en place (sinon un autre addon s'est enveloppe par-dessus : on reste en
-- transmission pure, M.on est faux).
function M.Unwrap()
	local g = M.wrapped
	if not g then return end
	local freeShow = g:GetScript("OnShow") == M.OnShow
	local freeHide = g:GetScript("OnHide") == M.OnHide
	if freeShow then g:SetScript("OnShow", M.oldShow) end
	if freeHide then g:SetScript("OnHide", M.oldHide) end
	if freeShow and freeHide then
		M.wrapped = nil
		M.oldShow, M.oldHide = nil, nil
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Attach()
	if not M.on then return false end
	local gui = M.Gui()
	if not gui then return false end
	M.Wrap(gui)
	if not M.accentHooked then
		M.accentHooked = true
		T.OnAccent(M.Repaint)
	end
	SUI.Off("PLAYER_ENTERING_WORLD", M.Attach)
	if gui:IsShown() then M.Skin() end
	return true
end

function M.OnKey(key, value)
	if not M.on or not M.present then return end
	if C.Get("bulletin.skin") then
		local gui = M.Gui()
		if gui and gui:IsShown() then M.Skin() end
	else
		M.Unskin()
	end
end

function M.Enable()
	M.on = true
	M.present = M.Detect()
	if not M.present then return end            -- DBB absent : rien d'enregistre
	if not M.Attach() then SUI.On("PLAYER_ENTERING_WORLD", M.Attach) end
	if not M.watching then
		M.watching = true
		C.Watch("bulletin.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_ENTERING_WORLD", M.Attach)
	M.Unskin()
	M.Unwrap()
	M.present = false
end

-- ---------------------------------------------------------------- page du menu et commande
function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "bulletin" and Mn.GridBtn then
			local found = M.Gui() ~= nil
			Mn.Section(L("mod.bulletin.sec"), "")
			Mn.Para(L(found and "mod.bulletin.found" or "mod.bulletin.missing"), 34, found and T.c.good or T.c.warn)
			if found then
				Mn.GridBtn(L("mod.bulletin.open"), 3, 208, 24, function() M.Open("toggle") end, false)
			end
		end
		orig()
	end
end

SUI.RegisterCategory("bulletin", 34)

local function opt(key, typ, order, def, extra)
	local o = { key = "bulletin." .. key, type = typ, cat = "bulletin", label = "opt.bulletin." .. key, tip = "tip.bulletin." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("bulletin", {
	default = false,
	cost = "light",
	options = {
		opt("skin", "bool", 10, true, { simple = true }),
		opt("rememberpos", "bool", 20, false, { simple = true }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnee (pas un reglage de menu) : position memorisee "POINT|POINTREL|x|y".
SUI.Config.Register({ ["bulletin.pos"] = "" })

-- Les integrations connues (menu, /sui status) listent DBB quand le module tourne et que DBB est la.
if SUI.Api and SUI.Api.Integrations and not M.apiWrapped then
	M.apiWrapped = true
	local orig = SUI.Api.Integrations
	SUI.Api.Integrations = function()
		local t = orig()
		if M.on and M.present then table.insert(t, "DifficultBulletinBoard") end
		return t
	end
end

M.HookMenu()

-- /sui dbb [open | close | toggle | status] ; sans argument : ouvre / ferme la fenetre de DBB.
SUI.RegisterCommand("dbb", function(rest)
	local w = string.lower(rest or "")
	if w == "status" then
		SUI.Print(L("msg.bulletin.status", M.Detect() and 1 or 0, M.Gui() and 1 or 0, M.on and 1 or 0, M.skinned and 1 or 0))
	elseif w == "open" or w == "close" then
		M.Open(w)
	else
		M.Open("toggle")
	end
end, "help.bulletin")
