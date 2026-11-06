--[[
	Tests for sharing a guide with the party (PartySync.lua).

	Sharing only helps if it keeps people together without ever leaving one
	of them stuck: a finished step waits for the others, and moves on the
	moment they catch up; nobody is pulled back to meet someone behind them;
	a partner on a step this character does not have cannot hold it; and the
	skip arrow still gets you out. The messages have to say the same thing on
	both sides, the popups have to do what their buttons say, and the panel
	has to show where everyone is.

	Run:  lua5.1 Tools/tests/test_partysync.lua
]]

package.path = "Tools/tests/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
local now = 100
GetTime = function() return now end

-- The group: names by unit, and what goes out on the addon channel.
local party, raid = { "Ghanndraine" }, {}
GetNumPartyMembers = function() return table.getn(party) end
GetNumRaidMembers = function() return table.getn(raid) end
UnitName = function(unit)
	if unit == "player" then return "Me" end
	local _, _, n = string.find(unit, "^party(%d)$")
	if n then return party[tonumber(n)] end
	_, _, n = string.find(unit, "^raid(%d+)$")
	if n then return raid[tonumber(n)] end
end
local sent = {}
SendAddonMessage = function(prefix, msg, channel) table.insert(sent, { prefix = prefix, msg = msg, channel = channel }) end

local printed, updates, panels, opened, skipped = {}, 0, 0, {}, 0
AegisPathfinder = {
	guides = { ["Elwynn Forest (1-12)"] = function() end, ["Westfall (10-20)"] = function() end },
	db = { char = { currentguide = "Elwynn Forest (1-12)" }, profile = {} },
	current = 3,
}
local A = AegisPathfinder
function A:Debug() end
function A:Print(msg) table.insert(printed, msg) end
function A:HasNoGuide() return false end
function A:UpdateStatusFrame() updates = updates + 1 end
function A:UpdateOHPanel() panels = panels + 1 end
function A:OpenGuideTab(name) table.insert(opened, name); self.db.char.currentguide = name end
function A:SkipToNextObjective() skipped = skipped + 1 end

-- A guide: steps by action, title and quest id.
local tagsQid = {}
local function Guide(steps)
	A.actions, A.quests, tagsQid = {}, {}, {}
	for i, s in ipairs(steps) do
		A.actions[i] = s[1]
		A.quests[i] = s[2] .. "@" .. i .. "@"
		tagsQid[i] = s[3]
	end
end
function A:GetObjectiveTag(tag, i)
	if tag == "QID" then return tagsQid[i] end
end
local logs = {}
function A:GetObjectiveStatus(i) local l = logs[i]; if l then return false, l.logi, l.complete end end
A.ReadLeaderboard = function(logi) return "Mottled Boar slain", 3, 6 end

dofile("Theme.lua")
dofile("PartySync.lua")
local Theme = A.Theme
local share = A.shareState

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, unpack(arg))) end
end
local function lastPrint() return printed[table.getn(printed)] or "" end
local function lastSent() return sent[table.getn(sent)] or {} end
local function run(f, script) this = f; f:GetScript(script)() end
local function hear(from, msg) A:OnShareMessage(msg, from) end
local function tick() run(A.shareDriver, "OnUpdate") end
local function tint(tex) local r, g, b = tex:GetVertexColor() return { r, g, b } end
local function is(c, name) local t = Theme.color[name] return math.abs(c[1] - t[1]) < 1e-6 and math.abs(c[2] - t[2]) < 1e-6 end

Guide({
	{ "ACCEPT", "Wolves", 33 },
	{ "COMPLETE", "Wolves", 33 },
	{ "COMPLETE", "Mottled Boars", 17 },
	{ "NOTE", "Talk to the guard" },
	{ "NOTE", "Talk to the guard" },
	{ "TURNIN", "Wolves", 33 },
})

-- Steps by name ---------------------------------------------------------------------------

check(A:ShareStepKey(3) == "COMPLETE:17#1", "a step is named by action and quest id: %s", tostring(A:ShareStepKey(3)))
check(A:ShareStepKey(4) == "NOTE:Talk to the guard#1" and A:ShareStepKey(5) == "NOTE:Talk to the guard#2",
	"without a quest id by title, and a repeat by which occurrence it is")
check(A:ShareStepIndex("COMPLETE:17#1") == 3 and A:ShareStepIndex("nope") == nil, "and a name finds its step here")
local mine = {}
for i = 1, 6 do mine[i] = A:ShareStepKey(i) end
-- A class step the other character has, before the rest: the names still match.
Guide({
	{ "ACCEPT", "Wolves", 33 },
	{ "TRAIN", "Train your spells" },
	{ "COMPLETE", "Wolves", 33 },
	{ "COMPLETE", "Mottled Boars", 17 },
	{ "NOTE", "Talk to the guard" },
	{ "NOTE", "Talk to the guard" },
	{ "TURNIN", "Wolves", 33 },
})
check(A:ShareStepIndex(mine[3]) == 4 and A:ShareStepIndex(mine[5]) == 6,
	"a step keeps its name when another character's step numbers differ")
Guide({
	{ "ACCEPT", "Wolves", 33 },
	{ "COMPLETE", "Wolves", 33 },
	{ "COMPLETE", "Mottled Boars", 17 },
	{ "NOTE", "Talk to the guard" },
	{ "NOTE", "Talk to the guard" },
	{ "TURNIN", "Wolves", 33 },
})

-- The party icon and the confirmation -----------------------------------------------------------

local navrow = CreateFrame("Frame", nil, UIParent)
navrow.count = navrow:CreateFontString(nil, "OVERLAY")
local button = A:AttachShareButton(navrow)
check(button and A.sharebutton == button and button.glyph.__texture == Theme.glyph.party, "the step row gets the party icon")
local _, rel = navrow.count:GetPoint()
check(rel == button, "the step count moves over to make room")
check(is(tint(button.glyph), "textDim"), "dim while not sharing")
local hint, detail = A:ShareHint()
check(hint == "Share this guide with your party [BETA]" and string.find(detail[1], "Aegis: Pathfinder too", 1, true),
	"its hint says what it does: %s", hint)

party = {}
A:ToggleSharing()
check(string.find(lastPrint(), "Join a party first", 1, true) and not share.active, "alone, there is no one to share with")
party = { "Ghanndraine" }

A:ToggleSharing()
local dialog = share.dialog
check(dialog and dialog:IsShown() and dialog.mode == "confirm", "in a party it asks first")
check(dialog.lines[1]:GetText() == "Do you want to start sharing the guide:" and dialog.lines[2]:GetText() == "Elwynn Forest (1-12)"
	and dialog.lines[3]:GetText() == "with your party?" and string.find(dialog.lines[4]:GetText(), "Aegis: Pathfinder", 1, true),
	"naming the guide, as Zygor's does")
check(dialog.check:IsShown() and not dialog.check:GetChecked(), "with a don't-warn-me box, unticked")
check(table.getn(sent) == 0, "and nothing goes out until it is accepted")
run(dialog.no, "OnClick")
check(not dialog:IsShown() and not share.active and table.getn(sent) == 0, "Cancel does nothing")

A:ToggleSharing()
run(dialog.check, "OnClick")
run(dialog.yes, "OnClick")
check(A.db.char.sharenowarn == true, "ticked, it will not ask again")
check(share.active and share.guide == "Elwynn Forest (1-12)", "Accept starts sharing the guide you are on")
check(lastSent().prefix == "AegisPF" and lastSent().channel == "PARTY", "over the party addon channel")
check(lastSent().msg == "INV^Elwynn Forest (1-12)^COMPLETE:17#1", "inviting with the guide and your step: %s", tostring(lastSent().msg))
check(string.find(lastPrint(), "Invited your party to share Elwynn Forest", 1, true), "and says so")
check(is(tint(button.glyph), "gold"), "the icon turns gold while nobody has accepted")
check(A:ShareHint() == "Waiting for your party to accept", "and its hint says why")

-- Answers -------------------------------------------------------------------------------------

hear("Ghanndraine", "DEC^Elwynn Forest (1-12)")
check(string.find(lastPrint(), "Ghanndraine declined", 1, true), "a decline is reported")
hear("Ghanndraine", "NOG^Elwynn Forest (1-12)")
check(string.find(lastPrint(), "does not have Elwynn Forest", 1, true), "so is not having the guide")
hear("Ghanndraine", "ACC^Elwynn Forest (1-12)")
check(share.members.Ghanndraine ~= nil and string.find(lastPrint(), "Ghanndraine is sharing", 1, true), "an accept adds them")
check(is(tint(button.glyph), "accent"), "and the icon lights up")
check(A:ShareHint() == "Sharing with Ghanndraine", "naming who: %s", A:ShareHint())
hear("Ghanndraine", "ACC^Westfall (10-20)")
check(A:ShareMembers()[2] == nil, "an answer about another guide is ignored")
hear("Ghanndraine", "ST^Westfall (10-20)^COMPLETE:17#1^1^^")
check(share.members.Ghanndraine.key == nil, "and so is a status for another guide")
hear("Me", "ST^Elwynn Forest (1-12)^COMPLETE:17#1^1^^")
check(share.members.Me == nil, "our own messages come back and are ignored")

-- Where they are, in words ------------------------------------------------------------------

check(A:ShareMemberStatus("Ghanndraine") == "joining...", "before any status: joining")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^COMPLETE:17#1^0^3^6")
local text, color = A:ShareMemberStatus("Ghanndraine")
check(text == "[3/6]" and color == "gold", "on your step with counts: [3/6], got %s", text)
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^COMPLETE:17#1^1^^")
text, color = A:ShareMemberStatus("Ghanndraine")
check(text == "[done]" and color == "accent", "done with it: [done]")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^NOTE:Talk to the guard#1^0^^")
check(A:ShareMemberStatus("Ghanndraine") == "step 4", "ahead: which step")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^NOTE:Talk to the guard#1^1^^")
check(A:ShareMemberStatus("Ghanndraine") == "step 4, waiting", "ahead and finished: waiting")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^COMPLETE:33#1^0^^")
text, color = A:ShareMemberStatus("Ghanndraine")
check(text == "step 2, behind" and color == "gold", "behind: which step, in gold")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^TRAIN:Train your spells#1^0^^")
check(A:ShareMemberStatus("Ghanndraine") == "on a step you do not have", "on a step this character lacks")
hear("Ghanndraine", "ST^Elwynn Forest (1-12)^NOTE:Talk to the guard#2^0^^")
check(A:ShareMemberStatus("Ghanndraine") == "step 5", "a repeated step, by occurrence")

-- Holding the step ------------------------------------------------------------------------------

local function status(key, done) hear("Ghanndraine", "ST^Elwynn Forest (1-12)^" .. key .. "^" .. (done and 1 or 0) .. "^^") end
A.current = 3
status("COMPLETE:17#1", false)
check(A:ShareHold(4, 3) == 3 and share.holding == 3, "finished while they are not: stay on the step")
status("COMPLETE:17#1", true)
check(A:ShareHold(4, 3) == nil and share.holding == nil, "both finished: move on together")
status("NOTE:Talk to the guard#1", false)
check(A:ShareHold(4, 3) == nil, "they are ahead: carry on")
status("COMPLETE:33#1", false)
check(A:ShareHold(4, 3) == 3, "they are behind: wait where you are, not back where they are")
check(A:ShareHold(3, 3) == nil, "a step not finished yet needs no holding")
status("TRAIN:Train your spells#1", false)
check(A:ShareHold(4, 3) == nil, "a partner on a step you lack cannot hold you")
-- Two partners: the one furthest behind decides.
share.members.Arla = { key = "COMPLETE:33#1", done = false }
share.members.Ghanndraine = { key = "NOTE:Talk to the guard#2", done = true }
check(A:ShareHold(4, 3) == 3, "one ahead and one behind: wait for the one behind")
share.members.Arla = nil
status("COMPLETE:17#1", false)
check(A:ShareHold(nil, 6) == 6, "the end of the guide waits too, on the last step you were on")
A.db.char.currentguide = "Westfall (10-20)"
check(A:ShareHold(4, 3) == nil, "another guide in your tab is not held")
A.db.char.currentguide = "Elwynn Forest (1-12)"

-- The skip arrow gets you out.
A.current = 3
check(A:ShareHold(4, 3) == 3, "held again")
A:SkipToNextObjective()
check(skipped == 1 and share.bypass == 3, "skipping a held step skips it alone")
check(A:ShareHold(4, 3) == nil, "and it is not held again")
A.current = 4
check(A:ShareHold(5, 4) == 4, "the next finished step still waits")
status("NOTE:Talk to the guard#1", false)
A:ShareHold(5, 4)
check(share.bypass == nil, "once they catch up, the skip is forgotten")

-- Our own status -------------------------------------------------------------------------------

sent = {}
A.current = 3
logs[3] = { logi = 5, complete = false }
share.lastSent, share.lastSig, share.polled = 0, nil, 0
A.shareDriver:Show()
tick()
check(lastSent().msg == "ST^Elwynn Forest (1-12)^COMPLETE:17#1^0^3^6", "our status: step, not done, 3 of 6: %s", tostring(lastSent().msg))
local count = table.getn(sent)
now = now + 0.6
tick()
check(table.getn(sent) == count, "nothing new, nothing sent")
share.members.Ghanndraine = { key = "COMPLETE:17#1", done = false }
A:ShareHold(4, 3)
now = now + 0.6
tick()
check(lastSent().msg == "ST^Elwynn Forest (1-12)^COMPLETE:17#1^1^^", "held, we say we are done: %s", tostring(lastSent().msg))
count = table.getn(sent)
share.holding = nil
now = now + 0.5
tick()
check(table.getn(sent) == count, "a change inside the throttle waits")
now = now + 0.6
tick()
check(table.getn(sent) == count + 1, "and goes once the throttle allows")
count = table.getn(sent)
now = now + A.shareTunables.HEARTBEAT + 1
tick()
check(table.getn(sent) == count + 1, "a heartbeat goes even with nothing new")
hear("Ghanndraine", "REQ^Elwynn Forest (1-12)")
count = table.getn(sent)
tick()
check(table.getn(sent) == count + 1, "asked where we are, we answer at once")

-- Members' news settles once a frame.
updates, panels = 0, 0
status("COMPLETE:17#1", true)
status("COMPLETE:17#1", false)
check(updates == 0, "news does not run the engine inline")
tick()
check(updates == 1 and panels == 1, "it runs once on the next frame (%d, %d)", updates, panels)

-- The panel ------------------------------------------------------------------------------------

local panel = CreateFrame("Frame", nil, UIParent)
panel:SetWidth(396)
local anchor = CreateFrame("Frame", nil, panel)
A.current = 3
share.members = { Ghanndraine = { key = "COMPLETE:17#1", have = 3, need = 6 }, Arla = { key = "COMPLETE:33#1" } }
share.holding = nil
check(A:PaintPartyBlock(panel, anchor, 14), "sharing, the members show under the step")
local block = panel.partyblock
check(block.lines[1].name:GetText() == "Arla" and block.lines[1].status:GetText() == "step 2, behind",
	"one line each, by name: %s %s", tostring(block.lines[1].name:GetText()), tostring(block.lines[1].status:GetText()))
check(block.lines[2].name:GetText() == "Ghanndraine" and block.lines[2].status:GetText() == "[3/6]", "Ghanndraine [3/6]")
check(block:GetHeight() == 2 * A.shareTunables.LINE_H + 8, "sized to its lines")
share.holding = 3
A:PaintPartyBlock(panel, anchor, 14)
check(block.lines[1].name:GetText() == "Done. Waiting for your party to finish this step.", "a held step says why it waits")
check(block.lines[3].name:IsShown(), "above the members")
A.db.char.overviewmode = true
check(not A:PaintPartyBlock(panel, anchor, 14) and not block:IsShown(), "the overview does not show it")
A.db.char.overviewmode = nil

-- Invitations ------------------------------------------------------------------------------------

A:StopSharing()
check(lastSent().msg == "BYE^Elwynn Forest (1-12)" and not share.active, "stopping says goodbye")
check(not A:PaintPartyBlock(panel, anchor, 14), "and the members go from the panel")
check(is(tint(button.glyph), "textDim"), "and the icon dims")

sent = {}
hear("Ghanndraine", "INV^Dun Morogh (1-10)^ACCEPT:179#1")
check(lastSent().msg == "NOG^Dun Morogh (1-10)" and string.find(lastPrint(), "which you do not have", 1, true),
	"an invitation to a guide you lack is answered and explained")
hear("Ghanndraine", "INV^Westfall (10-20)^ACCEPT:109#1")
check(dialog:IsShown() and dialog.mode == "invite", "an invitation opens the popup")
check(string.find(dialog.lines[1]:GetText(), "Ghanndraine", 1, true)
	and string.find(dialog.lines[1]:GetText(), "would like to share the following guide with you:", 1, true)
	and dialog.lines[2]:GetText() == "Westfall (10-20)"
	and string.find(dialog.lines[4]:GetText(), "a new tab will open", 1, true), "saying who, and what, and what accepting does")
check(not dialog.check:IsShown() and dialog.no:GetText() == "DECLINE", "with Accept and Decline, and no don't-warn box")
run(dialog.yes, "OnClick")
check(opened[1] == "Westfall (10-20)", "accepting opens the guide in a new tab")
check(share.active and share.guide == "Westfall (10-20)" and share.members.Ghanndraine, "and shares it with them")
check(sent[table.getn(sent) - 1].msg == "ACC^Westfall (10-20)" and lastSent().msg == "REQ^Westfall (10-20)",
	"telling them, and asking where they are")
check(not dialog:IsShown(), "the popup closes")

hear("Ghanndraine", "INV^Westfall (10-20)^ACCEPT:109#1")
check(lastSent().msg == "ACC^Westfall (10-20)" and not dialog:IsShown(), "a repeat invitation to the same share is just accepted")

A:StopSharing(true)
A.db.char.currentguide = "Elwynn Forest (1-12)"
A.db.char.sharenowarn = false
A:ToggleSharing()
run(dialog.yes, "OnClick")
check(share.active and A.db.char.sharenowarn == false, "accepting without the box ticked keeps asking")
A:StopSharing(true)
A.db.char.sharenowarn = true
local shownBefore = dialog:IsShown()
A:ToggleSharing()
check(share.active and not dialog:IsShown() and not shownBefore, "told not to warn, the icon starts sharing at once")
A:StopSharing(true)
hear("Ghanndraine", "INV^Elwynn Forest (1-12)^ACCEPT:33#1")
run(dialog.no, "OnClick")
check(lastSent().msg == "DEC^Elwynn Forest (1-12)" and not share.active, "Decline declines")
hear("Ghanndraine", "INV^Elwynn Forest (1-12)^ACCEPT:33#1")
sent = {}
dialog:Hide()
run(dialog, "OnHide")
check(lastSent().msg == "DEC^Elwynn Forest (1-12)", "and so does closing the popup")

-- The group changing ------------------------------------------------------------------------------

party = { "Ghanndraine", "Arla" }
A.db.char.currentguide = "Elwynn Forest (1-12)"
A:StartSharing()
hear("Ghanndraine", "ACC^Elwynn Forest (1-12)")
hear("Arla", "ACC^Elwynn Forest (1-12)")
check(table.getn(A:ShareMembers()) == 2, "two members")
hear("Arla", "BYE^Elwynn Forest (1-12)")
check(A:ShareMembers()[1] == "Ghanndraine" and A:ShareMembers()[2] == nil and string.find(lastPrint(), "Arla stopped sharing", 1, true),
	"one says goodbye")
party = {}
raid = { "Me", "Ghanndraine", "Tovar" }
A:OnShareRosterChanged()
check(share.active and share.members.Ghanndraine, "a party turned raid keeps sharing")
A:StartSharing()
check(lastSent().channel == "RAID", "over the raid channel")
hear("Ghanndraine", "ACC^Elwynn Forest (1-12)")
raid = { "Me", "Tovar" }
A:OnShareRosterChanged()
check(share.active and not share.members.Ghanndraine, "whoever leaves the group leaves the share")
raid = {}
A:OnShareRosterChanged()
check(not share.active and string.find(lastPrint(), "group is gone", 1, true), "with no group left it ends")

-- The events frame routes by prefix.
party = { "Ghanndraine" }
A:StartSharing()
event, arg1, arg2, arg4 = "CHAT_MSG_ADDON", "SomethingElse", "ACC^Elwynn Forest (1-12)", "Ghanndraine"
run(A.shareEvents, "OnEvent")
check(not share.members.Ghanndraine, "another addon's messages are not ours")
arg1 = "AegisPF"
run(A.shareEvents, "OnEvent")
check(share.members.Ghanndraine, "ours are")

-- Party sync off (the Step Display page): no party icon, and invitations
-- answered no without a popup.
A:StopSharing(true)
dialog:Hide()
A.db.char.partysync = false
A:PaintShareButton()
check(not button:IsShown(), "party sync off: no party icon")
local _, countRel = navrow.count:GetPoint()
check(countRel == navrow, "and the step count takes its place")
hear("Ghanndraine", "INV^Westfall (10-20)^ACCEPT:184:1")
check(not dialog:IsShown() and lastSent().msg == "DEC^Westfall (10-20)", "an invitation is declined, without a popup")
A.db.char.partysync = nil
A:PaintShareButton()
_, countRel = navrow.count:GetPoint()
check(button:IsShown() and countRel == button, "back on, the icon is back beside the count")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
if table.getn(failures) > 0 then
	for _, f in ipairs(failures) do print("FAIL: " .. f) end
	print(string.format("%d of %d checks failed", table.getn(failures), checks))
	os.exit(1)
end
print(string.format("test_partysync: all %d checks passed", checks))
