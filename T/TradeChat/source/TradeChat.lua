TradeChat = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0")

function TradeChat:OnInitialize()
	TradeChat.otherMoney = 0
end

function TradeChat:OnEnable()
	self:RegisterEvent("PLAYER_TRADE_MONEY")
	self:RegisterEvent("TRADE_MONEY_CHANGED")
	self:RegisterEvent("TRADE_ACCEPT_UPDATE")
end

function TradeChat:PLAYER_TRADE_MONEY()
	TradeChat.playerMoney = GetPlayerTradeMoney()
	TradeChat.otherMoney = GetTargetTradeMoney()
	-- DEFAULT_CHAT_FRAME:AddMessage("playertrade " .. TradeChat.playerMoney .. " - " .. TradeChat.otherMoney)

end

function TradeChat:TRADE_MONEY_CHANGED()
	TradeChat.playerMoney = GetPlayerTradeMoney()
	TradeChat.otherMoney = GetTargetTradeMoney()
	-- DEFAULT_CHAT_FRAME:AddMessage("changed " .. TradeChat.playerMoney .. " - " .. TradeChat.otherMoney)

end

function TradeChat:TRADE_ACCEPT_UPDATE(p1, p2)
	if p1 == 1  and p2 == 1 then
		local money = tonumber(TradeChat.otherMoney)
		local gold = floor(money / 1e4)
		money = money - 1e4 * gold
		local silver = floor(money / 100)
		money = money - 100 * silver
		local copper = money
		DEFAULT_CHAT_FRAME:AddMessage("You were traded "..gold.."g, "..silver.."s, "..copper.."c")
		-- DEFAULT_CHAT_FRAME:AddMessage(p1 .. "X" .. p2 .. ":" .."You were traded "..TradeChat.otherMoney .. " Copper")
	end
end
