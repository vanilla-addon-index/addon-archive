local DKPAuctionBidder_Identifier = "DKPAuctionBidder"
local DKPAuctionBidder_SOTAprefix = "SOTAv1"

local DKPAuctionBidder_CHAT_END					= "|r"
local DKPAuctionBidder_COLOUR_INTRO				= "|c80F0F0F0"
local DKPAuctionBidder_COLOUR_CHAT				= "|c8040A0F8"  
local DKPAuctionBidder_AuctionState             = 0 -- 0: No Auction, 1: Auction - no bids, 2: Auction - with bids, 3: Auction Paused
local DKPAuctionBidder_AuctionStatePrePause     = 0
local DKPAuctionBidder_PlayerDKP                = 0
local DKPAuctionBidder_SOTA_Master              = ""
local DKPAuctionBidder_SubmitBidTimer           = 1 -- time between to bid submissions in seconds
local DKPAuctionBidder_SubmitBidFlag            = 1 -- 1: Able to submit bid, 0: Not able to submit bid
local DKPAuctionBidder_AuctionTime              = 0
local DKPAuctionBidder_AuctionTimeLeft          = 0
local DKPAuctionBidder_AuctionTimerUpdateRate   = 0.05 -- update the timer bar every 0.05 seconds
local DKPAuctionBidder_StatusbarStandardwidth   = 0
local DKPAuctionBidder_IsShown                  = 0
local DKPAuctionBidder_MinimumStartingBid       = 30 -- 30 per default

local DKPAuctionBidder_Currentbid               = {}
local DKPAuctionBidder_LastHighestBid           = {}

DKPAuctionBidder_CurrenItemLink = ""


local DKPAuctionBidder_CLASS_COLORS = {
	{ "Druid",			{ 255,125, 10 } },	--255 	125 	10		1.00 	0.49 	0.04 	#FF7D0A
	{ "Hunter",			{ 171,212,115 } },	--171 	212 	115 	0.67 	0.83 	0.45 	#ABD473 
	{ "Mage",			{ 105,204,240 } },	--105 	204 	240 	0.41 	0.80 	0.94 	#69CCF0 
	{ "Paladin",		{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Priest",			{ 255,255,255 } },	--255 	255 	255 	1.00 	1.00 	1.00 	#FFFFFF
	{ "Rogue",			{ 255,245,105 } },	--255 	245 	105 	1.00 	0.96 	0.41 	#FFF569
	{ "Shaman",			{   0,112,222 } },	--0 	112 	222 	0.00 	0.44 	0.87 	#0070DE
	{ "Warlock",		{ 148,130,201 } },	--148 	130 	201 	0.58 	0.51 	0.79 	#9482C9
	{ "Warrior",		{ 199,156,110 } }	--199 	156 	110 	0.78 	0.61 	0.43 	#C79C6E
}

function DKPAuctionBidder_OnEvent(event, arg1, arg2, arg3, arg4, arg5)
    if (event == "CHAT_MSG_ADDON") then
        DKPAuctionBidder_OnChatMsgAddon(event, arg1, arg2, arg3, arg4, arg5)
    end
    if (event == "GUILD_ROSTER_UPDATE") then
        DKPAuctionBidder_GetPlayerDKP()
    end
end

function DKPAuctionBidder_OnLoad()
    this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("GUILD_ROSTER_UPDATE");
    this:RegisterEvent("CHAT_MSG_ADDON");
    getglobal("DKPAuctionBidder_MinimapButtonFrame"):Show()
    DKPAuctionBidder_GetPlayerDKP()
    DKPAuctionBidder_StatusbarStandardwidth = getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):GetWidth()
end

function DKPAuctionBidder_BidMinOnClick()
    if DKPAuctionBidder_SubmitBidFlag == 1 then
        local sendtext = "bid min"
        SendAddonMessage(DKPAuctionBidder_Identifier, sendtext, "RAID")
        DKPAuctionBidder_SubmitBidFlag = 0
    end
end

function DKPAuctionBidder_BidMaxOnClick()
    getglobal("DKPAuctionBidderMaxBidConfirmTextButtonText"):SetText("Are you sure \n you want to bid \n ALL (" ..DKPAuctionBidder_PlayerDKP ..") \n your DKP?")
    DKPAuctionBidderMaxBidConfirmationFrame:Show()
end

function DKPAuctionBidder_BidXOnEnter(dkp)
    if DKPAuctionBidder_SubmitBidFlag == 1 then
        local sendtext = "bid " ..dkp
        SendAddonMessage(DKPAuctionBidder_Identifier, sendtext, "RAID")
        DKPAuctionBidder_SubmitBidFlag = 0
    end
end

function DKPAuctionBidder_MaxBidConfirmOnClick()
    if DKPAuctionBidder_SubmitBidFlag == 1 then
        getglobal("DKPAuctionBidderMaxBidConfirmTextButtonText"):SetText("Are you sure you want \n to bid ALL your DKP(" ..DKPAuctionBidder_PlayerDKP ..")?")
        local sendtext = "bid max"
        SendAddonMessage(DKPAuctionBidder_Identifier, sendtext, "RAID")
        DKPAuctionBidderMaxBidConfirmationFrame:Hide()
        DKPAuctionBidder_SubmitBidFlag = 0
    end
end

function DKPAuctionBidder_MaxBidDeclineOnClick()
    DKPAuctionBidderMaxBidConfirmationFrame:Hide()
end

local DKPAuctionBidder_BidTimer = 0
local DKPAuctionBidder_RefreshTimer = 0

function DKPAuctionBidder_BidFrameOnUpdate(elapsed)
    DKPAuctionBidder_BidTimer = DKPAuctionBidder_BidTimer + elapsed
    DKPAuctionBidder_RefreshTimer = DKPAuctionBidder_RefreshTimer + elapsed
    if DKPAuctionBidder_BidTimer > DKPAuctionBidder_SubmitBidTimer then
        DKPAuctionBidder_BidTimer = 0
        DKPAuctionBidder_SubmitBidFlag = 1
        --if getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):GetWidth() < 1 then
        --    getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):SetWidth(230)
        --end
        --getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):SetWidth(getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):GetWidth()-11)
    end
    if DKPAuctionBidder_AuctionState == 1 or DKPAuctionBidder_AuctionState == 2 then
        if DKPAuctionBidder_RefreshTimer > DKPAuctionBidder_AuctionTimerUpdateRate then
            if DKPAuctionBidder_AuctionTimeLeft > DKPAuctionBidder_AuctionTime then DKPAuctionBidder_AuctionTime = DKPAuctionBidder_AuctionTimeLeft end
            DKPAuctionBidder_AuctionTimeLeft = DKPAuctionBidder_AuctionTimeLeft - DKPAuctionBidder_RefreshTimer
            DKPAuctionBidder_RefreshTimer = 0
            local fraction = DKPAuctionBidder_AuctionTimeLeft/DKPAuctionBidder_AuctionTime
            if fraction >= 1 then fraction = 1 end
            local newwidth = floor(DKPAuctionBidder_StatusbarStandardwidth * fraction)
            if newwidth <= 0 then newwidth = 1 end
            getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):SetWidth(newwidth)
        end
    end
end

function DKPAuctionBidder_MinimapButtonOnClick()
    if DKPAuctionBidder_IsShown == 0 then
        DKPAuctionBidderUIFrame:Show()
        if DKPAuctionBidder_AuctionState == 0 then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("No Auction")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText("")
        elseif DKPAuctionBidder_AuctionState == 1 then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Auction Running - No Bids")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText("")
        elseif DKPAuctionBidder_AuctionState == 2 then
            local color = DKPAuctionBidder_GetClassColorCodes(DKPAuctionBidder_Currentbid[5]);
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Highest Bid: " ..DKPAuctionBidder_Currentbid[3] .." ")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText(DKPAuctionBidder_Currentbid[4])
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
        elseif DKPAuctionBidder_AuctionState == 3 then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Auction Paused")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText("")
        end
        DKPAuctionBidder_GetPlayerDKP()
        DKPAuctionBidder_IsShown = 1
    else
        DKPAuctionBidder_CloseUI()
    end
end

function DKPAuctionBidder_CloseUI()
    DKPAuctionBidderMaxBidConfirmationFrame:Hide()
    DKPAuctionBidderUIFrame:Hide()
    DKPAuctionBidder_IsShown = 0
end

function DKPAuctionBidder_CurrentItemTooltip()
    GameTooltip:SetHyperlink(DKPAuctionBidder_CurrenItemLink)
    GameTooltip:Show()
end

function DKPAuctionBidder_OnChatMsgAddon(event, prefix, msg, channel, sender)
    if prefix == "SOTA_reply_DKPAuctionBidder" then
        if string.find(msg, UnitName("player")) == 1 then
            local message = string.sub(msg, string.len(UnitName("player"))+1)
            DEFAULT_CHAT_FRAME:AddMessage(DKPAuctionBidder_COLOUR_CHAT .. message .. DKPAuctionBidder_CHAT_END)
        end
    end
    
    if prefix == DKPAuctionBidder_SOTAprefix then
        
        local msg_HB = string.sub(msg, 1, string.len("HIGEST_BID")+1)
        local text = getglobal("DKPAuctionBidderHighestBidTextButtonText"):GetText()
        DKPAuctionBidder_Currentbid = DKPAuctionBidder_SplitString(msg)

        if string.find(msg, "SOTA_AUCTION_START") == 1 then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Auction Running - No Bids")
            DKPAuctionBidder_GetPlayerDKP()

            DKPAuctionBidder_AuctionTime = tonumber(DKPAuctionBidder_Currentbid[4])
            DKPAuctionBidder_AuctionTimeLeft = tonumber(DKPAuctionBidder_Currentbid[4])
            getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):SetWidth(DKPAuctionBidder_StatusbarStandardwidth)

            local itemName, itemString, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(DKPAuctionBidder_Currentbid[5])
            local r, g, b, hex = GetItemQualityColor(itemQuality)
            --local itemLink =  hex ..  '|H' .. itemString .. '|h[' .. itemName .. ']|h' .. FONT_COLOR_CODE_CLOSE
            DKPAuctionBidder_CurrenItemLink = itemString

            DKPAuctionBidder_MinimumStartingBid = tonumber(DKPAuctionBidder_Currentbid[6])

            DKPAuctionBidderUIFrame:Show()
            DKPAuctionBidderUIFrameAuctionStatusbar:Show()
            DKPAuctionBidderUIFrameTimerFrame:Show()

            --if DKPAuctionBidder_MinimumStartingBid > DKPAuctionBidder_PlayerDKP then
                --getglobal("DKPAuctionBidderBidMaxButton"):Disable()
                --getglobal("DKPAuctionBidderBidXButton"):Disable()
            --else
                --getglobal("DKPAuctionBidderBidMaxButton"):Enable()
                --getglobal("DKPAuctionBidderBidXButton"):Enable()
            --end

            local frame = getglobal("DKPAuctionBidderUIFrameItem")
            if frame then
                local inf = getglobal(frame:GetName().."ItemName")
                inf:SetText(itemName)
                inf:SetTextColor( r, g, b, 1)
                
                local tf = getglobal(frame:GetName().."ItemTexture")
                if tf then
                    tf:SetTexture(itemTexture)
                end
                frame:Show()
            end

            DKPAuctionBidder_AuctionState = 1

        elseif msg_HB == "HIGHEST_BID" then
            --if DKPAuctionBidder_Currentbid[4] == UnitName("player") then DKPAuctionBidder_Currentbid[4] = DKPAuctionBidder_Currentbid[4] .."(you)"
            local color = DKPAuctionBidder_GetClassColorCodes(DKPAuctionBidder_Currentbid[5]);
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Highest Bid: " ..DKPAuctionBidder_Currentbid[3] .." ")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText(DKPAuctionBidder_Currentbid[4])
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
            DKPAuctionBidder_LastHighestBid = DKPAuctionBidder_Currentbid
            DKPAuctionBidder_AuctionState = 2

        elseif msg == "SOTA_AUCTION_FINISH" or msg == "SOTA_AUCTION_CANCEL" then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("No Auction")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText("")
            getglobal("DKPAuctionBidderUIFrameAuctionStatusbar"):Hide()
            getglobal("DKPAuctionBidderUIFrameTimerFrame"):Hide()
            getglobal("DKPAuctionBidderUIFrameItem"):Hide()
            getglobal("DKPAuctionBidderBidMaxButton"):Enable()
            getglobal("DKPAuctionBidderBidXButton"):Enable()
            DKPAuctionBidder_AuctionState = 0

        elseif msg == "SOTA_AUCTION_PAUSE" then
            getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Auction Paused")
            getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText("")
            DKPAuctionBidder_AuctionStatePrePause = DKPAuctionBidder_AuctionState
            DKPAuctionBidder_AuctionState = 3

        elseif string.find(msg, "SOTA_AUCTION_RESUME") == 1 then
            if DKPAuctionBidder_AuctionStatePrePause == 2 then
                local color = DKPAuctionBidder_GetClassColorCodes(DKPAuctionBidder_LastHighestBid[5]);
                getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Highest Bid: " ..DKPAuctionBidder_LastHighestBid[3] .." ")
                getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetText(DKPAuctionBidder_LastHighestBid[4])
                getglobal("DKPAuctionBidderHighestBidTextButtonPlayer"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
                DKPAuctionBidder_AuctionTimeLeft = tonumber(DKPAuctionBidder_Currentbid[4])
                DKPAuctionBidder_AuctionState = 2

            elseif DKPAuctionBidder_AuctionStatePrePause == 1 then
                getglobal("DKPAuctionBidderHighestBidTextButtonText"):SetText("Auction Running - No Bids")
                DKPAuctionBidder_AuctionTimeLeft = tonumber(DKPAuctionBidder_Currentbid[4])
                DKPAuctionBidder_AuctionState = 1
            end
        end

        if msg == "SOTAMASTER" then
            DKPAuctionBidder_SOTA_Master = sender
        end
    end

    if prefix == "SOTA_TIMER_SYNC" then
        DKPAuctionBidder_AuctionTimeLeft = tonumber(msg)
    end
end

function DKPAuctionBidder_GetPlayerDKP()
	local memberCount = GetNumGuildMembers();
	local note
	for n=1,memberCount,1 do
		local name, rank, _, _, class, zone, publicnote, officernote, online = GetGuildRosterInfo(n)

        if name == UnitName("player") then
		    if not zone then
		    	zone = "";
		    end

		    note = publicnote

		    if not note or note == "" then
		    	note = "<0>";
		    end
        
		    if not online then
		    	online = 0;
		    end
        
		    local _, _, dkp = string.find(note, "<(-?%d*)>")
		    if not dkp then
		    	dkp = 0;
            end
            DKPAuctionBidder_PlayerDKP = (1*dkp)
        end
    end
    getglobal("DKPAuctionBidderPlayerDKPButtonText"):SetText("Your DKP: " ..DKPAuctionBidder_PlayerDKP)
end

function DKPAuctionBidder_GetClassColorCodes(classname)
	local colors = { 128,128,128 }
	local cc;
	for n=1, table.getn(DKPAuctionBidder_CLASS_COLORS), 1 do
		cc = DKPAuctionBidder_CLASS_COLORS[n];
		if cc[1] == classname then
			return cc[2];
		end
	end

	return colors;
end

function DKPAuctionBidder_SplitString(inputstr)
    local t={} ; i=1
    for w in string.gfind(inputstr, "%w+") do
        t[i] = w
        i = i + 1
    end
    return t
end
