-- ShikiUI Ghosts : compteur de fantomes du set "Possessions of the Lost" (necropaladin).
-- Chaque declenchement du set invoque un fantome pour 20 s ("You cast Summon The Lost." dans le journal de combat) : on compte les
-- invocations encore vivantes, sans plafond (1 a X), et on affiche le temps restant du plus ancien. Aucune API serveur : uniquement
-- les messages du chat du joueur (CHAT_MSG_SPELL_SELF_BUFF / _DAMAGE). Fenetre deplaceable (Mover, cle "ghosts.win").
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor = math.floor
local slower, sformat, sfind = string.lower, string.format, string.find

local M = {}
SUI.Ghosts = M

M.on = false
M.procs = {}          -- dates d'expiration des fantomes encore actifs (ordre croissant)
M.total = 0           -- invocations vues depuis la connexion
M.best = 0            -- record de fantomes simultanes
M.win = nil

local EVENTS = { "CHAT_MSG_SPELL_SELF_BUFF", "CHAT_MSG_SPELL_SELF_DAMAGE" }
local ICON = "Interface\\Icons\\Spell_Shadow_AnimateDead"

-- le message annonce-t-il l'invocation d'un fantome ? ("You cast Summon The Lost." ; les lignes du fantome lui-meme
-- "The Lost (Nom) ..." et le butin "... of the Lost" ne comptent pas)
function M.IsSummon(msg)
	if type(msg) ~= "string" then return false end
	local low = slower(msg)
	if sfind(low, "summon the lost", 1, true) then return true end
	if sfind(low, "the lost", 1, true) and (sfind(low, "^you cast") or sfind(low, "^vous lancez")) then return true end
	return false
end

function M.Duration()
	return C.Get("ghosts.duration") or 20
end

-- Retire les fantomes expires ; retourne (nombre actif, secondes restantes du plus ancien).
function M.Count(now)
	now = now or GetTime()
	local p = M.procs
	while getn(p) > 0 and p[1] <= now do tremove(p, 1) end
	local n = getn(p)
	if n == 0 then return 0, 0 end
	return n, p[1] - now
end

function M.Add(now)
	now = now or GetTime()
	M.Count(now)
	local e = now + M.Duration()
	local p = M.procs
	local i = getn(p) + 1
	while i > 1 and p[i - 1] > e do i = i - 1 end   -- reste trie (la duree peut changer entre deux invocations)
	tinsert(p, i, e)
	M.total = M.total + 1
	local n = getn(p)
	if n > M.best then M.best = n end
	M.Paint()
end

function M.Reset()
	M.procs = {}
	M.Paint()
end

function M.OnEvent(ev, msg)
	if not M.on then return end
	if M.IsSummon(msg) then M.Add() end
end

function M.Paint()
	local f = M.win
	if not f then return end
	local n, left = M.Count()
	if n == 0 and C.Get("ghosts.hide") then
		f:Hide()
		return
	end
	f.num:SetText(n)
	if n > 0 then
		f.icon:SetVertexColor(1, 1, 1, 1)                 -- style:ok texture du jeu non teintee
		f.timer:SetText(sformat("%ds", floor(left + 0.5)))
		f.num:SetTextColor(T.c.good[1], T.c.good[2], T.c.good[3], 1)
	else
		f.icon:SetVertexColor(0.35, 0.35, 0.35, 1)        -- style:ok icone grisee = teinte neutre de texture du jeu
		f.timer:SetText("")
		f.num:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	end
	f:Show()
end

function M.Build()
	if M.win then return end
	local s = C.Get("ghosts.size") or 30
	local f = T.Panel(UIParent, s + 50, s + 10)
	f:SetFrameStrata("LOW")
	f:EnableMouse(false)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetTexture(ICON)
	f.icon:SetWidth(s)
	f.icon:SetHeight(s)
	f.icon:SetPoint("LEFT", f, "LEFT", 5, 0)
	f.num = T.Text(f, 18, T.c.good, "LEFT", true)
	f.num:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, 0)
	f.timer = T.Text(f, 11, T.c.text, "LEFT", true)
	f.timer:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 6, 0)
	f:Hide()
	M.win = f
	SUI.Mover.Register("ghosts.win", f, { label = L("mod.ghosts.title"), point = "CENTER", x = 0, y = -120, scale = true })
	M.ApplyOptions()
end

function M.ApplyOptions()
	local f = M.win
	if not f then return end
	local s = C.Get("ghosts.size") or 30
	f:SetWidth(s + 50)
	f:SetHeight(s + 10)
	f.icon:SetWidth(s)
	f.icon:SetHeight(s)
	M.Paint()
end

function M.Tick()
	if M.win then M.Paint() end
end

function M.OnKey(key, value)
	M.ApplyOptions()
end

function M.Enable()
	M.on = true
	for i = 1, getn(EVENTS) do SUI.On(EVENTS[i], M.OnEvent) end
	SUI.WhenSafe(function()
		M.Build()
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(0.25, M.Tick, "ghosts.tick", true)
		M.Paint()
	end)
	if not M.watching then
		M.watching = true
		C.Watch("ghosts.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	if M.win then M.win:Hide() end
end

SUI.RegisterCategory("ghosts", 78)

local function opt(key, typ, order, def, extra)
	local o = { key = "ghosts." .. key, type = typ, cat = "ghosts", label = "opt.ghosts." .. key, tip = "tip.ghosts." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("ghosts", {
	default = false,
	cost = "light",
	options = {
		opt("hide", "bool", 10, false, { simple = true }),
		opt("size", "number", 20, 30, { min = 20, max = 64, step = 2, simple = true }),
		opt("duration", "number", 30, 20, { min = 5, max = 60, step = 1 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("ghosts", function(rest)
	local w = slower(rest or "")
	if w == "reset" then
		M.Reset()
		SUI.Print(L("msg.ghosts.reset"))
		return
	end
	if not C.Get("modules.ghosts") then C.Set("modules.ghosts", true) end
	SUI.Print(L("msg.ghosts.status", M.Count(), M.total, M.best))
end, "help.ghosts")
