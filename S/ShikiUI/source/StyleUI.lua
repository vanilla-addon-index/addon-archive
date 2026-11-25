-- ShikiUI StyleUI : panneau "Styles" (choix en un clic avec apercu reel) et mises en page. Ouvert par le bouton Styles du menu ou /sui style pick.
-- Chaque carte dessine un APERCU du style a partir de ses jetons resolus (Style.Resolve sans reglage individuel) sans toucher au theme
-- global : un widget d'apercu n'est donc jamais enregistre dans le moteur de repeinture. Cartes en pool (8 par page) : aucune creation
-- apres la construction, la fenetre se construit hors combat uniquement.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local T = SUI.Theme
local S = SUI.Style
local L = SUI.L

local getn, tinsert = table.getn, table.insert

local P = {}
SUI.StylePicker = P
P.cards = {}
P.layoutButtons = {}
P.page = 1

local PER_PAGE = 8
local CARD_W, CARD_H = 206, 66
-- 20 mises en page enregistrees (14 de base + 6 presets d'ecran) : 5 par rangee, 4 rangees
local MAX_LAYOUT_BUTTONS = 24   -- 23 mises en page enregistrees (5 par rangee)

local function accentRGB(tok)
	local a = tok.accent
	if type(a) == "table" then return a[1], a[2], a[3] end
	if a == "class" and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then return col.r, col.g, col.b end
	end
	local t = T.accents[a] or T.accents.blue
	return t[1], t[2], t[3]
end

local function newCard(parent, i)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(CARD_W)
	b:SetHeight(CARD_H)
	T.Backdrop(b, T.c.panel, T.c.border)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function()
		local card = this
		if card.id and S.styles[card.id] then
			C.Set("style.name", card.id)
		end
	end)
	-- apercu : fond + bordure + barre + texte, aux couleurs du style montre
	b.pv = CreateFrame("Frame", nil, b)
	b.pv:SetWidth(64)
	b.pv:SetHeight(46)
	b.pv:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.pv:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	b.bar = b.pv:CreateTexture(nil, "ARTWORK")
	b.bar:SetTexture(T.tex.white)
	b.bar:SetHeight(8)
	b.bar:SetPoint("BOTTOMLEFT", b.pv, "BOTTOMLEFT", 6, 6)
	b.bar:SetPoint("BOTTOMRIGHT", b.pv, "BOTTOMRIGHT", -6, 6)
	b.sample = b.pv:CreateFontString(nil, "OVERLAY")
	b.sample:SetFont(T.assets.font.arial, 11)
	b.sample:SetPoint("TOPLEFT", b.pv, "TOPLEFT", 6, -6)
	b.name = T.Text(b, 12, T.c.text, "LEFT")
	b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 78, -8)
	b.name:SetWidth(CARD_W - 78 - 22)
	b.name:SetHeight(14)
	b.desc = T.Text(b, 9, T.c.dim, "LEFT")
	b.desc:SetPoint("TOPLEFT", b, "TOPLEFT", 78, -26)
	b.desc:SetWidth(CARD_W - 78 - 8)
	b.desc:SetHeight(34)
	b.del = T.Button(b, "x", 16, 16, function(btn)
		local card = btn:GetParent()
		if card.id then
			local ok, key = S.Delete(card.id)
			SUI.Print(L(key, card.id))
			P.Render()
		end
	end)
	b.del:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
	b.del:Hide()
	return b
end

local function bindCard(b, id)
	b.id = id
	local rec = S.styles[id]
	local tok = S.Resolve(id)
	local c = tok.c
	b.pv:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], c.bg[4] * tok.alpha)
	b.pv:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
	local ar, ag, ab = accentRGB(tok)
	b.bar:SetVertexColor(ar, ag, ab, 1)
	pcall(b.sample.SetFont, b.sample, tok.font or T.assets.font.arial, 11 * tok.fontScale, tok.outline)
	b.sample:SetText(L("mod.style.sample"))
	b.sample:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
	b.name:SetText(S.Label(id))
	b.desc:SetText(S.Desc(id))
	if rec.origin == "user" then b.del:Show() else b.del:Hide() end
	T.SetSelected(b, C.Get("style.name") == id)
end

local function pageCount()
	local n = getn(S.names)
	local pages = math.floor((n + PER_PAGE - 1) / PER_PAGE)
	if pages < 1 then pages = 1 end
	return pages
end

function P.Render()
	local f = P.frame
	if not f then return end
	local pages = pageCount()
	if P.page > pages then P.page = pages end
	if P.page < 1 then P.page = 1 end
	local first = (P.page - 1) * PER_PAGE
	for i = 1, PER_PAGE do
		local card = P.cards[i]
		local id = S.names[first + i]
		if id then
			bindCard(card, id)
			card:Show()
		else
			card.id = nil
			card:Hide()
		end
	end
	f.pageText:SetText(L("mod.style.page", P.page, pages))
	f.title:SetText(L("mod.style.title"))
	f.current:SetText(L("mod.style.current", S.Label(C.Get("style.name"))))
	T.SetButtonText(f.prev, "<")
	T.SetButtonText(f.next, ">")
	T.SetButtonText(f.import, L("mod.style.import"))
	T.SetButtonText(f.export, L("mod.style.export"))
	T.SetButtonText(f.edit, L("mod.style.edit"))
	T.SetButtonText(f.reset, L("mod.style.reset"))
	T.SetButtonText(f.save, L("mod.style.save"))
	f.layoutLabel:SetText(L("mod.style.layouts"))
	f.nameHint:SetText((f.name:GetText() or "") == "" and L("mod.style.namehint") or "")
	local cur = SUI.Layout.Current()
	for i = 1, MAX_LAYOUT_BUTTONS do
		local b = P.layoutButtons[i]
		local id = SUI.layoutOrder[i]
		if id then
			b.id = id
			T.SetButtonText(b, SUI.Layout.Label(id))
			T.SetSelected(b, cur == id)
			b:Show()
		else
			b.id = nil
			b:Hide()
		end
	end
end

function P.Build()
	if P.frame then return P.frame end
	local f = CreateFrame("Frame", "ShikiUI_Styles", UIParent)
	P.frame = f
	f:SetWidth(2 * CARD_W + 30)
	f:SetHeight(540)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	f.title = T.Text(f, 14, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	f.close = T.Button(f, "x", 22, 20, function() f:Hide() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
	f.current = T.Text(f, 10, T.c.dim, "LEFT")
	f.current:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
	for i = 1, PER_PAGE do
		local card = newCard(f, i)
		local col, row = SUI.Mod(i - 1, 2), math.floor((i - 1) / 2)
		card:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + col * (CARD_W + 4), -48 - row * (CARD_H + 4))
		P.cards[i] = card
	end
	f.prev = T.Button(f, "<", 26, 20, function() P.page = P.page - 1; P.Render() end)
	f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -330)
	f.next = T.Button(f, ">", 26, 20, function() P.page = P.page + 1; P.Render() end)
	f.next:SetPoint("LEFT", f.prev, "RIGHT", 6, 0)
	f.pageText = T.Text(f, 10, T.c.dim, "LEFT")
	f.pageText:SetPoint("LEFT", f.next, "RIGHT", 8, 0)
	f.name = T.Edit(f, 130, 20)
	f.name:SetMaxLetters(24)
	f.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -88, -330)
	f.name:SetScript("OnTextChanged", function()
		f.nameHint:SetText((this:GetText() or "") == "" and L("mod.style.namehint") or "")
	end)
	f.nameHint = T.Text(f.name, 10, T.c.dim, "LEFT")
	f.nameHint:SetPoint("LEFT", f.name, "LEFT", 6, 0)
	f.save = T.Button(f, "", 76, 20, function()
		local txt = f.name:GetText() or ""
		local ok, id = S.SaveCurrent(txt)
		if ok then
			SUI.Print(L("msg.style.saved", id))
			f.name:SetText("")
			P.page = pageCount()
		else
			SUI.Print(L(id, txt))
		end
		P.Render()
	end)
	f.save:SetPoint("LEFT", f.name, "RIGHT", 6, 0)
	f.layoutLabel = T.Text(f, 11, T.c.dim, "LEFT")
	f.layoutLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -362)
	for i = 1, MAX_LAYOUT_BUTTONS do
		local b = T.Button(f, "", 96, 20, function(btn)
			if btn.id then
				local ok, key, n, bad = SUI.Layout.ApplyPreset(btn.id)
				if ok then SUI.Print(L(key, SUI.Layout.Label(btn.id), n, bad)) end
				P.Render()
			end
		end)
		local col, row = SUI.Mod(i - 1, 5), math.floor((i - 1) / 5)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + col * 100, -378 - row * 24)
		P.layoutButtons[i] = b
	end
	f.import = T.Button(f, "", 90, 20, function() SUI.Menu.ShowTransfer("import", nil, "style") end)
	f.import:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.export = T.Button(f, "", 90, 20, function()
		local str = S.Export()
		SUI.Menu.ShowTransfer("export", str)
	end)
	f.export:SetPoint("LEFT", f.import, "RIGHT", 6, 0)
	f.edit = T.Button(f, "", 110, 20, function()
		SUI.Menu.Show("all")
		SUI.Menu.Open("cat", "style")
	end)
	f.edit:SetPoint("LEFT", f.export, "RIGHT", 6, 0)
	f.reset = T.Button(f, "", 70, 20, function()
		S.ResetOverrides()
		SUI.Print(L("msg.style.reset"))
		P.Render()
	end)
	f.reset:SetPoint("LEFT", f.edit, "RIGHT", 6, 0)
	tinsert(UISpecialFrames, "ShikiUI_Styles")
	C.Watch("style.", function() if P.frame and P.frame:IsShown() then P.Render() end end)
	C.Watch("layout", function() if P.frame and P.frame:IsShown() then P.Render() end end)
	C.Watch("", function(key) if key == nil and P.frame and P.frame:IsShown() then P.Render() end end)
	return f
end

function P.Show()
	if not P.frame and SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return false
	end
	P.Build()
	P.frame:Show()
	P.Render()
	return true
end

function P.Hide()
	if P.frame then P.frame:Hide() end
end

function P.Toggle()
	if P.frame and P.frame:IsShown() then P.Hide() else P.Show() end
end
