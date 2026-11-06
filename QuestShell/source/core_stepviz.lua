-- =========================
-- QuestShell core_stepviz.lua
-- Step type registry + unified visual row builder for Tracker + Steps UIs
-- Vanilla/Turtle (Lua 5.0) safe
-- =========================

-- Public:
--   QS_RegisterStepType(name, spec)     -- register/override a step type
--   QS_BuildVisualRows(step, fallbackTitle, forceComplete) -> rows[]
--   QS_StepIcon(kind)                   -- helper to get common icons ("talk","accept","turnin","kill","loot","other","run","use","hearth")

-- Row shape expected by UIs:
--   { bullet = boolean, icon = texturePathOrNil, text = "string", done = boolean? }

-- Notes:
--   - Keep ALL UI-specific logic (icons, bullet vs no-bullet, formatting) here.
--   - Both ui_tracker.lua and ui_steps.lua just call QS_BuildVisualRows(...) now.

local TEX = {
  talk   = "Interface\\GossipFrame\\GossipGossipIcon",
  accept = "Interface\\GossipFrame\\AvailableQuestIcon",
  turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  kill   = "Interface\\Icons\\Ability_DualWield",
  loot   = "Interface\\Icons\\INV_Misc_Bag_08",
  other  = "Interface\\Icons\\INV_Misc_Note_01",
  run    = "Interface\\Icons\\Ability_Rogue_Sprint",
  use    = "Interface\\Icons\\INV_Misc_Gear_02",
  hearth = "Interface\\Icons\\INV_Misc_Rune_01",
}

function QS_StepIcon(kind)
    return TEX[string.lower(kind or "") or ""] or TEX.other
end

local REG = {}

function QS_RegisterStepType(name, spec)
    if not name or not spec then return end
    REG[string.upper(name)] = spec
end

local function _npcName(npc)
    if type(npc) == "table" and npc.name and npc.name ~= "" then return npc.name end
    if type(npc) == "string" and npc ~= "" then return npc end
    return "the quest giver"
end

-- Default COMPLETE-like builder that shows a note + objective rows
local function _build_completeish(step, fallbackTitle, forceComplete)
    local rows, c = {}, 0
    local note = (step and step.note) or (fallbackTitle or "")
    c=c+1; rows[c] = { bullet=false, icon=nil, text=note }

    local orows = QS_BuildObjectiveRows and QS_BuildObjectiveRows(step, forceComplete) or {}
    local j = 1
    while orows[j] do
        local R = orows[j]
        local kind = R.kind or "other"
        local icon = (kind=="kill" and TEX.kill) or (kind=="loot" and TEX.loot) or TEX.other
        c=c+1; rows[c] = { bullet=true, icon=icon, text=(R.text or ""), done=(R.done and true or false) }
        j = j + 1
    end
    return rows
end

-- ------------------ Built-in step types ------------------

-- ACCEPT
QS_RegisterStepType("ACCEPT", {
    build = function(step, fallbackTitle, forceComplete)
        local rows, c = {}, 0
        local who = _npcName(step and step.npc)
        c=c+1; rows[c] = { bullet=false, icon=TEX.talk,   text=("Talk to "..who) }
        c=c+1; rows[c] = { bullet=false, icon=TEX.accept, text=(step and step.title) or "" }
        return rows
    end
})

-- TURNIN
QS_RegisterStepType("TURNIN", {
    build = function(step, fallbackTitle, forceComplete)
        local rows, c = {}, 0
        local who = _npcName(step and step.npc)
        c=c+1; rows[c] = { bullet=false, icon=TEX.talk,   text=("Talk to "..who) }
        c=c+1; rows[c] = { bullet=false, icon=TEX.turnin, text=(step and step.title) or "" }
        return rows
    end
})

-- TRAVEL
QS_RegisterStepType("TRAVEL", {
    build = function(step, fallbackTitle, forceComplete)
        local rows, c = {}, 0
        local note = (step and step.note) or "Travel to the marked location."
        local where = ""
        local cmeta = step and step.coords or {}
        if cmeta and cmeta.x and cmeta.y then
            local z = cmeta.map or ""
            local zx = ""
            if z and z ~= "" then zx = " "..z end
            where = string.format("(%.1f, %.1f%s)", cmeta.x, cmeta.y, zx)
        end
        c=c+1; rows[c] = { bullet=false, icon=TEX.run, text=note }
        if where ~= "" then c=c+1; rows[c] = { bullet=false, icon=nil, text=where } end
        return rows
    end
})

-- USE_ITEM
QS_RegisterStepType("USE_ITEM", {
    build = function(step, fallbackTitle, forceComplete)
        local nameTxt = step and (step.itemName or (step.itemId and ("Item ID "..tostring(step.itemId)) or "item"))
        local tar = (step and step.npc and step.npc.name) and (" with "..step.npc.name.." selected") or ""
        local line = "Use: "..(nameTxt or "item")..tar
        return { { bullet=false, icon=TEX.use, text=line } }
    end
})

-- COMPLETE (generic objectives/note)
QS_RegisterStepType("COMPLETE", {
    build = _build_completeish
})

-- Default fallback
QS_RegisterStepType("OTHER", {
    build = _build_completeish
})

-- Public builder used by both UIs
function QS_BuildVisualRows(step, fallbackTitle, forceComplete)
    local stype = string.upper(step and step.type or "OTHER")
    local spec = REG[stype] or REG["OTHER"]
    if spec and spec.build then
        return spec.build(step, fallbackTitle, forceComplete)
    end
    return _build_completeish(step, fallbackTitle, forceComplete)
end


-- SET_HEARTH
QS_RegisterStepType("SET_HEARTH", {
    build = function(step, fallbackTitle, forceComplete)
        local who = (step and step.npc and step.npc.name) or "the innkeeper"
        local line = "Set your hearthstone at "..who
        return { { bullet=false, icon=QS_StepIcon("hearth"), text=line } }
    end
})
