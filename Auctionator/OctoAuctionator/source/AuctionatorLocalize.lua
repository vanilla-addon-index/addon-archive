
local addonName, addonTable = "Auctionator", AtrNS; 
local zc = addonTable.zc;


-----------------------------------------

AtrL = {};

-----------------------------------------

function Atr_PickLocalizationTable (locale)

	local f = getglobal ("AtrBuildLTable_"..locale);
	if (type (f) == "function") then
		f();
--		DEFAULT_CHAT_FRAME:AddMessage (locale.." found");
	else
		AtrBuildLTable_enUS();
--		DEFAULT_CHAT_FRAME:AddMessage (locale.." not found");
	end

end

-----------------------------------------

Atr_PickLocalizationTable (GetLocale());
--Atr_PickLocalizationTable ("esES");

-----------------------------------------

function ZT (s)

	if (s == nil or s == "") then
		return s;
	end
	
	if (AtrL) then
		local s1 = AtrL[s];
		if (s1 and s1 ~= "") then		
			return s1;
		end
	end
		
	return s;
end


-----------------------------------------

function zc.IsEnglishLocale()

	return (GetLocale() == "enUS" or GetLocale() == "enGB");

end

-----------------------------------------

local testt = {};
local Atr_excludes = { Cancel=1, Okay=1, Done=1, Close=1 }

-----------------------------------------

local function Atr_LocalizeChildText (frame)

	local child;
	local subregions = { frame:GetRegions() };
	for _, child in ipairs(subregions) do

		if  (type (child.GetText) == "function") then
			local ftext = child:GetText();
			local fname = tostring(child:GetName());
			
			if (ftext and ftext ~= "" and not Atr_excludes[ftext] and not zc.StringStartsWith (fname, "AuctionatorEntry")) then
				testt[ftext] = 1;
				child:SetText (ZT(ftext));
			end
		end
	end
	
	local kids = { frame:GetChildren() };
	for _, child in ipairs(kids) do
		
		if  (type (child.GetText) == "function") then
			local ftext = child:GetText();
			local fname = tostring(child:GetName());
			
			if (ftext and ftext ~= "" and not Atr_excludes[ftext] and not zc.StringStartsWith (fname, "AuctionatorEntry")) then
				testt[ftext] = 1;
				
				if (child:GetObjectType() == "Button") then
					local oldwid = math.floor(child:GetWidth());
					child:SetText (ZT(ftext));
					local newwid = math.floor(child:GetTextWidth()) + 15;
					if (newwid > oldwid) then
						child:SetWidth (newwid+20);
					end
				else
					child:SetText (ZT(ftext));
				end
			end
		end
			
		if (child:GetObjectType() ~= "Button") then
			Atr_LocalizeChildText (child);
		end
	end			

end

-----------------------------------------

function Atr_LocalizeFrames ()

	-- the 3.x port walked every frame with EnumerateFrames() to translate it; the 1.12 client has no
	-- such call and this build ships English text only, so there is nothing to do.

end

-----------------------------------------

local kUncutGems = {
	36924, 		-- sky sapphire
	36925, 		-- majestic zircon

	36918, 		-- scarlet ruby
	36919, 		-- cardinal ruby

	36933, 		-- forest emerald
	36934, 		-- eye of zul

	36930, 		-- monarch topaz
	36931, 		-- ametrine

	36927, 		-- twilight opal
	36928, 		-- dreadstone

	36921, 		-- autumns glow
	36922, 		-- kings amber

	41334, 		-- earthsiege diamond
	41266, 		-- skyflare diamond

	42225 		-- dragon's eye
	}

-----------------------------------------

function Atr_IsCutGem (itemLink)		return false;	end
function Atr_IsGlyph (itemLink)			return false;	end
function Atr_IsGem (itemLink)			return false;	end
function Atr_IsItemEnhancement (itemLink)	return false;	end

local function Atr_IsTypeAndSub (itemLink, wantType, wantSub)

	if (itemLink == nil) then
		return false;
	end

	local _, _, _, _, _, itemType, itemSubType = Atr_GetItemInfo (itemLink);

	return (itemType ~= nil and itemSubType ~= nil and zc.StringSame (itemType, wantType) and zc.StringSame (itemSubType, wantSub));
end

function Atr_IsPotion (itemLink)		return Atr_IsTypeAndSub (itemLink, "Consumable", "Potion");		end
function Atr_IsElixir (itemLink)		return Atr_IsTypeAndSub (itemLink, "Consumable", "Elixir");		end
function Atr_IsFlask (itemLink)			return Atr_IsTypeAndSub (itemLink, "Consumable", "Flask");		end
function Atr_IsHerb (itemLink)			return Atr_IsTypeAndSub (itemLink, "Trade Goods", "Herb");		end

-----------------------------------------

local gItemClasses;
local gItemSubClasses;

-----------------------------------------
-- if Blizz introduces new auction classes this might need to change

function Atr_IsWeaponType				(itemType)		return (Atr_ItemType2AuctionClass (itemType) == 1);		end
function Atr_IsArmorType				(itemType)		return (Atr_ItemType2AuctionClass (itemType) == 2);		end

-----------------------------------------

function Atr_IsClass (itemLink, class, subclass)

	if (itemLink == nil) then
		return false;
	end

	local _, _, _, _, _, itemType, itemSubType = Atr_GetItemInfo (itemLink);

	local itemClass = Atr_ItemType2AuctionClass (itemType);
	local itemSubClass;
	
	if (itemClass == class) then
	
		if (subclass == nil) then
			return true;
		end
	
		itemSubClass = Atr_SubType2AuctionSubclass (itemClass, itemSubType)

		if (subclass == itemSubClass) then
			return true;
		end
	end
		
	return false;
end

-----------------------------------------

function Atr_ItemType2AuctionClass(itemType)

	if (gItemClasses == nil) then
		gItemClasses = { GetAuctionItemClasses() };
	end
	
	if getn(gItemClasses) > 0 then
	local itemClass;
		for x, itemClass in pairs(gItemClasses) do
			if (zc.StringSame (itemClass, itemType)) then
				return x;
			end
		end
	end

	return 0;
end


-----------------------------------------

function Atr_SubType2AuctionSubclass(auctionClass, itemSubtype)

	if (gItemSubClasses == nil) then
		gItemSubClasses = {};
	end
	
	if (gItemSubClasses[auctionClass] == nil) then
		gItemSubClasses[auctionClass] = { GetAuctionItemSubClasses(auctionClass) };
	end
	
	local subclasses = gItemSubClasses[auctionClass];

	if getn(subclasses) > 0 then
	local itemSubClass;
		for x, itemSubClass in pairs(subclasses) do
			if (zc.StringSame (itemSubClass, itemSubtype)) then
				return x;
			end
		end
	end

	return 0;
end


