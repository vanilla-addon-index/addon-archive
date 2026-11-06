--[[
PandaQuest / Quest/StandaloneQuestLog.lua

Two-page Dragonflight Quest Log for a session with no pandaUI.

The stock quest list is expanded down the left page and the stock detail pane is
moved onto the right one, inside imported Dragonflight page art
(media/Textures/QuestLog/, geometry in Compatibility/ClientAPI.lua). The client still
owns selection, scrolling, quest actions and detail population, while
PandaQuest's existing level, translation, tracking, reward and action-button
modules continue to decorate those same native widgets.

It is deliberately the same interface pandaUI draws for its Modern WoW Quest
Log, from the same artwork and the same measurements, so the window looks the
same whether or not that addon is installed. It replaces the Extended QuestLog
3.6.1 parchment layout this module carried until 0.3.6; that art is no longer
shipped.

The row count is not a fixed number: the rows are spaced by the live row height
and only as many are installed as end inside the list page. That count is also
what QUESTS_DISPLAYED is set to, so everything past it is what the client's own
FauxScrollFrame scrolls -- exactly as the native log behaves.

STANDALONE ONLY.

pandaUI owns the Quest Log under every one of its themes: its Modern theme
draws its own two-pane window, its Modern WoW theme and its Classic WoW theme
both draw this same Dragonflight design from one shared module of their own
(pandaUI/modules/questlogdesign.lua), and Classic falls back to a parchment
two-page log when that module is switched off. So this module applies nothing at
all whenever pandaUI is installed -- not merely when a particular theme is
active. Two addons re-anchoring the same native widgets is the failure mode
being avoided here, and pandaUI wins by design.

"Installed" means the PandaUI global exists, which is also what
Client.GetPandaUIQuestLogMode reads for the diagnostic note below. Resolution
is delayed until that global appears, or until the same fifteen-second
late-load grace period used by Core/Settings.lua expires, because addon load
order does not guarantee pandaUI has run when this module is enabled.
]]

local PQ = PandaQuest
local Client = PQ.Client
local StandaloneQuestLog = PQ:NewModule("StandaloneQuestLog")

local HOST_POLL_INTERVAL = 0.5
local HOST_POLL_SECONDS = 15
local REWARD_LAYOUT_INTERVAL = 0.2

StandaloneQuestLog.mode = nil
StandaloneQuestLog.waited = 0
StandaloneQuestLog.applied = false
StandaloneQuestLog.rewardJobStarted = false

function StandaloneQuestLog:StartRewardLayoutJob()
    if self.rewardJobStarted or not self.applied then
        return
    end
    local driver = PQ:GetModule("Driver")
    if not driver then
        return
    end
    self.rewardJobStarted = true
    driver:Schedule("questlog.standalone.rewards", REWARD_LAYOUT_INTERVAL,
        function()
            -- Reasserts the window art and the page layout after a native show
            -- recreates the client's own artwork. It watches for the
            -- hidden-to-shown transition itself, so it is asked on every tick
            -- and does work on almost none of them.
            Client.RefreshStandaloneQuestLogArt()
            if Client.IsStandaloneQuestLogShown() then
                Client.RefreshStandaloneQuestLogRewards()
                Client.RefreshStandaloneQuestLogFoldFaces()
            end
        end)
end

-- Which pandaUI surface owns the Quest Log. Diagnostic wording only; nothing
-- branches on it, because any pandaUI at all is enough to stand down.
function StandaloneQuestLog:DescribeHost()
    local mode = Client.GetPandaUIQuestLogMode()
    if mode == "classic" then
        return "its Classic WoW theme's extended two-page Quest Log"
    elseif mode == "modern-wow" then
        return "its Dragonflight two-page Quest Log"
    elseif mode == "modern" then
        return "its Modern two-pane Quest Log"
    end
    return "its own Quest Log"
end

function StandaloneQuestLog:Resolve(force)
    if self.mode then
        return self.mode
    end

    if Client.HasObject("PandaUI") then
        -- Installed is enough. An older pandaUI without its own Quest Log
        -- design is still treated as owning this frame, so PandaQuest never
        -- modifies a native widget it may skin later in the same load sequence.
        self.mode = "host"
        PQ:DeclareCapability("standaloneQuestLog", "detected",
            "pandaUI is installed and owns the Quest Log through "
            .. self:DescribeHost()
            .. "; PandaQuest's own two-page Quest Log is standalone-only and "
            .. "intentionally left the native frame unchanged")
        return self.mode
    end

    if not force then
        return nil
    end

    local applied = Client.ApplyStandaloneQuestLog()
    if applied == nil then
        -- The native frames are not available yet. Keep polling rather than
        -- making their load timing a correctness dependency.
        return nil
    end

    self.mode = "standalone"
    self.applied = applied and true or false
    if self.applied then
        self:StartRewardLayoutJob()
        PQ:DeclareCapability("questLogFoldGlyphs", "unverified",
            "header rows and the collapse-all control draw the tracker's plus/minus "
            .. "art over their stock glyph, which is hidden through GetNormalTexture "
            .. "(documented, not probed) and SetVertexColor's alpha; needs one in-game "
            .. "look that the stock glyph stays gone after a native refresh")
        local rows = Client.GetStandaloneQuestLogRows()
        PQ:DeclareCapability("standaloneQuestLog", "unverified",
            "no pandaUI in this session, so the native Quest Log was rebuilt as the "
            .. "Dragonflight two-page spread: "
            .. tostring(rows or "?")
            .. " stock rows -- as many as the measured row height fits inside the left "
            .. "page, so a longer quest list scrolls on the native FauxScrollFrame "
            .. "instead of running off it -- with the stock detail pane on the right "
            .. "page, both native scroll bars moved into the gutter and the channel the "
            .. "art draws for them, and the three stock quest actions in its drawn "
            .. "button beds. The frame calls, the row-template technique and the texture "
            .. "encoding are all supported here, and the geometry is what pandaUI draws "
            .. "this same art at, but the assembly needs one in-game visual "
            .. "confirmation: that the native parchment is fully gone (the window's "
            .. "BACKGROUND draw layer is disabled), and that the title, the count line, "
            .. "the quest rows and the reward text all still draw above the pages")
    else
        PQ:DeclareCapability("standaloneQuestLog", "missing",
            "the standalone layout was selected, but one of the native Quest Log "
            .. "widgets or imported page textures could not be prepared")
    end
    return self.mode
end

function StandaloneQuestLog:OnInit()
    PQ:DeclareCapability("standaloneQuestLog", "unverified",
        "waiting to determine whether pandaUI is installed and owns the Quest Log")
end

function StandaloneQuestLog:OnEnable()
    if self:Resolve(false) then
        return
    end

    local driver = PQ:GetModule("Driver")
    if not driver then
        self:Resolve(true)
        return
    end

    driver:Schedule("questlog.standalone", HOST_POLL_INTERVAL, function(elapsed)
        StandaloneQuestLog.waited = StandaloneQuestLog.waited
            + (elapsed or HOST_POLL_INTERVAL)
        local mode = StandaloneQuestLog:Resolve(
            StandaloneQuestLog.waited >= HOST_POLL_SECONDS)
        if mode then
            local running = PQ:GetModule("Driver")
            if running then
                running:Unschedule("questlog.standalone")
            end
        end
    end)
end
