-- Create main addon frame
local QuickAssist = CreateFrame("Frame", "QuickAssistAddon")
QuickAssist:RegisterEvent("VARIABLES_LOADED")

-- Variables
QuickAssist.targetName = nil

-- Initialize DB immediately
QuickAssistDB = QuickAssistDB or {}

-- print("QuickAssist: Addon loaded")

-- Slash commands
SLASH_QUICKASSIST1 = "/qa"
SLASH_QUICKASSIST2 = "/quickassist"

-- Save variables between sessions
function QuickAssist_OnLoad()
--     print("QuickAssist: OnLoad called")

    -- Ensure DB exists
    QuickAssistDB = QuickAssistDB or {}
    QuickAssistDB.targetName = QuickAssistDB.targetName or nil

    QuickAssist.targetName = QuickAssistDB.targetName
--     print("QuickAssist: Local targetName set to:", tostring(QuickAssist.targetName))
end

-- Event handler
QuickAssist:SetScript("OnEvent", function(self, event)
--     print("QuickAssist: Event fired:", event)
    if event == "VARIABLES_LOADED" then
        QuickAssist_OnLoad()
    end
end)

-- Function to set target
function QuickAssist:SetTarget(name)
--     print("QuickAssist: SetTarget called with name:", tostring(name))

    -- Ensure DB exists before setting
    QuickAssistDB = QuickAssistDB or {}

    self.targetName = name
    QuickAssistDB.targetName = name

    if name then
        DEFAULT_CHAT_FRAME:AddMessage("QuickAssist: Target set to " .. name, 1, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("QuickAssist: Target cleared", 1, 1, 0)
    end
end

-- Function to assist target
function QuickAssist:AssistTarget()
    if self.targetName then
        TargetByName(self.targetName)
        AssistUnit("target")
    else
        -- If no "assist" target is set, assist current target
        if UnitExists("target") then
            AssistUnit("target")
        else
            DEFAULT_CHAT_FRAME:AddMessage("QuickAssist: No assist target set and no target selected", 1, 0, 0)
        end
    end
end

function QuickAssist:SelectTarget()
    if self.targetName then
        TargetByName(self.targetName)
    else
        DEFAULT_CHAT_FRAME:AddMessage("QuickAssist: No assist target set", 1, 0, 0)
    end
end

-- Slash command handler
function SlashCmdList.QUICKASSIST(msg)
    if msg == "clear" then
        QuickAssist:SetTarget(nil)
    else
        DEFAULT_CHAT_FRAME:AddMessage("QuickAssist commands:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/qa clear - Clear current assist target", 1, 1, 0)
        -- Show current target with green color
        local targetText = QuickAssist.targetName and ("|cFF00FF00" .. QuickAssist.targetName .. "|r") or "None"
        DEFAULT_CHAT_FRAME:AddMessage("Current Assist Target: " .. targetText, 1, 1, 0)
    end
end

-- Hook the UnitPopup_OnClick function
local original_UnitPopup_OnClick = UnitPopup_OnClick
function UnitPopup_OnClick()
    if this and this.value == "SET_ASSIST_TARGET" then
        local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU)
        if dropdownFrame then
            local unit = dropdownFrame.unit
            if unit then
                local name = UnitName(unit)
                if name then
                    QuickAssist:SetTarget(name)
                end
            end
        end
        PlaySound("UChatScrollButton")
        CloseDropDownMenus()

    elseif this and this.value == "CLEAR_ASSIST_TARGET" then
        QuickAssist:SetTarget(nil)
    else
        original_UnitPopup_OnClick()
    end
end

-- Add option to UnitPopupMenus
UnitPopupButtons["SET_ASSIST_TARGET"] = { text = "Set as Assist Target", dist = 0 }
UnitPopupButtons["CLEAR_ASSIST_TARGET"] = { text = "Clear Assist Target", dist = 0 }

-- Make sure menus are defined before adding our option
if not UnitPopupMenus["SELF"] then UnitPopupMenus["SELF"] = {} end
if not UnitPopupMenus["PARTY"] then UnitPopupMenus["PARTY"] = {} end
if not UnitPopupMenus["PLAYER"] then UnitPopupMenus["PLAYER"] = {} end
if not UnitPopupMenus["RAID"] then UnitPopupMenus["RAID"] = {} end

-- Add our option to various menus
table.insert(UnitPopupMenus["SELF"], "SET_ASSIST_TARGET")
table.insert(UnitPopupMenus["SELF"], "CLEAR_ASSIST_TARGET")

table.insert(UnitPopupMenus["PARTY"], "SET_ASSIST_TARGET")
table.insert(UnitPopupMenus["PLAYER"], "SET_ASSIST_TARGET")
table.insert(UnitPopupMenus["RAID"], "SET_ASSIST_TARGET")

-- Binding functions
BINDING_HEADER_QUICKASSIST = "QuickAssist"
BINDING_NAME_QUICKASSIST = "Assist Target"
BINDING_NAME_SELECTTARGET = "Select Assist Target"
BINDING_NAME_CLEARTARGET = "Clear Assist Target"
BINDING_NAME_SETTARGET = "Set as Assist Target"

function QAAssistBinding()
    QuickAssist:AssistTarget()
end

function QASelectTargetBinding()
    QuickAssist:SelectTarget()
end

function QAClearTargetBinding()
    QuickAssist:SetTarget(nil)
end

function QASetTargetBinding()
    if UnitExists("target") then
        QuickAssist:SetTarget(UnitName("target"))
    end
end
