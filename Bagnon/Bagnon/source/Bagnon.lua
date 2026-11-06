--[[
	Bagnon
		Displays the player's inventory in a single frame
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

if not Bagnon_EngineReady then
	return
end

local bBagSlotButton_OnEnter, bMainBag_OnEnter, bKeyRingButton_OnEnter;
local bBagSlotButton_OnClick, bKeyRingButton_OnClick, bMainBag_OnClick;

--[[ Loading Functions ]]--

function Bagnon_OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

--[[ Event Handler ]]--

function Bagnon_OnEvent(self, ev, a1)
	if ( ev == "ADDON_LOADED" and a1 == "Bagnon" ) then
		Bagnon:UnregisterEvent("ADDON_LOADED");
		Bagnon_Load();
	end
end

function Bagnon_Load()
	local bankTex = "Interface\\AddOns\\Bagnon\\assets\\bank.blp"
	BagnonOpenBank:SetNormalTexture(bankTex)
	BagnonOpenBank:SetPushedTexture(bankTex)

	local sortTex = "Interface\\AddOns\\Bagnon\\assets\\sort.blp"
	BagnonSortButton:SetNormalTexture(sortTex)
	BagnonSortButton:SetPushedTexture(sortTex)

	BagnonFrame_Load(Bagnon, {-2, 0, 1, 2, 3, 4}, BAGNON_INVENTORY_TITLE);
	Bagnon_AddBagHooks();
end

--[[ UI Functions ]]--

--OnShow
function Bagnon_OnShow()
	MainMenuBarBackpackButton:SetChecked(1);
	PlaySound("igBackPackOpen");
	BagnonFrame_UpdateFreeSlots(Bagnon);
end

--OnHide
function Bagnon_OnHide()
	MainMenuBarBackpackButton:SetChecked(0);
	PlaySound("igBackPackClose");
end

--Show Bags
function Bagnon_ToggleBags(btn)
	if( not BagnonBags:IsShown() ) then
		BagnonBags:Show();
		BagnonSets["Bagnon"].bagsShown = 1;
		btn:SetText(BAGNON_HIDEBAGS)
	else
		BagnonBags:Hide();
		BagnonSets["Bagnon"].bagsShown = 0;
		btn:SetText(BAGNON_SHOWBAGS)
	end

	BagnonFrame_TrimToSize(Bagnon);
end

function Bagnon_ViewBank()
	BagnonFrame_Toggle("Banknon")
end

--[[ Bag Overrides ]]--

function Bagnon_AddBagHooks()
	bMainBag_OnEnter = MainMenuBarBackpackButton:GetScript("OnEnter");
	bMainBag_OnClick = MainMenuBarBackpackButton:GetScript("OnClick");
	MainMenuBarBackpackButton:SetScript("OnEnter", BagnonBlizMainBag_OnEnter);
	MainMenuBarBackpackButton:SetScript("OnLeave", BagnonBlizBag_OnLeave);
	MainMenuBarBackpackButton:SetScript("OnClick", BagnonBlizMainBag_OnClick);

	bBagSlotButton_OnEnter = BagSlotButton_OnEnter;
	BagSlotButton_OnEnter = BagnonBlizBag_OnEnter;
	bBagSlotButton_OnClick = CharacterBag0Slot:GetScript("OnClick");
	for i = 0, 3 do
		_G["CharacterBag" .. i .. "Slot"]:SetScript("OnLeave", BagnonBlizBag_OnLeave);
		_G["CharacterBag" .. i .. "Slot"]:SetScript("OnClick", BagnonBlizBag_OnClick);
	end

	bKeyRingButton_OnEnter = KeyRingButton:GetScript("OnEnter");
	bKeyRingButton_OnClick = KeyRingButton:GetScript("OnClick");
	KeyRingButton:SetScript("OnEnter", BagnonBlizKeyRing_OnEnter);
	KeyRingButton:SetScript("OnLeave", BagnonBlizBag_OnLeave);
	KeyRingButton:SetScript("OnClick", BagnonBlizKeyRing_OnClick);
end

--Main Bag
function BagnonBlizMainBag_OnEnter()
	if( Bagnon:IsShown() ) then
		BagnonFrame_HighlightSlots(Bagnon, this:GetID());
	end
	bMainBag_OnEnter();
	if C_Container.GetBackpackAutosortDisabled() then
		GameTooltip:AddLine("|cffff6060" .. BAGNON_AUTOSORT_IGNORED .. "|r");
	end
	GameTooltip:AddLine(BAGNON_AUTOSORT_TOGGLE_IGNORE, 0.6, 0.8, 1);
	GameTooltip:Show();
end

function BagnonBlizMainBag_OnClick()
	if (IsAltKeyDown() or (arg1 == "RightButton" and not CursorHasItem())) then
		Bagnon_ToggleSortIgnore(BagnonBags0)
		if GameTooltip:IsOwned(this) then
			BagnonBlizMainBag_OnEnter()
		end
	elseif( IsShiftKeyDown() ) then
		BagnonFrame_ToggleBag(Bagnon, this:GetID());
	else
		bMainBag_OnClick();
	end
end

--Normal Bags
function BagnonBlizBag_OnEnter()
	if(Bagnon:IsShown() ) then
		BagnonFrame_HighlightSlots(Bagnon, this:GetID() - 19);
	end

	bBagSlotButton_OnEnter();
end

function BagnonBlizBag_OnClick()
	if( IsShiftKeyDown() ) then
		BagnonFrame_ToggleBag(Bagnon, this:GetID() - 19);
	else
		bBagSlotButton_OnClick();
	end
end

function BagnonBlizBag_OnLeave()
	GameTooltip:Hide();
	BagnonFrame_UnhighlightAll(Bagnon);
end

--KeyRing
function BagnonBlizKeyRing_OnEnter()
	if(Bagnon:IsShown() ) then
		BagnonFrame_HighlightSlots(Bagnon, this:GetID());
	end
	bKeyRingButton_OnEnter();
end

function BagnonBlizKeyRing_OnClick()
	if( IsShiftKeyDown() ) then
		BagnonFrame_ToggleBag(Bagnon, this:GetID());
	else
		bKeyRingButton_OnClick();
	end
end
