-- ShikiUI GameMenu : bouton "ShikiUI" dans le menu Echap de Blizzard (GameMenuFrame), insere juste sous le bouton "Macros".
-- Aucun nom de bouton n'est suppose : on parcourt les enfants de la fenetre (GetChildren) et on repere les boutons par leur texte.
-- Les boutons du dessous sont decales (ou raccroches au nouveau bouton) et la fenetre grandit d'un bouton, UNE SEULE FOIS.
-- Repli si "Macros" est introuvable : sous le dernier bouton du bloc Options / Key Bindings. Apparence Blizzard (aucun style ShikiUI).
-- NON VERIFIE EN JEU : le modele "GameMenuButtonTemplate" (repli "UIPanelButtonTemplate"), la hauteur reelle des boutons, GetChildren sur
-- GameMenuFrame, HideUIPanel, et le fonctionnement avec pfUI (qui habille ce menu a sa facon).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L

local getn, tinsert = table.getn, table.insert
local G = {}
SUI.GameMenu = G

G.NAME = "ShikiUI_GameMenuButton"
G.TEMPLATES = { "GameMenuButtonTemplate", "UIPanelButtonTemplate" }
G.button = nil
G.grown = false
G.hooked = false
G.how = nil           -- "macros" | "fallback" | nil (rien d'insere)

local function norm(s)
	if type(s) ~= "string" then return "" end
	return string.lower(s)
end

local function globalText(name, default)
	local v = getglobal(name)
	if type(v) == "string" and v ~= "" then return norm(v) end
	return norm(default)
end

-- Boutons enfants de la fenetre : liste de { b, text, top }
function G.Buttons(frame)
	local res = {}
	if not frame or not frame.GetChildren then return res end
	local kids = { frame:GetChildren() }
	for i = 1, getn(kids) do
		local k = kids[i]
		if k and k.IsObjectType and k:IsObjectType("Button") and k ~= G.button and k.GetText then
			local txt = k:GetText()
			local top = k.GetTop and k:GetTop()
			if type(txt) == "string" and txt ~= "" and type(top) == "number" then
				tinsert(res, { b = k, text = norm(txt), top = top })
			end
		end
	end
	return res
end

-- Bouton modele : "Macros" ; sinon le plus bas de Key Bindings / Options. Retourne bouton, "macros" | "fallback".
function G.FindModel(btns)
	local macros = globalText("MACROS", "Macros")
	local keys = globalText("KEY_BINDINGS", "Key Bindings")
	local opts = globalText("OPTIONS", "Options")
	local low = nil
	for i = 1, getn(btns) do
		local e = btns[i]
		if e.text == macros then return e.b, "macros" end
		if e.text == keys or e.text == opts then
			if not low or e.top < low.top then low = e end
		end
	end
	if low then return low.b, "fallback" end
	return nil
end

local function makeButton(frame)
	for i = 1, getn(G.TEMPLATES) do
		local ok, b = pcall(CreateFrame, "Button", G.NAME, frame, G.TEMPLATES[i])
		if ok and b then return b end
	end
	return nil
end

function G.Click()
	local f = getglobal("GameMenuFrame")
	local hide = getglobal("HideUIPanel")
	if f then
		if hide then hide(f) else f:Hide() end
	end
	if SUI.Menu then SUI.Menu.Show() end
end

-- Insere le bouton. Idempotent : retourne true si le bouton est (deja) en place.
function G.Install()
	if G.button then return true end
	local frame = getglobal("GameMenuFrame")
	if not frame then return false end
	local btns = G.Buttons(frame)
	local model, how = G.FindModel(btns)
	if not model then return false end
	local mtop = model:GetTop()
	local h = model:GetHeight() or 0
	-- pas vertical = ecart de tete entre le bouton juste au-dessus du modele et le modele (sinon hauteur + 1)
	local above = nil
	local below = {}
	for i = 1, getn(btns) do
		local e = btns[i]
		if e.b ~= model then
			if e.top > mtop + 0.5 then
				if not above or e.top < above.top then above = e end
			elseif e.top < mtop - 0.5 then
				tinsert(below, e.b)
			end
		end
	end
	local step = h + 1
	if above then step = above.top - mtop end
	if step < h then step = h end
	local gap = step - h
	local b = makeButton(frame)
	if not b then return false end
	b:SetWidth(model:GetWidth())
	b:SetHeight(h)
	b:SetText(L("mod.addons.gamemenu"))
	b:SetScript("OnClick", G.Click)
	-- Le bouton nait APRES l habillage du menu (premiere ouverture) : on l habille nous-memes, sinon il reste le gros bouton rouge de Blizzard.
	local sk = SUI.Skin
	if sk and sk.Button and SUI.Config and SUI.Config.Get("modules.skin") then pcall(sk.Button, b, "GameMenuFrame") end
	b:ClearAllPoints()
	b:SetPoint("TOP", model, "BOTTOM", 0, -gap)
	-- le dessous : raccroche au nouveau bouton s'il l'etait au modele, decale s'il est pose en absolu, laisse tel quel s'il suit un voisin decale
	local isBelow = {}
	for i = 1, getn(below) do isBelow[below[i]] = true end
	for i = 1, getn(below) do
		local x = below[i]
		-- FIX 2026-11-20 : un bouton sans ancre (DeleteRegion entre-temps) levait ici et tuait le menu Echap
		local okP, p, rel, rp, ox, oy = pcall(x.GetPoint, x, 1)
		if okP and p then
			-- selon les clients, relativeTo arrive en chaine : normalise vers l'objet ancre
			if type(rel) == "string" then rel = getglobal(rel) end
			if rel == model then
				x:ClearAllPoints()
				x:SetPoint(p, b, rp, ox or 0, oy or 0)
			elseif not isBelow[rel] then
				-- pose en absolu : sur un bouton du dessus ou sur le haut de la fenetre -> decale d'un pas ; sur le bas de la fenetre -> suit tout seul
				local shift = step
				if rel == frame then
					rp = rp or p
					if string.find(rp, "BOTTOM") then shift = 0 elseif not string.find(rp, "TOP") then shift = step / 2 end
				end
				if shift ~= 0 then
					x:ClearAllPoints()
					x:SetPoint(p, rel, rp, ox or 0, (oy or 0) - shift)
				end
			end
		end
	end
	if not G.grown then
		G.grown = true
		frame:SetHeight(frame:GetHeight() + step)
	end
	G.button = b
	G.how = how
	return true
end

-- Remet l etat a zero (tests : un nouveau GameMenuFrame simule).
function G.Reset()
	G.button, G.grown, G.hooked, G.how = nil, false, false, nil
end

local function onShow()
	G.Install()
end

-- Accroche l'installation a l'affichage du menu Echap (les boutons ajoutes par le serveur existent alors).
function G.Hook()
	if G.hooked then return end
	local frame = getglobal("GameMenuFrame")
	if not frame then return end
	G.hooked = true
	local old = frame:GetScript("OnShow")
	frame:SetScript("OnShow", function()
		if old then old() end
		onShow()
	end)
	if frame:IsShown() then G.Install() end
end

SUI.On("PLAYER_LOGIN", G.Hook)
