local SelfFound = CreateFrame("Frame")

-- Check which game expansion
function SelfFound:Expansion()
    local _, _, _, client = GetBuildInfo()
    client = client or 11200

    -- detect client expansion
    if client >= 20000 and client <= 20400 then
        return "tbc"
    elseif client >= 30000 and client <= 30300 then
        return "wotlk"
    else
        return "vanilla"
    end
end

-- Print function
function SelfFound:Print(msg)
    print("|cff3ffca4SelfFound: " .. msg)
end

-- Limit auction house
function SelfFound:AUCTION_HOUSE_SHOW()
    local isHighEnoughLvl = UnitLevel("player") >= SelfFound.maxLvl

    if isHighEnoughLvl then return end

    SelfFound:Print("Auction House is available from lvl " .. SelfFound.maxLvl)
    CloseAuctionHouse()
end

-- Limit mail
function SelfFound:MAIL_SHOW()
    local lvl = UnitLevel("player")
    local isHighEnoughLvl = lvl >= SelfFound.maxLvl
    local isDivisibleBy10 = math.mod(lvl, 10) == 0 -- Rewards for challenges

    if isHighEnoughLvl or isDivisibleBy10 then return end

    SelfFound:Print("Mail is available every 10 levels")
    CloseMail()
end

-- Limit trading
TradeFrameTradeButton:SetScript("OnClick", function()
    local isHighEnoughLvl = UnitLevel("player") >= SelfFound.maxLvl
    local isInInstance, _ = IsInInstance()
    local noMoneyToBeReceived = tonumber(GetTargetTradeMoney()) == 0

    if (isHighEnoughLvl or (isInInstance and noMoneyToBeReceived)) then
        AcceptTrade()
    else
        SelfFound:Print("Trading is available from lvl " .. SelfFound.maxLvl .. " or in instances")
        CloseTrade()
    end
end)

function SelfFound:PLAYER_ENTERING_WORLD()
    -- Set max lvl
    local expansion = SelfFound:Expansion()
    local maxLvl = 60

    if (expansion == "tbc") then
        maxLvl = 70
    elseif (expansion == "wotlk") then
        maxLvl = 80
    end

    SelfFound.maxLvl = maxLvl
end

-- Notify player on new functionality
function SelfFound:PLAYER_LEVEL_UP(newLvl)
    if not SelfFound then return end

    if (newLvl == SelfFound.maxLvl) then
        SelfFound:Print("Congrats! You finished the Self Found challenge!")
        SelfFound:Print("Mail, Trading and the Auction House are now available")
    end
end

-- Start the addon
SelfFound:RegisterEvent("PLAYER_ENTERING_WORLD")
SelfFound:RegisterEvent("PLAYER_LEVEL_UP")
SelfFound:RegisterEvent("MAIL_SHOW")
SelfFound:RegisterEvent("AUCTION_HOUSE_SHOW")

SelfFound:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        SelfFound:PLAYER_ENTERING_WORLD()
    elseif event == "PLAYER_LEVEL_UP" then
        SelfFound:PLAYER_LEVEL_UP()
    elseif event == "MAIL_SHOW" then
        SelfFound:MAIL_SHOW()
    elseif event == "AUCTION_HOUSE_SHOW" then
        SelfFound:AUCTION_HOUSE_SHOW()
    end
end)
