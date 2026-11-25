-- ShikiUI Datatext : blocs d'information cote a cote (or, durabilite, heure, FPS, latence, experience),
-- dans UNE fenetre deplaceable (Mover, cle "datatext.win"), mise a jour par une minuterie d'une seconde.
-- Chaque bloc est active/coche dans les reglages ; un bloc vide ne prend pas de place.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local getn, tinsert, max = table.getn, table.insert, math.max
local floor = math.floor
local sformat, strsub = string.format, string.sub

local M = {}
SUI.Datatext = M

M.on = false
M.win = nil
M.cells = {}            -- key -> FontString
M.btns = {}             -- key -> Button (zone de clic du bloc)

local cfg = {}

-- liste des blocs : cle, ordre d'affichage, lecteur -> texte court. P.seuil = texte en jaune si "!" en tete.
M.BLOCKS = {
	{ key = "money", fn = function()
		local m = getglobal("GetMoney")
		if not m then return "" end
		local gold = floor(m() / 10000)
		return sformat("%dg", gold)
	end },
	{ key = "durab", fn = function()
		local gf = getglobal("GetInventoryItemDurability")
		if not gf then return "-" end
		-- le client Turtle/OctoWow definit GetInventoryItemDurability(invSlot) : UN seul argument ; un emplacement vide renvoie nil (pas une erreur).
		-- La forme a deux arguments (unite, emplacement) n'est essayee qu'UNE fois par session, si la forme simple n'a rien donne.
		local function sum(two)
			local cur, mx = 0, 0
			for slot = 1, 16 do
				local ok, c, m
				if two then ok, c, m = pcall(gf, "player", slot) else ok, c, m = pcall(gf, slot) end
				if ok and c and m then cur = cur + c ; mx = mx + m end
			end
			return cur, mx
		end
		local cur, mx = 0, 0
		if M.durTwo then
			cur, mx = sum(true)
		else
			cur, mx = sum(false)
			if mx <= 0 and not M.durTried then
				M.durTried = true
				local c2, m2 = sum(true)
				if m2 > 0 then M.durTwo = true cur, mx = c2, m2 end
			end
		end
		if mx <= 0 then return "-" end
		local pct = floor(cur * 100 / mx + 0.5)
		if pct <= 30 then return "! " .. pct .. "%" end   -- "! " = alerte (retire a l'affichage)
		return pct .. "%"
	end },
	{ key = "clock", fn = function()
		local gt = getglobal("GetGameTime")
		if not gt then return date("%H:%M") end
		local h, m = gt()
		return sformat("%02d:%02d", h, m)
	end },
	{ key = "fps", fn = function()
		local p = SUI.Perf
		if not p or not p.fps then return "" end
		return sformat("%d fps", p.fps)
	end },
	{ key = "latency", fn = function()
		local p = SUI.Perf
		if not p or not p.lat then return "" end
		return sformat("%d ms", p.lat)
	end },
	{ key = "meters", fn = function()
		if not (SUI.Meter and SUI.Meter.ToggleAll) then return "" end
		return L("msg.datatext.meters")
	end },
	{ key = "xp", fn = function()
		local ux, um = getglobal("UnitXP"), getglobal("UnitXPMax")
		if not ux or not um then return "" end
		local lv = getglobal("UnitLevel")
		if lv and (lv("player") or 0) >= 60 then return "" end
		local cur, mx = ux("player"), um("player")
		if not mx or mx <= 0 then return "" end
		return sformat("%d%%", floor(cur * 100 / mx + 0.5))
	end },
}

function M.ReadConfig()
	for i = 1, getn(M.BLOCKS) do
		local e = M.BLOCKS[i]
		cfg[e.key] = C.Get("datatext." .. e.key)
	end
	cfg.scale = C.Get("datatext.scale") or 100
end

function M.Build()
	if M.win then return end
	local f = T.Panel(UIParent, 220, 20)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(30)   -- au-dessus de la zone du chat (qui avale les clics a cet endroit)
	f:EnableMouse(false)
	f:Hide()
	if f.SetClampedToScreen then f:SetClampedToScreen(true) end   -- une position enregistree hors ecran (autre echelle) ne doit pas la perdre
	M.win = f
	SUI.Mover.Register("datatext.win", f, { label = L("mod.datatext.title"), point = "BOTTOMLEFT", x = 220, y = 6, scale = true })
	M.built = true
	M.ApplyOptions()
end

-- un bloc : texte colore (jaune si le lecteur a prefixe "!"), avec son libelle court devant
local function paintCell(fs, key, text)
	if not fs then return end
	local val = text or ""
	if strsub(val, 1, 2) == "! " then
		fs:SetText(strsub(val, 3))
		local y = T.c.warn
		fs:SetTextColor(y[1], y[2], y[3], 1)
	else
		fs:SetText(val)
		local x = T.c.text
		fs:SetTextColor(x[1], x[2], x[3], 1)
	end
	fs:SetWidth(200)
end

function M.ApplyOptions()
	if not M.win then return end
	M.ReadConfig()
	-- scale (70-160) : applique au cadre ; la compensation d'echelle du Mover garde la place
	if M.win.SetScale then
		M.win:SetScale((cfg.scale or 100) / 100)
	end
	-- cellules creees une fois par bloc (pool) : on montre les actives dans l'ordre de BLOCKS
	local x = 0
	local wide = 0
	for i = 1, getn(M.BLOCKS) do
		local e = M.BLOCKS[i]
		local fs = M.cells[e.key]
		if cfg[e.key] then
			if not fs then
				fs = T.Text(M.win, 11, T.c.text, "LEFT")
				M.cells[e.key] = fs
			end
			-- clic sur un bloc : ouvre la fenetre correspondante (confort). Un FontString n'a pas de SetScript en 1.12 : bouton dedie.
			M.win:EnableMouse(true)
			local btn = M.btns[e.key]
			if not btn then
				btn = CreateFrame("Button", nil, M.win)
				btn.clickKey = e.key
				btn:SetScript("OnClick", function()
					local k = this.clickKey
					if k == "money" and ToggleBackpack then ToggleBackpack() end
					if k == "durab" and ToggleCharacter then ToggleCharacter("PaperDollFrame") end
					if k == "meters" and SUI.Meter and SUI.Meter.ToggleAll then SUI.Meter.ToggleAll() end
					if k == "xp" and ToggleCharacter then ToggleCharacter("PaperDollFrame") end
					if k == "fps" and SUI.Perf and SUI.Perf.SetProfile then SUI.Perf.SetProfile(not SUI.Perf.profile) end
				end)
				M.btns[e.key] = btn
			end
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", M.win, "LEFT", 6 + x, 0)
			fs:SetHeight(16)
			local text = e.fn()
			paintCell(fs, e.key, text)
			local w = fs:GetStringWidth() + 24
			fs:SetWidth(w)
			fs:Show()
			btn:ClearAllPoints()
			btn:SetPoint("LEFT", M.win, "LEFT", 6 + x, 0)
			btn:SetWidth(w)
			btn:SetHeight(16)
			btn:Show()
			x = x + w
			wide = wide + w
		elseif fs then
			fs:Hide()
			if M.btns[e.key] then M.btns[e.key]:Hide() end
		end
	end
	M.win:SetWidth(max(wide, 20))
	M.win:SetHeight(20)
	local st = M.win:IsShown()
	if M.active and wide > 0 then
		if not st then M.win:Show() end
	elseif st then
		M.win:Hide()
	end
end

function M.Tick()
	if not M.active or not M.win or not M.win:IsShown() then return end
	M.ApplyOptions()
end

function M.Activate()
	M.active = true
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(1, M.Tick, "datatext.tick", true)
	M.ApplyOptions()
end

function M.Deactivate()
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	if M.win then M.win:Hide() end
end

function M.OnKey(key, value)
	M.ApplyOptions()
end

function M.Enable()
	SUI.WhenSafe(function()
		M.Build()
		M.Activate()
	end)
	if not M.watching then
		M.watching = true
		C.Watch("datatext.", M.OnKey)
	end
end

function M.Disable()
	M.Deactivate()
end

SUI.RegisterCategory("datatext", 73)

local function opt(key, typ, order, def, extra)
	local o = { key = "datatext." .. key, type = typ, cat = "datatext", label = "opt.datatext." .. key, tip = "tip.datatext." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("datatext", {
	default = false,
	cost = "light",
	options = {
		opt("money", "bool", 10, true, { simple = true }),
		opt("durab", "bool", 20, true, { simple = true }),
		opt("clock", "bool", 30, true, { simple = true }),
		opt("fps", "bool", 40, false, { simple = true }),
		opt("latency", "bool", 50, false, { simple = true }),
		opt("xp", "bool", 60, false, { simple = true }),
		opt("meters", "bool", 65, true, { simple = true }),
		opt("scale", "number", 70, 100, { min = 70, max = 160, step = 5 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("datatext", function()
	if not C.Get("modules.datatext") then C.Set("modules.datatext", true) end
	if M.win then
		if M.win:IsShown() then M.win:Hide() else M.win:Show() end
		-- etat reel (diagnostic : ou est la barre, de quelle taille)
		SUI.Print("datatext: " .. (M.win:IsShown() and "visible" or "masque") .. " largeur=" .. floor(M.win:GetWidth() or 0)
			.. " echelle=" .. string.format("%.2f", M.win:GetEffectiveScale() or 0) .. " ecran=" .. floor(UIParent:GetWidth() or 0) .. "x" .. floor(UIParent:GetHeight() or 0) .. " gauche=" .. floor(M.win:GetLeft() or -1) .. " bas=" .. floor(M.win:GetBottom() or -1) .. " actif=" .. tostring(M.active))
	else
		SUI.Print("datatext: fenetre non creee (module " .. (C.Get("modules.datatext") and "actif" or "coupe") .. ")")
	end
end, "help.datatext")
