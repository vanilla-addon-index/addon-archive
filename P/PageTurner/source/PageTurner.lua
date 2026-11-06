-- PageTurner.lua
-- Vanilla WoW 1.12.1 compatible
-- Scroll DOWN = Next page
-- Scroll UP   = Previous page
-- BlizzMo-safe (Ctrl+Scroll untouched)

local hookStates = {}

-- =========================
-- Utility
-- =========================

local function HookMouseWheel(frame, handler)
    if not frame or not handler then return end
    if not frame.EnableMouseWheel then return end

    local state = hookStates[frame]
    if not state then
        state = {}
        hookStates[frame] = state
    end

    state.handler = handler
    frame:EnableMouseWheel(true)

    if not state.wrapper then
        state.wrapper = function()
            -- Prevent wrapper cycles when multiple addons re-hook OnMouseWheel.
            if state.running then return end
            state.running = true

            local ok, err = pcall(function()
                -- Allow BlizzMo scaling
                if IsControlKeyDown() then
                    if state.original and state.original ~= state.wrapper then
                        state.original()
                    end
                    return
                end

                -- PageTurner logic
                if state.handler and state.handler() then
                    return
                end

                -- Fallback
                if state.original and state.original ~= state.wrapper then
                    state.original()
                end
            end)

            state.running = false
            if not ok then
                error(err)
            end
        end
    end

    local current = frame:GetScript("OnMouseWheel")
    if current ~= state.wrapper then
        state.original = current
        frame:SetScript("OnMouseWheel", state.wrapper)
    end
end

local function ClickIfEnabled(button)
    if button and button:IsShown() and button:IsEnabled() then
        button:Click()
        return true
    end
end

local function HandlePagedButtons(nextButton, prevButton)
    local delta = arg1
    if not delta or delta == 0 then return end
    if delta < 0 then
        return ClickIfEnabled(nextButton)
    end
    return ClickIfEnabled(prevButton)
end

-- =========================
-- Handlers
-- =========================
-- arg1 < 0  → scroll DOWN  → NEXT page
-- arg1 > 0  → scroll UP    → PREV page

local function MerchantHandler()
    return HandlePagedButtons(MerchantNextPageButton, MerchantPrevPageButton)
end

local function MailHandler()
    return HandlePagedButtons(InboxNextPageButton, InboxPrevPageButton)
end

local function GossipHandler()
    return HandlePagedButtons(GossipNextPageButton, GossipPrevPageButton)
end

local function QuestHandler()
    return HandlePagedButtons(QuestFrameNextButton, QuestFramePrevButton)
end

local function BookHandler()
    return HandlePagedButtons(BookNextPageButton, BookPrevPageButton)
end

local function SpellBookHandler()
    return HandlePagedButtons(SpellBookNextPageButton, SpellBookPrevPageButton)
end

local function ItemTextHandler()
    return HandlePagedButtons(ItemTextNextPageButton, ItemTextPrevPageButton)
end

-- =========================
-- Hook visible frames
-- =========================

local function TryHookFrames()
    if MerchantFrame and MerchantFrame:IsShown() then
        HookMouseWheel(MerchantFrame, MerchantHandler)
    end

    if MailFrame and MailFrame:IsShown() then
        HookMouseWheel(MailFrame, MailHandler)
    end

    if GossipFrame and GossipFrame:IsShown() then
        HookMouseWheel(GossipFrame, GossipHandler)
    end

    if QuestFrame and QuestFrame:IsShown() then
        HookMouseWheel(QuestFrame, QuestHandler)
    end

    if BookFrame and BookFrame:IsShown() then
        HookMouseWheel(BookFrame, BookHandler)
    end

    -- ✅ Spellbook explicitly enabled
    if SpellBookFrame and SpellBookFrame:IsShown() then
        HookMouseWheel(SpellBookFrame, SpellBookHandler)
    end

    if ItemTextFrame and ItemTextFrame:IsShown() then
        HookMouseWheel(ItemTextFrame, ItemTextHandler)
    end
end

-- =========================
-- Events
-- =========================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("ITEM_TEXT_BEGIN")
f:RegisterEvent("ITEM_TEXT_READY")

f:SetScript("OnEvent", function()
    TryHookFrames()
end)

local elapsed = 0
f:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed < 0.5 then return end
    elapsed = 0
    TryHookFrames()
end)
