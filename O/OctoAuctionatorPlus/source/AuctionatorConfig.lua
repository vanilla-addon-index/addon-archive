
local addonName, addonTable = "Auctionator", AtrNS; 
local zc = addonTable.zc;

AtrNS.optionPanels = AtrNS.optionPanels or {};

-----------------------------------------

function Atr_LoadOptionsSubPanel (f, name, title, subtitle)

	f.name		= name

	local frameName = f:GetName();

	f.okay   = getglobal (frameName.."_Save")

	if (title    == nil) then title = name; end
	if (subtitle == nil) then subtitle = ""; end

	getglobal (frameName.."_ATitle"):SetText (title);
	getglobal (frameName.."_BTitle"):SetText (subtitle);

	-- 3.x registered these with the Interface Options window; here they live in Atr_OptionsWindow
	tinsert (AtrNS.optionPanels, f);

end


-----------------------------------------

-----------------------------------------

function Atr_Options_Cancel ()

	Atr_InitOptionsPanels();

end


-----------------------------------------

function Atr_InitOptionsPanels()

	if (AUCTIONATOR_SAVEDVARS == nil) then
		Atr_ResetSavedVars();
	elseif (AUCTIONATOR_SAVEDVARS.BIDDING_RATIO == nil) then
		-- BIDDING_RATIO was added after this table already existed for some accounts - back it
		-- fill here too since Options can be opened before Atr_Init ever runs (that only fires
		-- once Blizzard_AuctionUI loads, i.e. after the player has actually visited an auctioneer)
		AUCTIONATOR_SAVEDVARS.BIDDING_RATIO = 95;	-- matches auctionator_savedvars_defaults.BIDDING_RATIO in Auctionator.lua
	end

	Atr_SetupBasicOptionsFrame();
	Atr_SetupTooltipsOptionsFrame();
	Atr_SetupUCConfigFrame();
	Atr_SetupStackingFrame();

end


-----------------------------------------

function Atr_SetDurationOptionRB(name)

	Atr_RB_S:SetChecked (zc.StringEndsWith (name, "S"));
	Atr_RB_M:SetChecked (zc.StringEndsWith (name, "M"));
	Atr_RB_L:SetChecked (zc.StringEndsWith (name, "L"));

end

-----------------------------------------

function Atr_BasicOptionsFrame_Save()

	local origValues = zc.msg_str (AUCTIONATOR_OPEN_ALL_BAGS, AUCTIONATOR_DEFTAB, AUCTIONATOR_DEF_DURATION);

	AUCTIONATOR_OPEN_ALL_BAGS	= zc.BoolToNum(AuctionatorOption_Open_All_Bags_CB:GetChecked ());

	AUCTIONATOR_DEFTAB			= UIDropDownMenu_GetSelectedValue(AuctionatorOption_Deftab);

	AUCTIONATOR_DEF_DURATION = "N";

	if (AuctionatorOption_Def_Duration_CB:GetChecked()) then
		if (Atr_RB_S:GetChecked())	then	AUCTIONATOR_DEF_DURATION = "S"; end;
		if (Atr_RB_M:GetChecked())	then	AUCTIONATOR_DEF_DURATION = "M"; end;
		if (Atr_RB_L:GetChecked())	then	AUCTIONATOR_DEF_DURATION = "L"; end;
	end

	local newValues = zc.msg_str (AUCTIONATOR_OPEN_ALL_BAGS, AUCTIONATOR_DEFTAB, AUCTIONATOR_DEF_DURATION);

	if (origValues ~= newValues) then
		zc.msg_atr (ZT ("basic options saved"));
	end
end


-----------------------------------------

function Atr_SetupBasicOptionsFrame()

	Atr_BasicOptionsFrame_BTitle:SetText (string.format (ZT("Basic Options for %s"), "|cffffff55"..UnitName("player")));

	AuctionatorOption_Open_All_Bags_CB:SetChecked		(zc.NumToBool(AUCTIONATOR_OPEN_ALL_BAGS));

	UIDropDownMenu_Initialize		(AuctionatorOption_Deftab, AuctionatorOption_Deftab_Initialize);
	UIDropDownMenu_SetSelectedValue	(AuctionatorOption_Deftab, AUCTIONATOR_DEFTAB);

	AuctionatorOption_Def_Duration_CB:SetChecked (AUCTIONATOR_DEF_DURATION == "S" or AUCTIONATOR_DEF_DURATION == "M" or AUCTIONATOR_DEF_DURATION == "L");

	Atr_SetDurationOptionRB (AUCTIONATOR_DEF_DURATION);

end

-----------------------------------------

function Atr_SetupTooltipsOptionsFrame ()

	ATR_tipsVendorOpt_CB:SetChecked		(zc.NumToBool(AUCTIONATOR_V_TIPS));
	ATR_tipsAuctionOpt_CB:SetChecked	(zc.NumToBool(AUCTIONATOR_A_TIPS));
	ATR_tipsDisenchantOpt_CB:SetChecked	(zc.NumToBool(AUCTIONATOR_D_TIPS));

	UIDropDownMenu_Initialize(Atr_tipsShiftDD, Atr_tipsShiftDD_Initialize);
	UIDropDownMenu_SetSelectedValue(Atr_tipsShiftDD, AUCTIONATOR_SHIFT_TIPS);
	
	UIDropDownMenu_Initialize(Atr_deDetailsDD, Atr_deDetailsDD_Initialize);
	UIDropDownMenu_SetSelectedValue(Atr_deDetailsDD, AUCTIONATOR_DE_DETAILS_TIPS);
end


-----------------------------------------

function Atr_TooltipsOptionsFrame_Save()

	local origValues = zc.msg_str (AUCTIONATOR_V_TIPS, AUCTIONATOR_A_TIPS, AUCTIONATOR_D_TIPS, AUCTIONATOR_SHIFT_TIPS, AUCTIONATOR_DE_DETAILS_TIPS);

	AUCTIONATOR_V_TIPS		= zc.BoolToNum(ATR_tipsVendorOpt_CB:GetChecked ());
	AUCTIONATOR_A_TIPS		= zc.BoolToNum(ATR_tipsAuctionOpt_CB:GetChecked ());
	AUCTIONATOR_D_TIPS		= zc.BoolToNum(ATR_tipsDisenchantOpt_CB:GetChecked ());

	AUCTIONATOR_SHIFT_TIPS		= UIDropDownMenu_GetSelectedValue(Atr_tipsShiftDD);
	AUCTIONATOR_DE_DETAILS_TIPS	= UIDropDownMenu_GetSelectedValue(Atr_deDetailsDD);

	local newValues = zc.msg_str (AUCTIONATOR_V_TIPS, AUCTIONATOR_A_TIPS, AUCTIONATOR_D_TIPS, AUCTIONATOR_SHIFT_TIPS, AUCTIONATOR_DE_DETAILS_TIPS);

	if (origValues ~= newValues) then
		zc.msg_atr (ZT("tooltip configuration saved"));
	end


end


-----------------------------------------

function AuctionatorOption_Deftab_Initialize()

	local info = UIDropDownMenu_CreateInfo();
	
	Atr_AddMenuPick (info, ZT("None"),	0, AuctionatorOption_Deftab_OnClick);
	Atr_AddMenuPick (info, ZT("Sell"),	1, AuctionatorOption_Deftab_OnClick);
	Atr_AddMenuPick (info, ZT("Buy"),	2, AuctionatorOption_Deftab_OnClick);
	Atr_AddMenuPick (info, ZT("Listings"),	3, AuctionatorOption_Deftab_OnClick);

end

-----------------------------------------

function AuctionatorOption_Deftab_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value);
end

-----------------------------------------

function Atr_tipsShiftDD_Initialize()

	local info = UIDropDownMenu_CreateInfo();
	
	Atr_AddMenuPick (info, ZT("stack price"),		1, Atr_tipsShiftDD_OnClick);
	Atr_AddMenuPick (info, ZT("per item price"),	2, Atr_tipsShiftDD_OnClick);

end

-----------------------------------------

function Atr_tipsShiftDD_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value);
end

-----------------------------------------

function Atr_deDetailsDD_Initialize()

	local info = UIDropDownMenu_CreateInfo();
	
	Atr_AddMenuPick (info, ZT("when SHIFT is held down"),	1, Atr_deDetailsDD_OnClick);
	Atr_AddMenuPick (info, ZT("when CONTROL is held down"),	2, Atr_deDetailsDD_OnClick);
	Atr_AddMenuPick (info, ZT("when ALT is held down"),		3, Atr_deDetailsDD_OnClick);
	Atr_AddMenuPick (info, ZT("never"),						4, Atr_deDetailsDD_OnClick);
	Atr_AddMenuPick (info, ZT("always"),					5, Atr_deDetailsDD_OnClick);

end

-----------------------------------------

function Atr_deDetailsDD_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value);
end

-----------------------------------------

function Atr_Option_OnClick (self)

	if (zc.StringContains (self:GetName(), "Open_BUY") and self:GetChecked()) then
		AuctionatorOption_Open_SELL_CB:SetChecked (false);
	end

	if (zc.StringContains (self:GetName(), "Open_SELL") and self:GetChecked()) then
		AuctionatorOption_Open_BUY_CB:SetChecked (false);
	end

end


-----------------------------------------

local kThresh = {}

kThresh[1] = { amt=5000000,		text=ZT("over %d gold"),		v=500	};
kThresh[2] = { amt=1000000,		text=ZT("over %d gold"),		v=100	};
kThresh[3] = { amt=200000,		text=ZT("over %d gold"),		v=20	};
kThresh[4] = { amt=50000,		text=ZT("over %d gold"),		v=5		};
kThresh[5] = { amt=10000,		text=ZT("over 1 gold"),			v=1		};
kThresh[6] = { amt=2000,		text=ZT("over %d silver"),		v=20	};
kThresh[7] = { amt=500,			text=ZT("over %d silver"),		v=5		};
                 
-----------------------------------------

function Atr_SetupUCConfigFrame()

	for i = 1, getn(kThresh) do

		local amt		= kThresh[i].amt;
		local linetext	= string.format (kThresh[i].text, kThresh[i].v);

		getglobal("UC_"..amt.."_RangeText"):SetText (linetext);

		MoneyInputFrame_SetCopper (getglobal("UC_"..amt.."_MoneyInput"), AUCTIONATOR_SAVEDVARS["_"..amt]);
	end

	Atr_BiddingRatioSlider:SetValue (AUCTIONATOR_SAVEDVARS.BIDDING_RATIO);
	Atr_BiddingRatioSlider_OnValueChanged ();
	getglobal("Atr_BiddingRatioSliderLow"):SetText ("1c");
	getglobal("Atr_BiddingRatioSliderHigh"):SetText ("Same as Buyout");

end

-----------------------------------------

-- just refreshes the slider's own label as it's dragged; the chosen ratio isn't committed to
-- AUCTIONATOR_SAVEDVARS until Save, same as every other value on this panel
function Atr_BiddingRatioSlider_OnValueChanged ()
	local ratio = math.floor (Atr_BiddingRatioSlider:GetValue() / 5 + 0.5) * 5;
	Atr_BiddingRatioSliderText:SetText (ZT("Starting Price Ratio")..": "..ratio.."%");
end

-----------------------------------------

function Atr_UCConfigFrame_Save()

	local origValues	= AUCTIONATOR_SAVEDVARS.BIDDING_RATIO;
	local newValues		= math.floor (Atr_BiddingRatioSlider:GetValue() / 5 + 0.5) * 5;

	AUCTIONATOR_SAVEDVARS.BIDDING_RATIO = newValues;

	for i = 1, getn(kThresh) do
		local amt = kThresh[i].amt;

		origValues = origValues + AUCTIONATOR_SAVEDVARS["_"..amt];

		AUCTIONATOR_SAVEDVARS["_"..amt]	= MoneyInputFrame_GetCopper(getglobal("UC_"..amt.."_MoneyInput"));

		newValues = newValues + AUCTIONATOR_SAVEDVARS["_"..amt];
	end

	if (origValues ~= newValues) then
		zc.msg_atr (ZT("undercutting configuration saved"));
	end


end

-----------------------------------------

local function plistEntry (key, txt, num, size)

	return { sortkey=key, text=txt, numstacks=num, stacksize=size }

end

-----------------------------------------

local function plistSort (x, y)

	return x.sortkey < y.sortkey;

end

-----------------------------------------

local kStackList_LinesToDisplay = 12;
local gStackList_SelectedIndex = 0;
local gStackList_plist;


kStackList_categories = {};

kStackList_categories[ATR_SK_GLYPHS]		= { txt=ZT("Glyphs")			}
kStackList_categories[ATR_SK_GEMS_CUT]		= { txt=ZT("Gems - Cut")		}
kStackList_categories[ATR_SK_GEMS_UNCUT]	= { txt=ZT("Gems - Uncut")		}
kStackList_categories[ATR_SK_ITEM_ENH]		= { txt=ZT("Item Enhancements")	}
kStackList_categories[ATR_SK_POT_ELIX]		= { txt=ZT("Potions and Elixirs")	}
kStackList_categories[ATR_SK_FLASKS]		= { txt=ZT("Flasks")	}
kStackList_categories[ATR_SK_HERBS]			= { txt=ZT("Herbs")	}

-----------------------------------------

function Atr_SetupStackingFrame ()

	if (getglobal ("Atr_StackList1") == nil) then
		local line, n;

		for n = 1, kStackList_LinesToDisplay do
			local y = -5 - ((n-1)*16);
			line = CreateFrame("BUTTON", "Atr_StackList"..n, Atr_Stacking_List, "Atr_StackingEntryTemplate");
			line:SetPoint("TOP", 0, y);
		end
	end
	
	Atr_StackingList_Display();

end

-----------------------------------------

function Atr_StackingList_Display()

	gStackList_plist = {};

	local plist = gStackList_plist;
	local text, spinfo;
	local sortkey, info;
	local n = 1;
	
	for sortkey, info in pairs (kStackList_categories) do
		info.overrideFound = false;
	end

	for text, spinfo in pairs (AUCTIONATOR_STACKING_PREFS) do

		-- skip over any that were set automatically rather than explicitly by the user
		-- and mark the built-in categories

		if (spinfo.numstacks ~= 0) then
			local sortkey = text;
			
			if (kStackList_categories[text]) then
				kStackList_categories[text].overrideFound = true;
				text = kStackList_categories[text].txt;
			end

			plist[n] = plistEntry (sortkey, text, spinfo.numstacks, spinfo.stacksize);
			n = n + 1;
		end
	end
	
	for sortkey, info in pairs (kStackList_categories) do
		if (not info.overrideFound) then
			plist[n] = plistEntry (sortkey, info.txt, -2, 0);			
			n = n + 1;
		end
	end
	
	table.sort (plist, plistSort)
	
	local totalRows = getn(plist);

	local line;							-- 1 through NN of our window to scroll
	local dataOffset;					-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (Atr_Stacking_ScrollFrame, totalRows, kStackList_LinesToDisplay, 16);

	for line = 1,kStackList_LinesToDisplay do

		dataOffset = line + FauxScrollFrame_GetOffset (Atr_Stacking_ScrollFrame);

		local lineEntry = getglobal ("Atr_StackList"..line);

		lineEntry:SetID (dataOffset);

		if (dataOffset <= totalRows and plist[dataOffset]) then

			local lineEntry_text = getglobal("Atr_StackList"..line.."_text");
			local lineEntry_info = getglobal("Atr_StackList"..line.."_info");

			local pdata = plist[dataOffset];
			
			local colorText = ((pdata.text == pdata.sortkey) and "" or "|cffffff88");
			
			lineEntry_text:SetText (colorText..pdata.text);

			local numstacks = plist[dataOffset].numstacks;
			local stacksize = plist[dataOffset].stacksize;
			local info = "???";
			
			if     (numstacks == -2) then	info = "|cff777777"..ZT("default behavior");														
			elseif (numstacks == -1) then	info = string.format (ZT("max. stacks of %d"), stacksize);		
			elseif (stacksize == 0)  then	info = "1 "..ZT("stack");	
			elseif (numstacks == 0)  then	info = ZT("stacks of").." "..stacksize;	
			elseif (numstacks > 0)   then	info = numstacks.." "..ZT("stacks of").." "..stacksize;	
			end
				
			lineEntry_info:SetText (info);
			
			if (gStackList_SelectedIndex == dataOffset) then
				Atr_SetRowSelected (lineEntry, true);
			else
				Atr_SetRowSelected (lineEntry, false);
			end
			
			lineEntry:Show();
		else
			lineEntry:Hide();
		end
	end

	zc.EnableDisable (Atr_StackingOptionsFrame_Edit, gStackList_SelectedIndex > 0);

end

-----------------------------------------

function Atr_StackingEntry_OnClick(self)

	gStackList_SelectedIndex = self:GetID();

	Atr_StackingList_Display();
end

-----------------------------------------

function Atr_StackingEntry_OnDoubleClick(self)

	Atr_StackingEntry_OnClick(self);
	Atr_StackingList_Edit_OnClick();
end

-----------------------------------------

function Atr_Memorize_Show (isNew)

	local numStacks = -1;
	local stackSize = 1;

	zc.ShowHide (Atr_Mem_itemName_static,	not isNew);
	zc.ShowHide (Atr_Mem_EB_itemName,		    isNew);
	zc.ShowHide (Atr_Mem_Forget,		   	not isNew);

	Atr_MemorizeFrame["isCategory"] = false;
	
	if (not isNew) then
		local x		= gStackList_SelectedIndex;
		local plist	= gStackList_plist;
		
		Atr_Mem_itemName_static:SetText (plist[x].text);
		
		stackSize = plist[x].stacksize
		numStacks = plist[x].numstacks

		local isCategory = (plist[x].sortkey ~= plist[x].text);

		Atr_MemorizeFrame["isCategory"] = isCategory;
		
		if (isCategory and numStacks == -2) then
			numStacks = -1;
			stackSize = 1;
		end
		
		zc.SetTextIf (Atr_Mem_itemName_text, isCategory, ZT("Category"), ZT("Item Name"));
		zc.SetTextIf (Atr_Mem_Forget,		 isCategory, ZT("Reset to Default"), ZT("Forget this Item"));
	end
		
	Atr_Mem_EB_stackSize:SetText (stackSize);

	UIDropDownMenu_Initialize		(Atr_Mem_DD_numStacks, Atr_SONumStacks_Initialize);
	UIDropDownMenu_SetSelectedValue	(Atr_Mem_DD_numStacks, numStacks);

	Atr_Mem_EB_itemName:SetText ("");
	
	ShowInterfaceOptionsMask();

	Atr_MemorizeFrame:Show();

end

-----------------------------------------

function Atr_StackingList_Edit_OnClick()

	Atr_Memorize_Show(false);

end

-----------------------------------------

function Atr_StackingList_New_OnClick()

	Atr_Memorize_Show(true);

end

-----------------------------------------

function Atr_Memorize_Save()

	local x		= gStackList_SelectedIndex;
	local plist	= gStackList_plist;

	local key = Atr_Mem_EB_itemName:GetText();
	if (key == nil or key == "") then
		key = plist[x].sortkey;
	end
	
	if (key and key ~= "") then
		Atr_Set_StackingPrefs_numstacks (key, UIDropDownMenu_GetSelectedValue (Atr_Mem_DD_numStacks));
		Atr_Set_StackingPrefs_stacksize (key, Atr_Mem_EB_stackSize:GetNumber ());
	end

	Atr_StackingList_Display();
	
end

-----------------------------------------

function Atr_Memorize_Forget()

	local x		= gStackList_SelectedIndex;
	local plist	= gStackList_plist;
	local key	= plist[x].sortkey;

	if (key) then
		Atr_Clear_StackingPrefs (key);
	end

	if (not Atr_MemorizeFrame["isCategory"]) then
		gStackList_SelectedIndex = 0;
	end

	Atr_StackingList_Display();

end


-----------------------------------------

function Atr_SONumStacks_OnLoad(self)

	UIDropDownMenu_Initialize		(self, Atr_SONumStacks_Initialize);
	UIDropDownMenu_SetSelectedValue	(self, -1);
	UIDropDownMenu_JustifyText		("CENTER", self);
	UIDropDownMenu_SetWidth			(150, self);

end

-----------------------------------------

function Atr_SONumStacks_Initialize()

	local info = UIDropDownMenu_CreateInfo();

	Atr_AddMenuPick (info, ZT("As many as possible"),		-1,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "1",								 1,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "2",								 2,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "3",								 3,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "4",								 4,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "5",								 5,  Atr_SONumStacks_OnClick)
	Atr_AddMenuPick (info, "10",							10,  Atr_SONumStacks_OnClick)
                                            
end

-----------------------------------------

function Atr_SONumStacks_OnClick()

	UIDropDownMenu_SetSelectedValue(this.owner, this.value);
	Atr_Mem_stacksOf_text:SetText (ZT ((this.value == 1) and "stack of" or "stacks of"));
end



-----------------------------------------

function Atr_ShowOptionTooltip (elem)

	local name = elem:GetName();
	local text;

	if (zc.StringContains (name, "Deftab")) then
		text = ZT("Select the Auctionator panel to be displayed first whenever you open the Auction House window.");
	end

	if (zc.StringContains (name, "Open_BUY")) then
		text = ZT("If this option is checked, the Auctionator BUY panel will display first whenever you open the Auction House window.");
	end

	if (zc.StringContains (name, "Open_All_Bags")) then
		text = ZT("If this option is checked, ALL your bags will be opened when you first open the Auctionator panel.");
	end

	if (zc.StringContains (name, "Def_Duration")) then
		text = ZT("If this option is checked, every time you initiate a new auction the auction duration will be reset to the default duration you've selected.");
	end

	if (text) then
		local titleFrame = getglobal (name.."_CB_Text") or getglobal (name.."_Text");
		
		local titleText = titleFrame and titleFrame:GetText() or "???";
		
		GameTooltip:SetOwner(this, "ANCHOR_LEFT");
			GameTooltip:SetText(titleText, 0.9, 1.0, 1.0);
		GameTooltip:AddLine(text, 0.5, 0.5, 1.0, 1);
		GameTooltip:Show();
	end
	
end

-----------------------------------------

function Atr_scanLevelDD_Initialize()

	local info = UIDropDownMenu_CreateInfo();
	
	Atr_AddMenuPick (info, "|cffa335ee"..ZT("Epic items").."|r",			5, Atr_scanLevelDD_OnClick);
	Atr_AddMenuPick (info, "|cff0070dd"..ZT("Rare items").."|r",			4, Atr_scanLevelDD_OnClick);
	Atr_AddMenuPick (info, "|cff1eff00"..ZT("Uncommon items").."|r",		3, Atr_scanLevelDD_OnClick);
	Atr_AddMenuPick (info, "|cffffffff"..ZT("Common items").."|r",			2, Atr_scanLevelDD_OnClick);
	Atr_AddMenuPick (info, "|cff9d9d9d"..ZT("Poor items (all)").."|r",		1, Atr_scanLevelDD_OnClick);

end

-----------------------------------------

function Atr_scanLevelDD_OnClick()
	UIDropDownMenu_SetSelectedValue(this.owner, this.value);

	-- there's no separate Save step for this dropdown anymore now that it lives in the Full Scan
	-- dialog instead of an options sub-panel - commit it immediately
	AUCTIONATOR_SCAN_MINLEVEL = this.value;
end

-----------------------------------------

function Atr_scanLevelDD_showTip(self)

	GameTooltip:SetOwner(this, "ANCHOR_LEFT");
	GameTooltip:SetText(ZT("Minimum Quality Level"), 0.9, 1.0, 1.0);
	GameTooltip:AddLine(ZT("Only include items in the scanning database that are this level or higher"), 0.5, 0.5, 1.0, 1);
	GameTooltip:Show();
end



-----------------------------------------

function Atr_MakeOptionsFrameOpaque ()

end

-----------------------------------------

local gInterfaceOptionsMask;

-----------------------------------------

function ShowInterfaceOptionsMask()

	if (gInterfaceOptionsMask == nil) then
		gInterfaceOptionsMask = CreateFrame ("Frame", "Atr_Mask_StdOptions", Atr_OptionsWindow, "Atr_Mask_StdOptionsTempl");
		gInterfaceOptionsMask:SetFrameLevel (Atr_OptionsWindow:GetFrameLevel() + 10);
	end

	gInterfaceOptionsMask:Show();

end

-----------------------------------------

function HideInterfaceOptionsMask()
	if (gInterfaceOptionsMask) then
		gInterfaceOptionsMask:Hide();
	end
end


