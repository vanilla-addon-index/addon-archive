-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

function pfUI.lazyres:LoadGui()
    if not pfUI.gui then return end

    local function CreateSlashCmdLine(parent, index, cmd, description)
        parent.cmds = parent.cmds or {}
        if parent.cmds[index] then return end
        parent.cmds[index] = {}
        parent.cmds[index].cmd = parent:CreateFontString("Status", "LOW", "GameFontWhite")
        parent.cmds[index].cmd:SetFont(pfUI.font_default, C.global.font_size)
        parent.cmds[index].cmd:SetText("|cff33ffcc" .. cmd .. "|r")
        parent.cmds[index].cmd:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", - (parent:GetWidth() * 0.8), - (tonumber(C.global.font_size) * 2) * index)

        if description and description ~= "" then
            parent.cmds[index].desc = parent:CreateFontString("Status", "LOW", "GameFontWhite")
            parent.cmds[index].desc:SetFont(pfUI.font_default, C.global.font_size)
            parent.cmds[index].desc:SetText(" - " .. description)
            parent.cmds[index].desc:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", (parent:GetWidth() * 0.2), - (tonumber(C.global.font_size) * 2) * index)
        end

        parent:GetParent().objectCount = parent:GetParent().objectCount + 1
    end

    local CreateConfig = pfUI.gui.CreateConfig
    local CreateGUIEntry = pfUI.gui.CreateGUIEntry
    local Ulazyres = pfUI.gui.UpdaterFunctions["lazyres"]

    CreateGUIEntry(T["Thirdparty"], GetAddOnMetadata("pfUI-lazyres", "X-LocalName"), function()
        CreateConfig(Ulazyres, T["Show Notifcations"], C.lazyres, "notification", "checkbox")
        CreateConfig(Ulazyres, T["Show Debug Messages"], C.lazyres, "debug", "checkbox")

        local slash_header = CreateConfig(nil, T["Slash commands"], nil, nil, "header")
        CreateSlashCmdLine(slash_header, 1, "/pflr", "Run LazyRes")

        CreateConfig(nil, T["Version"] .. ": " .. GetAddOnMetadata("pfUI-lazyres", "Version"), nil, nil, "header")
        CreateConfig(Ulazyres, T["Website"], nil, nil, "button", function()
            pfUI.chat.urlcopy.CopyText("https://github.com/liiora/pfUI-lazyres")
        end)
    end)
end

pfUI.lazyres:LoadGui()
