-------------------------------------------------------------------------------------------------------
-- Arcanum

-- Addon for Mage inspired by the famous Necrosis
-- Management of buffs, portals and Component Counter

-- Thanks to the authors of Necrosis

-- Author Lenny415
-- Reworked by Fayz for Turtle WoW
------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------

-- GENERAL FUNCTIONS RELATED TO THE XML FILE

------------------------------------------------------------------------------------------------------

Default_ArcanumConfig = {
	Version = ArcanumData.Version;
	ChatType = true;
	Tooltip = 2;
	HideInCombat = true;
	OrangesMessage = true;
	PortalMessage = false;
	InsideDisplay = 1;
	Display = { true, --DisplayHearthstone
	            true, --DisplayManaGem
	            true, --DisplayEvocation
	            true, --DisplayIceBlock
	            true, --DisplayColdSnap
	            true, --DisplayIntell
	            true, --DisplayArmor
	            true, --DisplayBandage
	};
	HealthColor = {
		r = 0,
		g = 1,
		b = 0,
	};
	ManaColor = {
		r = 0,
		g = 0,
		b = 1,
	};
	ButtonColor = {
		r = 0,
		g = 1,
		b = 1,
	};

	MinimapIcon = true;
	MinimapIconPos = 360;

	EvocationLimit = 20;
	LevelBuff = true;
	ConsumeFood = "Right";

	ReagentSort = true;
	ReagentContainer = 3;
	ReagentBuy = true;
	Powder = 20;
	Teleport = 10;
	Portal = 10;

	InterfaceVersion = 2;
	BuffType = 0;
	BuffButton = true;
	ArmorButton = true;
	PortalButton = true;
	FoodButton = true;
	WaterButton = true;
	ManaGemButton = true;
	HearthstoneButton = true;
	KarazhanButton = true;
	LeftClick = 1;
	MiddleClick = 8;
	RightClick = 3;
	ButtonsOrder = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

	LastBuff = 4;
	LastArmor = 2;
	LastMagic = 7;
	LastPortal = 1;

	ArcanumLockServ = true;
	Toggle = true;
	NoDragAll = false;
	BuffMenuPos = "x";
	ArmorMenuPos = "x";
	MagicMenuPos = "x";
	PortalMenuPos = "x";
	MountMenuPos = "x";
	ArcanumButtonxPos = 550;
	ArcanumButtonyPos = 450;
	ArcanumButtonScale = 100;
	ArcanumAngle = 108;

	ArcanumLanguage = GetLocale();
}

local isHidden = false;
local hiddenByUser = false;
local firstLoad = true;

-- Variables used for component management
-- (mainly counting)
local ArcanumArcanePowder = nil;
local ArcanumRuneOfTeleportation = nil;
local ArcanumRuneOfPortals = nil;
local ArcanumLightFeathers = nil;
local ReagentBought = false;

local LastItemsCount = nil;
local FoodLocationCount, WaterLocationCount;
local WaterCount = nil;
local WaterLocation = { nil, nil, nil };
local FoodCount = nil;
local FoodLocation = { nil, nil, nil };
local OrangeCount = nil;
local ManaGemCount = nil;
local ManaGemExists = { nil, nil, nil, nil };
local ManaGemLocation = { { nil, nil }, { nil, nil }, { nil, nil }, { nil, nil } };

local IceblockDone = false;
local IceblockWait = false;
local IceblockWaitTimer = nil;
local HearthstoneLocation = { nil, nil };
local AtieshLocation = { nil, nil };
local AtieshEquipped = false;
local AtieshEquipTime = 0; -- GetTime() when Atiesh was last detected as newly equipped
local AtieshCooldown = 0;
local AtieshUsed = false; -- Track when Atiesh use is initiated
local HearthstoneCooldown = 0; -- Track Hearthstone cooldown (60 min)
local HearthstoneUsed = false; -- Track when Hearthstone use is initiated
local HearthstoneUseTime = 0; -- Track when Hearthstone button was clicked
local PortalCooldown = {0, 0, 0, 0}; -- Cooldowns for portal buttons 7, 8, 9, 10
local MountLocation = { nil, nil };
local MountName = { nil };
local MountIcon = { nil };
local AQMountLocation = { nil, nil };
local AQMountName = { nil };
local AQMountIcon = { nil };
local MountAQ = nil;

local MerchantOpened = false;
local PlayerName, PlayerLevel = nil;
local Loaded = false;
local PlayerZone = nil;
local playerClass, englishClass = nil;

local TPMess = 0;
local TPMessTime = 0; -- Track when last portal message was sent
local OrangeMess = 0; -- Track last orange message to avoid repeats
local OrangeMessTime = 0; -- Track when last orange message was sent
local RandMount = 0;

-- Menus: Allows display of buff menus...
local BuffShow = false;
local BuffMenuShow = false;
local ArmorShow = false;
local ArmorMenuShow = false;
local MagicShow = false;
local MagicMenuShow = false;
local PortalShow = false;
local PortalMenuShow = false;
local MountShow = false;
local MountMenuShow = false;

-- Menus: Allows progressive fading of buff menu (transparency)
local AlphaBuffMenu = 1;
local AlphaBuffVar = 0;
local BuffVisible = false;

-- Menus: Allows progressive fading of armor menu (transparency)
local AlphaArmorMenu = 1;
local AlphaArmorVar = 0;
local ArmorVisible = false;

-- Menus: Allows progressive fading of magic menu (transparency)
local AlphaMagicMenu = 1;
local AlphaMagicVar = 0;
local MagicVisible = false;

-- Menus: Allows progressive fading of portal menu (transparency)
local AlphaPortalMenu = 1;
local AlphaPortalVar = 0;
local PortalVisible = false;

-- Menus: Allows progressive fading of mount menu (transparency)
local AlphaMountMenu = 1;
local AlphaMountVar = 0;
local MountVisible = false;

local AlphaDisplay = 1;
local AlphaDisplayVar = 0;
local DisplayFadingLimit = 0;
local DisplayFadingWay = -1;

-- List of available buttons for the mage in each menu
local BuffMenuCreate = {};
local ArmorMenuCreate = {};
local MagicMenuCreate = {};
local PortalMenuCreate = {};
local MountMenuCreate = {};

local xBuffMenuPos = nil;
local xArmorMenuPos = nil;
local xMagicMenuPos = nil;
local xPortalMenuPos = nil;
local xMountMenuPos = nil;
local yBuffMenuPos = nil;
local yArmorMenuPos = nil;
local yMagicMenuPos = nil;
local yPortalMenuPos = nil;
local yMountMenuPos = nil;

local UIPath = "Interface\\AddOns\\Arcanum\\UI\\"

local ArcanumLeftButtonClick = {};
local ArcanumMiddleButtonClick = {};
local ArcanumRightButtonClick = {};
local ArcanumInsideDisplayClick = {};

local Buff_Minlvl = { 1, 4, 17, 32, 46 };
local Amplify_Minlvl = { 18, 30, 42, 54 };
local Dampen_Minlvl = { 12, 24, 36, 48, 60 };
local Water_Minlvl = { 0, 5, 15, 25, 35, 45, 55, 60 };

local ArcanumTradeNB = 1;
local ArcanumTradeFoodNB = 1;
local ArcanumTradeWaterNB = 1;
local ArcanumTradeNow = false;
local ArcanumTradeOpened = false;
local ArcanumTradeAccept = false;
local ArcanumTradeAcceptT = 0;
local ArcanumTradeAcceptTimer = 1.5;

local IceblockReady = false;
local IceblockCounter = 0;

local SelectedOrderButton;

local ArcanumT = 0;
local ArcanumButtonDisplayT = 1;
local ArcanumButtonDisplayTimer = 10;
local ArcanumButtonDisplayValue = 1;
local ArcanumButtonDisplayImage = nil;
local ArcanumButtonDisplayFlashing = false;
local ArcanumButtonDisplayTexture;

local ArcanumButtonDisplayTexture = { nil, nil, nil, nil, nil, nil, nil, nil };
local CoolDown = {
	{ nil, true, HearthstoneLocation[1], HearthstoneLocation[2] },
	{ nil, true, ManaGemLocation[1][1], ManaGemLocation[1][2] },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[26], nil },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[32], nil },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[33], nil },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[26], nil },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[32], nil },
	{ nil, true, ARCANUM_SPELL_TABLE.ID[33], nil },
};
------------------------------------------------------------------------------------------------------

-- INTERFACE FUNCTIONS

------------------------------------------------------------------------------------------------------

-- Function applied at loading
function Arcanum_OnLoad()
	playerClass, englishClass = UnitClass("player");

	if englishClass == "MAGE" then
		this:RegisterForDrag("LeftButton");
		this:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp");

		-- Enregistrement des Ã©vÃ©nements interceptÃ©s par ARCANUM
		this:RegisterEvent("PLAYER_ENTERING_WORLD");
		this:RegisterEvent("PLAYER_LEAVING_WORLD");
		this:RegisterEvent("BAG_UPDATE");
		this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");
		this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF");
		this:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA");
		this:RegisterEvent("PLAYER_REGEN_DISABLED");
		this:RegisterEvent("PLAYER_REGEN_ENABLED");
		this:RegisterEvent("SPELLCAST_START");
		this:RegisterEvent("SPELLCAST_FAILED");
		this:RegisterEvent("SPELLCAST_INTERRUPTED");
		this:RegisterEvent("SPELLCAST_STOP");
		this:RegisterEvent("LEARNED_SPELL_IN_TAB");
		this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
		this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE");
		this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER");
		this:RegisterEvent("PLAYER_TARGET_CHANGED");
		this:RegisterEvent("TRADE_REQUEST");
		this:RegisterEvent("TRADE_REQUEST_CANCEL");
		this:RegisterEvent("TRADE_SHOW");
		this:RegisterEvent("TRADE_CLOSED");
		this:RegisterEvent("TRADE_ACCEPT_UPDATE");
		this:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED");
		this:RegisterEvent("MERCHANT_SHOW");
		this:RegisterEvent("MERCHANT_CLOSED");
		this:RegisterEvent("PLAYER_LEVEL_UP");


		-- Enregistrement des commandes console
		SlashCmdList["Arcanum"] = Arcanum_Slash;
		SLASH_Arcanum1 = "/arcanum";
		SLASH_Arcanum2 = "/arca";
	end
end

-- Initialization function
function Arcanum_Initialize()
	isHidden = false;
	if englishClass == "MAGE" then
		-- On charge (ou on crÃ©Ã©) la configuration pour le joueur et on l'affiche sur la console
		if ArcanumConfig == nil or ArcanumConfig.Version ~= Default_ArcanumConfig.Version then
			ArcanumConfig = {};
			ArcanumConfig = Default_ArcanumConfig;
			Arcanum_Localization_Dialog_En();
			ArcanumButton:ClearAllPoints();
		else
			Arcanum_Localization_Dialog_En();
		end

		-- Get fresh faction data (important for Turtle WoW High Elves/Goblins)
		local currentFaction, _ = UnitFactionGroup("player")
		ArcanumConfig.IsAlliance = (currentFaction == "Alliance");

		-- Recupertation du nom du joueur
		PlayerName = UnitName("player");
		PlayerLevel = UnitLevel("player");

		Arcanum_LoadConfig();

		-- Chargement des sorts du joueur
		Arcanum_SpellSetup();

		if ARCANUM_SPELL_TABLE.ID[2] == nil then
			ArcanumConfig.LastArmor = 1;
		end

		--Chargements de l'UI et dÃ©compte des composants
		local initialMainHandLink = GetInventoryItemLink("player", 16);
		AtieshEquipped = initialMainHandLink and string.find(initialMainHandLink, ARCANUM_ITEM.Atiesh);
		Arcanum_BagExplore();
		Arcanum_InitButtons();
		if ArcanumConfig.ArcanumLockServ then
			Arcanum_UpdateButtonsScale();
		end

		Arcanum_ButtonSetup();
		Arcanum_LoadIcons();
		ArcanumMinimapButtonTexture:SetTexture(ARCANUM_SPELL_TABLE.Texture[4]);
		ArcanumMinimapButtonTexture2:SetTexture(UIPath .. "ButtonCircle");
		ArcanumMinimapButtonTexture2:SetVertexColor(ArcanumConfig.ButtonColor.r, ArcanumConfig.ButtonColor.g, ArcanumConfig.ButtonColor.b);

		ArcanumButtonTexture:SetTexture(UIPath .. "ArcanumN");
		ArcanumOrderButtonTexture:SetTexture(UIPath .. "ArcanumN");
		ArcanumOrderButtonTexture2:SetTexture(UIPath .. "Overlay");
		ArcanumButtonTexture3:SetTexture(UIPath .. "Overlay");

		ArcanumFoodCount:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumWaterCount:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumManaGemCooldown:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton4Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton5Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton7Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton8Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton9Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
		ArcanumButton10Text:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")

		if not pfUI or not pfUI.addonbuttons then
			ArcanumMoveMinimapButton()
		end

		if ArcanumConfig.Toggle == false then
			Arcanum_HideUI();
			if firstLoad then
				Arcanum_Msg(ARCANUM_MESSAGE.Interface.InitOff, "USER");
			end
		elseif firstLoad then
			-- always shown in chat, never center-screen, regardless of the
			-- player's ChatType setting
			local msg = Arcanum_MsgAddColor(ARCANUM_MESSAGE.Interface.InitOn);
			local Intro = Arcanum_ColoredMsg("Arcanum").."|CFFFFFFFF: ";
			ChatFrame1:AddMessage(Intro..msg, 1.0, 0.7, 1.0, 1.0, UIERRORS_HOLD_TIME);
			firstLoad = false;
		end
	else
		ArcanumConfig = {};
		Arcanum_HideUI();
	end
end

-- Function allowing movement of Arcanum elements on screen
function Arcanum_OnDragStart(button)
	if (button == "ArcanumIcon") then
		GameTooltip:Hide();
	end

	button:StartMoving();
end

-- Function stopping movement of ARCANUM elements on screen
function Arcanum_OnDragStop(button)
	if (button == "ArcanumIcon") then
		Arcanum_BuildTooltip("OVERALL");
	end
	button:StopMovingOrSizing();
end

local tick = 1
-- Function launches interface update (main) -- approximately every 0.1 seconds
function Arcanum_OnUpdate()
	--Si c'est la premiere update on initialize
	if Loaded == false  then
		Arcanum_Initialize();
		Loaded = true;
	end

	if tick > GetTime() then
		return
	else
		tick = GetTime() + .2
	end

	if englishClass == "MAGE" then
		Arcanum_DisplayFading();
		ArcanumT = ArcanumT + arg1;
		
		-- Check if Hearthstone was used and has started its actual cooldown (not just the cast time)
		if HearthstoneUsed and HearthstoneLocation[1] ~= nil then
			local start, duration = GetContainerItemCooldown(HearthstoneLocation[1], HearthstoneLocation[2])
			-- Only set cooldown if the actual 60-minute cooldown has started (duration > 3000 seconds)
			-- This prevents triggering during the 10-second cast time
			if start > 0 and duration > 3000 then
				-- Hearthstone cooldown has started, set our tracking cooldown
				HearthstoneCooldown = GetTime() + duration
				HearthstoneUsed = false
			elseif HearthstoneUseTime > 0 and GetTime() - HearthstoneUseTime > 15 then
				-- Clear flag after 15 seconds if cast was interrupted
				HearthstoneUsed = false
				HearthstoneUseTime = 0
			end
		end
		
		-- Update Button 5 display: Hearthstone cooldown in solo mode, Atiesh cooldown in group mode
		if ArcanumConfig.BuffType == 0 then
			-- Solo mode: Show Hearthstone cooldown
			if HearthstoneCooldown > GetTime() then
				local remaining = math.ceil(HearthstoneCooldown - GetTime())
				if remaining > 60 then
					ArcanumButton5Text:SetText(tostring(math.ceil(remaining / 60)) .. "m")
				else
					ArcanumButton5Text:SetText(tostring(remaining) .. "s")
				end
				ArcanumButton5Text:Show()
			else
				ArcanumButton5Text:SetText("")
				ArcanumButton5Text:Hide()
			end
		else
			-- Group mode: Show Atiesh cooldown
			if AtieshCooldown > GetTime() then
				local remaining = math.ceil(AtieshCooldown - GetTime())
				if remaining > 60 then
					ArcanumButton5Text:SetText(tostring(math.ceil(remaining / 60)) .. "m")
				else
					ArcanumButton5Text:SetText(tostring(remaining) .. "s")
				end
				ArcanumButton5Text:Show()
			else
				ArcanumButton5Text:SetText("")
				ArcanumButton5Text:Hide()
			end
		end
		
		-- Update portal cooldown displays (buttons 7, 8, 9, 10)
		for i = 1, 4 do
			local buttonNum = i + 6 -- Button 7 = i+6 where i=1, Button 10 = i+6 where i=4
			local textElement = getglobal("ArcanumButton" .. buttonNum .. "Text")
			
			if PortalCooldown[i] > GetTime() then
				local remaining = math.ceil(PortalCooldown[i] - GetTime())
				if remaining > 60 then
					textElement:SetText(tostring(math.ceil(remaining / 60)) .. "m")
				else
					textElement:SetText(tostring(remaining) .. "s")
				end
				textElement:Show()
			else
				textElement:SetText("")
				textElement:Hide()
			end
		end
		
		if ArcanumT >= ArcanumButtonDisplayT then
			ArcanumButtonDisplayT = ArcanumButtonDisplayT + 0.5;
			Arcanum_Cooldown();
			ArcanumButton_TextDisplay();
		end

		if ArcanumT >= ArcanumButtonDisplayTimer then
			ArcanumButton_ImageDisplay();
			ArcanumT = 0;
			ArcanumButtonDisplayT = 1;
		end

		if ArcanumTradeAccept == true then
			ArcanumTradeAcceptT = ArcanumTradeAcceptT + arg1
			if ArcanumTradeAcceptT > ArcanumTradeAcceptTimer then
				ArcanumTradeAccept = false
				AcceptTrade();
			end
		end

		if IceblockDone == true then
			IceblockCounter = IceblockCounter + arg1;
			if IceblockCounter >= 3 then
				IceblockReady = true;
				IceblockCounter = 0;
			end
		end

		-- On met  jour la localisation du joueur
		PlayerZone = GetRealZoneText();
	end
end

function Arcanum_OnEvent(event)
	if (not Loaded) or englishClass ~= "MAGE" then
		return ;
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		this:RegisterEvent("BAG_UPDATE");
		this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");
		this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF");
		this:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA");
		this:RegisterEvent("PLAYER_REGEN_DISABLED");
		this:RegisterEvent("PLAYER_REGEN_ENABLED");
		this:RegisterEvent("SPELLCAST_START");
		this:RegisterEvent("SPELLCAST_FAILED");
		this:RegisterEvent("SPELLCAST_INTERRUPTED");
		this:RegisterEvent("SPELLCAST_STOP");
		this:RegisterEvent("LEARNED_SPELL_IN_TAB");
		this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
		this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE");
		this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER");
		this:RegisterEvent("PLAYER_TARGET_CHANGED");
		this:RegisterEvent("TRADE_REQUEST");
		this:RegisterEvent("TRADE_REQUEST_CANCEL");
		this:RegisterEvent("TRADE_SHOW");
		this:RegisterEvent("TRADE_CLOSED");
		this:RegisterEvent("TRADE_ACCEPT_UPDATE");
		this:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED");
		this:RegisterEvent("MERCHANT_SHOW");
		this:RegisterEvent("MERCHANT_CLOSED");
		this:RegisterEvent("PLAYER_LEVEL_UP");

	elseif (event == "PLAYER_LEAVING_WORLD") then
		this:UnregisterEvent("BAG_UPDATE");
		this:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");
		this:UnregisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF");
		this:UnregisterEvent("CHAT_MSG_SPELL_BREAK_AURA");
		this:UnregisterEvent("PLAYER_REGEN_DISABLED");
		this:UnregisterEvent("PLAYER_REGEN_ENABLED");
		this:UnregisterEvent("SPELLCAST_START");
		this:UnregisterEvent("SPELLCAST_FAILED");
		this:UnregisterEvent("SPELLCAST_INTERRUPTED");
		this:UnregisterEvent("SPELLCAST_STOP");
		this:UnregisterEvent("LEARNED_SPELL_IN_TAB");
		this:UnregisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
		this:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE");
		this:UnregisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER");
		this:UnregisterEvent("PLAYER_TARGET_CHANGED");
		this:UnregisterEvent("TRADE_REQUEST");
		this:UnregisterEvent("TRADE_REQUEST_CANCEL");
		this:UnregisterEvent("TRADE_SHOW");
		this:UnregisterEvent("TRADE_CLOSED");
		this:UnregisterEvent("TRADE_ACCEPT_UPDATE");
		this:UnregisterEvent("TRADE_PLAYER_ITEM_CHANGED");
		this:UnregisterEvent("MERCHANT_SHOW");
		this:UnregisterEvent("MERCHANT_CLOSED");
		this:UnregisterEvent("PLAYER_LEVEL_UP");

		-- Changement de couleur suivant le mode Combat
	elseif (event == "PLAYER_REGEN_DISABLED") then
		Arcanum_CombatDisableIcons();
	elseif (event == "PLAYER_REGEN_ENABLED") then
		Arcanum_CombatEnableIcons();
		-- Si un nouveau sort est apris, on rafraichie le tableau des sorts
	elseif (event == "LEARNED_SPELL_IN_TAB") then
		Arcanum_SpellSetup();
		Arcanum_ButtonSetup();
		Arcanum_LoadIcons();
		-- Managing end of spell casting
	elseif (event == "SPELLCAST_STOP") then
		Arcanum_SpellManagement();
		-- Quand le mage commence  incanter un sort, on intercepte le nom de celui-ci
		-- On sauve Ã©galement le nom de la cible du sort ainsi que son niveau
	elseif (event == "SPELLCAST_START") then
		SpellCastName = arg1;
		SpellTargetName = UnitName("target");
		if not SpellTargetName then
			SpellTargetName = "";
		end
		SpellTargetLevel = UnitLevel("target");
		if not SpellTargetLevel then
			SpellTargetLevel = "";
		end
		-- Quand le mage stoppe son incantation, on relache le nom de celui-ci
	elseif (event == "SPELLCAST_FAILED") or (event == "SPELLCAST_INTERRUPTED") then
		SpellCastName = nil;
		SpellCastRank = nil;
		SpellTargetName = nil;
		SpellTargetLevel = nil;
		AtieshUsed = false; -- Clear Atiesh flag if cast was interrupted
	elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then

	elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then

	elseif event == "TRADE_REQUEST" or event == "TRADE_SHOW" then
		if ArcanumTradeNow == true then
			Arcanum_Trade();
			ArcanumTradeOpened = true;
			ArcanumTradeAcceptT = 0;
			ArcanumtTradeAccept = true;
			ArcanumTradeNow = false;
		end
	elseif event == "TRADE_REQUEST_CANCEL" or event == "TRADE_CLOSED" then
		ArcanumTradeNB = 1;
		ArcanumTradeFoodNB = 1;
		ArcanumTradeWaterNB = 1;
		ArcanumTradeOpened = false;
	elseif event == "TRADE_ACCEPT_UPDATE" then
	elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
		ArcanumTradeNB = ArcanumTradeNB + 1;
	elseif (event == "BAG_UPDATE") then
		local wasAtieshEquipped = AtieshEquipped;
		local mainHandLink = GetInventoryItemLink("player", 16);
		AtieshEquipped = mainHandLink and string.find(mainHandLink, ARCANUM_ITEM.Atiesh);
		if (not wasAtieshEquipped and AtieshEquipped) then
			AtieshEquipTime = GetTime();
		end
		Arcanum_BagExplore();
		Arcanum_LoadIconsV();
		Arcanum_EDIcons();
		Arcanum_ButtonSetup();
		if (ArcanumConfig.Powder > ArcanumArcanePowder or ArcanumConfig.Teleport > ArcanumRuneOfTeleportation or ArcanumConfig.Portal > ArcanumRuneOfPortals) then
			ReagentBought = false;
		end
	elseif (event == "MERCHANT_SHOW") then
		MerchantOpened = true;
		if ArcanumConfig.ReagentBuy == true then
			if ReagentBought == false then
				Arcanum_AutoBuy();
			end
		end
	elseif (event == "MERCHANT_CLOSED") then
		MerchantOpened = false;
	elseif (event == "PLAYER_LEVEL_UP") then
		PlayerLevel = UnitLevel("player");
	end
end

-- Managing clicks on Arcanum
-- Left click: Switch Arcanum to Individual/Class buff mode
-- Right click: Hearthstone

function Arcanum_OnClick(button)
	if (button == "LeftButton") then
		Arcanum_Click(ArcanumConfig.LeftClick);
	elseif (button == "MiddleButton") then
		Arcanum_Click(ArcanumConfig.MiddleClick);
	elseif (button == "RightButton") then
		Arcanum_Click(ArcanumConfig.RightClick);
	end
end

-- Creation and Display of help tooltips
function Arcanum_BuildTooltip(button, anchor, type)
	GameTooltip:SetOwner(button, anchor);
	if (type == "Mount") then
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TRANSLATION.Mounting .. " " .. MountName[ArcanumConfig.LastMount] .. "\n" .. ARCANUM_MESSAGE.Tooltip.MiddleClick .. ARCANUM_TRANSLATION.Hearth));
		if (CoolDown[1][1] ~= nil) then
			GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.Cooldown .. CoolDown[1][1]));
		end
	elseif (type == "Buff") and ArcanumConfig.LastBuff ~= 0 then
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TOOLTIP_DATA.LastSpell .. "\n" .. ARCANUM_SPELL_TABLE.Name[ArcanumConfig.LastBuff] .. "\nMana : " .. ARCANUM_SPELL_TABLE.Mana[ArcanumConfig.LastBuff]));
	elseif (type == "ArcaneIntellect") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[4], 1);
	elseif (type == "ArcaneBrilliance") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[5], 1);
	elseif (type == "Magic") and ArcanumConfig.LastMagic ~= 0 then
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TOOLTIP_DATA.LastSpell .. "\n" .. ARCANUM_SPELL_TABLE.Name[ArcanumConfig.LastMagic] .. "\nMana : " .. ARCANUM_SPELL_TABLE.Mana[ArcanumConfig.LastMagic]));
	elseif (type == "AmplifyMagic") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[7], 1);
	elseif (type == "DampenMagic") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[6], 1);
	elseif (type == "Armor") and ArcanumConfig.LastArmor ~= 0 then
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TOOLTIP_DATA.LastSpell .. "\n" .. ARCANUM_SPELL_TABLE.Name[ArcanumConfig.LastArmor] .. "\nMana : " .. ARCANUM_SPELL_TABLE.Mana[ArcanumConfig.LastArmor]));
	elseif (type == "FrostArmor") then
		if (ARCANUM_SPELL_TABLE.Mana[2] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[2], 1);
		elseif (ARCANUM_SPELL_TABLE.Mana[1] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[1], 1);
		end
	elseif (type == "MageArmor") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[3], 1);
	elseif (type == "Karazhan") then
		GameTooltip:AddLine(Arcanum_ColoredMsg("Portal: Karazhan"));
		GameTooltip:AddLine("Click to open portal");
		if not AtieshEquipped then
			GameTooltip:AddLine("(Will equip Atiesh first)")
		else
			local equipRemaining = math.ceil(30 - (GetTime() - AtieshEquipTime));
			if equipRemaining > 0 then
				GameTooltip:AddLine("(Usable in " .. equipRemaining .. "s - just equipped)")
			elseif AtieshCooldown > GetTime() then
				GameTooltip:AddLine("(On cooldown: " .. math.ceil(AtieshCooldown - GetTime()) .. "s remaining)")
			end
		end
	elseif (type == "AlahThalasTP") then
		if (ARCANUM_SPELL_TABLE.ID[45] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[45], 1);
			GameTooltip:AddLine(ArcanumRuneOfTeleportation .. " Runes Left");
		end
	elseif (type == "AlahThalasPortal") then
		if (ARCANUM_SPELL_TABLE.ID[55] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[55], 1);
			GameTooltip:AddLine(ArcanumRuneOfPortals .. " Runes Left");
		end
	elseif (type == "Oranges") then
		if (ARCANUM_SPELL_TABLE.ID[35] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[35], 1);
			GameTooltip:AddLine("Left click to use, Right click to create");
			GameTooltip:AddLine(ArcanumArcanePowder .. " Arcane Powder Left");
		else
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[8], 1);
			GameTooltip:AddLine("Left click to eat, Right click to create");
		end
	elseif (type == "Food") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[8], 1);
		GameTooltip:AddLine("Left click to eat, Right click to create");
	elseif (type == "Water") then
		GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[9], 1);
		GameTooltip:AddLine("Left click to drink, Right click to create");
	elseif (type == "ManaGem") then
		if (ARCANUM_SPELL_TABLE.ID[13] ~= nil and ManaGemExists[1] == false) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[13], 1);
		elseif (ARCANUM_SPELL_TABLE.ID[12] ~= nil and ManaGemExists[2] == false) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[12], 1);
		elseif (ARCANUM_SPELL_TABLE.ID[11] ~= nil and ManaGemExists[3] == false) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[11], 1);
		elseif (ARCANUM_SPELL_TABLE.ID[10] ~= nil and ManaGemExists[4] == false) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[10], 1);
		end
		GameTooltip:AddLine("Left click to use, Right click to create");
	elseif (type == "Portal") and ArcanumConfig.LastPortal ~= 0 then
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TOOLTIP_DATA.LastSpell .. "\n" .. ARCANUM_SPELL_TABLE.Name[ArcanumConfig.LastPortal] .. "\nMana : " .. ARCANUM_SPELL_TABLE.Mana[ArcanumConfig.LastPortal]));
	elseif (type == "Teleport1") then
		if (ARCANUM_SPELL_TABLE.ID[41] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[41], 1);
			GameTooltip:AddLine(ArcanumRuneOfTeleportation .. " Runes Left");
		end
	elseif (type == "Teleport2") then
		if (ARCANUM_SPELL_TABLE.ID[42] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[42], 1);
			GameTooltip:AddLine(ArcanumRuneOfTeleportation .. " Runes Left");
		end
	elseif (type == "Teleport3") then
		if (ARCANUM_SPELL_TABLE.ID[43] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[43], 1);
			GameTooltip:AddLine(ArcanumRuneOfTeleportation .. " Runes Left");
		end
	elseif (type == "Teleport4") then
		if (ARCANUM_SPELL_TABLE.ID[44] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[44], 1);
			GameTooltip:AddLine(ArcanumRuneOfTeleportation .. " Runes Left");
		end
	elseif (type == "Portal1") then
		if (ARCANUM_SPELL_TABLE.ID[51] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[51], 1);
			GameTooltip:AddLine(ArcanumRuneOfPortals .. " Runes Left");
		end
	elseif (type == "Portal2") then
		if (ARCANUM_SPELL_TABLE.ID[52] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[52], 1);
			GameTooltip:AddLine(ArcanumRuneOfPortals .. " Runes Left");
		end
	elseif (type == "Portal3") then
		if (ARCANUM_SPELL_TABLE.ID[53] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[53], 1);
			GameTooltip:AddLine(ArcanumRuneOfPortals .. " Runes Left");
		end
	elseif (type == "Portal4") then
		if (ARCANUM_SPELL_TABLE.ID[54] ~= nil) then
			GameTooltip:SetSpell(ARCANUM_SPELL_TABLE.ID[54], 1);
			GameTooltip:AddLine(ArcanumRuneOfPortals .. " Runes Left");
		end
		-- Soit c'est le bouton principal
	elseif (type == "Main") then
		GameTooltip:AddLine(Arcanum_MsgAddColor("<white>" .. ArcanumArcanePowder) .. " " .. Arcanum_ColoredMsg(ARCANUM_ITEM.ArcanePowder));
		GameTooltip:AddLine(Arcanum_MsgAddColor("<white>" .. ArcanumRuneOfTeleportation) .. " " .. Arcanum_ColoredMsg(ARCANUM_ITEM.RuneOfTeleportation));
		GameTooltip:AddLine(Arcanum_MsgAddColor("<white>" .. ArcanumRuneOfPortals) .. " " .. Arcanum_ColoredMsg(ARCANUM_ITEM.RuneOfPortals));
		GameTooltip:AddLine(Arcanum_MsgAddColor("<white>" .. ArcanumLightFeathers) .. " " .. Arcanum_ColoredMsg(ARCANUM_ITEM.LightFeathers));
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.LeftClick .. ARCANUM_CLICK[ArcanumConfig.LeftClick]));
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.MiddleClick .. ARCANUM_CLICK[ArcanumConfig.MiddleClick]));
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.RightClick .. ARCANUM_CLICK[ArcanumConfig.RightClick]));
	elseif (type == "Minimap") then
		GameTooltip:AddLine("|CFF0050FFAr|CFF0080FFca|CFF00B0FFnum|CFFFFFFFF: " .. "\n" .. ARCANUM_MESSAGE.Tooltip.Minimap);
	elseif (type == "SpellTimer") then
		Arcanum_MoneyToggle();
		ArcanumTooltip:SetBagItem(HearthstoneLocation[1], HearthstoneLocation[2]);
		local itemName = tostring(ArcanumTooltipTextLeft5:GetText());
		GameTooltip:AddLine(Arcanum_ColoredMsg(ARCANUM_TOOLTIP_DATA[type].Text));
		if string.find(itemName, ARCANUM_TRANSLATION.Cooldown) then
			GameTooltip:AddLine(Arcanum_MsgAddColor(ARCANUM_TRANSLATION.Hearth .. " - " .. itemName));
		else
			GameTooltip:AddLine(Arcanum_MsgAddColor(ARCANUM_TOOLTIP_DATA[type].Right .. GetBindLocation()));
		end
	end
	-- On affiche
	GameTooltip:Show();
end

function Arcanum_CallToolTip(Id)
	ToolTipList = {
		{},
		{},
		{},
		{ "Buff", "ArcaneIntellect", "ArcaneBrilliance" },
		{ "Armor", "FrostArmor", "Karazhan" },
		{ "Portal", "AlahThalasTP", "AlahThalasPortal" },
		{ "Portal", "Teleport1", "Portal1" },
		{ "Portal", "Teleport2", "Portal2" },
		{ "Portal", "Teleport3", "Portal3" },
		{ "Portal", "Teleport4", "Portal4" },
	};
	if ArcanumConfig.BuffType == 0 then
		Arcanum_BuildTooltip(this, "ANCHOR_CURSOR", ToolTipList[Id][2]);
	else
		Arcanum_BuildTooltip(this, "ANCHOR_CURSOR", ToolTipList[Id][3]);
	end
end
------------------------------------------------------------------------------------------------------

-- CONFIGURATION LOADING FUNCTIONS

------------------------------------------------------------------------------------------------------

function Arcanum_LoadConfig()
	if (ArcanumConfig.ChatType) then
		ArcanumChatType_Button:SetChecked(1);
	end
	if (ArcanumConfig.HideInCombat) then
		ArcanumHideInCombat_Button:SetChecked(1);
	end
	if (ArcanumConfig.OrangesMessage) then
		ArcanumOrangesMessage_Button:SetChecked(1);
	end
	if (ArcanumConfig.PortalMessage) then
		ArcanumPortalMessage_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[1]) then
		ArcanumDisplayHearthStone_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[2]) then
		ArcanumDisplayManaGem_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[3]) then
		ArcanumDisplayEvocation_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[4]) then
		ArcanumDisplayIceBlock_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[5]) then
		ArcanumDisplayColdSnap_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[6]) then
		ArcanumDisplayIntell_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[7]) then
		ArcanumDisplayArmor_Button:SetChecked(1);
	end
	if (ArcanumConfig.Display[8]) then
		ArcanumDisplayBandage_Button:SetChecked(1);
	end

	if (ArcanumConfig.Toggle) then
		ArcanumToggle_Button:SetChecked(1);
	end
	if (ArcanumConfig.NoDragAll) then
		ArcanumLock_Button:SetChecked(1);
		Arcanum_NoDrag();
		ArcanumButton:RegisterForDrag("");
	end
	if (ArcanumConfig.ArcanumLockServ) then
		ArcanumIconsLock_Button:SetChecked(1);
	end
	if (ArcanumConfig.BuffMenuPos == "y") then
		ArcanumBuffMenu_Button:SetChecked(1);
	end
	if (ArcanumConfig.ArmorMenuPos == "y") then
		ArcanumArmorMenu_Button:SetChecked(1);
	end
	if (ArcanumConfig.MagicMenuPos == "y") then
		ArcanumMagicMenu_Button:SetChecked(1);
	end
	if (ArcanumConfig.PortalMenuPos == "y") then
		ArcanumPortalMenu_Button:SetChecked(1);
	end
	if (ArcanumConfig.MountMenuPos == "y") then
		ArcanumMountMenu_Button:SetChecked(1);
	end

	if (ArcanumConfig.ReagentSort) then
		ArcanumReagentSort_Button:SetChecked(1);
	end
	if (ArcanumConfig.ReagentBuy) then
		ArcanumReagentBuy_Button:SetChecked(1);
	end

	if (ArcanumConfig.LevelBuff) then
		ArcanumLevelBuff_Button:SetChecked(1);
	end
	if (ArcanumConfig.BuffButton) then
		ArcanumBuffButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.PortalButton) then
		ArcanumPortalButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.FoodButton) then
		ArcanumFoodButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.WaterButton) then
		ArcanumWaterButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.ManaGemButton) then
		ArcanumManaGemButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.HearthstoneButton) then
		ArcanumHearthstoneButton_Button:SetChecked(1);
	end
	if (ArcanumConfig.KarazhanButton) then
		ArcanumKarazhanButton_Button:SetChecked(1);
	end

	ArcanumEvocationLimit_Slider:SetValue(ArcanumConfig.EvocationLimit);
	ArcanumEvocationLimit_SliderLow:SetText("0 %");
	ArcanumEvocationLimit_SliderHigh:SetText("100 %");

	ArcanumBag_Slider:SetValue(4 - ArcanumConfig.ReagentContainer);
	ArcanumBag_SliderLow:SetText("5");
	ArcanumBag_SliderHigh:SetText("1");
	ArcanumPowder_EditBox:SetTextColor(0, 0.5, 1);
	ArcanumPowder_EditBox:SetNumber(ArcanumConfig.Powder);
	ArcanumPowder_EditBox:SetNumeric(true);
	ArcanumTeleport_EditBox:SetTextColor(0, 0.5, 1);
	ArcanumTeleport_EditBox:SetNumber(ArcanumConfig.Teleport);
	ArcanumTeleport_EditBox:SetNumeric(true);
	ArcanumPortal_EditBox:SetTextColor(0, 0.5, 1);
	ArcanumPortal_EditBox:SetNumber(ArcanumConfig.Portal);
	ArcanumPortal_EditBox:SetNumeric(true);

	ArcanumButtonRotate_Slider:SetValue(ArcanumConfig.ArcanumAngle);
	ArcanumButtonRotate_SliderLow:SetText("0");
	ArcanumButtonRotate_SliderHigh:SetText("360");
	ArcanumButtonScale_Slider:SetValue(ArcanumConfig.ArcanumButtonScale);
	ArcanumButtonScale_SliderLow:SetText("50 %");
	ArcanumButtonScale_SliderHigh:SetText("150 %");
	ArcanumButton:SetScale(ArcanumConfig.ArcanumButtonScale / 100);

	if ArcanumConfig.NoDragAll then
		Arcanum_NoDrag();
		ArcanumButton:RegisterForDrag("");
	else
		Arcanum_Drag();
		ArcanumButton:RegisterForDrag("LeftButton");
	end
	Arcanum_LanguageInitialize();
end

function Arcanum_LanguageInitialize()
	ArcanumLocalization();
	-- Localisation du XML
	ArcanumVersion:SetText(Arcanum_ColoredMsg(ArcanumData.AppName) .. "|CFFFFFFFF V" .. ArcanumData.Version .. " by " .. ArcanumData.Author .. ", updated by Fayz");

	ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu1));
	ArcanumMessagePlayer_Section:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.MessageMenu1));
	ArcanumChatType_Option:SetText(ARCANUM_CONFIGURATION.ChatType);
	ArcanumHideInCombat_Option:SetText(ARCANUM_CONFIGURATION.HideInCombatMessage);
	ArcanumOrangesMessage_Option:SetText(ARCANUM_CONFIGURATION.OrangesMessage);
	ArcanumPortalMessage_Option:SetText(ARCANUM_CONFIGURATION.PortalMessage);
	ArcanumButtonDisplay_Section:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ArcanumButtonDisplay));
	ArcanumInsideDisplayDD:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.InsideDisplay));
	ArcanumDisplayHearthStone_Option:SetText(ARCANUM_CONFIGURATION.DisplayHearthStone);
	ArcanumDisplayManaGem_Option:SetText(ARCANUM_CONFIGURATION.DisplayManaGem);
	ArcanumDisplayEvocation_Option:SetText(ARCANUM_CONFIGURATION.DisplayEvocation);
	ArcanumDisplayIceBlock_Option:SetText(ARCANUM_CONFIGURATION.DisplayIceBlock);
	ArcanumDisplayColdSnap_Option:SetText(ARCANUM_CONFIGURATION.DisplayColdSnap);
	ArcanumDisplayIntell_Option:SetText(ARCANUM_CONFIGURATION.DisplayIntell);
	ArcanumDisplayArmor_Option:SetText(ARCANUM_CONFIGURATION.DisplayArmor);
	ArcanumDisplayBandage_Option:SetText(ARCANUM_CONFIGURATION.DisplayBandage);
	ArcanumHealthColor_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.HealthColor));
	ArcanumManaColor_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ManaColor));
	ArcanumButtonColor_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ButtonColor));

	ArcanumLevelBuff_Option:SetText(ARCANUM_CONFIGURATION.LevelBuff);
	ArcanumEvocationLimit_SliderText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.EvocationLimit));
	ArcanumDeleteFood_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.DeleteFood));
	ArcanumDeleteWater_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.DeleteWater));
	ArcanumDeleteManaGem_Button:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.DeleteManaGem));

	ArcanumReagentSort_Option:SetText(ARCANUM_CONFIGURATION.ReagentSort);
	ArcanumBag_SliderText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ReagentBag));
	ArcanumReagentBuy_Option:SetText(ARCANUM_CONFIGURATION.ReagentBuy);
	ArcanumReagent_Section:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Reagent));
	ArcanumPowder_Section:SetText(ARCANUM_CONFIGURATION.Powder);
	ArcanumTeleport_Section:SetText(ARCANUM_CONFIGURATION.Teleport);
	ArcanumPortal_Section:SetText(ARCANUM_CONFIGURATION.Portal);

	ArcanumToggle_Option:SetText(ARCANUM_CONFIGURATION.Toggle);
	ArcanumLock_Option:SetText(ARCANUM_CONFIGURATION.Lock);
	ArcanumIconsLock_Option:SetText(ARCANUM_CONFIGURATION.IconsLock);
	ArcanumButtonRotate_SliderText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ArcanumRotation));
	ArcanumButtonScale_SliderText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.ArcanumSize));

	ArcanumButton_Option:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Button));
	ArcanumOrder_Option:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Order));
	ArcanumBuffButton_Option:SetText(ARCANUM_CONFIGURATION.BuffButton);
	ArcanumPortalButton_Option:SetText(ARCANUM_CONFIGURATION.PortalButton);
	ArcanumFoodButton_Option:SetText(ARCANUM_CONFIGURATION.FoodButton);
	ArcanumWaterButton_Option:SetText(ARCANUM_CONFIGURATION.WaterButton);
	ArcanumManaGemButton_Option:SetText(ARCANUM_CONFIGURATION.ManaGemButton);
	ArcanumHearthstoneButton_Option:SetText(ARCANUM_CONFIGURATION.HearthstoneButton);
	ArcanumKarazhanButton_Option:SetText(ARCANUM_CONFIGURATION.KarazhanButton);
	ArcanumLeftClick:SetText(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.LeftClick));
	ArcanumMiddleClick:SetText(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.MiddleClick));
	ArcanumRightClick:SetText(Arcanum_ColoredMsg(ARCANUM_MESSAGE.Tooltip.RightClick));

	ClearTable(ArcanumLeftButtonClick);
	for i = 1, table.getn(ARCANUM_CLICK) do
		table.insert(ArcanumLeftButtonClick, ARCANUM_CLICK[i]);
	end
	ClearTable(ArcanumMiddleButtonClick);
	for i = 1, table.getn(ARCANUM_CLICK) do
		table.insert(ArcanumMiddleButtonClick, ARCANUM_CLICK[i]);
	end
	ClearTable(ArcanumRightButtonClick);
	for i = 1, table.getn(ARCANUM_CLICK) do
		table.insert(ArcanumRightButtonClick, ARCANUM_CLICK[i]);
	end
	ClearTable(ArcanumInsideDisplayClick);
	for i = 1, table.getn(ARCANUM_INSIDE_DISPLAY) do
		table.insert(ArcanumInsideDisplayClick, ARCANUM_INSIDE_DISPLAY[i]);
	end
	UIDropDownMenu_SetSelectedID(ArcanumLeftClickDropDown, ArcanumConfig.LeftClick);
	UIDropDownMenu_SetSelectedID(ArcanumMiddleClickDropDown, ArcanumConfig.MiddleClick);
	UIDropDownMenu_SetSelectedID(ArcanumRightClickDropDown, ArcanumConfig.RightClick);
	UIDropDownMenu_SetText(ARCANUM_CLICK[ArcanumConfig.LeftClick], ArcanumLeftClickDropDown);
	UIDropDownMenu_SetText(ARCANUM_CLICK[ArcanumConfig.MiddleClick], ArcanumMiddleClickDropDown);
	UIDropDownMenu_SetText(ARCANUM_CLICK[ArcanumConfig.RightClick], ArcanumRightClickDropDown);

	UIDropDownMenu_SetSelectedID(ArcanumInsideDisplayDropDown, ArcanumConfig.InsideDisplay);
	UIDropDownMenu_SetText(ARCANUM_INSIDE_DISPLAY[ArcanumConfig.InsideDisplay], ArcanumInsideDisplayDropDown);
end

------------------------------------------------------------------------------------------------------

-- CONFIGURATION WINDOW MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

function ArcanumGeneralTab_OnClick(id)
	local TabName;
	for index = 1, 5, 1 do
		TabName = getglobal("ArcanumGeneralTab" .. index);
		if index == id then
			TabName:SetChecked(1);
		else
			TabName:SetChecked(nil);
		end
	end
	if id == 1 then
		ShowUIPanel(ArcanumMessageMenu);
		HideUIPanel(ArcanumSpellsMenu);
		HideUIPanel(ArcanumReagentMenu);
		HideUIPanel(ArcanumGraphOptionMenu);
		HideUIPanel(ArcanumButtonOptionMenu);
		HideUIPanel(ArcanumTradeMenu);
		ArcanumGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
		ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu1));
	elseif id == 2 then
		HideUIPanel(ArcanumMessageMenu);
		ShowUIPanel(ArcanumSpellsMenu);
		HideUIPanel(ArcanumReagentMenu);
		HideUIPanel(ArcanumGraphOptionMenu);
		HideUIPanel(ArcanumButtonOptionMenu);
		HideUIPanel(ArcanumTradeMenu);
		ArcanumGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
		ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu2));
	elseif id == 3 then
		HideUIPanel(ArcanumMessageMenu);
		HideUIPanel(ArcanumSpellsMenu);
		ShowUIPanel(ArcanumReagentMenu);
		HideUIPanel(ArcanumGraphOptionMenu);
		HideUIPanel(ArcanumButtonOptionMenu);
		HideUIPanel(ArcanumTradeMenu);
		ArcanumGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
		ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu3));
	elseif id == 4 then
		HideUIPanel(ArcanumMessageMenu);
		HideUIPanel(ArcanumSpellsMenu);
		HideUIPanel(ArcanumReagentMenu);
		ShowUIPanel(ArcanumGraphOptionMenu);
		HideUIPanel(ArcanumButtonOptionMenu);
		HideUIPanel(ArcanumTimerMenu);
		HideUIPanel(ArcanumTradeMenu);
		ArcanumGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
		ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu4));
	elseif id == 5 then
		HideUIPanel(ArcanumMessageMenu);
		HideUIPanel(ArcanumSpellsMenu);
		HideUIPanel(ArcanumReagentMenu);
		HideUIPanel(ArcanumGraphOptionMenu);
		ShowUIPanel(ArcanumButtonOptionMenu);
		HideUIPanel(ArcanumTradeMenu);
		ArcanumGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
		ArcanumGeneralPageText:SetText(Arcanum_ColoredMsg(ARCANUM_CONFIGURATION.Menu5));
	end
end

------------------------------------------------------------------------------------------------------

-- REAGENT PURCHASE MANAGEMENT FUNCTION

------------------------------------------------------------------------------------------------------
function Arcanum_AutoBuy()
	local ReagentCount = { ArcanumConfig.Powder - ArcanumArcanePowder, ArcanumConfig.Teleport - ArcanumRuneOfTeleportation, ArcanumConfig.Portal - ArcanumRuneOfPortals };
	local ReagentName = { ARCANUM_ITEM.ArcanePowder, ARCANUM_ITEM.RuneOfTeleportation, ARCANUM_ITEM.RuneOfPortals };
	local ReagentBuyCount = 0;
	if ARCANUM_SPELL_TABLE.ID[5] == nil then
		ReagentCount[1] = 0;
	end
	if (ARCANUM_SPELL_TABLE.ID[41] == nil and ARCANUM_SPELL_TABLE.ID[42] == nil and ARCANUM_SPELL_TABLE.ID[43] == nil and ARCANUM_SPELL_TABLE.ID[44] == nil) then
		ReagentCount[2] = 0;
	end
	if (ARCANUM_SPELL_TABLE.ID[51] == nil and ARCANUM_SPELL_TABLE.ID[52] == nil and ARCANUM_SPELL_TABLE.ID[53] == nil and ARCANUM_SPELL_TABLE.ID[54] == nil) then
		ReagentCount[3] = 0;
	end
	if ReagentCount[1] ~= 0 or ReagentCount[2] ~= 0 or ReagentCount[3] ~= 0 then
		local NumItems = GetMerchantNumItems()
		for j = 1, NumItems do
			for i = 1, 3 do
				local slotItemString = GetMerchantItemInfo(j)
				if slotItemString == ReagentName[i] and ReagentCount[i] > 0 then
					Arcanum_Msg(ARCANUM_MESSAGE.Autobuy .. ReagentCount[i] .. " " .. ReagentName[i], "USER");
					ReagentBuyCount = ReagentCount[i] / 10;
					for k = 1, ReagentBuyCount do
						BuyMerchantItem(j, 10);
						ReagentCount[i] = ReagentCount[i] - 10;
					end
					if ReagentCount[i] > 0 then
						BuyMerchantItem(j, ReagentCount[i]);
						ReagentCount[i] = ReagentCount[i] - ReagentCount[i];
					end
					--CloseMerchant();
					ReagentBought = true;
				end
			end
		end
		if ArcanumConfig.ReagentSort == true then
			Arcanum_ReagentSwitch();
		end
	end
end

function Arcanum_Trade()
	if UnitExists("target") and UnitIsFriend("player", "target") and UnitIsPlayer("target") and not UnitIsUnit("player", "target") then
		if (FoodCount > 0 or WaterCount > 0 or OrangeCount > 0) and ArcanumTradeNB <= 6 then
			if ArcanumTradeOpened == false then
				InitiateTrade("target");
			end
			Arcanum_FoodWaterSweep(UnitLevel("target"));
			local playerClass, englishClass = UnitClass("target");

			if englishClass ~= "WARRIOR" or englishClass ~= "ROGUE" then
				if table.getn(FoodLocation) >= ceil((ArcanumTradeNB) / 2) then
					PickupContainerItem(FoodLocation[ceil((ArcanumTradeNB) / 2)][1], FoodLocation[ceil((ArcanumTradeNB) / 2)][2]);
					if CursorHasItem() then
						DropItemOnUnit("target");
					end
				end
				if table.getn(WaterLocation) >= ceil((ArcanumTradeNB) / 2) then
					PickupContainerItem(WaterLocation[ceil((ArcanumTradeNB) / 2)][1], WaterLocation[ceil((ArcanumTradeNB) / 2)][2]);
					if CursorHasItem() then
						DropItemOnUnit("target");
					end
				end
			else
				PickupContainerItem(FoodLocation[ArcanumTradeNB][1], FoodLocation[ArcanumTradeNB][2]);
				if CursorHasItem() then
					DropItemOnUnit("target");
				end
			end
			ArcanumTradeAcceptT = 0;
			ArcanumTradeAccept = true;
		end
	end
end

function ArcanumTradeFood()
	if UnitExists("target") and UnitIsFriend("player", "target") and UnitIsPlayer("target") and not UnitIsUnit("player", "target") then
		Arcanum_FoodWaterSweep(UnitLevel("target"));
		PickupContainerItem(FoodLocation[ArcanumTradeFoodNB][1], FoodLocation[ArcanumTradeFoodNB][2]);
		if CursorHasItem() then
			DropItemOnUnit("target");
		end
		ArcanumTradeAcceptT = 0;
		ArcanumTradeAccept = true;
		ArcanumTradeFoodNB = ArcanumTradeFoodNB + 1;
	end
end

function ArcanumTradeWater()
	if UnitExists("target") and UnitIsFriend("player", "target") and UnitIsPlayer("target") and not UnitIsUnit("player", "target") then
		Arcanum_FoodWaterSweep(UnitLevel("target"));
		PickupContainerItem(WaterLocation[ArcanumTradeWaterNB][1], WaterLocation[ArcanumTradeWaterNB][2]);
		if CursorHasItem() then
			DropItemOnUnit("target");
		end
		ArcanumTradeAcceptT = 0;
		ArcanumTradeAccept = true;
		ArcanumTradeWaterNB = ArcanumTradeWaterNB + 1;
	end
end

function Arcanum_FoodWaterSweep(Level)
	local FoodLevel, WaterLevel;
	FoodLocationCount = 0;
	WaterLocationCount = 0;
	local foodLevel;
	local waterLevel;
	local orangeLevel = 8;

	for j = ARCANUM_SPELL_TABLE.Rank[8], 1, -1 do
		if Level >= Water_Minlvl[j] then
			foodLevel = j;
			waterLevel = j;
			break ;
		end
	end

	ClearTable(FoodLocation);
	ClearTable(WaterLocation);
	for container = 0, 4, 1 do
		for slot = 1, GetContainerNumSlots(container), 1 do
			Arcanum_MoneyToggle();
			ArcanumTooltip:SetBagItem(container, slot);
			local itemName = ArcanumTooltipTextLeft1:GetText();
			if itemName == ARCANUM_FOOD[orangeLevel] then
				local _, itemCount = GetContainerItemInfo(container, slot);
				table.insert(FoodLocation, { container, slot, itemCount });
				FoodLocationCount = FoodLocationCount + 1;
			elseif itemName == ARCANUM_FOOD[foodLevel] then
				local _, itemCount = GetContainerItemInfo(container, slot);
				table.insert(FoodLocation, { container, slot, itemCount });
				FoodLocationCount = FoodLocationCount + 1;
			elseif itemName == ARCANUM_WATER[waterLevel] then
				local _, itemCount = GetContainerItemInfo(container, slot);
				table.insert(WaterLocation, { container, slot, itemCount });
				WaterLocationCount = WaterLocationCount + 1;
			end
		end
	end
	if FoodLocationCount > 0 then
		for i = 1, FoodLocationCount - 1 do
			local j = i + 1;
			while FoodLocation[i][3] < 20 do
				FoodWaterSwitch(FoodLocation, i, j)
				j = j + 1;
			end
		end
	end
	if WaterLocationCount > 0 then
		for i = 1, WaterLocationCount - 1 do
			local j = i + 1;
			while WaterLocation[i][3] < 20 do
				FoodWaterSwitch(WaterLocation, i, j)
				j = j + 1;
			end
		end
	end
end

function FoodWaterSwitch(table, a, b)
	local _, itemCount = GetContainerItemInfo(table[b][1], table[b][2]);
	table[a][3] = itemCount;
	_, itemCount = GetContainerItemInfo(table[a][1], table[a][2]);
	table[b][3] = itemCount;
	PickupContainerItem(table[a][1], table[a][2]);
	PickupContainerItem(table[b][1], table[b][2]);
end
------------------------------------------------------------------------------------------------------

-- BAG MANAGEMENT FUNCTIONS (LOCATION AND COUNTING OF COMPONENTS, SUMMONED OBJECTS)

------------------------------------------------------------------------------------------------------

-- destroy water, food and managem item
function Arcanum_DeleteItem(Type)
	for container = 0, 4, 1 do
		for slot = 1, GetContainerNumSlots(container), 1 do
			if (Type == "Food") then
				for i = 1, table.getn(ARCANUM_FOOD) do
					Arcanum_MoneyToggle();
					ArcanumTooltip:SetBagItem(container, slot);
					local itemName = ArcanumTooltipTextLeft1:GetText();
					if (itemName == ARCANUM_FOOD[i]) then
						PickupContainerItem(container, slot);
						if (CursorHasItem()) then
							DeleteCursorItem();
						end
					end
				end
			elseif (Type == "Water") then
				for i = 1, table.getn(ARCANUM_WATER) do
					Arcanum_MoneyToggle();
					ArcanumTooltip:SetBagItem(container, slot);
					local itemName = ArcanumTooltipTextLeft1:GetText();
					if (itemName == ARCANUM_WATER[i]) then
						PickupContainerItem(container, slot);
						if (CursorHasItem()) then
							DeleteCursorItem();
						end
					end
				end
			else
				for i = 1, table.getn(ARCANUM_MANAGEM) do
					Arcanum_MoneyToggle();
					ArcanumTooltip:SetBagItem(container, slot);
					local itemName = ArcanumTooltipTextLeft1:GetText();
					if (itemName == ARCANUM_MANAGEM[i]) then
						PickupContainerItem(container, slot);
						if (CursorHasItem()) then
							DeleteCursorItem();
						end
					end
				end
			end
		end
	end

end

function Arcanum_ReagentSwitch()
	local offset = 0;
	for container = 0, 4, 1 do
		if (container ~= ArcanumConfig.ReagentContainer) then
			for slot = 1, GetContainerNumSlots(container), 1 do
				Arcanum_MoneyToggle();
				ArcanumTooltip:SetBagItem(container, slot);
				local itemInfo = tostring(ArcanumTooltipTextLeft1:GetText());
				if (itemInfo == ARCANUM_ITEM.ArcanePowder or itemInfo == ARCANUM_ITEM.RuneOfTeleportation or itemInfo == ARCANUM_ITEM.RuneOfPortals) then
					Arcanum_FindSlot(container, slot, offset);
					offset = offset + 1;
				end
			end
		end
	end
	-- Aprs avoir tout dplacer, il faut retrouver les emplacements des pierres, etc, etc...
	Arcanum_BagExplore();
end

-- Pendant le dplacement des fragments, il faut trouver un nouvel emplacement aux objets dplacs :)
function Arcanum_FindSlot(Index, Slot, offset)
	for slot = 1, GetContainerNumSlots(ArcanumConfig.ReagentContainer), 1 do
		Arcanum_MoneyToggle();
		ArcanumTooltip:SetBagItem(ArcanumConfig.ReagentContainer, slot);
		local itemInfo = tostring(ArcanumTooltipTextLeft1:GetText());
		if (itemInfo ~= ARCANUM_ITEM.ArcanePowder and itemInfo ~= ARCANUM_ITEM.RuneOfTeleportation and itemInfo ~= ARCANUM_ITEM.RuneOfPortals) then
			PickupContainerItem(Index, Slot);
			PickupContainerItem(ArcanumConfig.ReagentContainer, slot + offset);
			break ;
		end
	end
end

function Arcanum_BagExplore()
	LastItemsCount = { ArcanumArcanePowder, ArcanumRuneOfTeleportation, ArcanumRuneOfPortals, ArcanumLightFeathers, FoodCount, WaterCount };
	ArcanumArcanePowder = 0;
	ArcanumRuneOfTeleportation = 0;
	ArcanumRuneOfPortals = 0;
	ArcanumLightFeathers = 0;
	ManaGemCount = 0;
	FoodCount = 0;
	WaterCount = 0;
	OrangeCount = 0;
	ManaGemExists = { false, false, false, false };
	ClearTable(FoodLocation);
	ClearTable(WaterLocation);
	MountLocation = { nil, nil };
	MountName = { nil };
	MountIcon = { nil };
	AQMountLocation = { nil, nil };
	AQMountName = { nil };
	AQMountIcon = { nil };
	for container = 0, 4, 1 do
		for slot = 1, GetContainerNumSlots(container), 1 do
			Arcanum_MoneyToggle();
			ArcanumTooltip:SetBagItem(container, slot);
			local itemName = ArcanumTooltipTextLeft1:GetText();
			if itemName then
				-- On prend le nombre d'item en stack sur le slot
				local texture, itemCount, locked, quality, readable = GetContainerItemInfo(container, slot);
				if itemName == ARCANUM_ITEM.Hearthstone then
					ArcanumButtonDisplayTexture[1] = texture;
					HearthstoneLocation = { container, slot };
				end
				if itemName == ARCANUM_ITEM.Atiesh then
					AtieshLocation = { container, slot };
				end
				if itemName == ARCANUM_ITEM.ArcanePowder then
					ArcanumArcanePowder = ArcanumArcanePowder + itemCount;
				end
				if itemName == ARCANUM_ITEM.RuneOfTeleportation then
					ArcanumRuneOfTeleportation = ArcanumRuneOfTeleportation + itemCount;
				end
				if itemName == ARCANUM_ITEM.RuneOfPortals then
					ArcanumRuneOfPortals = ArcanumRuneOfPortals + itemCount;
				end
				if itemName == ARCANUM_ITEM.LightFeathers then
					ArcanumLightFeathers = ArcanumLightFeathers + itemCount;
				end
				--Recherche de la monture
				for i = 1, table.getn(MOUNT), 1 do
					for j = 1, table.getn(MOUNT[i]), 1 do
						if (itemName == MOUNT[i][j]) then
							table.insert(MountLocation, { container, slot });
							table.insert(MountName, itemName);
							table.insert(MountIcon, texture);
							for k = 1, table.getn(MOUNT_PREFIX) do
								MountName[table.getn(MountName)] = string.gsub(MountName[table.getn(MountName)], MOUNT_PREFIX[k], "");
							end
						end
					end
				end
				--Recherche de la monture qiraji
				for i = 1, table.getn(QIRAJ_MOUNT), 1 do
					if (itemName == QIRAJ_MOUNT[i]) then
						table.insert(AQMountLocation, { container, slot });
						table.insert(AQMountName, itemName);
						table.insert(AQMountIcon, texture);
						if quality == 5 then
							table.insert(MountLocation, { container, slot });
							table.insert(MountName, itemName);
							table.insert(MountIcon, texture);
							MountAQ = table.getn(AQMountLocation);
						end
						break ;
					end
				end

				--Recherche de la gemme de mana
				if (itemName == ARCANUM_MANAGEM[4]) then
					ManaGemLocation[1] = { container, slot };
					ManaGemExists[1] = true;
					ManaGemCount = ManaGemCount + 1;
				end
				if (itemName == ARCANUM_MANAGEM[3]) then
					ManaGemLocation[2] = { container, slot };
					ManaGemExists[2] = true;
					ManaGemCount = ManaGemCount + 1;
				end
				if (itemName == ARCANUM_MANAGEM[2]) then
					ManaGemLocation[3] = { container, slot };
					ManaGemExists[3] = true;
					ManaGemCount = ManaGemCount + 1;
				end
				if (itemName == ARCANUM_MANAGEM[1]) then
					ManaGemLocation[4] = { container, slot };
					ManaGemExists[4] = true;
					ManaGemCount = ManaGemCount + 1;
				end

				-- check for oranges
				if itemName == ARCANUM_FOOD[8] then
					table.insert(FoodLocation, { container, slot, itemCount });
					OrangeCount = OrangeCount + itemCount;
				end

				if OrangeCount == 0 then
					--Recherche du pain
					local rank = ARCANUM_SPELL_TABLE.Rank[8];
					if itemName == ARCANUM_FOOD[rank] then
						table.insert(FoodLocation, { container, slot, itemCount });
						FoodCount = FoodCount + itemCount;
					end
				end

				--Recherche de l'eau
				local rank = ARCANUM_SPELL_TABLE.Rank[9];
				if itemName == ARCANUM_WATER[rank] then
					table.insert(WaterLocation, { container, slot, itemCount });
					WaterCount = WaterCount + itemCount;
				end
			end
		end
	end
end

function ClearTable(Table)
	for i = 0, table.getn(Table) do
		table.remove(Table)
	end
end

-- Fonction pour gÃ©rer les actions effectuÃ©es par Arcanum au clic sur un boutton
function Arcanum_UseItem(type, button)
	if MerchantOpened == false then
		-- Function to use Hearthstone from inventory
		if (type == "Hearthstone") then
			-- Find the item used by Arcanum
			if (HearthstoneLocation[1] ~= nil) then
				-- Use it and set flag - cooldown will be set after cast completes
				UseContainerItem(HearthstoneLocation[1], HearthstoneLocation[2]);
				HearthstoneUsed = true;
				HearthstoneUseTime = GetTime();
			-- If not in inventory, display error message
			else
				Arcanum_Msg(ARCANUM_MESSAGE.Error.NoHearthstone, "USER");
			end
		end

		if (type == "Evocation") then
			if ARCANUM_SPELL_TABLE.ID[26] ~= nil then
				if (math.ceil(UnitMana("player") / UnitManaMax("player") * 100)) <= ArcanumConfig.EvocationLimit then
					CastSpell(ARCANUM_SPELL_TABLE.ID[26], "spell");
				end
			end
		end

		if (type == "Iceblock") then
			if ARCANUM_SPELL_TABLE.ID[32] ~= nil then
				if IceblockDone == true and IceblockReady == true then
					CastSpell(ARCANUM_SPELL_TABLE.ID[32], "spell");
					IceblockDone = false;
				elseif IceblockDone == false then
					if CoolDown[5][1] == nil then
						SpellStopCasting();
						CastSpell(ARCANUM_SPELL_TABLE.ID[32], "spell");
						IceblockDone = true;
					else
						if ARCANUM_SPELL_TABLE.ID[33] ~= nil then
							if CoolDown[4][1] == nil then
								SpellStopCasting();
								CastSpell(ARCANUM_SPELL_TABLE.ID[33], "spell");
							end
						end
					end
				end
			end
		end

		-- Si on clic sur le bouton de nourriture
		if (type == "Food") then
			if (button == "RightButton") then
				if ArcanumConfig.BuffType == 1 and ARCANUM_SPELL_TABLE.ID[35] ~= nil then
					if ArcanumConfig.OrangesMessage and (GetTime() - OrangeMessTime) > 3 then
						-- Only send emote if 3 seconds have passed since last one
						-- Select random orange message (avoid repeating last one)
						local tempnum = random(1, table.getn(ARCANUM_ORANGE_MESSAGES));
						while tempnum == OrangeMess and table.getn(ARCANUM_ORANGE_MESSAGES) >= 2 do
							tempnum = random(1, table.getn(ARCANUM_ORANGE_MESSAGES));
						end
						OrangeMess = tempnum;
						OrangeMessTime = GetTime(); -- Update timestamp
						-- Send as emote
						for i = 1, table.getn(ARCANUM_ORANGE_MESSAGES[tempnum]) do
							SendChatMessage(ARCANUM_ORANGE_MESSAGES[tempnum][i], "EMOTE");
						end
					end
					CastSpell(ARCANUM_SPELL_TABLE.ID[35], "spell");
				elseif (UnitExists("target") and UnitIsPlayer("target")) then
					for i = ARCANUM_SPELL_TABLE.Rank[8], 1, -1 do
						if UnitLevel("target") >= Water_Minlvl[i] then
							local FoodName = ARCANUM_SPELL_TABLE.Name[8] .. "(" .. ARCANUM_TRANSLATION.Rank .. " " .. i .. ")";
							CastSpellByName(FoodName);
							break ;
						end
					end
				else
					CastSpell(ARCANUM_SPELL_TABLE.ID[8], "spell");
				end
			elseif (button == "LeftButton") then
				if FoodCount ~= 0 or OrangeCount ~= 0 then
					UseContainerItem(FoodLocation[table.getn(FoodLocation)][1], FoodLocation[table.getn(FoodLocation)][2]);
				end
			else
				ArcanumTradeFood();
			end
		end

		-- Si on clic sur le bouton d'eau
		if (type == "Water") then
			if (button == "RightButton") then
				if (UnitExists("target") and UnitIsPlayer("target")) then
					for i = ARCANUM_SPELL_TABLE.Rank[9], 1, -1 do
						if UnitLevel("target") >= Water_Minlvl[i] then
							local WaterName = ARCANUM_SPELL_TABLE.Name[9] .. "(" .. ARCANUM_TRANSLATION.Rank .. " " .. i .. ")";
							CastSpellByName(WaterName);
							break ;
						end
					end
				else
					CastSpell(ARCANUM_SPELL_TABLE.ID[9], "spell");
				end
			elseif (button == "LeftButton") then
				if WaterCount ~= 0 then
					UseContainerItem(WaterLocation[table.getn(WaterLocation)][1], WaterLocation[table.getn(WaterLocation)][2]);
				end
			else
				ArcanumTradeWater();
			end
		end

		-- Si on clic sur le bouton de la gemme de mana
		if (type == "ManaGem") then
			if (button == "RightButton") then
				if (ARCANUM_SPELL_TABLE.ID[13] ~= nil and ManaGemExists[1] == false) then
					CastSpell(ARCANUM_SPELL_TABLE.ID[13], "spell");
				elseif (ARCANUM_SPELL_TABLE.ID[12] ~= nil and ManaGemExists[2] == false) then
					CastSpell(ARCANUM_SPELL_TABLE.ID[12], "spell");
				elseif (ARCANUM_SPELL_TABLE.ID[11] ~= nil and ManaGemExists[3] == false) then
					CastSpell(ARCANUM_SPELL_TABLE.ID[11], "spell");
				elseif (ARCANUM_SPELL_TABLE.ID[10] ~= nil and ManaGemExists[4] == false) then
					CastSpell(ARCANUM_SPELL_TABLE.ID[10], "spell");
				end
			elseif (ManaGemExists[1] == true) then
				UseContainerItem(ManaGemLocation[1][1], ManaGemLocation[1][2]);
				ManaGemCount = ManaGemCount - 1;
			elseif (ManaGemExists[2] == true) then
				UseContainerItem(ManaGemLocation[2][1], ManaGemLocation[2][2]);
				ManaGemCount = ManaGemCount - 1;
			elseif (ManaGemExists[3] == true) then
				UseContainerItem(ManaGemLocation[3][1], ManaGemLocation[3][2]);
				ManaGemCount = ManaGemCount - 1;
			elseif (ManaGemExists[4] == true) then
				UseContainerItem(ManaGemLocation[4][1], ManaGemLocation[4][2]);
				ManaGemCount = ManaGemCount - 1;
			end
		end
		
		-- Portal: Karazhan via Atiesh
		if (type == "Karazhan") then
			Arcanum_UseAtiesh();
		end
	end
end

-- Function to check whether the player currently has Atiesh, equipped or in bags
function Arcanum_HasAtiesh()
	local mainHandLink = GetInventoryItemLink("player", 16)

	if mainHandLink and string.find(mainHandLink, ARCANUM_ITEM.Atiesh) then
		return true
	end

	return AtieshLocation[1] ~= nil
end

-- Function to handle Atiesh and Portal: Karazhan
function Arcanum_UseAtiesh()
	-- Check if Atiesh is equipped
	local wasAtieshEquipped = AtieshEquipped
	local mainHandLink = GetInventoryItemLink("player", 16)
	AtieshEquipped = mainHandLink and string.find(mainHandLink, ARCANUM_ITEM.Atiesh)

	if (not wasAtieshEquipped and AtieshEquipped) then
		AtieshEquipTime = GetTime()
	end

	if not AtieshEquipped then
		-- Atiesh is not equipped, try to equip it
		if AtieshLocation[1] ~= nil then
			-- Equip Atiesh
			PickupContainerItem(AtieshLocation[1], AtieshLocation[2])
			PickupInventoryItem(16) -- Main hand slot
			Arcanum_Msg("Equipping Atiesh... Use button again after weapon swap to cast portal.", "USER")
		else
			Arcanum_Msg("Atiesh not found in bags!", "USER")
		end
	else
		-- Atiesh must be equipped for a short delay before its portal can be cast
		local equipRemaining = math.ceil(30 - (GetTime() - AtieshEquipTime))
		if equipRemaining > 0 then
			Arcanum_Msg("Atiesh needs " .. equipRemaining .. " more second(s) after equipping before it can be used.", "USER")
		-- Check if portal cooldown is active (60-second cooldown after casting)
		elseif AtieshCooldown > GetTime() then
			local remaining = math.ceil(AtieshCooldown - GetTime())
			Arcanum_Msg("Portal cooldown: " .. remaining .. " seconds remaining.", "USER")
		else
			-- Atiesh is equipped, delay has passed, and cooldown expired, use it from the equipped slot
			-- Send emote
			SendChatMessage("raises Atiesh high as a vortex opens, crackling with fel energy. A gateway to demon-haunted Karazhan emerges, calling the brave—and the doomed.", "EMOTE")
			AtieshUsed = true -- Flag that we're using Atiesh
			UseInventoryItem(16) -- Use main hand item (Atiesh)
			-- Cooldown will be set by Arcanum_SpellManagement when cast completes
		end
	end
end

---------------------------------------------------------------------------------------------

-- SPELL CENSUS FUNCTIONS

---------------------------------------------------------------------------------------------

-- Creates the list of spells known by the mage, and classifies them by rank.
function Arcanum_SpellSetup()
	local CurrentSpells = {
		ID = {},
		Name = {},
		subName = {},
	};

	local spellID = 1;
	local Invisible = 0;
	local InvisibleID = 0;

	-- On va parcourir tous les sorts possedÃ©s par le Mage
	while true do
		local spellName, subSpellName = GetSpellName(spellID, BOOKTYPE_SPELL);
		if not spellName then
			do
				break
			end
		end

		if (spellName) then
			-- Pour les sorts avec des rangs numÃ©rotÃ©s, on compare pour chaque sort les rangs 1 Ã  1
			-- Le rang suprieur est conservÃ©
			if (string.find(subSpellName, ARCANUM_TRANSLATION.Rank)) then
				local found = false;
				local rank = tonumber(strsub(subSpellName, 6, strlen(subSpellName)));
				for index = 1, table.getn(CurrentSpells.Name), 1 do
					if string.find(CurrentSpells.Name[index], spellName) then
						found = true;
						if (CurrentSpells.subName[index] < rank) then
							CurrentSpells.ID[index] = spellID;
							CurrentSpells.subName[index] = rank;
						end
						break ;
					end
				end
				-- Les plus grands rangs de chacun des sorts Ã  rang numÃ©rotÃ©s sont insÃ©rÃ©s dans la table
				if (not found) then
					table.insert(CurrentSpells.ID, spellID);
					table.insert(CurrentSpells.Name, spellName);
					table.insert(CurrentSpells.subName, rank);
				end
			else
				table.insert(CurrentSpells.ID, spellID);
				table.insert(CurrentSpells.Name, spellName);
				table.insert(CurrentSpells.subName, 0);
			end
		end
		spellID = spellID + 1;
	end

	-- loop through ARCANUM_SPELL_IDS in pairs
	for spellName, index in pairs(ARCANUM_SPELL_INDEXES) do
		-- loop through CurrentSpells.Name
		for i = 1, table.getn(CurrentSpells.Name), 1 do
			-- if the spellName is found in CurrentSpells.Name
			if (CurrentSpells.Name[i] == spellName) then
				-- set the ID, Rank, ManaCost, and Texture
				ARCANUM_SPELL_TABLE.ID[index] = CurrentSpells.ID[i];
				ARCANUM_SPELL_TABLE.Name[index] = CurrentSpells.Name[i];
				ARCANUM_SPELL_TABLE.Rank[index] = CurrentSpells.subName[i];
				ARCANUM_SPELL_TABLE.Mana[index] = Arcanum_ManaCost(CurrentSpells.ID[i]);
				ARCANUM_SPELL_TABLE.Texture[index] = GetSpellTexture(CurrentSpells.ID[i], BOOKTYPE_SPELL);
			end
		end
	end

	ArcanumButtonDisplayTexture = {
		ArcanumButtonDisplayTexture[1],
		ArcanumButtonDisplayTexture[2],
		ARCANUM_SPELL_TABLE.Texture[26],
		ARCANUM_SPELL_TABLE.Texture[32],
		ARCANUM_SPELL_TABLE.Texture[33],
		ARCANUM_SPELL_TABLE.Texture[4],
		ARCANUM_SPELL_TABLE.Texture[1],
		ARCANUM_SPELL_TABLE.Texture[34],
	};
end

function Arcanum_ManaCost(spellID)
	Arcanum_MoneyToggle();
	ArcanumTooltip:SetSpell(spellID, 1);
	local _, _, ManaCost = string.find(ArcanumTooltipTextLeft2:GetText(), "(%d+)");
	Arcanum_MoneyToggle();
	return tonumber(ManaCost);
end

function Arcanum_MoneyToggle()
	for index = 1, 10 do
		local text = getglobal("ArcanumTooltipTextLeft" .. index);
		text:SetText(nil);
		text = getglobal("ArcanumTooltipTextRight" .. index);
		text:SetText(nil);
	end
	ArcanumTooltip:Hide();
	ArcanumTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
end

------------------------------------------------------------------------------------------------------

-- SLASH COMMAND MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

-- Managing the command
function Arcanum_Slash(msg)
	if msg == "options" then
		if (ArcanumGeneralFrame:IsVisible()) then
			HideUIPanel(ArcanumGeneralFrame);
			return ;
		else
			ShowUIPanel(ArcanumGeneralFrame);
			ArcanumGeneralTab_OnClick(1);
			return ;
		end
	else
		if isHidden then
			hiddenByUser = false;
			Arcanum_Initialize();
		else
			hiddenByUser = true;
			Arcanum_HideUI();
		end
	end
end

------------------------------------------------------------------------------------------------------

-- MINIMAP ICON MANAGEMENT FUNCTION

------------------------------------------------------------------------------------------------------

function ArcanumMoveMinimapButton()
	ArcanumMinimapButton:SetPoint("TOPLEFT", "Minimap", "TOPLEFT", 52 - (80 * cos(ArcanumConfig.MinimapIconPos)), (80 * sin(ArcanumConfig.MinimapIconPos)) - 52);
end

function ArcanumMinimapMoved()
	local xpos, ypos = GetCursorPosition()
	local xmin, ymin = Minimap:GetLeft() or 400, Minimap:GetBottom() or 400
	xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
	ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70

	ArcanumConfig.MinimapIconPos = math.deg(math.atan2(ypos, xpos))
end

------------------------------------------------------------------------------------------------------

-- UI BUTTON MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

function Arcanum_ButtonSetup()
	if ArcanumConfig.Toggle == true then
		Arcanum_Arcanum2ButtonSetup();
	end
end

function Arcanum_Arcanum2ButtonSetup()
	ShowUIPanel(ArcanumButton);
	if (ARCANUM_SPELL_TABLE.ID[8] ~= nil and ArcanumConfig.FoodButton == true) then
		ShowUIPanel(ArcanumButton1);
		ShowUIPanel(OrderButton1);
	else
		HideUIPanel(ArcanumButton1);
		HideUIPanel(OrderButton1);
	end
	if (ARCANUM_SPELL_TABLE.ID[9] ~= nil and ArcanumConfig.WaterButton == true) then
		ShowUIPanel(ArcanumButton2);
		ShowUIPanel(OrderButton2);
	else
		HideUIPanel(ArcanumButton2);
		HideUIPanel(OrderButton2);
	end
	if ((ARCANUM_SPELL_TABLE.ID[10] ~= nil or ARCANUM_SPELL_TABLE.ID[11] ~= nil or ARCANUM_SPELL_TABLE.ID[12] ~= nil or ARCANUM_SPELL_TABLE.ID[13] ~= nil) and ArcanumConfig.ManaGemButton == true) then
		ShowUIPanel(ArcanumButton3);
		ShowUIPanel(OrderButton3);
	else
		HideUIPanel(ArcanumButton3);
		HideUIPanel(OrderButton3);
	end
	if (ArcanumConfig.BuffType == 0) then
		if (ArcanumConfig.HearthstoneButton == true) then
			ShowUIPanel(ArcanumButton5);
			ShowUIPanel(OrderButton5);
		else
			HideUIPanel(ArcanumButton5);
			HideUIPanel(OrderButton5);
		end
		if (ARCANUM_SPELL_TABLE.ID[4] ~= nil and ArcanumConfig.BuffButton == true) then
			ShowUIPanel(ArcanumButton4);
			ShowUIPanel(OrderButton4);
		else
			HideUIPanel(ArcanumButton4);
			HideUIPanel(OrderButton4);
		end
		if (ArcanumConfig.PortalButton == true) then
			if (ARCANUM_SPELL_TABLE.ID[45] ~= nil) then
				ShowUIPanel(ArcanumButton6);
				ShowUIPanel(OrderButton6);
			else
				HideUIPanel(ArcanumButton6);
				HideUIPanel(OrderButton6);
			end
			if (ARCANUM_SPELL_TABLE.ID[41] ~= nil) then
				ShowUIPanel(ArcanumButton7);
				ShowUIPanel(OrderButton7);
			else
				HideUIPanel(ArcanumButton7);
				HideUIPanel(OrderButton7);
			end
			if (ARCANUM_SPELL_TABLE.ID[42] ~= nil) then
				ShowUIPanel(ArcanumButton8);
				ShowUIPanel(OrderButton8);
			else
				HideUIPanel(ArcanumButton8);
				HideUIPanel(OrderButton8);
			end
			if (ARCANUM_SPELL_TABLE.ID[43] ~= nil) then
				ShowUIPanel(ArcanumButton9);
				ShowUIPanel(OrderButton9);
			else
				HideUIPanel(ArcanumButton9);
				HideUIPanel(OrderButton9);
			end
			if (ARCANUM_SPELL_TABLE.ID[44] ~= nil) then
				ShowUIPanel(ArcanumButton10);
				ShowUIPanel(OrderButton10);
			else
				HideUIPanel(ArcanumButton10);
				HideUIPanel(OrderButton10);
			end
		else
			HideUIPanel(ArcanumButton6);
			HideUIPanel(OrderButton6);
			HideUIPanel(ArcanumButton7);
			HideUIPanel(OrderButton7);
			HideUIPanel(ArcanumButton8);
			HideUIPanel(OrderButton8);
			HideUIPanel(ArcanumButton9);
			HideUIPanel(OrderButton9);
			HideUIPanel(ArcanumButton10);
			HideUIPanel(OrderButton10);
		end
	else
		if (ArcanumConfig.KarazhanButton == true and Arcanum_HasAtiesh()) then
			ShowUIPanel(ArcanumButton5);
			ShowUIPanel(OrderButton5);
		else
			HideUIPanel(ArcanumButton5);
			HideUIPanel(OrderButton5);
		end
		if (ARCANUM_SPELL_TABLE.ID[5] ~= nil and ArcanumConfig.BuffButton == true) then
			ShowUIPanel(ArcanumButton4);
			ShowUIPanel(OrderButton4);
		else
			HideUIPanel(ArcanumButton4);
			HideUIPanel(OrderButton4);
		end
		if (ArcanumConfig.PortalButton == true) then
			if (ARCANUM_SPELL_TABLE.ID[55] ~= nil) then
				ShowUIPanel(ArcanumButton6);
				ShowUIPanel(OrderButton6);
			else
				HideUIPanel(ArcanumButton6);
				HideUIPanel(OrderButton6);
			end
			if (ARCANUM_SPELL_TABLE.ID[51] ~= nil) then
				ShowUIPanel(ArcanumButton7);
				ShowUIPanel(OrderButton7);
			else
				HideUIPanel(ArcanumButton7);
				HideUIPanel(OrderButton7);
			end
			if (ARCANUM_SPELL_TABLE.ID[52] ~= nil) then
				ShowUIPanel(ArcanumButton8);
				ShowUIPanel(OrderButton8);
			else
				HideUIPanel(ArcanumButton8);
				HideUIPanel(OrderButton8);
			end
			if (ARCANUM_SPELL_TABLE.ID[53] ~= nil) then
				ShowUIPanel(ArcanumButton9);
				ShowUIPanel(OrderButton9);
			else
				HideUIPanel(ArcanumButton9);
				HideUIPanel(OrderButton9);
			end
			if (ARCANUM_SPELL_TABLE.ID[54] ~= nil) then
				ShowUIPanel(ArcanumButton10);
				ShowUIPanel(OrderButton10);
			else
				HideUIPanel(ArcanumButton10);
				HideUIPanel(OrderButton10);
			end
		else
			HideUIPanel(ArcanumButton6);
			HideUIPanel(OrderButton6);
			HideUIPanel(ArcanumButton7);
			HideUIPanel(OrderButton7);
			HideUIPanel(ArcanumButton8);
			HideUIPanel(OrderButton8);
			HideUIPanel(ArcanumButton9);
			HideUIPanel(OrderButton9);
			HideUIPanel(ArcanumButton10);
			HideUIPanel(OrderButton10);
		end
	end
end

function Arcanum_HideUI()
	isHidden = true;
	HideUIPanel(ArcanumButton);
	HideUIPanel(ArcanumButton1);
	HideUIPanel(ArcanumButton2);
	HideUIPanel(ArcanumButton3);
	HideUIPanel(ArcanumButton4);
	HideUIPanel(ArcanumButton5);
	HideUIPanel(ArcanumButton6);
	HideUIPanel(ArcanumButton7);
	HideUIPanel(ArcanumButton8);
	HideUIPanel(ArcanumButton9);
	HideUIPanel(ArcanumButton10);
end

function Arcanum_InitButtons()
	ArcanumButton:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", ArcanumConfig.ArcanumButtonxPos, ArcanumConfig.ArcanumButtonyPos);
	ArcanumButton1:SetPoint("CENTER", "ArcanumButton", "CENTER", 0, 48);
	ArcanumButton2:SetPoint("CENTER", "ArcanumButton", "CENTER", 28, 39);
	ArcanumButton3:SetPoint("CENTER", "ArcanumButton", "CENTER", 45, 15);
	ArcanumButton4:SetPoint("CENTER", "ArcanumButton", "CENTER", 45, -15);
	ArcanumButton5:SetPoint("CENTER", "ArcanumButton", "CENTER", 28, -39);
	ArcanumButton6:SetPoint("CENTER", "ArcanumButton", "CENTER", 0, -48);
	ArcanumButton7:SetPoint("CENTER", "ArcanumButton", "CENTER", -28, 39);
	ArcanumButton8:SetPoint("CENTER", "ArcanumButton", "CENTER", -45, 15);
	ArcanumButton9:SetPoint("CENTER", "ArcanumButton", "CENTER", -45, -15);
	ArcanumButton10:SetPoint("CENTER", "ArcanumButton", "CENTER", -28, -39);
end

------------------------------------------------------------------------------------------------------

-- UI ICON MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

function Arcanum_LoadIconsV2()
	if ArcanumConfig.BuffType == 1 and ARCANUM_SPELL_TABLE.Rank[35] ~= nil then
		ArcanumButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[35]);
		OrderButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[35]);
	elseif ARCANUM_SPELL_TABLE.Rank[8] ~= nil then
		ArcanumButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[8]);
		OrderButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[8]);
	end

	ArcanumButton4Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[4 + ArcanumConfig.BuffType]);
	OrderButton4Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[4 + ArcanumConfig.BuffType]);

	-- Button 5: Hearthstone in solo mode, Portal: Karazhan in group mode
	if ArcanumConfig.BuffType == 0 then
		ArcanumButton5Texture:SetTexture(ArcanumButtonDisplayTexture[1]); -- Hearthstone texture
		OrderButton5Texture:SetTexture(ArcanumButtonDisplayTexture[1]);
	else
		-- Use Undercity portal icon for Karazhan portal
		ArcanumButton5Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[53] or ARCANUM_SPELL_TABLE.Texture[51]);
		OrderButton5Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[53] or ARCANUM_SPELL_TABLE.Texture[51]);
	end

	-- Button 6: Teleport Alah'Thalas in solo mode, Portal Alah'Thalas in group mode
	-- Uses bundled icons instead of the client's own spell icon files, since some
	-- Turtle WoW forks (e.g. OctoWoW) were built from an older client version that
	-- never received these two icons, leaving the button blank.
	if ArcanumConfig.BuffType == 0 then
		ArcanumButton6Texture:SetTexture("Interface\\AddOns\\Arcanum\\Icons\\spell_teleport_alahthalas");
		OrderButton6Texture:SetTexture("Interface\\AddOns\\Arcanum\\Icons\\spell_teleport_alahthalas");
	else
		ArcanumButton6Texture:SetTexture("Interface\\AddOns\\Arcanum\\Icons\\spell_portal_alahthalas");
		OrderButton6Texture:SetTexture("Interface\\AddOns\\Arcanum\\Icons\\spell_portal_alahthalas");
	end

	if ArcanumConfig.BuffType == 0 then
		for i = 41, 44 do
			local buttonNumber = i - 41 + 7;
			if (ARCANUM_SPELL_TABLE.ID[i] ~= nil) then
				getglobal("ArcanumButton" .. (buttonNumber) .. "Texture"):SetTexture(ARCANUM_SPELL_TABLE.Texture[i]);
				getglobal("OrderButton" .. (buttonNumber) .. "Texture"):SetTexture(ARCANUM_SPELL_TABLE.Texture[i]);
			end
		end
	else
		for i = 51, 54 do
			local buttonNumber = i - 51 + 7;
			if (ARCANUM_SPELL_TABLE.ID[i] ~= nil) then
				getglobal("ArcanumButton" .. (buttonNumber) .. "Texture"):SetTexture(ARCANUM_SPELL_TABLE.Texture[i]);
				getglobal("OrderButton" .. (buttonNumber) .. "Texture"):SetTexture(ARCANUM_SPELL_TABLE.Texture[i]);
			end
		end
	end
end

function Arcanum_LoadIconsV()
	CoolDown[1][3] = HearthstoneLocation[1];
	CoolDown[1][4] = HearthstoneLocation[2];
	CoolDown[2][3] = ManaGemLocation[1][1];
	CoolDown[2][4] = ManaGemLocation[1][2];
	CoolDown[3][3] = ARCANUM_SPELL_TABLE.ID[26];
	CoolDown[4][3] = ARCANUM_SPELL_TABLE.ID[32];
	CoolDown[5][3] = ARCANUM_SPELL_TABLE.ID[33];
	CoolDown[6][3] = ARCANUM_SPELL_TABLE.ID[26];
	CoolDown[7][3] = ARCANUM_SPELL_TABLE.ID[32];
	CoolDown[8][3] = ARCANUM_SPELL_TABLE.ID[33];

	for i = 1, 10 do
		getglobal("ArcanumButton" .. i .. "Texture2"):SetTexture(UIPath .. "ButtonCircle");
		getglobal("OrderButton" .. i .. "Texture2"):SetTexture(UIPath .. "ButtonCircle");
	end

	if ArcanumConfig.BuffType == 1 and ARCANUM_SPELL_TABLE.Rank[35] ~= nil then
		ArcanumButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[35]);
		OrderButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[35]);
	elseif ARCANUM_SPELL_TABLE.Rank[8] ~= nil then
		ArcanumButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[8]);
		OrderButton1Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[8]);
	end

	if ARCANUM_SPELL_TABLE.Rank[9] ~= nil then
		ArcanumButton2Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[9]);
		OrderButton2Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[9]);
	end

	Arcanum_ManaGemIcons();
end

function Arcanum_LoadIcons()
	Arcanum_LoadIconsV();
	Arcanum_LoadIconsV2();
	Arcanum_EDIcons();
end

function Arcanum_ManaGemIcons()
	if (ManaGemExists[1] == true) then
		ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[13]);
		OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[13]);
		ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[13];
	elseif (ManaGemExists[2] == true) then
		ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[12]);
		OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[12]);
		ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[12];
	elseif (ManaGemExists[3] == true) then
		ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[11]);
		OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[11]);
		ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[11];
	elseif (ManaGemExists[4] == true) then
		ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[10]);
		OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[10]);
		ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[10];
	else
		if (ARCANUM_SPELL_TABLE.ID[13] ~= nil) then
			ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[13]);
			OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[13]);
			ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[13];
		elseif (ARCANUM_SPELL_TABLE.ID[12] ~= nil) then
			ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[12]);
			OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[12]);
			ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[12];
		elseif (ARCANUM_SPELL_TABLE.ID[11] ~= nil) then
			ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[11]);
			OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[11]);
			ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[11];
		elseif (ARCANUM_SPELL_TABLE.ID[10] ~= nil) then
			ArcanumButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[10]);
			OrderButton3Texture:SetTexture(ARCANUM_SPELL_TABLE.Texture[10]);
			ArcanumButtonDisplayTexture[2] = ARCANUM_SPELL_TABLE.Texture[10];
		end
	end
end

function Arcanum_EDIconsV()
	if ARCANUM_SPELL_TABLE.Rank[8] ~= nil then
		if OrangeCount > 0 then
			ArcanumFoodCount:SetText(OrangeCount);
			ArcanumButton1Texture:SetDesaturated(nil);
		elseif FoodCount > 0 then
			ArcanumFoodCount:SetText(FoodCount);
			ArcanumButton1Texture:SetDesaturated(nil);
		else
			ArcanumFoodCount:SetText("");
			ArcanumButton1Texture:SetDesaturated(1);
		end
	end
	if ARCANUM_SPELL_TABLE.Rank[9] ~= nil then
		if WaterCount == 0 then
			ArcanumWaterCount:SetText("");
			ArcanumButton2Texture:SetDesaturated(1);
		else
			ArcanumWaterCount:SetText(WaterCount);
			ArcanumButton2Texture:SetDesaturated(nil);
		end
	end
	if (ManaGemExists[1] == true or ManaGemExists[2] == true or ManaGemExists[3] == true or ManaGemExists[4] == true) then
		ArcanumButton3Texture:SetDesaturated(nil);
	else
		ArcanumButton3Texture:SetDesaturated(1);
	end
end

function Arcanum_EDIconsV2()
	if ArcanumConfig.BuffType == 0 then
		ArcanumButton4Text:SetText("");
		ArcanumButton4Texture:SetDesaturated(nil);
		if ArcanumRuneOfTeleportation == 0 then
			ArcanumButton7Texture:SetDesaturated(1);
			ArcanumButton8Texture:SetDesaturated(1);
			ArcanumButton9Texture:SetDesaturated(1);
			ArcanumButton10Texture:SetDesaturated(1);
		else
			ArcanumButton7Texture:SetDesaturated(nil);
			ArcanumButton8Texture:SetDesaturated(nil);
			ArcanumButton9Texture:SetDesaturated(nil);
			ArcanumButton10Texture:SetDesaturated(nil);
		end
	else
		if ArcanumArcanePowder == 0 then
			ArcanumButton4Text:SetText("");
			ArcanumButton4Texture:SetDesaturated(1);
		else
			ArcanumButton4Text:SetText(ArcanumArcanePowder);
			ArcanumButton4Texture:SetDesaturated(nil);
		end
		if ArcanumRuneOfPortals == 0 then
			ArcanumButton7Texture:SetDesaturated(1);
			ArcanumButton8Texture:SetDesaturated(1);
			ArcanumButton9Texture:SetDesaturated(1);
			ArcanumButton10Texture:SetDesaturated(1);
		else
			ArcanumButton7Texture:SetDesaturated(nil);
			ArcanumButton8Texture:SetDesaturated(nil);
			ArcanumButton9Texture:SetDesaturated(nil);
			ArcanumButton10Texture:SetDesaturated(nil);
		end
	end
end

function Arcanum_EDIcons()
	Arcanum_EDIconsV();
	Arcanum_EDIconsV2();
end

function Arcanum_CombatDisableIcons()
	if ArcanumConfig.HideInCombat then
		Arcanum_HideUI();
	else
		if ARCANUM_SPELL_TABLE.ID[8] ~= nil then
			ArcanumButton1Texture:SetDesaturated(1);
		end
		if ARCANUM_SPELL_TABLE.ID[9] ~= nil then
			ArcanumButton2Texture:SetDesaturated(1);
		end
		ArcanumButtonTexture:SetTexture(UIPath .. "ArcanumC");
	end
end

function Arcanum_CombatEnableIcons()
	if hiddenByUser then
		return ;
	end

	if ArcanumConfig.HideInCombat then
		Arcanum_Initialize();
	else
		if OrangeCount ~= 0 and ARCANUM_SPELL_TABLE.ID[35] ~= nil then
			ArcanumButton1Texture:SetDesaturated(nil);
		else
			if FoodCount ~= 0 and ARCANUM_SPELL_TABLE.ID[8] ~= nil then
				ArcanumButton1Texture:SetDesaturated(nil);
			end
		end

		if WaterCount ~= 0 and ARCANUM_SPELL_TABLE.ID[9] ~= nil then
			ArcanumButton2Texture:SetDesaturated(nil);
		end
		ArcanumButtonTexture:SetTexture(UIPath .. "ArcanumN");
	end
end

------------------------------------------------------------------------------------------------------

-- UI BUTTON BEHAVIOR MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

-- Function (XML) to restore default anchor points for buttons
function Arcanum_ClearAllPoints()
	ArcanumButton1:ClearAllPoints();
	ArcanumButton2:ClearAllPoints();
	ArcanumButton3:ClearAllPoints();
	ArcanumButton4:ClearAllPoints();
	ArcanumButton5:ClearAllPoints();
	ArcanumButton6:ClearAllPoints();
	ArcanumButton7:ClearAllPoints();
	ArcanumButton8:ClearAllPoints();
	ArcanumButton9:ClearAllPoints();
	ArcanumButton10:ClearAllPoints();
end

-- Fonction (XML) pour Ã©tendre la propriÃ©tÃ© NoDrag() du bouton principal d'Arcanum sur tous ses boutons
function Arcanum_NoDrag()
	ArcanumButton1:RegisterForDrag("");
	ArcanumButton2:RegisterForDrag("");
	ArcanumButton3:RegisterForDrag("");
	ArcanumButton4:RegisterForDrag("");
	ArcanumButton5:RegisterForDrag("");
	ArcanumButton6:RegisterForDrag("");
	ArcanumButton7:RegisterForDrag("");
	ArcanumButton8:RegisterForDrag("");
	ArcanumButton9:RegisterForDrag("");
	ArcanumButton10:RegisterForDrag("");
end

-- Fonction (XML) inverse de celle du dessus
function Arcanum_Drag()
	ArcanumButton1:RegisterForDrag("LeftButton");
	ArcanumButton2:RegisterForDrag("LeftButton");
	ArcanumButton3:RegisterForDrag("LeftButton");
	ArcanumButton4:RegisterForDrag("LeftButton");
	ArcanumButton5:RegisterForDrag("LeftButton");
	ArcanumButton6:RegisterForDrag("LeftButton");
	ArcanumButton7:RegisterForDrag("LeftButton");
	ArcanumButton8:RegisterForDrag("LeftButton");
	ArcanumButton9:RegisterForDrag("LeftButton");
	ArcanumButton10:RegisterForDrag("LeftButton");
end

function Arcanum_MovableIcons()
	ArcanumButton1:SetPoint("CENTER", "UIParent", "CENTER", -161, -100);
	ArcanumButton2:SetPoint("CENTER", "UIParent", "CENTER", -125, -100);
	ArcanumButton3:SetPoint("CENTER", "UIParent", "CENTER", -89, -100);
	ArcanumButton4:SetPoint("CENTER", "UIParent", "CENTER", -53, -100);
	ArcanumButton5:SetPoint("CENTER", "UIParent", "CENTER", -17, -100);
	ArcanumButton6:SetPoint("CENTER", "UIParent", "CENTER", 17, -100);
	ArcanumButton7:SetPoint("CENTER", "UIParent", "CENTER", 53, -100);
	ArcanumButton8:SetPoint("CENTER", "UIParent", "CENTER", 89, -100);
	ArcanumButton9:SetPoint("CENTER", "UIParent", "CENTER", 125, -100);
	ArcanumButton10:SetPoint("CENTER", "UIParent", "CENTER", 161, -100);
end

function Arcanum_UpdateButtonsScale()
	local NBRScale = (100 + (ArcanumConfig.ArcanumButtonScale - 85)) / 100;
	if ArcanumConfig.ArcanumButtonScale <= 95 then
		NBRScale = 1.1;
	end
	if ArcanumConfig.ArcanumLockServ then
		Arcanum_ClearAllPoints();
		local indexScale = -18;
		NBRScale = 1.15;
		for index = 1, 10, 1 do
			getglobal("ArcanumButton" .. ArcanumConfig.ButtonsOrder[index]):SetPoint("CENTER", "ArcanumButton", "CENTER", ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale)), ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale)));
			getglobal("OrderButton" .. ArcanumConfig.ButtonsOrder[index]):SetPoint("CENTER", "ArcanumOrderButton", "CENTER", (32 * cos(ArcanumConfig.ArcanumAngle - indexScale)), (32 * sin(ArcanumConfig.ArcanumAngle - indexScale)));
			if ArcanumConfig.ButtonsOrder[index] == 4 and BuffMenuCreate ~= {} then
				xBuffMenuPos = ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale))
				yBuffMenuPos = ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale));
			end
			if ArcanumConfig.ButtonsOrder[index] == 5 and PortalMenuCreate ~= {} then
				xArmorMenuPos = ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale))
				yArmorMenuPos = ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale));
			end
			if ArcanumConfig.ButtonsOrder[index] == 6 and MountMenuCreate ~= {} then
				xMagicMenuPos = ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale))
				yMagicMenuPos = ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale));
			end
			if ArcanumConfig.ButtonsOrder[index] == 7 and ArmorMenuCreate ~= {} then
				xMountMenuPos = ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale))
				yMountMenuPos = ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale));
			end
			if ArcanumConfig.ButtonsOrder[index] == 8 and MagicMenuCreate ~= {} then
				xPortalMenuPos = ((40 * NBRScale) * cos(ArcanumConfig.ArcanumAngle - indexScale))
				yPortalMenuPos = ((40 * NBRScale) * sin(ArcanumConfig.ArcanumAngle - indexScale));
			end
			indexScale = indexScale + 36;
		end

		ArcanumButton1:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton2:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton3:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton4:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton5:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton6:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton7:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton8:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton9:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
		ArcanumButton10:SetScale(ArcanumConfig.ArcanumButtonScale / 100);
	end
end

function Arcanum_MenuPos(button)
	local a, b, c, x, y = button:GetPoint("CENTER");
	x = ((32 * x) / 40);
	y = ((32 * y) / 40);
	return x, y;
end

function Arcanum_IntSign(Value)
	local Result;
	if math.abs(Value) == Value then
		Result = 1;
	else
		Result = -1;
	end
	return Result;
end

------------------------------------------------------------------------------------------------------

-- UI MENU BUTTON MANAGEMENT FUNCTIONS

------------------------------------------------------------------------------------------------------

-- Managing casts from buff menu
function Arcanum_BuffCast(type)
	local TargetEnemy = false;
	if (not (UnitIsFriend("player", "target"))) then
		TargetUnit("player");
		TargetEnemy = true;
	end
	if (type == 4) then
		if ArcanumConfig.LevelBuff == true then
			if (UnitExists("target")) then
				for i = ARCANUM_SPELL_TABLE.Rank[4], 1, -1 do
					if UnitLevel("target") >= Buff_Minlvl[i] then
						local BuffName = ARCANUM_SPELL_TABLE.Name[4] .. "(" .. ARCANUM_TRANSLATION.Rank .. " " .. i .. ")";
						CastSpellByName(BuffName);
						break ;
					end
				end
			end
		else
			CastSpell(ARCANUM_SPELL_TABLE.ID[4], "spell");
		end
	else
		CastSpell(ARCANUM_SPELL_TABLE.ID[type], "spell");
	end

	ArcanumConfig.LastBuff = type;

	if TargetEnemy then
		TargetLastTarget();
	end
	AlphaBuffMenu = 1;
	AlphaBuffVar = GetTime() + 3;
end


-- Managing casts from armor menu
function Arcanum_ArmorCast(type)
	-- Si le mage possÃ¨de l'armure de glace
	if (ARCANUM_SPELL_TABLE.ID[type] ~= nil) then
		CastSpell(ARCANUM_SPELL_TABLE.ID[type], "spell");
		ArcanumConfig.LastArmor = type;
	else
		CastSpell(ARCANUM_SPELL_TABLE.ID[1], "spell");
		ArcanumConfig.LastArmor = 1;
	end

	AlphaArmorMenu = 1;
	AlphaArmorVar = GetTime() + 3;
end

-- Managing casts from magic menu
function Arcanum_MagicCast(type)
	local TargetEnemy = false;
	if (not (UnitIsFriend("player", "target"))) and type ~= 9 then
		TargetUnit("player");
		TargetEnemy = true;
	end
	if ArcanumConfig.LevelBuff == true then
		if (UnitExists("target")) then
			for i = ARCANUM_SPELL_TABLE.Rank[type], 1, -1 do
				if type == 7 then
					if UnitLevel("target") >= Amplify_Minlvl[i] then
						local BuffName = ARCANUM_SPELL_TABLE.Name[7] .. "(" .. ARCANUM_TRANSLATION.Rank .. " " .. i .. ")";
						CastSpellByName(BuffName);
						break ;
					end
				elseif type == 6 then
					if UnitLevel("target") >= Dampen_Minlvl[i] then
						local BuffName = ARCANUM_SPELL_TABLE.Name[6] .. "(" .. ARCANUM_TRANSLATION.Rank .. " " .. i .. ")";
						CastSpellByName(BuffName);
						break ;
					end
				end
			end
		end
	else
		CastSpell(ARCANUM_SPELL_TABLE.ID[type], "spell");
	end

	ArcanumConfig.LastMagic = type;
	if TargetEnemy then
		TargetLastTarget();
	end
	AlphaMagicMenu = 1;
	AlphaMagicVar = GetTime() + 3;
end

-- Managing casts from portal menu
function Arcanum_PortalCast(type)
	if (ARCANUM_SPELL_TABLE.ID[type] ~= nil) then
		CastSpell(ARCANUM_SPELL_TABLE.ID[type], "spell");
		ArcanumConfig.LastPortal = type;

		local ville;
		if type > 40 and type < 50 then
			ville = type - 40;
		elseif type > 50 and type < 60 then
			ville = type - 50;
		end

		AlphaPortalMenu = 1;
		AlphaPortalVar = GetTime() + 3;

		if ArcanumConfig.PortalMessage == true and type >= 20 and (GetTime() - TPMessTime) > 3 then
			-- Only send emote if 3 seconds have passed since last one
			local tempnum = random(1, table.getn(ARCANUM_PORTAL_MESSAGES));
			while tempnum == TPMess and table.getn(ARCANUM_PORTAL_MESSAGES) >= 2 do
				tempnum = random(1, table.getn(ARCANUM_PORTAL_MESSAGES));
			end
			TPMess = tempnum;
			TPMessTime = GetTime(); -- Update timestamp
			for i = 1, table.getn(ARCANUM_PORTAL_MESSAGES[tempnum]) do
				-- Send as emote instead of chat message
				SendChatMessage(Arcanum_MsgReplace(ARCANUM_PORTAL_MESSAGES[tempnum][i], ville), "EMOTE");
			end
		end
	end
end

------------------------------------------------------------------------------------------------------

-- COMBOBOX MANAGEMENT FUNCTION

------------------------------------------------------------------------------------------------------

function ArcanumInsideDisplayDropDown_Initialize()
	local index;
	local info = {};

	for i in pairs(ArcanumInsideDisplayClick) do
		info.text = ArcanumInsideDisplayClick[i];
		info.checked = nil;
		info.func = ArcanumInsideDisplayDropDown_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function ArcanumInsideDisplayDropDown_OnClick()
	UIDropDownMenu_SetSelectedID(ArcanumInsideDisplayDropDown, this:GetID());
	ArcanumConfig.InsideDisplay = this:GetID();
end

function ArcanumLeftClickDropDown_Initialize()
	local index;
	local info = {};

	for i in pairs(ArcanumLeftButtonClick) do
		info.text = ArcanumLeftButtonClick[i];
		info.checked = nil;
		info.func = ArcanumLeftClickDropDown_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function ArcanumLeftClickDropDown_OnClick()
	UIDropDownMenu_SetSelectedID(ArcanumLeftClickDropDown, this:GetID());
	ArcanumConfig.LeftClick = this:GetID();
end

function ArcanumMiddleClickDropDown_Initialize()
	local index;
	local info = {};

	for i in pairs(ArcanumMiddleButtonClick) do
		info.text = ArcanumMiddleButtonClick[i];
		info.checked = nil;
		info.func = ArcanumMiddleClickDropDown_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function ArcanumMiddleClickDropDown_OnClick()
	UIDropDownMenu_SetSelectedID(ArcanumMiddleClickDropDown, this:GetID());
	ArcanumConfig.MiddleClick = this:GetID();
end

function ArcanumRightClickDropDown_Initialize()
	local index;
	local info = {};

	for i in pairs(ArcanumRightButtonClick) do
		info.text = ArcanumRightButtonClick[i];
		info.checked = nil;
		info.func = ArcanumRightClickDropDown_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function ArcanumRightClickDropDown_OnClick()
	UIDropDownMenu_SetSelectedID(ArcanumRightClickDropDown, this:GetID());
	ArcanumConfig.RightClick = this:GetID();
end

function Arcanum_FillClickTable(table)
	ClearTable(table);
	for i = 1, table.getn(ARCANUM_CLICK) do
		table.insert(table, ARCANUM_CLICK[i]);
	end
end

function Arcanum_Click(button)
	if (button == 1) then
		if (ArcanumGeneralFrame:IsVisible()) then
			HideUIPanel(ArcanumGeneralFrame);
			return ;
		else
			ShowUIPanel(ArcanumGeneralFrame);
			ArcanumGeneralTab_OnClick(1);
			return ;
		end
		GameTooltip:Hide();
	elseif (button == 2) then
		if (UnitHealth("Player") < UnitHealthMax("Player")) then
			Arcanum_UseItem("Food", "LeftButton");
		end
		if (UnitMana("Player") < UnitManaMax("Player")) then
			Arcanum_UseItem("Water", "LeftButton");
		end
	elseif (button == 3) then
		Arcanum_UseItem("Hearthstone");
	elseif (button == 4) then
		Arcanum_UseItem("Evocation");
	elseif (button == 5) then
		Arcanum_UseItem("ManaGem", "LeftButton");
	elseif (button == 6) then
		Arcanum_UseItem("Iceblock");
	elseif (button == 7) then
		Arcanum_Trade();
		ArcanumTradeNow = true;
	elseif (button == 8) then
		if (ArcanumConfig.BuffType == 0) then
			--On passe de 'Solo' Ã  'en groupe'
			if (ARCANUM_SPELL_TABLE.ID[3] ~= nil or ARCANUM_SPELL_TABLE.ID[5] ~= nil or ARCANUM_SPELL_TABLE.ID[7] ~= nil or ARCANUM_SPELL_TABLE.ID[20] ~= nil or ARCANUM_SPELL_TABLE.ID[21] ~= nil or ARCANUM_SPELL_TABLE.ID[22] ~= nil or ARCANUM_SPELL_TABLE.ID[23] ~= nil or ARCANUM_SPELL_TABLE.ID[24] ~= nil or ARCANUM_SPELL_TABLE.ID[25] ~= nil) then
				ArcanumConfig.BuffType = 1;
				Arcanum_Arcanum2ButtonSetup();
				Arcanum_LoadIconsV2();
				Arcanum_EDIcons();
			end
		else
			--On passe de 'en groupe' Ã  'Solo'
			ArcanumConfig.BuffType = 0;
			Arcanum_Arcanum2ButtonSetup();
			Arcanum_LoadIconsV2();
			Arcanum_EDIcons();
		end
		GameTooltip:Hide();
	end
end

function Arcanum_Cooldown()
	local start, duration;

	CoolDown[2][3], CoolDown[2][4] = nil;
	for i = 1, 4 do
		if (ManaGemExists[i] == true) then
			CoolDown[2][3] = ManaGemLocation[i][1];
			CoolDown[2][4] = ManaGemLocation[i][2];
		end
	end

	for i = 1, table.getn(CoolDown) - 3 do
		start, duration = 0;
		if (CoolDown[i][3] ~= nil) then
			if (CoolDown[i][4] == nil) then
				start, duration = GetSpellCooldown(CoolDown[i][3], "spell");
			else
				start, duration = GetContainerItemCooldown(CoolDown[i][3], CoolDown[i][4]);
			end
			if (start > 0 and duration > 0) then
				cooldown = duration - GetTime() + start;
				if cooldown > 60 then
					CoolDown[i][1] = tostring(math.ceil(cooldown / 60)) .. "m";
				else
					CoolDown[i][1] = tostring(math.ceil(cooldown)) .. "s";
				end
				if CoolDown[i][2] == true and cooldown > 10 then
					CoolDown[i][2] = false;
				end
			else
				CoolDown[i][1] = nil;
			end
		end
	end

	CoolDown[6][1] = nil;
	CoolDown[7][1] = nil;
	CoolDown[8][1] = nil;
	--Temps restant d'intell et armure
	for i = 0, 23 do
		buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL|HARMFUL|PASSIVE");
		if (buffIndex < 0) then
			break ;
		elseif (untilCancelled) then
			ArcanumTooltip:SetPlayerBuff(buffIndex);
			if (ArcanumTooltipTextLeft1:IsShown()) then
				local text = ArcanumTooltipTextLeft1:GetText();
				local time = GetPlayerBuffTimeLeft(buffIndex)
				if time ~= nil then
					if time > 60 then
						time = tostring(math.ceil(time / 60)) .. "m";
					else
						time = tostring(math.ceil(time)) .. "s";
					end
				end
				if (text) then
					if (text == ARCANUM_SPELL_TABLE.Name[1] or text == ARCANUM_SPELL_TABLE.Name[2]) then
						ArcanumButtonDisplayTexture[7] = ARCANUM_SPELL_TABLE.Texture[1];
						CoolDown[7][1] = time;
						if CoolDown[7][2] == true then
							CoolDown[7][2] = false;
						end
					elseif (text == ARCANUM_SPELL_TABLE.Name[3]) then
						ArcanumButtonDisplayTexture[7] = ARCANUM_SPELL_TABLE.Texture[3];
						CoolDown[7][1] = time;
						if CoolDown[7][2] == true then
							CoolDown[7][2] = false;
						end
					elseif (text == ARCANUM_SPELL_TABLE.Name[4]) then
						ArcanumButtonDisplayTexture[6] = ARCANUM_SPELL_TABLE.Texture[4];
						CoolDown[6][1] = time;
						if CoolDown[6][2] == true then
							CoolDown[6][2] = false;
						end
					elseif (text == ARCANUM_SPELL_TABLE.Name[5]) then
						ArcanumButtonDisplayTexture[6] = ARCANUM_SPELL_TABLE.Texture[5];
						CoolDown[6][1] = time;
						if CoolDown[6][2] == true then
							CoolDown[6][2] = false;
						end
					elseif (text == ARCANUM_BANDAGE) then
						CoolDown[8][1] = time;
						if CoolDown[8][2] == true then
							CoolDown[8][2] = false;
						end
					end
				end
			end
		end
	end
end

function Arcanum_SpellManagement()
	-- This is called when SPELLCAST_STOP fires (spell successfully completes)
	-- Set cooldowns based on what spell was just cast
	
	-- Check if we just used Atiesh
	if AtieshUsed then
		AtieshCooldown = GetTime() + 60
		AtieshUsed = false
	end
	
	if not SpellCastName then
		return
	end
	
	-- Check for portal/teleport spells and set 60-second cooldowns
	-- Map spell names to button indices
	local portalMap = {
		["Teleport: Darnassus"] = 1,
		["Teleport: Ironforge"] = 2,
		["Teleport: Stormwind"] = 3,
		["Teleport: Theramore"] = 4,
		["Teleport: Alah'Thalas"] = 5,
		["Teleport: Orgrimmar"] = 1,
		["Teleport: Thunder Bluff"] = 2,
		["Teleport: Undercity"] = 3,
		["Teleport: Stonard"] = 4,
		["Portal: Darnassus"] = 1,
		["Portal: Ironforge"] = 2,
		["Portal: Stormwind"] = 3,
		["Portal: Theramore"] = 4,
		["Portal: Alah'Thalas"] = 5,
		["Portal: Orgrimmar"] = 1,
		["Portal: Thunder Bluff"] = 2,
		["Portal: Undercity"] = 3,
		["Portal: Stonard"] = 4,
	}
	
	local buttonIndex = portalMap[SpellCastName]
	if buttonIndex and buttonIndex <= 4 then
		-- Set 60 second cooldown for portal buttons 7, 8, 9, 10
		PortalCooldown[buttonIndex] = GetTime() + 60
	end
end

function Arcanum_SelectButtonOrder(Id)
	SelectedOrderButton = Id;
	for i = 1, 10 do
		Button = getglobal("OrderButton" .. i .. "Texture2");
		Button:SetTexture(UIPath .. "ButtonCircle");
	end
	Button = getglobal("OrderButton" .. Id .. "Texture2");
	Button:SetVertexColor(ArcanumConfig.ButtonColor.r, ArcanumConfig.ButtonColor.g, ArcanumConfig.ButtonColor.b);
end

function Arcanum_SwitchButtonOrder(Way)
	if SelectedOrderButton ~= nil then
		local Temp = Arcanum_FindButton(SelectedOrderButton);
		if Temp == 1 and Way == -1 then
			ArcanumConfig.ButtonsOrder[Temp] = ArcanumConfig.ButtonsOrder[10];
			ArcanumConfig.ButtonsOrder[10] = SelectedOrderButton;
		elseif Temp == 10 and Way == 1 then
			ArcanumConfig.ButtonsOrder[Temp] = ArcanumConfig.ButtonsOrder[1];
			ArcanumConfig.ButtonsOrder[1] = SelectedOrderButton;
		else
			ArcanumConfig.ButtonsOrder[Temp] = ArcanumConfig.ButtonsOrder[Temp + Way];
			ArcanumConfig.ButtonsOrder[Temp + Way] = SelectedOrderButton;
		end
		Arcanum_UpdateButtonsScale();
	end
end

function Arcanum_FindButton(Id)
	for i = 1, table.getn(ArcanumConfig.ButtonsOrder) do
		if ArcanumConfig.ButtonsOrder[i] == Id then
			return i;
		end
	end
end

function Arcanum_ButtonMouseOver(button, menu)
	local Button;
	if menu == nil then
		if button <= 10 then
			Button = getglobal("ArcanumButton" .. button .. "Texture2");
		else
			Button = getglobal("OrderButton" .. (button - 10) .. "Texture2");
		end
	else
		Button = getglobal("ArcanumButton" .. button .. "Menu" .. menu .. "Texture2");
	end
	Button:SetVertexColor(ArcanumConfig.ButtonColor.r, ArcanumConfig.ButtonColor.g, ArcanumConfig.ButtonColor.b);
end

function Arcanum_ButtonNormal(button, menu)
	local Button;
	if menu == nil then
		if button <= 10 then
			Button = getglobal("ArcanumButton" .. button .. "Texture2");
		else
			Button = getglobal("OrderButton" .. (button - 10) .. "Texture2");
		end
	else
		Button = getglobal("ArcanumButton" .. button .. "Menu" .. menu .. "Texture2");
	end
	if SelectOrderButton ~= nil then
		if button ~= (SelectedOrderButton + 10) then
			Button:SetVertexColor(1, 1, 1);
		end
	else
		Button:SetVertexColor(1, 1, 1);
	end
end

function ArcanumButton_TextDisplay()
	ArcanumButtonDisplay = {
		{ "|CFF00FF00" .. tostring(UnitHealth("player")), floor(UnitHealth("player") / UnitHealthMax("player") * 100) },
		{ "|CFF0000FF" .. tostring(UnitMana("player")), floor(UnitMana("player") / UnitManaMax("player") * 100) },
		CoolDown[2][1],
		CoolDown[3][1],
		CoolDown[4][1],
		CoolDown[5][1],
		IntellCooldown,
		ArmorCooldown,
		BandageCooldown,
	};

	--local size = 58 * p;
	--ArcanumButtonTexture3:SetHeight(size);
	--ArcanumButtonTexture3:SetTexCoord(0, 1, (1-p), 1);

	local p = UnitHealth("player") / UnitHealthMax("player");
	p = floor(UnitMana("player") / UnitManaMax("player"));
	Arcanum_DisplayMana(ArcanumButtonDisplay[2][2]);
	Arcanum_DisplayHealth(ArcanumButtonDisplay[1][2]);

	if ArcanumButtonDisplayImage == nil and ArcanumConfig.InsideDisplay < 3 then
		ArcanumButtonText:SetText(ArcanumButtonDisplay[ArcanumConfig.InsideDisplay][1] .. "\n" .. ArcanumButtonDisplay[ArcanumConfig.InsideDisplay][2] .. "%");
	else
		ArcanumButtonText:SetText("");
	end

	if (CoolDown[2][1] ~= nil) then
		ArcanumManaGemCooldown:SetText(CoolDown[2][1]);
	elseif ManaGemCount ~= 0 then
		ArcanumManaGemCooldown:SetText(ManaGemCount);
	else
		ArcanumManaGemCooldown:SetText("");
	end
end

function ArcanumButton_ImageDisplay()
	ArcanumButtonDisplayImage = Arcanum_DisplayNextImage();
	ArcanumButton_TextDisplay();
	if ArcanumButtonDisplayImage ~= nil then
		ArcanumButtonTexture2:SetTexture(ArcanumButtonDisplayTexture[ArcanumButtonDisplayImage]);
		CoolDown[ArcanumButtonDisplayImage][2] = true;
	else
		ArcanumButtonTexture2:SetTexture(nil);
	end
end

function Arcanum_DisplayNextImage()
	local Next = nil;
	for j = 1, 8 do
		if ArcanumConfig.Display[j] == true then
			if CoolDown[j][1] == nil and CoolDown[j][2] == false then
				Next = j;
				return Next;
			end
		end
	end
	return Next;
end

function Arcanum_DisplayNext(start)
	local Next = nil;
	for i = 1, 2 do
		for j = start + 1, 9 do
			if ArcanumConfig.Display[j] == true then
				if ArcanumButtonDisplay[j] ~= nil then
					if ArcanumConfig.DisplayWhenReady == true then
					else
						Next = j;
						return Next;
					end
				else
					Next = j;
					return Next;
				end
			end
		end
		start = 0;
	end
	return Next;
end

function Arcanum_DisplayFading()
	--if ArcanumConfig.DisplayWhenReady == true and ArcanumButtonDisplay[ArcanumButtonDisplayValue] ~= nil then
	if DisplayFadingLimit == 0 then
		if AlphaDisplay <= DisplayFadingLimit then
			DisplayFadingWay = -DisplayFadingWay;
			DisplayFadingLimit = 1;
		end
	else
		if AlphaDisplay >= DisplayFadingLimit then
			DisplayFadingWay = -DisplayFadingWay;
			DisplayFadingLimit = 0;
		end
	end
	if GetTime() >= AlphaDisplayVar then
		AlphaDisplayVar = GetTime() + 0.1;
		ArcanumButtonTexture2:SetAlpha(AlphaDisplay);
		AlphaDisplay = AlphaDisplay + (DisplayFadingWay * (0.1 / 1));
		if AlphaDisplay < 0 then
			AlphaDisplay = 0;
		elseif AlphaDisplay > 1 then
			AlphaDisplay = 1;
		end
	end
	--end
end

function Arcanum_RotateTexture(t, angle)
	local H = 1 / (2 * cos(45));
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy;
	ULx, ULy = H * cos(angle - 135) + 0.5, H * sin(angle - 135) + 0.5;
	LLx, LLy = H * cos(angle + 135) + 0.5, H * sin(angle + 135) + 0.5;
	URx, URy = H * cos(angle - 45) + 0.5, H * sin(angle - 45) + 0.5;
	LRx, LRy = H * cos(angle + 45) + 0.5, H * sin(angle + 45) + 0.5;
	t:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy);
end

function Arcanum_DisplayMana(p)
	for i = 1, 100 do
		angle = -1.8 * (i - 1);
		Arcanum_RotateTexture(getglobal("ArcanumButtonManaTexture" .. i), angle)
		if i <= (100 - p) then
			getglobal("ArcanumButtonManaTexture" .. i):SetTexture(nil);
		else
			getglobal("ArcanumButtonManaTexture" .. i):SetTexture(UIPath .. "Circle");
		end
		if p >= 50 then
			getglobal("ArcanumButtonManaTexture" .. i):SetVertexColor(ArcanumConfig.ManaColor.r, ArcanumConfig.ManaColor.g, ArcanumConfig.ManaColor.b);
		else
			getglobal("ArcanumButtonManaTexture" .. i):SetVertexColor(ArcanumConfig.ManaColor.r + 1, ArcanumConfig.ManaColor.g, ArcanumConfig.ManaColor.b);
		end
		getglobal("ArcanumButtonManaTexture" .. i):SetBlendMode("BLEND");
	end
end

function Arcanum_DisplayHealth(p)
	for i = 1, 100 do
		angle = 1.8 * i;
		Arcanum_RotateTexture(getglobal("ArcanumButtonHealthTexture" .. i), angle)
		if i <= (100 - p) then
			getglobal("ArcanumButtonHealthTexture" .. i):SetTexture(nil);
		else
			getglobal("ArcanumButtonHealthTexture" .. i):SetTexture(UIPath .. "Circle");
		end
		getglobal("ArcanumButtonHealthTexture" .. i):SetVertexColor(ArcanumConfig.HealthColor.r, ArcanumConfig.HealthColor.g, ArcanumConfig.HealthColor.b);
		getglobal("ArcanumButtonHealthTexture" .. i):SetBlendMode("BLEND");
	end
end

function Arcanum_HealthColor()
	ArcanumConfig.HealthColor.r, ArcanumConfig.HealthColor.g, ArcanumConfig.HealthColor.b = ColorPickerFrame:GetColorRGB();
end

function Arcanum_ManaColor()
	ArcanumConfig.ManaColor.r, ArcanumConfig.ManaColor.g, ArcanumConfig.ManaColor.b = ColorPickerFrame:GetColorRGB();
end

function Arcanum_ButtonColor()
	ArcanumConfig.ButtonColor.r, ArcanumConfig.ButtonColor.g, ArcanumConfig.ButtonColor.b = ColorPickerFrame:GetColorRGB();
	ArcanumMinimapButtonTexture2:SetVertexColor(ArcanumConfig.ButtonColor.r, ArcanumConfig.ButtonColor.g, ArcanumConfig.ButtonColor.b);
end

function Arcanum_CancelHealthColor()
	local color = ColorPickerFrame.previousValues;
	--ColorPickerFrame:SetBackdropColor(color.r, color.g, color.b);
	ArcanumConfig.HealthColor = color;
end

function Arcanum_CancelManaColor()
	local color = ColorPickerFrame.previousValues;
	--ColorPickerFrame:SetBackdropColor(color.r, color.g, color.b);
	ArcanumConfig.ManaColor = color;
end

function Arcanum_CancelButtonColor()
	local color = ColorPickerFrame.previousValues;
	--ColorPickerFrame:SetBackdropColor(color.r, color.g, color.b);
	ArcanumConfig.ButtonColor = color;
end

function Arcanum_HealthColorClick()
	local color = {};
	color.r = ArcanumConfig.HealthColor.r;
	color.g = ArcanumConfig.HealthColor.g;
	color.b = ArcanumConfig.HealthColor.b;
	ColorPickerFrame.previousValues = color;
	ColorPickerFrame.cancelFunc = Arcanum_CancelHealthColor;
	ColorPickerFrame.func = Arcanum_HealthColor;
	ColorPickerFrame:SetColorRGB(color.r, color.g, color.b);
	ColorPickerFrame:Show();
end

function Arcanum_ManaColorClick()
	local color = {};
	color.r = ArcanumConfig.ManaColor.r;
	color.g = ArcanumConfig.ManaColor.g;
	color.b = ArcanumConfig.ManaColor.b;
	ColorPickerFrame.previousValues = color;
	ColorPickerFrame.cancelFunc = Arcanum_CancelManaColor;
	ColorPickerFrame.func = Arcanum_ManaColor;
	ColorPickerFrame:SetColorRGB(color.r, color.g, color.b);
	ColorPickerFrame:Show();
end

function Arcanum_ButtonColorClick()
	local color = {};
	color.r = ArcanumConfig.ButtonColor.r;
	color.g = ArcanumConfig.ButtonColor.g;
	color.b = ArcanumConfig.ButtonColor.b;
	ColorPickerFrame.previousValues = color;
	ColorPickerFrame.cancelFunc = Arcanum_CancelButtonColor;
	ColorPickerFrame.func = Arcanum_ButtonColor;
	ColorPickerFrame:SetColorRGB(color.r, color.g, color.b);
	ColorPickerFrame:Show();
end
