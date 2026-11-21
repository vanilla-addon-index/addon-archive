---
--- Replay\Begin.lua - [Atlas-CFM split] first file of Atlas-CFM_Core.
---
--- Atlas-CFM_Core is LoadOnDemand, so it is loaded long after ADDON_LOADED
--- ("Atlas-CFM"), VARIABLES_LOADED, PLAYER_LOGIN and PLAYER_ENTERING_WORLD have
--- fired. The upstream code initialises itself from those events. While this
--- addon's files run, CreateFrame is wrapped so that every frame created here
--- records which events it registers (and unregisters). After loading, the stub
--- (Atlas-CFM\Stub\Loader.lua) replays the startup events to exactly those
--- frames, in the original order, then removes the per-frame wrappers.
--- Replay\End.lua restores the original CreateFrame.
---
--- @compatible World of Warcraft 1.12 (Lua 5.0)
---

local _G = getfenv()
local AtlasCFM = _G.AtlasCFM

local R = {
    origCreateFrame = CreateFrame,
    list = {},     -- records in registration order: { frame = f, events = { [event] = true } }
    byFrame = {},
}
AtlasCFM._Replay = R

local function record(frame)
    local rec = R.byFrame[frame]
    if not rec then
        rec = { frame = frame, events = {} }
        R.byFrame[frame] = rec
        table.insert(R.list, rec)
    end
    return rec
end

local function track(frame)
    if type(frame) ~= "table" then return frame end
    local register = frame.RegisterEvent
    local unregister = frame.UnregisterEvent
    local unregisterAll = frame.UnregisterAllEvents
    if not register then return frame end

    frame.RegisterEvent = function(self, ev)
        record(self).events[ev] = true
        return register(self, ev)
    end
    frame.UnregisterEvent = function(self, ev)
        local rec = R.byFrame[self]
        if rec then rec.events[ev] = nil end
        return unregister(self, ev)
    end
    frame.UnregisterAllEvents = function(self)
        local rec = R.byFrame[self]
        if rec then rec.events = {} end
        return unregisterAll(self)
    end
    return frame
end

-- Lua 5.0 varargs: keep the caller's exact argument count (arg.n).
CreateFrame = function(...)
    return track(R.origCreateFrame(unpack(arg)))
end
