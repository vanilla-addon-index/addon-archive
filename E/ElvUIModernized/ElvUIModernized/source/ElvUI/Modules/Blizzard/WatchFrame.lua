local E, L, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local B = E:GetModule("Blizzard");

--Cache global variables
--Lua functions
local min = math.min
--WoW API / Variables
local hooksecurefunc = hooksecurefunc
local GetScreenHeight = GetScreenHeight
local GetNumQuestWatches = GetNumQuestWatches
local GetQuestIndexForWatch = GetQuestIndexForWatch
local RemoveQuestWatch = RemoveQuestWatch
local AddQuestWatch = AddQuestWatch
local QuestWatch_Update = QuestWatch_Update

local original_QuestWatch_Update = QuestWatch_Update
function _G.QuestWatch_Update()
	local watched = {}
	local order = {}
	local hasDuplicates = false
	for i = 1, GetNumQuestWatches() do
		local qIndex = GetQuestIndexForWatch(i)
		if qIndex then
			if watched[qIndex] then
				hasDuplicates = true
			else
				watched[qIndex] = true
				table.insert(order, qIndex)
			end
		end
	end
	
	if hasDuplicates then
		for i = 1, table.getn(order) do
			RemoveQuestWatch(order[i])
		end
		for i = 1, table.getn(order) do
			AddQuestWatch(order[i])
		end
	end
	
	original_QuestWatch_Update()
end

local WatchFrameHolder = CreateFrame("Frame", "WatchFrameHolder", E.UIParent)
WatchFrameHolder:SetWidth(150)
WatchFrameHolder:SetHeight(22)
WatchFrameHolder:SetPoint("TOPRIGHT", E.UIParent, "TOPRIGHT", -135, -300)

function B:SetWatchFrameHeight()
	local top = QuestWatchFrame:GetTop() or 0
	local screenHeight = GetScreenHeight()
	local gapFromTop = screenHeight - top
	local maxHeight = screenHeight - gapFromTop
	local watchFrameHeight = min(maxHeight, E.db.general.watchFrameHeight)

	QuestWatchFrame:SetHeight(watchFrameHeight)
end

function B:MoveWatchFrame()
	E:CreateMover(WatchFrameHolder, "WatchFrameMover", L["Watch Frame"])
	WatchFrameHolder:SetAllPoints(WatchFrameMover)

	QuestWatchFrame:ClearAllPoints()
	QuestWatchFrame:SetPoint("TOP", WatchFrameHolder, "TOP")
	B:SetWatchFrameHeight()
	QuestWatchFrame:SetClampedToScreen(false)

	hooksecurefunc(QuestWatchFrame, "SetPoint", function(_, _, parent)
		if parent ~= WatchFrameHolder then
			QuestWatchFrame:ClearAllPoints()
			QuestWatchFrame:SetPoint("TOP", WatchFrameHolder, "TOP")
		end
	end)
end