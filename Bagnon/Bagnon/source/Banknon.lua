--[[
	Banknon
		Combines the player's bank into a single frame
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

if not Bagnon_EngineReady then
	return
end

--[[ Loading Functions ]]--

function Banknon_OnLoad(self)
	--Create the confirmation dialog when purchasing a bank slot
	StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_BANKNON"] = {
		text = TEXT(CONFIRM_BUY_BANK_SLOT),
		button1 = TEXT(YES),
		button2 = TEXT(NO),

		OnAccept = function() PurchaseSlot() end,

		OnShow = function()
			MoneyFrame_Update(this:GetName().."MoneyFrame", GetBankSlotCost(GetNumBankSlots()))
		end,

		hasMoneyFrame = 1,
		timeout = 0,
		hideOnEscape = 1,
	}
	self:RegisterEvent("ADDON_LOADED")
end

--[[ Event Handler ]]--

function Banknon_OnEvent(f, ev, a1)
	if ev == "PLAYER_MONEY" or ev == "PLAYERBANKBAGSLOTS_CHANGED" then
		if f:IsShown() then
			Banknon_UpdateSlotCost()
		end
	elseif ev == "ADDON_LOADED" and a1 == "Bagnon" then
		f:UnregisterEvent("ADDON_LOADED")
		Banknon_Load(f)
	end
end

function Banknon_Load(frame)
	local sortTex = "Interface\\AddOns\\Bagnon\\assets\\sort.blp"
	local sortBtn = _G[frame:GetName() .. "SortButton"]
	sortBtn:SetNormalTexture(sortTex)
	sortBtn:SetPushedTexture(sortTex)

	BagnonFrame_Load(frame, {-1, 5, 6, 7, 8, 9, 10}, BAGNON_BANK_TITLE)

	frame:RegisterEvent("PLAYER_MONEY")
	frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

	Banknon_UpdateSlotCost()
end

--[[ UI Functions ]]--

--OnShow
function Banknon_OnShow()
	Banknon_UpdatePurchaseButtonVis()
	PlaySound("igMainMenuOpen")
	BagnonFrame_UpdateFreeSlots(Banknon)
end

--OnHide
function Banknon_OnHide()
	PlaySound("igMainMenuClose")
	if Bagnon_AtBank() then
		CloseBankFrame()
	end
end

--[[ Bank Slots functions ]]--

--Show/Hide the bag frame
function Banknon_ToggleSlots(btn)
	if not BanknonBags:IsShown() then
		BanknonBags:Show()
		BagnonSets["Banknon"].bagsShown = 1
		btn:SetText(BAGNON_HIDEBAGS)
	else
		BanknonBags:Hide()
		BagnonSets["Banknon"].bagsShown = 0
		btn:SetText(BAGNON_SHOWBAGS)
	end

	Banknon_UpdatePurchaseButtonVis(BagnonSets["Banknon"].bagsShown ~= 1)
end

function Banknon_UpdateSlotCost()
	local numSlots, full = GetNumBankSlots()
	if full then
		BanknonPurchase:Hide()
		BanknonCost:Hide()
		return
	end

	local cost = GetBankSlotCost(numSlots)
	if cost then
		if GetMoney() >= cost then
			SetMoneyFrameColor("BanknonCost", 1.0, 1.0, 1.0)
		else
			SetMoneyFrameColor("BanknonCost", 1.0, 0.1, 0.1)
		end
		MoneyFrame_Update("BanknonCost", cost)
	end

	Banknon_UpdatePurchaseButtonVis()
end

--yes, magic numbers are bad
function Banknon_UpdatePurchaseButtonVis(hide)
	if BanknonBags:IsVisible() or hide then
		local _, full = GetNumBankSlots()
		if Bagnon_AtBank() and not (full or hide) and (not Banknon.player or Banknon.player == UnitName("player")) then
			BanknonPurchase:Show()
			BanknonCost:Show()
			BanknonBags:SetHeight(68)
		else
			BanknonPurchase:Hide()
			BanknonCost:Hide()
			BanknonBags:SetHeight(42)
		end
	end
	BagnonFrame_TrimToSize(Banknon)
end
