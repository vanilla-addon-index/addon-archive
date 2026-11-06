-- BulwarkFrame - main.lua
-- Load order tail: wires the slash commands and starts the UI once the player is in the world.
-- WoW-API file (parse-checked only).

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffBulwarkFrame|r " .. s) end

local loader = CreateFrame("Frame", "BulwarkFrameLoader")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    BF.ensureDefaults()
    BF.InitUI()
    BF.UpdateMinimapButton()
    if not BF.envOk then
        msg(BulwarkFrameEnv.MESSAGE)
    end
end)

SLASH_BULWARKFRAME1 = "/bulwark"
SLASH_BULWARKFRAME2 = "/bf"
SlashCmdList["BULWARKFRAME"] = function(input)
    local cmd = string.lower(input or "")
    -- No string.match / no ':' string methods -- Lua 5.0.
    --
    -- Set by every branch that writes BulwarkFrameDB. The options panel is built once and its
    -- widgets then hold their own state, so a slash command that changes a setting behind an open
    -- panel left every checkbox, slider and cycle button showing the pre-command values -- and the
    -- first nudge of a stale slider writes the discarded value straight back over the change. The
    -- panel's own Reset button already calls BF.RefreshOptions for exactly this reason; collecting
    -- it here gives the slash side the same treatment, and keeps a future command from silently
    -- drifting out of sync again.
    local dirty = false
    if cmd == "" or cmd == "options" or cmd == "config" then
        BF.ToggleOptions()
    elseif cmd == "demo" then
        -- Read before the toggle: BF.ToggleDemo clears the manual hide so the frame it promises
        -- actually appears, and that is worth saying rather than leaving the user to wonder why
        -- an unrelated setting moved.
        local wasHidden = BulwarkFrameDB.hidden and true or false
        local on = BF.ToggleDemo()
        if on and wasHidden then
            msg("demo on (manual hide cleared)")
        else
            msg("demo " .. (on and "on" or "off"))
        end
        dirty = true
    elseif cmd == "probe" then
        BF.RunProbe()
    elseif cmd == "lock" then
        BulwarkFrameDB.locked = not BulwarkFrameDB.locked
        BF.ApplyLayout()
        msg(BulwarkFrameDB.locked and "frame locked" or "frame unlocked")
        dirty = true
    elseif cmd == "reset" then
        BF.resetConfig()
        BF.ApplyLayout()
        BF.RequestUpdate()
        BF.UpdateMinimapButton()
        msg("settings reset to defaults")
        dirty = true
    elseif cmd == "show" then
        -- All THREE suppressors, not just the two automatic ones. The manual hide (minimap
        -- right-click) is a SavedVariable and overrides both of them in RequestUpdate, so leaving
        -- it set meant '/bulwark show' reported success while the frame stayed off screen -- and
        -- no other command except a full reset could clear it.
        BulwarkFrameDB.hidden = false
        BulwarkFrameDB.hideWhenInactive = false
        BulwarkFrameDB.hideOutOfCombat = false
        BF.RequestUpdate()
        msg("frame pinned visible (manual hide, hide-when-idle and combat-only turned off)")
        dirty = true
    else
        msg("commands: options | demo | probe | lock | show | reset")
    end
    -- Safe unconditionally: the refresher list is empty until the panel has been built, so this is
    -- a no-op for anyone who never opened it.
    if dirty and BF.RefreshOptions then BF.RefreshOptions() end
end
