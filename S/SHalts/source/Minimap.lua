-------------------------------------------------------------------------------
-- SHAlts minimap button. Left-click opens the window, right-click and drag
-- moves it around the minimap. The logo does its quick spin on the same beat
-- as the window portrait, but the ring stays still here.
-------------------------------------------------------------------------------
local S = SHAlts

S.Try("Minimap.lua", function()

local button = CreateFrame("Button", "SHAltsMinimapButton", Minimap)
button:SetWidth(31); button:SetHeight(31)   -- the usual size, so button bars treat it like the rest
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- the portrait has its own ring, so no minimap border; a little smaller than
-- the button so its ring matches the gold ring on other buttons
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetWidth(28); icon:SetHeight(28)
icon:SetPoint("CENTER", button, "CENTER", 0, 0)
icon:SetTexture(S.MEDIA .. "Logo")
S.AddSpin(icon, button, "logo")

-- the ring is not registered for spinning. Angle 0 keeps the same zoom as
-- the logo so the two line up.
local ring = button:CreateTexture(nil, "OVERLAY")
ring:SetAllPoints(icon)
ring:SetTexture(S.MEDIA .. "LogoRing")
S.SetSpinAngle(ring, 0)

function S.UpdateMinimapButton()
	local db = S.db or {}
	local angle = math.rad(db.minimapPos or 225)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
	if db.minimapHidden then button:Hide() else button:Show() end
end

button:RegisterForClicks("LeftButtonUp")
button:SetScript("OnClick", function() S.UI.Toggle() end)

-- The hover display: this character's reset timers, everyone's raid lockouts
-- and any cooldowns that are ready. It is redrawn once a second while the
-- mouse stays on the button, so the timers count down.
function S.ShowMinimapTip()
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText("SHAlts")
	if S.db then
		local total, n = S.TotalGold()
		GameTooltip:AddLine(n .. " characters, " .. S.FormatMoney(total), 1, 1, 1)

		local me = S.db.chars[S.CharKey()]
		if me and S.ResetView then
			local view = S.ResetView(me)
			local now = time()
			local coin = 0
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Instance resets   " .. table.getn(view) .. " / " .. S.MAX_RESETS, 1, .82, 0)
			for i = 1, S.MAX_RESETS do
				local e = view[i]
				if e then
					coin = coin + (e.coin or 0)
					GameTooltip:AddDoubleLine("Reset " .. i .. "   |cff33ff99" .. S.FormatClock(S.RESET_DURATION - (now - e.t)) .. "|r",
						S.MoneyGSC(e.coin), 1, 1, 1, 1, 1, 1)
				else
					GameTooltip:AddLine("Reset " .. i .. "   cleared", .47, .47, .47)
				end
			end
			GameTooltip:AddDoubleLine("Lockout total", S.MoneyGSC(coin), 1, .82, 0, 1, 1, 1)
		end

		-- raid lockouts, only for characters that have one
		local locked = {}
		local chars = S.SortedChars()
		for i = 1, table.getn(chars) do
			local locks = S.LockView(chars[i].c)
			if table.getn(locks) > 0 then
				local parts = {}
				for j = 1, table.getn(locks) do
					table.insert(parts, locks[j].n .. " " .. S.FormatDuration(locks[j].e - time()))
				end
				table.insert(locked, { S.ColoredName(chars[i].c), table.concat(parts, ", ") })
			end
		end
		GameTooltip:AddLine(" ")
		if table.getn(locked) > 0 then
			GameTooltip:AddLine("Raid lockouts", 1, .82, 0)
			for i = 1, table.getn(locked) do
				GameTooltip:AddDoubleLine(locked[i][1], locked[i][2], 1, 1, 1, .8, .8, .8)
			end
		else
			GameTooltip:AddLine("No characters are raid locked", .25, 1, .25)
		end

		local ready = S.ReadyList()
		if table.getn(ready) > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Cooldowns ready:", 1, .82, 0)
			for i = 1, table.getn(ready) do GameTooltip:AddLine(ready[i], 1, 1, 1) end
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Click to open", .6, .6, .6)
	GameTooltip:AddLine("Right-click and drag to move", .6, .6, .6)
	GameTooltip:Show()
end

button:SetScript("OnEnter", function()
	S.minimapHover = true
	S.ShowMinimapTip()
end)
button:SetScript("OnLeave", function()
	S.minimapHover = false
	GameTooltip:Hide()
end)

-- a short flash on the button, used by the reset alerts
function S.FlashMinimapButton()
	if not button.flash then
		local f = button:CreateTexture(nil, "OVERLAY")
		f:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		f:SetBlendMode("ADD")
		f:SetWidth(34); f:SetHeight(34)
		f:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.flash = f
	end
	if UIFrameFlash then UIFrameFlash(button.flash, 0.3, 0.3, 2.4, false, 0, 0.3) end
end

button:RegisterForDrag("RightButton")
button:SetScript("OnDragStart", function()
	this:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		S.db.minimapPos = math.deg(math.atan2(py - my, px - mx))
		S.UpdateMinimapButton()
	end)
end)
button:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

S.On("PLAYER_LOGIN", function() S.UpdateMinimapButton() end)

end)
