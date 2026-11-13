
local addonName, addonTable = "Auctionator", AtrNS; 
local zc = addonTable.zc;

-----------------------------------------

Atr_SList = {};
Atr_SList.__index = Atr_SList;

local SLITEMS_NUM_LINES = 15;

local gCurrentSList;

-----------------------------------------

function Atr_ShoppingListsInit ()

	local num = getn(AUCTIONATOR_SHOPPING_LISTS);
	local x;
	
	for x = 1,num do
		setmetatable (AUCTIONATOR_SHOPPING_LISTS[x], Atr_SList);
	end
	
end

-----------------------------------------

function Atr_SList.create (name, isRecents)

	local slist = {};
	setmetatable (slist,Atr_SList);

	slist.name		= name;
	slist.items		= {};
	
	if (isRecents) then
		slist.isRecents = 1;
	end
	
	table.insert (AUCTIONATOR_SHOPPING_LISTS, slist);

	table.sort (AUCTIONATOR_SHOPPING_LISTS, Atr_SortSlists);
	
	return slist;
end


-----------------------------------------

function Atr_SortSlists (x, y)

	if (x.isRecents) then return true; end;
	if (y.isRecents) then return false; end;

	return (string.lower(x.name) < string.lower(y.name));

end

-----------------------------------------

function Atr_SList:AddItem (itemName)

	if (itemName == "" or itemName == nil) then
		return;
	end

	if (self.isRecents) then
		table.insert (self.items, 1, itemName);
		
		while (getn(self.items) > 50) do		-- max 50 items on recents list
			table.remove (self.items);
		end
	else
		table.insert (self.items, itemName);
		self.isSorted = false;
	end

	
end

-----------------------------------------

function Atr_SList:RemoveItem (itemName)

	local num = getn(self.items);
	local n;
	
	for n = 1,num do
		if (zc.StringSame (self.items[n], itemName)) then
			table.remove (self.items, n);
			return;
		end
	end

end

-----------------------------------------

function Atr_DisplaySlist ()
	if (gCurrentSList) then
		gCurrentSList:DisplayX ();
	end
end



-----------------------------------------

function sortSlist (x, y)

	return (string.lower(x) < string.lower(y));

end

-----------------------------------------

function Atr_SList:DisplayX ()

	gCurrentSList = self;

	local currentPane = Atr_GetCurrentPane();

	if (not (self.isRecents or self.isSorted)) then
		self.isSorted = true;
		table.sort (self.items, sortSlist);
	end


	local numrows = getn(self.items);

	local line;							-- 1 through NN of our window to scroll
	local dataOffset;					-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (Atr_Hlist_ScrollFrame, numrows, SLITEMS_NUM_LINES, 16);

	for line = 1,SLITEMS_NUM_LINES do

		currentPane.hlistScrollOffset = FauxScrollFrame_GetOffset (Atr_Hlist_ScrollFrame);
		
		dataOffset = line + currentPane.hlistScrollOffset;

		local lineEntry = getglobal ("AuctionatorHEntry"..line);

		lineEntry:SetID(dataOffset);

		local slItem = self.items[dataOffset];
		
		if (dataOffset <= numrows and slItem) then

			local lineEntry_text = getglobal("AuctionatorHEntry"..line.."_EntryText");

			lineEntry_text:SetText		(Atr_AbbrevItemName (slItem));
			lineEntry_text:SetTextColor	(.6,.6,.6);

			if (currentPane.activeSearch.origSearchText ~= "" and zc.StringSame (slItem , currentPane.activeSearch.origSearchText)) then
				Atr_SetRowSelected (lineEntry, true);
			elseif (currentPane.activeSearch.searchText == "" and zc.StringSame (slItem , Atr_Search_Box:GetText())) then
				Atr_SetRowSelected (lineEntry, true);
			else
				Atr_SetRowSelected (lineEntry, false);
			end

			lineEntry:Show();
		else
			lineEntry:Hide();
		end
	end


end

-----------------------------------------

function Atr_SList:FindItemIndex (itemName)

	local num = getn(self.items);
	local n;
	
	for n = 1,num do
		if (zc.StringSame (itemName, self.items[n])) then
			return n;
		end
	end
	
	return 0;

end

-----------------------------------------

function Atr_SList:IsItemOnList (itemName)

	return (self:FindItemIndex(itemName) > 0);
	
end

-----------------------------------------

function Atr_Search_Onclick ()

	local currentPane = Atr_GetCurrentPane();

	local searchText = Atr_Search_Box:GetText();

	Atr_Search_Button:Disable();
	Atr_Buy1_Button:Disable();
	Atr_AddToSListButton:Disable();
	Atr_RemFromSListButton:Disable();
	
	Atr_ClearAll();
	
	currentPane:DoSearch (searchText);

	Atr_Process_Historydata ();
end

-----------------------------------------

function Atr_Shop_OnFinishScan ()
	
	local currentPane = Atr_GetCurrentPane();

	local searchText = currentPane.activeSearch.origSearchText;

	Atr_Search_Box:SetText (searchText);
	
	local recentsList = AUCTIONATOR_SHOPPING_LISTS[1];
	if (recentsList) then

		local isRecentsShown = (gCurrentSList == recentsList);
		
		local n = recentsList:FindItemIndex(searchText);

		if (n > 14 or (not isRecentsShown and n > 0)) then
			table.remove (recentsList.items, n);
		end
		
		n = recentsList:FindItemIndex(searchText);
		
		if (n == 0) then
			recentsList:AddItem (searchText);
		end
		
		if (isRecentsShown) then
			FauxScrollFrame_SetOffset (Atr_Hlist_ScrollFrame, 0);
		end
		
	end

	if (getn(currentPane.activeScan.sortedData) > 0 and not currentPane.pickKey) then
		currentPane.currIndex = 1;
	end

	currentPane.UINeedsUpdate = true;
	
	Atr_Search_Button:Enable();
end


-----------------------------------------

function Atr_DropDownSL_OnLoad (self)
	UIDropDownMenu_Initialize(self, Atr_DropDownSL_Initialize);
	UIDropDownMenu_SetSelectedValue(Atr_DropDownSL, 1);
	Atr_DropDownSL:Show();
end

-----------------------------------------

function Atr_DropDownSL_Initialize()

	local info = UIDropDownMenu_CreateInfo();

	local num = getn(AUCTIONATOR_SHOPPING_LISTS);
	local x;
	
	for x = 1,num do
	
		local slist = AUCTIONATOR_SHOPPING_LISTS[x];
		
		info.text = slist.name;
		info.value = x;
		info.func = Atr_DropDownSL_OnClick;
		info.checked = nil;
		info.owner = Atr_DropDownSL;

--		info.colorCode = nil;
		
--		if (slist.isRecents) then
--			info.colorCode = "|c00ffddaa";
--		end


		UIDropDownMenu_AddButton(info);

	end

end

-----------------------------------------

function Atr_DropDownSL_OnClick()

	UIDropDownMenu_SetSelectedValue(this.owner, this.value);

	gCurrentSList = AUCTIONATOR_SHOPPING_LISTS[this.value];
	
	Atr_SetUINeedsUpdate();

end

-----------------------------------------

function Atr_SEntryOnClick ()

	local line			= this;
	local entryIndex	= line:GetID();

	local itemName = gCurrentSList.items[entryIndex];
	
	Atr_Search_Box:SetText (itemName);

	if (IsAltKeyDown()) then
		Atr_GetCurrentPane():ClearSearch();
		Atr_RemFromSListOnClick();
	else
		Atr_Search_Onclick ();
	end
	
	Atr_Shop_UpdateUI();

--	gCurrentSList:DisplayX();		-- for the highlight
end



-----------------------------------------

local function FinishCreateNewSList(text)

	local slist = Atr_SList.create(text);

	local num = getn(AUCTIONATOR_SHOPPING_LISTS);
	local n;
	
	for n = 1,num do
		if (AUCTIONATOR_SHOPPING_LISTS[n] == slist) then
			UIDropDownMenu_SetSelectedValue(Atr_DropDownSL, n);
			UIDropDownMenu_SetText (text, Atr_DropDownSL);	-- needed to fix bug in UIDropDownMenu
			slist:DisplayX();
			Atr_SetUINeedsUpdate();
			break;
		end
	end
	

end

-----------------------------------------

StaticPopupDialogs["ATR_NEW_SHOPPING_LIST"] = {
	text = "",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	OnAccept = function()
		local text = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		FinishCreateNewSList (text);
	end,
	EditBoxOnEnterPressed = function()
		local text = this:GetText();
		FinishCreateNewSList (text);
		this:GetParent():Hide();
	end,
	OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText("");
		getglobal(this:GetName().."EditBox"):SetFocus();
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};

-----------------------------------------

StaticPopupDialogs["ATR_DEL_SHOPPING_LIST"] = {
	text = "",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		local x;
		for x = 1,getn(AUCTIONATOR_SHOPPING_LISTS) do
			if (AUCTIONATOR_SHOPPING_LISTS[x] == gCurrentSList) then
				table.remove (AUCTIONATOR_SHOPPING_LISTS, x);
				gCurrentSList = AUCTIONATOR_SHOPPING_LISTS[1];
				UIDropDownMenu_SetSelectedValue(Atr_DropDownSL, 1);
				UIDropDownMenu_SetText (gCurrentSList.name, Atr_DropDownSL);
				Atr_SetUINeedsUpdate();
				return;
			end
		end
	end,
	OnShow = function()
		local s = string.format (ZT("Really delete the shopping list %s ?"), ": \n\n"..gCurrentSList.name);

		getglobal(this:GetName().."Text"):SetText("\n"..s.."\n\n");
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1
};

-----------------------------------------

function Atr_NewSlist_OnClick ()

	StaticPopupDialogs["ATR_NEW_SHOPPING_LIST"].text = ZT("Name for your new shopping list");

	StaticPopup_Show("ATR_NEW_SHOPPING_LIST");
	
end

-----------------------------------------

function Atr_DelSList_OnClick ()

	StaticPopup_Show("ATR_DEL_SHOPPING_LIST");
	
end



-----------------------------------------

function Atr_AddToSListOnClick ()

	local currentPane = Atr_GetCurrentPane();

	if (gCurrentSList) then
		if (getn(gCurrentSList.items) >= 50) then
			Atr_Error_Text:SetText (string.format (ZT("You may have no more than\n\n%d items on a shopping list."), 50));
			Atr_Error_Frame.withMask = 1;
			Atr_Error_Frame:Show ();
		else		
			gCurrentSList:AddItem (Atr_Search_Box:GetText());
			Atr_SetUINeedsUpdate();
		end
	end

end

-----------------------------------------

function Atr_RemFromSListOnClick ()

	local currentPane = Atr_GetCurrentPane();

	if (gCurrentSList) then
		gCurrentSList:RemoveItem (Atr_Search_Box:GetText());
		Atr_SetUINeedsUpdate();

	end

end


-----------------------------------------

function Atr_Shop_UpdateUI ()

	local currentPane = Atr_GetCurrentPane();

	Atr_AddToSListButton:Disable();
	Atr_RemFromSListButton:Disable();
	Atr_DelSListButton:Disable();
	
	if (gCurrentSList == nil) then
		gCurrentSList = AUCTIONATOR_SHOPPING_LISTS[1];
	end

	if (gCurrentSList) then
		gCurrentSList:DisplayX ();
	
		local iName = Atr_Search_Box:GetText();

		if (gCurrentSList:IsItemOnList (iName)) then
			Atr_RemFromSListButton:Enable();
		elseif (iName ~= "" and iName ~= nil and gCurrentSList ~= AUCTIONATOR_SHOPPING_LISTS[1]) then		-- hack
			Atr_AddToSListButton:Enable();
		end
		
		if (gCurrentSList ~= AUCTIONATOR_SHOPPING_LISTS[1]) then
			Atr_DelSListButton:Enable();
		end
		
	end
	
	if (currentPane.activeSearch:NumScans() > 1 and not currentPane:IsScanEmpty()) then
		Atr_Back_Button:Show();
	else
		Atr_Back_Button:Hide();
	end
	
end


