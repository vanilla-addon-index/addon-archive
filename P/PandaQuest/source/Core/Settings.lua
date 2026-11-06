--[[
PandaQuest / Core/Settings.lua

The options page, and which window draws it.

Two hosts, ONE builder. If pandaUI is installed, PandaQuest registers its page
with pandaUI's settings window and the player finds it in the same place as
every other pandaUI option. If it is not, the pages go to the shared Panda
settings window (Libs/PandaSettings): one window drawn like pandaUI's, one
panda button on the minimap, shared with every other Panda addon installed
(PandaMap). Both hosts take the same registration calls and hand the SAME
builder a content frame. There is no second layout to keep in step, and
neither addon depends on the other:

  * pandaUI contains no reference to PandaQuest of any kind. Its settings API
    is push-only -- U.RegisterSettingsTab stores an id, a label and a build
    function and calls it later -- so integrating costs pandaUI nothing and
    needs no change there.
  * PandaQuest declares no dependency on pandaUI, calls into it only through
    functions it has checked for by type, and falls back to its own window at
    every step where the integration could fail.

Detection is a POLL, not a load-order assumption or an event:
  * PandaQuest.toc declares no dependency, and the client's TOC dependency
    fields have no record in the compatibility database at all -- so nothing
    establishes that pandaUI's files run before this one.
  * IsAddOnLoaded is DOCUMENTED_NOT_RUNTIME_VERIFIED here, and in any case it
    answers "the files were loaded", not "the settings API exists". The page is
    registered against the API it actually needs, found by type check.
  * ADDON_LOADED has no probed record on this client either, so no event may be
    the mechanism (Core/Driver.lua's rule).

The host is decided ONCE, within a bounded window after the player is in the
world, and never changes afterwards. A host that could flip mid-session would
mean a page whose regions are parented to a window that is no longer the one on
screen.
]]

local PQ = PandaQuest
local Client = PQ.Client
local Settings = PQ:NewModule("Settings")

-- The id pandaUI files the page under. Checked against pandaUI's own ids
-- ("general", "unitframes", "petbar", "actionbars.*") so registration cannot
-- collide with a page it already owns.
local TAB_ID = "pandaquest"
local TAB_LABEL = "PandaQuest"
local SETTINGS_LOGO_TEXTURE =
    "Interface\\AddOns\\pandaQuest\\media\\Textures\\Settings\\PQ_logo"
local SETTINGS_MASCOT_TEXTURE =
    "Interface\\AddOns\\pandaQuest\\media\\Textures\\Settings\\panda-quest"
-- The submenu's pages, one per section of the page. Under a settings group
-- TAB_ID names the group, and these name the rows inside it.
local GENERAL_PAGE_ID = TAB_ID .. ".general"
local HUD_PAGE_ID = TAB_ID .. ".hud"
local DIALOGUE_PAGE_ID = TAB_ID .. ".dialogue"
local MOBS_PAGE_ID = TAB_ID .. ".mobs"
local SERVER_PAGE_ID = TAB_ID .. ".server"
local HUD_MARKER_SETTINGS_VISIBLE = PQ:IsFeatureEnabled("hudWorldMarker")
    or Client.HasCameraProjection()

-- The page's own first line: "Panda Quest" in the addon's two-tone wordmark,
-- with the running version after it. The split is the one the TOC Title already
-- uses -- "Panda" white, "Quest" in the shared accent -- so the options page
-- names the addon the way the addon list does. The host's menu row stays the
-- plain TAB_LABEL because it draws that in a sidebar of its own rows; this
-- wordmark is the page title above the page.
--
-- Inline colour escapes rather than SetTextColor, because one region has to
-- carry three colours where a heading region has one. Every span is closed, so
-- nothing runs on into the heading's own accent colour -- including the
-- version, kept grey so it reads as a subscript of the name rather than part
-- of it.
--
-- Built on call, not at file scope: a file-scope copy would freeze a version
-- read before Core/Namespace.lua had necessarily run. PQ.version is the single
-- place the number is written down in Lua.
local function PageTitle()
    return "|cffffffffPanda |cff" .. PQ.colors.accentHex .. "Quest|r"
        .. " |cff888888v" .. tostring(PQ.version) .. "|r"
end

-- The art of the shared settings window this addon ships. Registered with
-- the version of that copy, so the window reads the art of the copy it runs.
local SHARED_MEDIA = "Interface\\AddOns\\pandaQuest\\Libs\\PandaSettings\\Media\\"
do
    local shared = Client.GetNamedObject("PandaSettings")
    if type(shared) == "table" and type(shared.AddMediaRoot) == "function" then
        shared.AddMediaRoot(SHARED_MEDIA, shared.lastLoadedMinor)
    end
end

-- pandaUI's settings page width (U.SETTINGS_PAGE_WIDTH), registered as the
-- page's pageWidth so pandaUI draws it unscaled, at the game's settings text
-- size; a wider page was shrunk to fit. The shared window uses it too.
local CONTENT_WIDTH = 460
local CONTENT_HEIGHT = 428
-- Text stops short of the content edge so future copy and localization cannot
-- escape the panel, the same margin pandaUI keeps on its own settings text.
local TEXT_WIDTH = CONTENT_WIDTH - 12

local HOST_POLL_INTERVAL = 0.5
-- How long to keep looking for pandaUI before settling on the shared window.
-- Generous on purpose: this is a once-per-session decision and the job costs
-- one global read every half second until it is made.
local HOST_POLL_SECONDS = 15

-- nil while undecided, then "pandaui" or "shared". "shared" is taken at once
-- when pandaUI is absent, so the panda minimap button is there straight
-- away; a pandaUI found later in the poll still takes the pages over.
Settings.host = nil
Settings.hostWaited = 0
Settings.opens = 0
Settings.liveSliders = {}
Settings.activePageTab = "general"
Settings.mobSearchQuery = ""
Settings.mobSearchPage = 1

local function Config()
    return PQ:GetModule("Config")
end

local function Setting(key)
    local config = Config()
    if not config then
        return nil
    end
    return config:Get(key)
end

local function Store(key, value)
    local config = Config()
    if config then
        config:Set(key, value)
    end
end

-- pandaUI's namespace, but only if it carries the one function this needs.
-- Deliberately NOT IsAddOnLoaded: a loaded addon whose settings module failed
-- would pass that test and then refuse the page.
local function PandaUI()
    local host = Client.GetNamedObject("PandaUI")
    if not host or type(host.RegisterSettingsTab) ~= "function" then
        return nil
    end
    return host
end

-- The shared Panda settings window (Libs/PandaSettings), only if it can host.
local function SharedHost()
    local host = Client.GetNamedObject("PandaSettings")
    if type(host) ~= "table" or type(host.RegisterSettingsTab) ~= "function" then
        return nil
    end
    return host
end

-- Whichever window is hosting the page, or nil while undecided.
local function Host()
    if Settings.host == "pandaui" then
        return PandaUI()
    elseif Settings.host == "shared" then
        return SharedHost()
    end
    return nil
end

-- One of the host's settings components (CreateCheckbox, CreateRadioGroup,
-- CreateSlider, CreateDropdown), or nil. Both hosts draw them in pandaUI's
-- Game Settings style, so using them is what makes this page's controls match
-- every other settings page there.
local function HostComponent(name)
    local host = Host()
    if host and type(host[name]) == "function" then
        return host[name]
    end
    return nil
end

-- Page layout ---------------------------------------------------------------
--
-- ADDING A CHECKBOX OR RADIO IS TWO LINES, AND NEITHER IS ABOUT THE HOST:
--
--   1. its default in Core/Config.lua
--   2. one `page.Checkbox(...)` call in BuildPage below
--
-- A continuous value uses page.Slider and supplies its live apply callback.
-- There is no offset to recompute, no widget name
-- to invent, no refresh function to extend, and nothing to add for the second
-- window -- pandaUI and the shared Panda window both call this same builder, so
-- an option added here appears in whichever one is hosting the page, this
-- session and every session after.
--
-- The cursor is what buys that. Each Add* call places its region at the running
-- Y, advances it by what the region actually occupies, files the region in the
-- page's widget list (so both hosts show and hide it), and -- for a bound
-- control -- files a sync closure the page's refresh runs on every open (so the
-- control always opens on the stored value, never on a build-time snapshot).

local HEADING_ADVANCE = 22
local BODY_LINE_HEIGHT = 13
local CHECKBOX_ADVANCE = 18
-- A checkbox's label starts this far right of the control's own left edge:
-- the 14px box plus the 6px gap Client.CreateSettingsCheckbox anchors it at.
-- Only the three rank switches need the number -- they are the one row that
-- packs three controls into the width of one, so their labels are measured
-- rather than given the rest of the row.
local CHECKBOX_LABEL_GAP = 20
-- The three rank switches of the rare alert, sharing the page's right-hand
-- column (250..TEXT_WIDTH). 66px each leaves 46px of label, which fits the
-- longest of the four translations (7 letters) without wrapping into the row
-- below.
local RANK_COLUMN = 66
local RANK_LABEL_WIDTH = RANK_COLUMN - CHECKBOX_LABEL_GAP
-- Where the right-hand control of a PAIRED checkbox row starts. One number for
-- every such row on the page, because a second column that begins at a
-- different X on one row reads as a mistake rather than as a column.
local PAIR_COLUMN_RIGHT = 282
local SLIDER_ADVANCE = 58
local RULE_ADVANCE = 16
local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 20
local ROW_GAP = 8
local NOTE_INDENT = 20
-- Width of each option of a radio laid out on one line (page.Radio's
-- inlineWidth): the check, the label gap and a one-word label.
local RADIO_INLINE_WIDTH = 120
local DROPDOWN_WIDTH = 200
local DROPDOWN_HEIGHT = 22
-- Clear space above the first control of a tab that has no heading of its own.
local TAB_TOP_GAP = 10
local INTERNAL_TAB_HEIGHT = 20
-- Tab height, its 2px gap, and a 5px margin under the strip so the first
-- control of either tab does not sit against the row of tabs.
local INTERNAL_TAB_ADVANCE = 27
-- One width per tab, sized for the widest label in the four languages.
local INTERNAL_TAB_WIDTHS = {
    general = 60, hud = 44, dialogue = 91, mobs = 96, server = 58,
}
local INTERNAL_TAB_GAP = 6
local MOB_MIN_ROWS_PER_PAGE = 9
local MOB_ROW_HEIGHT = 20
-- One table, one upvalue: BuildMobSection is near the upvalue limit.
local MOB_FIT = {
    -- Vertical text offset inside a result row. The shared -6 drew the text
    -- ~5px below the stripe's centre on these 20px rows (screenshot,
    -- 2026-10-26).
    textDrop = -1,
    -- pandaUI settles its canvas a tick after the page is shown, so the
    -- height read while building or opening can be stale. The row count is
    -- fitted again this long after each refresh. The old fixed two-row
    -- reserve for that error left about five empty rows under the pager
    -- instead (screenshot, 2026-10-26).
    refitDelay = 0.2,
}
-- Table rows touch, as Forever's own lists do; the stripe separates them.
local MOB_ROW_ADVANCE = MOB_ROW_HEIGHT
-- Space between the last table row and the result counter under it.
local MOB_TABLE_GAP = 4
-- The tracked band and the result table end where the Search button ends
-- (field 296 + gap 10 + button 112), not at the page's full text width: at
-- that width their right edge ran past the host window's page box.
local MOB_LIST_WIDTH = 418
-- The tracked-creature band between the search field and the results: one
-- accent line naming the creature, and the square that stops tracking it, on
-- an outlined panel tinted with the same accent at a tenth of its opacity.
-- Its height is reserved whether or not a creature is tracked, so taking one
-- does not shove the whole result list down a row under the cursor.
local MOB_CLEAR_SIZE = 18
-- Clear space above and below the panel, separating it from the search field
-- and from the first result row.
local MOB_TRACKED_GAP = 5
-- Inside the panel, so its outline does not run against the text or the cross.
local MOB_TRACKED_INSET = 3
-- Left margin for the line inside the panel: the inset plus enough that the
-- glyphs do not sit on the edge.
local MOB_TRACKED_TEXT_INDENT = 6
local MOB_TRACKED_HEIGHT = MOB_CLEAR_SIZE + MOB_TRACKED_INSET * 2
local MOB_TRACKED_ADVANCE = MOB_TRACKED_HEIGHT + MOB_TRACKED_GAP * 2
-- The accent line is drawn from a smaller font than the 18px cross beside it,
-- so its top anchor is nudged down by half the difference to read as centred
-- against it.
local MOB_TRACKED_TEXT_DROP = 3
-- A tenth of the accent, which is a wash rather than a fill: the band has to
-- read as one region behind the line without competing with the accent text
-- drawn on it.
local MOB_TRACKED_FILL_ALPHA = 0.10
local MOB_TRACKED_BORDER_ALPHA = 1.00
local MOB_PAGING_ADVANCE = 26
-- The pager's own row inside that advance.
local MOB_PAGER_HEIGHT = 22
-- The one reserved body line the result/page counter takes above the paging
-- row, matching what page.Body advances for `reservedLines = 1`.
local MOB_STATUS_ADVANCE = BODY_LINE_HEIGHT + 4
local MOB_BOTTOM_MARGIN = 4
local OPTIONAL_STATUS_ADVANCE = 106

-- Average glyph width for the small font, used ONLY when the client will not
-- report a laid-out FontString's height. Deliberately narrow, so the estimate
-- errs towards more lines and controls crowd rather than overlap.
local ESTIMATED_GLYPH_WIDTH = 5.6

local function TextHeight(region, text, width)
    local measured = Client.GetObjectHeight(region)
    if type(measured) == "number" and measured > 0 then
        return measured
    end
    local perLine = math.floor(width / ESTIMATED_GLYPH_WIDTH)
    if perLine < 1 then
        perLine = 1
    end
    local lines = math.ceil(string.len(text or "") / perLine)
    if lines < 1 then
        lines = 1
    end
    return lines * BODY_LINE_HEIGHT
end

-- Widget names are derived from the setting key so a new option cannot collide
-- with an existing one or pick up a hyphen (which this client mangles). Only
-- the first byte is folded, by hand in the ASCII range: string.upper is
-- locale-dependent here and corrupts multi-byte text, and while a config key is
-- always ASCII, the addon does not keep two rules for the same job.
local function WidgetName(key)
    local first = string.byte(key, 1)
    if first and first >= 97 and first <= 122 then
        return "PandaQuestSettings" .. string.char(first - 32) .. string.sub(key, 2)
    end
    return "PandaQuestSettings" .. key
end

-- Shows one page region and every separately-owned part it carries. This is
-- needed both by the hosts and by the page's internal General/Mob
-- Tracking tabs: parent visibility does not reliably reach children here.
local function SetRegionShown(region, shown)
    if not region then
        return
    end
    -- pandaUI's composite controls may own their visibility (a styled slider
    -- keeps its min/max labels hidden, for one); honour that first.
    if type(region.puiSetShown) == "function" then
        region.puiSetShown(shown)
        return
    end
    if region.puiParts then
        local index = 1
        local total = table.getn(region.puiParts)
        while index <= total do
            SetRegionShown(region.puiParts[index], shown)
            index = index + 1
        end
        return
    end
    if shown then
        Client.ShowObject(region)
    else
        Client.HideObject(region)
    end
    if region.label then
        if shown then
            Client.ShowObject(region.label)
        else
            Client.HideObject(region.label)
        end
    end
end

local function NewPage(parent)
    local page = { parent = parent, widgets = {}, syncs = {}, y = 0,
        currentGroup = nil }

    page.Add = function(region)
        if region then
            table.insert(page.widgets, region)
            if page.currentGroup then
                table.insert(page.currentGroup, region)
            end
        end
        return region
    end

    page.Group = function(group)
        page.currentGroup = group
    end

    -- Registers a closure the page runs every time it is opened.
    page.Sync = function(callback)
        if type(callback) == "function" then
            table.insert(page.syncs, callback)
        end
    end

    page.Gap = function(pixels)
        page.y = page.y - (pixels or ROW_GAP)
    end

    -- `marginTop` moves one title down inside its existing reserved band. The
    -- page is already at the fixed height shared by both non-scrolling hosts,
    -- so this creates visual separation without growing the complete page.
    page.Heading = function(text, marginTop)
        local inset = type(marginTop) == "number" and marginTop or 0
        if inset < 0 then
            inset = 0
        elseif inset > HEADING_ADVANCE then
            inset = HEADING_ADVANCE
        end
        local region = page.Add(Client.CreateSettingsHeading(page.parent, text,
            0, page.y - inset))
        page.y = page.y - HEADING_ADVANCE
        return region
    end

    -- `reservedLines`, when given, fixes how much vertical space the line
    -- takes instead of measuring the text placed in it. Needed by any line
    -- whose text is rewritten at runtime (Client.SetSettingsBodyText): the
    -- cursor placed everything below it at build time from the height of the
    -- placeholder, so a longer replacement would otherwise run into the next
    -- control. Reserving the worst case up front is what keeps the layout
    -- honest -- the caller is then responsible for keeping its text inside it.
    page.Body = function(text, indent, reservedLines)
        indent = indent or 0
        local width = TEXT_WIDTH - indent
        local region = page.Add(Client.CreateSettingsBody(page.parent, text,
            indent, page.y, width))
        local height
        if type(reservedLines) == "number" and reservedLines > 0 then
            height = reservedLines * BODY_LINE_HEIGHT
        else
            height = TextHeight(region, text, width)
        end
        page.y = page.y - height - 4
        return region
    end

    page.Rule = function()
        local region = page.Add(Client.CreateSettingsRule(page.parent, 0, page.y, TEXT_WIDTH))
        page.y = page.y - RULE_ADVANCE
        return region
    end

    -- Optional client component status. pandaUI supplies the same public
    -- component used for its Nampower status; other hosts get an
    -- equivalent text fallback so PandaQuest never depends on pandaUI.
    page.OptionalStatus = function(options)
        options = options or {}
        local createStatus = HostComponent("CreateOptionalStatusSection")
        if createStatus then
            local control, refresh = createStatus(page.parent, {
                header = options.header,
                name = options.name,
                note = options.note,
                detectedText = options.detectedText,
                missingText = options.missingText,
                detected = options.detected,
                width = TEXT_WIDTH,
                y = page.y,
            })
            if control then
                page.Add(control)
                page.y = page.y - OPTIONAL_STATUS_ADVANCE
                page.Sync(refresh)
                return control
            end
        end

        page.Heading(options.header or "")
        page.Body(options.name or "")
        local status = page.Body("")
        page.Body(options.note or "", NOTE_INDENT, 2)
        page.Rule()
        local function RefreshStatus()
            local detected, detail = false, nil
            if type(options.detected) == "function" then
                detected, detail = options.detected()
            end
            local text = detected and (options.detectedText or "")
                or (options.missingText or "")
            if detected and detail and detail ~= "" then
                text = text .. " v" .. tostring(detail)
            end
            if detected then
                text = "|cff5cd647" .. text .. "|r"
            else
                text = "|cffe64038" .. text .. "|r"
            end
            Client.SetSettingsBodyText(status, text)
        end
        page.Sync(RefreshStatus)
        return status
    end

    -- One option. `key` is both the stored setting and the source of the widget
    -- name; `note` is the optional grey line under it.
    --
    -- `layout` is the same optional table page.Slider takes, and is there for
    -- the same reason: a control that shares a row with the one before it. The
    -- earlier control passes `advance = 0` so the cursor stays on its line, and
    -- this one is placed at `left` and given the width that is left over. The
    -- fixed 428px content box is what makes it worth having -- a paired option
    -- costs the page nothing vertically. Only pair a NOTELESS checkbox with a
    -- taller control (a slider's 58px band), so no locale's wrapped text can
    -- outgrow the row and run into whatever is drawn below it.
    page.Checkbox = function(key, text, note, layout)
        layout = layout or {}
        local left = type(layout.left) == "number" and layout.left or 0
        local width = type(layout.width) == "number" and layout.width
            or (TEXT_WIDTH - NOTE_INDENT - left)
        local box
        local SyncBox
        local createCheckbox = HostComponent("CreateCheckbox")
        if createCheckbox then
            box = createCheckbox(page.parent, {
                name = WidgetName(key),
                text = text,
                textWidth = width,
                value = Setting(key) and true or false,
                onChange = function(checked)
                    Store(key, checked and true or false)
                    if type(layout.onChange) == "function" then
                        layout.onChange(checked and true or false)
                    end
                    -- Controls that depend on this switch re-read it.
                    page.Refresh()
                end,
            })
            if box then
                box.SetPoint("TOPLEFT", page.parent, "TOPLEFT", left, page.y)
                SyncBox = function()
                    box.SetValue(Setting(key) and true or false)
                end
            end
        end
        if not box then
            box = Client.CreateSettingsCheckbox(page.parent, WidgetName(key), text,
                left, page.y, width,
                function(checked)
                    Store(key, checked)
                    if type(layout.onChange) == "function" then
                        layout.onChange(checked and true or false)
                    end
                    page.Refresh()
                end)
            SyncBox = function()
                Client.SetSettingsCheckbox(box, Setting(key) and true or false)
            end
        end
        page.Add(box)
        if type(layout.advance) == "number" then
            page.y = page.y - layout.advance
            page.Sync(SyncBox)
            return box
        end
        page.y = page.y - CHECKBOX_ADVANCE
        if note then
            page.Body(note, NOTE_INDENT)
        end
        page.y = page.y - ROW_GAP
        page.Sync(SyncBox)
        return box
    end

    -- One setting, several mutually exclusive values, drawn as a titled column
    -- of radio rows. Same contract as page.Checkbox and the same two lines to
    -- add one: a default in Core/Config.lua and one call here.
    --
    -- `options` is an array of { value = ..., label = "...", note = "..." }.
    -- The stored value is compared to `value` by equality, so anything the
    -- config store round-trips (a boolean, a number, a short string) works.
    --
    -- The group is what makes these radios rather than checkboxes: selecting
    -- one clears the others, and only this closure knows who the others are.
    -- Nothing here reads the widgets' own state to decide -- the stored setting
    -- is the single source of truth, on the click and on every page open.
    --
    -- `inlineWidth`, when given, lays the rows side by side, each that wide,
    -- on a single line instead of one line per row. Only for short noteless
    -- labels: a wrapped label or a note would run into its neighbour.
    --
    -- `layout`, optional, is page.Checkbox's: `left` starts the rows at that X
    -- instead of NOTE_INDENT, and a numeric `advance` moves the cursor by
    -- exactly that much instead of the rows plus ROW_GAP -- so an inline
    -- radio can share a row with a checkbox placed before it.
    page.Radio = function(key, title, options, note, inlineWidth, layout)
        if title then
            page.Body(title)
        end
        local total = table.getn(options)
        layout = layout or {}
        local left = type(layout.left) == "number" and layout.left or NOTE_INDENT
        local advance = type(layout.advance) == "number" and layout.advance or nil

        -- pandaUI's shared radio group when it hosts the page. It lays its
        -- rows out itself, so it is used only when no option carries a note
        -- line between rows (true of every radio on the page today).
        local createRadio = HostComponent("CreateRadioGroup")
        local hasNotes = false
        local noteIndex = 1
        while noteIndex <= total do
            if options[noteIndex].note then
                hasNotes = true
            end
            noteIndex = noteIndex + 1
        end
        if createRadio and not hasNotes then
            local items = {}
            local itemIndex = 1
            while itemIndex <= total do
                items[itemIndex] = { value = options[itemIndex].value,
                    text = options[itemIndex].label }
                itemIndex = itemIndex + 1
            end
            local group = createRadio(page.parent, {
                name = WidgetName(key) .. "Option",
                items = items,
                value = Setting(key),
                width = inlineWidth or (TEXT_WIDTH - NOTE_INDENT * 2),
                rowHeight = CHECKBOX_ADVANCE,
                columns = inlineWidth and total or 1,
                columnGap = 0,
                rowGap = 0,
                onChange = function(value)
                    Store(key, value)
                    -- Controls that depend on this choice re-read it.
                    page.Refresh()
                end,
            })
            if group then
                group.SetPoint("TOPLEFT", page.parent, "TOPLEFT", left, page.y)
                page.Add(group)
                if advance then
                    page.y = page.y - advance
                elseif inlineWidth then
                    page.y = page.y - CHECKBOX_ADVANCE
                else
                    page.y = page.y - CHECKBOX_ADVANCE * total
                end
                if note and not advance then
                    page.Body(note, NOTE_INDENT)
                end
                if not advance then page.y = page.y - ROW_GAP end
                page.Sync(function()
                    -- A stored value no option names leaves the group as it is
                    -- rather than writing a choice back for the player.
                    group.SetValue(Setting(key), false)
                end)
                return group
            end
        end

        local buttons = {}

        local function Select(index)
            local optionIndex = 1
            while optionIndex <= total do
                Client.SetSettingsRadio(buttons[optionIndex], optionIndex == index)
                optionIndex = optionIndex + 1
            end
        end

        local index = 1
        while index <= total do
            local option = options[index]
            -- Captured per row: `index` is the loop variable and the closure
            -- below outlives this iteration.
            local rowIndex = index
            local rowValue = option.value
            local rowLeft = left
            local rowWidth = TEXT_WIDTH - NOTE_INDENT * 2
            if inlineWidth then
                rowLeft = left + (index - 1) * inlineWidth
                rowWidth = inlineWidth - CHECKBOX_LABEL_GAP
            end
            local button = Client.CreateSettingsRadio(page.parent,
                WidgetName(key) .. "Option" .. tostring(index),
                option.label, rowLeft, page.y, rowWidth,
                function()
                    Store(key, rowValue)
                    Select(rowIndex)
                    page.Refresh()
                end)
            buttons[index] = button
            page.Add(button)
            if not inlineWidth then
                page.y = page.y - CHECKBOX_ADVANCE
                if option.note then
                    page.Body(option.note, NOTE_INDENT * 2)
                end
            end
            index = index + 1
        end
        if advance then
            page.y = page.y - advance
        else
            if inlineWidth then
                page.y = page.y - CHECKBOX_ADVANCE
            end
            if note then
                page.Body(note, NOTE_INDENT)
            end
            page.y = page.y - ROW_GAP
        end

        page.Sync(function()
            local stored = Setting(key)
            local selected = 0
            local syncIndex = 1
            while syncIndex <= total do
                if options[syncIndex].value == stored then
                    selected = syncIndex
                end
                syncIndex = syncIndex + 1
            end
            -- A stored value no option names -- an older build's setting, or a
            -- hand-edited file -- leaves every row clear rather than picking
            -- one for the player and writing that choice back.
            Select(selected)
        end)
        return buttons
    end

    -- One setting, several mutually exclusive values, as a titled dropdown:
    -- page.Radio's contract (same `options` shape, the stored setting is the
    -- single source of truth) in one row instead of one row per value. pandaUI's
    -- U.CreateDropdown when it hosts the page, Client.CreateSettingsDropdown
    -- otherwise; both hand back SetPoint / SetValue and a puiSetShown.
    page.Dropdown = function(key, title, options, width)
        if title then
            page.Body(title)
        end
        width = width or DROPDOWN_WIDTH
        local items = {}
        local index = 1
        while index <= table.getn(options) do
            items[index] = { value = options[index].value, text = options[index].label }
            index = index + 1
        end
        local function OnChange(value)
            Store(key, value)
            page.Refresh()
        end
        local control
        local createDropdown = HostComponent("CreateDropdown")
        if createDropdown then
            control = createDropdown(page.parent, {
                name = WidgetName(key),
                items = items,
                width = width,
                height = DROPDOWN_HEIGHT,
                value = Setting(key),
                onChange = OnChange,
            })
        end
        if not control then
            control = Client.CreateSettingsDropdown(page.parent, WidgetName(key),
                width, items, OnChange)
        end
        if not control then
            return nil
        end
        control.SetPoint("TOPLEFT", page.parent, "TOPLEFT", NOTE_INDENT, page.y)
        page.Add(control)
        page.y = page.y - DROPDOWN_HEIGHT - ROW_GAP
        page.Sync(function()
            control.SetValue(Setting(key), false)
        end)
        return control
    end

    -- An action rather than a setting: it runs something once and stores
    -- nothing, so unlike Checkbox/Radio/Slider it registers no sync closure
    -- and has no value to open on. `key` still names the widget so the same
    -- collision-free, hyphen-free naming rule applies.
    --
    -- The handler is handed the button back, so an action that wants to report
    -- what it did can relabel itself without the page having to hold a
    -- reference for it.
    page.Button = function(key, text, onClick, width, layout)
        layout = layout or {}
        local left = type(layout.left) == "number" and layout.left or 0
        local height = type(layout.height) == "number" and layout.height or BUTTON_HEIGHT
        local advance = type(layout.advance) == "number" and layout.advance
            or (height + ROW_GAP)
        -- Declared before the creator call so the click closure can capture it
        -- as an upvalue and hand the button to its own handler.
        local button
        button = Client.CreateSettingsButton(page.parent, WidgetName(key),
            text, left, page.y, width or BUTTON_WIDTH, height,
            function()
                if type(onClick) == "function" then
                    onClick(button)
                end
            end)
        if not button then
            return nil
        end
        -- Both hosts paint their own hover glow on the buttons they host.
        button.pandaQuestHostHover = Settings.host ~= nil
        page.Add(button)
        page.y = page.y - advance
        return button
    end

    -- The exact scriptless native EditBox contract established by
    -- widgets.editbox_minimal_search.v1. The field itself owns no scripts;
    -- callers submit through a separate Button.
    page.Input = function(key, left, width, advance)
        local control = Client.CreateSettingsEditBox(page.parent, WidgetName(key),
            left or 0, page.y, width, 25)
        page.Add(control)
        page.y = page.y - (type(advance) == "number" and advance or 29)
        return control
    end

    -- The hosting window's slider component. Client.CreateSettingsSlider, the
    -- imported equivalent in the compatibility layer, is the fallback. All
    -- expose the same current/SetPoint/SetValue surface, so binding and live
    -- application stay host-independent.
    page.Slider = function(key, text, minimum, maximum, step, onLive, layout)
        local host = Host()
        local createSlider = host and type(host.CreateSlider) == "function"
            and host.CreateSlider or Client.CreateSettingsSlider
        if type(createSlider) ~= "function" then
            return nil
        end

        local liveEntry
        local function Apply(value)
            if type(value) ~= "number" then
                return
            end
            if Setting(key) ~= value then
                Store(key, value)
            end
            if liveEntry then
                liveEntry.last = value
            end
            if type(onLive) == "function" then
                onLive(value)
            end
        end

        layout = layout or {}
        local width = type(layout.width) == "number" and layout.width or 260
        local left = type(layout.left) == "number" and layout.left or 0
        local advance = type(layout.advance) == "number" and layout.advance or SLIDER_ADVANCE
        local slider = createSlider(page.parent, {
            name = WidgetName(key),
            text = text,
            width = width,
            min = minimum,
            max = maximum,
            step = step,
            value = Setting(key),
            onChange = Apply,
        })
        if not slider then
            return nil
        end
        slider.SetPoint("TOPLEFT", page.parent, "TOPLEFT", left, page.y - 18)
        page.Add(slider)
        page.y = page.y - advance

        liveEntry = { key = key, control = slider, onLive = onLive,
            last = slider.current }
        -- One binding per setting: a rebuilt slider replaces the one an earlier
        -- build of the same setting left behind, so a stale control is never
        -- read back into the store alongside the live one.
        local existing = table.getn(Settings.liveSliders)
        while existing >= 1 do
            if Settings.liveSliders[existing].key == key then
                table.remove(Settings.liveSliders, existing)
            end
            existing = existing - 1
        end
        table.insert(Settings.liveSliders, liveEntry)
        page.Sync(function()
            local value = Setting(key)
            slider.SetValue(value)
            liveEntry.last = slider.current
        end)
        return slider
    end

    -- Greys out a checkbox whose option does not apply right now. Driven from
    -- a page.Sync closure, so it follows the setting it depends on every time
    -- that setting changes (page.Radio refreshes the page) and on every open.
    page.SetCheckboxEnabled = function(box, enabled)
        if not box then
            return
        end
        if box.puiParts and type(box.SetEnabled) == "function" then
            box.SetEnabled(enabled and true or false)
        else
            Client.SetSettingsCheckboxEnabled(box, enabled)
        end
    end

    page.Refresh = function()
        local index = 1
        local total = table.getn(page.syncs)
        while index <= total do
            page.syncs[index]()
            index = index + 1
        end
    end

    return page
end

-- The page ------------------------------------------------------------------
--
-- The contract is pandaUI's (modules/settings.lua, RegisterSettingsTab):
-- build(parent) returns the array of regions the page owns, and optionally a
-- refresh function that runs every time the page is opened. The shared Panda
-- window honours the same contract, so this builder never learns which host
-- called it -- it is handed a parent frame and anchors everything to that.
--
-- The page is two sections, General and Mob tracking, each built by its own
-- function below. Where they are switched is the host's business: a host
-- without settings groups gets both sections under an internal tab strip;
-- a host sidebar that is a list of pages gets a "PandaQuest" submenu with
-- one page per section and no strip at all.

-- The height a section may fill. A host can hand a builder a panel much
-- taller than the 428px content box; a host that reports less
-- (or nothing) is held to that box.
local function AvailableHeight(parent)
    -- pandaUI's canvas frame is TALLER than the box the player actually sees,
    -- because that window fits its pages by scale. Sizing to the parent there
    -- is what gave this page a scrollbar, so the host is asked for the height
    -- that fits (user request, 2026-09-23: this page must not scroll).
    local host = Host()
    if host and type(host.GetIntegratedSettingsPageHeight) == "function" then
        local ok, visible = pcall(host.GetIntegratedSettingsPageHeight)
        if ok and type(visible) == "number" and visible >= CONTENT_HEIGHT then
            -- Second value: pandaUI's canvas scrolls content past `visible`.
            return visible, true
        end
    end
    local height = Client.GetObjectHeight(parent)
    if type(height) ~= "number" or height < CONTENT_HEIGHT then
        return CONTENT_HEIGHT
    end
    return height
end

-- The General section: every stored option.
-- The caller has already put the cursor where the section starts and filed
-- the widget group its regions go into.
local function BuildGeneralSection(page)
    -- The tracker opacity and rare-alert range sliders share one row. The
    -- three alert ranks and the three tracker filters use the two compact rows
    -- beneath, the ranks packed three-across into one column.
    --
    -- The page is within a PIXEL of the fixed 428px content box both hosts
    -- hand it (the smoke test measures it), and neither host scrolls, so a new
    -- heading plus a row of its own would have pushed its own controls off the
    -- bottom -- silently, which is what the height check exists to prevent. A
    -- The sliders need 52px here and the two checkbox rows need 36px. The world
    -- map heading below is enough separation without another 16px rule, keeping
    -- the complete page inside the fixed content box (guarded below and in smoke).
    --
    -- The alert is three switches, one per rank it can raise -- rares, rare
    -- elites, bosses -- and they sit in the right-hand column directly under
    -- the alert distance slider, so the whole alert reads as one block. There
    -- is no master switch above them and no room for one: unticking all three
    -- IS the alert off, which is exactly what "/pq rare off" writes, so the
    -- row can never show a rank as tracked while something else silences it.
    -- Their labels are single words on purpose -- three controls share the
    -- width one normally takes, and a wrapped label here would run into the
    -- row below.
    --
    -- The sound kit remains on "/pq rare" because it has to be AUDITIONED: an
    -- unknown SoundEntries kit name is silent rather than an error here.
    local rowTop = page.y
    page.Slider("trackerBackgroundOpacity", PQ.L("SETTINGS_TRACKER_OPACITY"), 0, 100, 1,
        function(value)
            local tracker = PQ:GetModule("TrackerFrame")
            if tracker then
                tracker:ApplyBackgroundOpacity(value)
            end
        end, { width = 160, advance = 0 })
    page.y = rowTop
    page.Slider("rareAlertRange", PQ.L("SETTINGS_RARE_ALERT_RANGE"), 20, 500, 1,
        nil, { left = 250, width = 160, advance = 52 })

    page.Checkbox("trackerCurrentZoneOnly", PQ.L("SETTINGS_TRACKER_CURRENT_ZONE"),
        nil, { width = 230, advance = 0 })
    page.Checkbox("rareAlertRares", PQ.L("SETTINGS_RARE_ALERT_RARES"),
        nil, { left = 250, width = RANK_LABEL_WIDTH, advance = 0 })
    page.Checkbox("rareAlertElites", PQ.L("SETTINGS_RARE_ALERT_ELITES"),
        nil, { left = 250 + RANK_COLUMN, width = RANK_LABEL_WIDTH, advance = 0 })
    page.Checkbox("rareAlertBosses", PQ.L("SETTINGS_RARE_ALERT_BOSSES"),
        nil, { left = 250 + RANK_COLUMN * 2,
               width = TEXT_WIDTH - (250 + RANK_COLUMN * 2) - CHECKBOX_LABEL_GAP,
               advance = CHECKBOX_ADVANCE })
    local row2Top = page.y
    page.Checkbox("trackerHideUnstartedQuests", PQ.L("SETTINGS_TRACKER_HIDE_UNSTARTED"),
        nil, { width = 230, advance = 0 })
    page.y = row2Top
    page.Checkbox("trackerProgressBar", PQ.L("SETTINGS_TRACKER_PROGRESS_BAR"),
        nil, { left = 250, width = TEXT_WIDTH - 250, advance = CHECKBOX_ADVANCE })

    page.Heading(PQ.L("SETTINGS_HEADING_WORLD_MAP"), 7)

    -- Two presentations of one scene, each its own switch: dots, areas, both
    -- or neither. Map/WorldMapPins.lua carries both settings into its view
    -- signature, so ticking one repaints the map on the next refresh with
    -- nothing here to notify.
    --
    -- Areas (the default) on the left, Dots on the right, and "Show all
    -- areas" on its own line beneath them, 6px further down so the two rows
    -- read apart. Areas and "Show all areas" sit on the page's left edge like
    -- every other switch, not indented under the title (user request,
    -- 2026-09-27). No notes: the page is a fixed, non-scrolling 428px box.
    page.Body(PQ.L("SETTINGS_MAP_OBJECTIVE_STYLE"))
    local styleWidth = RADIO_INLINE_WIDTH - CHECKBOX_LABEL_GAP
    page.Checkbox("mapObjectiveAreas", PQ.L("SETTINGS_MAP_STYLE_AREAS"), nil,
        { width = styleWidth, advance = 0 })
    page.Checkbox("mapObjectiveDots", PQ.L("SETTINGS_MAP_STYLE_DOTS"), nil,
        { left = RADIO_INLINE_WIDTH, width = styleWidth,
          advance = CHECKBOX_ADVANCE + 6 })
    -- Only means anything with areas drawn, so it is greyed out without them;
    -- page.Checkbox refreshes the page on every click, which re-runs this.
    local showAllAreas = page.Checkbox("mapShowAllAreas",
        PQ.L("SETTINGS_MAP_SHOW_ALL_AREAS"), nil,
        { width = TEXT_WIDTH, advance = CHECKBOX_ADVANCE + ROW_GAP })
    page.Sync(function()
        page.SetCheckboxEnabled(showAllAreas, Setting("mapObjectiveAreas") and true or false)
    end)

    page.Slider("mapObjectiveDotScale", PQ.L("SETTINGS_MAP_DOT_SIZE"), 50, 150, 1,
        function()
            local worldMapPins = PQ:GetModule("WorldMapPins")
            if worldMapPins then
                worldMapPins:ApplyObjectiveDotSize()
            end
        end, { width = 160, advance = 0 })

    page.Slider("minimapObjectiveDotScale", PQ.L("SETTINGS_MINIMAP_DOT_SIZE"), 50, 150, 1,
        function()
            local minimapPins = PQ:GetModule("MinimapPins")
            if minimapPins then
                minimapPins:ApplyObjectiveDotSize()
            end
        end, { left = 250, width = 160 })

    -- Nine noteless switches, paired two to a line down five rows. Every row
    -- is written the same way -- left control with `advance = 0`, right
    -- control with the row's advance -- so the cursor alone decides where each
    -- row sits. No row rewinds page.y: a hand-set cursor is what let two
    -- controls be placed at the same Y and drawn on top of each other.
    --
    -- Both columns are fixed. The left one owns 0..PAIR_COLUMN_RIGHT, which is
    -- what the longest of the four translations needs on one line ("Garder la
    -- fleche du joueur au-dessus des marqueurs"), and the right one starts at
    -- PAIR_COLUMN_RIGHT for every row, so the second column reads as a column.
    -- It is wider than the 250 the rare-alert ranks use above, because that row
    -- packs three controls into one column and this one pairs long labels; the
    -- heading between them separates the two sections.
    --
    -- Notes on this page are kept to one line, and these rows carry none: both
    -- hosts hand the page a fixed 428px box that neither of them scrolls.
    local pairWidth = PAIR_COLUMN_RIGHT - CHECKBOX_LABEL_GAP
    local rightWidth = TEXT_WIDTH - PAIR_COLUMN_RIGHT

    page.Checkbox("mapClusterTooltips", PQ.L("SETTINGS_MAP_CLUSTER"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("navigatorEnabled", PQ.L("SETTINGS_NAVIGATOR"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("translateQuestTitles", PQ.L("SETTINGS_TRANSLATE_QUEST_TITLES"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("showLowLevelQuests", PQ.L("SETTINGS_LOW_LEVEL_QUESTS"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("minimapPinsClampEdge", PQ.L("SETTINGS_MINIMAP_CLAMP"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("announceObjectivesParty", PQ.L("SETTINGS_ANNOUNCE_PARTY"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("minimapPinsBelowArrow", PQ.L("SETTINGS_MINIMAP_ARROW_TOP"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("announceCompletedQuestsOnly", PQ.L("SETTINGS_ANNOUNCE_COMPLETE_ONLY"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("tooltipRespawnTimers", PQ.L("SETTINGS_TOOLTIP_RESPAWN"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("questLogRewards", PQ.L("SETTINGS_QUESTLOG_REWARDS"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("mobNavigatorEnabled", PQ.L("SETTINGS_MOB_NAVIGATOR"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("questRewardItemColors", PQ.L("SETTINGS_REWARD_QUALITY_COLORS"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    page.Checkbox("hideUnlearnedProfessionQuests", PQ.L("SETTINGS_HIDE_PROFESSION_QUESTS"), nil,
        { width = TEXT_WIDTH, advance = CHECKBOX_ADVANCE })
    page.Checkbox("nameplateQuestIcon", PQ.L("SETTINGS_NAMEPLATE_QUEST_ICON"), nil,
        { width = TEXT_WIDTH, advance = CHECKBOX_ADVANCE })
    page.Checkbox("targetQuestIcon", PQ.L("SETTINGS_TARGET_QUEST_ICON"), nil,
        { width = pairWidth, advance = 0 })
    page.Checkbox("questRewardGearAdvisor", PQ.L("SETTINGS_REWARD_GEAR_ADVISOR"), nil,
        { left = PAIR_COLUMN_RIGHT, width = rightWidth, advance = CHECKBOX_ADVANCE })

    -- The one panda button every Panda addon shares; pandaUI has its own.
    if Settings.host == "shared" then
        page.Checkbox("minimapButton", PQ.L("SETTINGS_MINIMAP_BUTTON"), nil,
            { width = TEXT_WIDTH, advance = CHECKBOX_ADVANCE,
              onChange = function(checked)
                  Settings:SetMinimapButtonEnabled(checked)
              end })
    end
end

local function BuildHUDSection(page)
    page.Gap(TAB_TOP_GAP)
    page.OptionalStatus({
        header = PQ.L("SETTINGS_CLASSICAPI_HEADER"),
        name = "ClassicAPI",
        note = PQ.L("SETTINGS_CLASSICAPI_HINT"),
        detectedText = PQ.L("SETTINGS_CLASSICAPI_DETECTED"),
        missingText = PQ.L("SETTINGS_CLASSICAPI_NOT_DETECTED"),
        detected = Client.GetClassicAPIStatus,
    })
    page.OptionalStatus({
        header = PQ.L("SETTINGS_CLASSICAPI_HEADER"),
        name = "PandaTool",
        note = PQ.L("SETTINGS_PANDATOOL_HINT"),
        detectedText = PQ.L("SETTINGS_CLASSICAPI_DETECTED"),
        missingText = PQ.L("SETTINGS_CLASSICAPI_NOT_DETECTED"),
        detected = Client.HasCameraProjection,
    })
    local marker = page.Checkbox("waypointEnabled", PQ.L("SETTINGS_HUD_MARKER"),
        PQ.L("SETTINGS_HUD_MARKER_NOTE"))
    page.Sync(function()
        local detected = Client.GetClassicAPIStatus() or Client.HasCameraProjection()
        page.SetCheckboxEnabled(marker, detected and true or false)
    end)
end

-- The Quest dialogue section: every option of the immersive dialogue, on a
-- page of its own so its controls no longer compete with General's fixed box
-- for a line. The theme is a dropdown: the theme choices as radio rows took a
-- line each, and inline columns overran the page width.
local function BuildDialogueSection(page)
    page.Gap(TAB_TOP_GAP)
    page.Checkbox("immersiveDialogue", PQ.L("SETTINGS_IMMERSIVE_DIALOGUE"))
    page.Checkbox("immersiveDialogueAllNpcs", PQ.L("SETTINGS_IMMERSIVE_DIALOGUE_ALL_NPCS"))
    page.Checkbox("dialogueHideInterface", PQ.L("SETTINGS_DIALOGUE_HIDE_INTERFACE"))
    page.Checkbox("dialogueKeyboard", PQ.L("SETTINGS_DIALOGUE_KEYBOARD"),
        PQ.L("SETTINGS_DIALOGUE_KEYBOARD_NOTE"))
    page.Checkbox("dialogueAutoQuest", PQ.L("SETTINGS_DIALOGUE_AUTO_QUEST"),
        PQ.L("SETTINGS_DIALOGUE_AUTO_QUEST_NOTE"))
    page.Dropdown("dialogueTheme", PQ.L("SETTINGS_DIALOGUE_THEME"), {
        { value = "minimal", label = PQ.L("SETTINGS_DIALOGUE_THEME_MINIMAL") },
        { value = "parchment", label = PQ.L("SETTINGS_DIALOGUE_THEME_PARCHMENT") },
        { value = "alliance", label = PQ.L("SETTINGS_DIALOGUE_THEME_ALLIANCE") },
        { value = "horde", label = PQ.L("SETTINGS_DIALOGUE_THEME_HORDE") },
        { value = "alliance-light", label = PQ.L("SETTINGS_DIALOGUE_THEME_ALLIANCE_LIGHT") },
        { value = "horde-light", label = PQ.L("SETTINGS_DIALOGUE_THEME_HORDE_LIGHT") },
    })
end

-- Downloads this character's complete quest history from Turtle's server.
-- The module owns the job and survives this page being closed; this builder
-- only presents its live state and the saved snapshot's freshness.
local function BuildServerHistorySection(page)
    page.Heading(PQ.L("SETTINGS_SERVER_HEADING"))
    page.Body(PQ.L("SETTINGS_SERVER_INTRO"), 0, 3)
    page.Body(PQ.L("SETTINGS_SERVER_REPLACES"), 0, 2)
    page.Heading(PQ.L("SETTINGS_SERVER_BEFORE"))
    page.Body(PQ.L("SETTINGS_SERVER_INSTRUCTIONS"), 0, 4)
    page.Gap(4)

    local query = PQ:GetModule("ServerQuestQuery")
    local button = page.Button("serverQuestQuery", PQ.L("SERVER_QUERY_BUTTON"),
        function()
            local module = PQ:GetModule("ServerQuestQuery")
            if module then module:Start() end
        end, 220)
    local activity = page.Add(Client.CreateSettingsQueryActivity(page.parent,
        WidgetName("serverQuestActivity"), 0, page.y, TEXT_WIDTH))
    page.y = page.y - 26
    local detail = page.Body(PQ.L("SERVER_QUERY_STATUS_READY"), 0, 2)
    local freshness = page.Body(PQ.L("SERVER_QUERY_NEVER"), 0, 2)

    local function RefreshServerQuery()
        local module = PQ:GetModule("ServerQuestQuery")
        if not module then
            Client.SetSettingsBodyText(detail, PQ.L("SERVER_QUERY_FAILED_HISTORY"))
            return
        end
        Client.SetButtonLabel(button, module:GetButtonText())
        Client.SetButtonEnabled(button, not module.running)
        Client.SetSettingsQueryActivity(activity, module.running,
            module.progress, module.angle)
        Client.SetSettingsBodyText(detail, module:GetDetailText())
        Client.SetSettingsBodyText(freshness, module:GetFreshnessText())
    end

    page.Sync(RefreshServerQuery)
    if query then
        query:SetStatusCallback(RefreshServerQuery)
    end
end

-- The Mob tracking section: the creature search, the tracked-creature band and
-- the paged results. `MobsShown` answers whether this section is the one on
-- screen, which only the caller knows -- on the tabbed page it is the internal
-- tab, as a page of pandaUI's submenu it always is. Returns the refresh
-- closure and the search field, which the caller's sync needs.
local function BuildMobSection(page, MobsShown)
    local parent = page.parent
    local RefreshMobResults

    -- Mob tracking ----------------------------------------------------------
    -- This page intentionally submits through a separate button. The native
    -- EditBox has no handlers at all, exactly matching the focused two-cycle
    -- probe that established focus/type/GetText/ClearFocus as safe here.
    page.Heading(PQ.L("SETTINGS_MOB_HEADING"))
    page.Body(PQ.L("SETTINGS_MOB_DESCRIPTION"), 0, 2)

    local searchRowTop = page.y
    local mobSearchInput = page.Input("mobSearchInput", 0, 296, 0)
    page.y = searchRowTop
    local SubmitMobSearch = function()
        Settings.mobSearchQuery = Client.GetSettingsEditText(mobSearchInput)
        Client.ClearSettingsEditFocus(mobSearchInput)
        Settings.mobSearchPage = 1
        RefreshMobResults()
    end
    page.Button("mobSearchSubmit", PQ.L("SETTINGS_MOB_SEARCH"),
        SubmitMobSearch, 112, { left = 306, height = 25, advance = 31 })
    -- Enter submits the same search as the button, once the client is known to
    -- survive an EditBox that owns a handler at all. Inert until then: the
    -- wrapper attaches nothing and answers false.
    Settings.mobSearchEnterSubmit =
        Client.SetSettingsEditSubmitHandler(mobSearchInput, SubmitMobSearch)

    -- The tracked creature, in its own band between the search field and the
    -- results rather than as a row inside them.
    --
    -- Tracking is single-select, so this band is also the whole of the state:
    -- it names what is tracked right now, and its cross is the way to stop.
    -- Neither depends on finding the creature in the list again -- the search
    -- that put it there may be several pages and one typed word away by the
    -- time the player wants it gone -- and taking another creature rewrites
    -- this line, which is what "tracking another one replaces it" looks like
    -- from the player's side.
    --
    -- Placed BEFORE the row count is computed, so its reserved height is one
    -- fewer result row rather than an overflow off the bottom of the host box.
    local trackedRowTop = page.y
    local accent = PQ.colors.accent
    local trackedPanel = page.Add(Client.CreateSettingsPanel(parent,
        0, page.y - MOB_TRACKED_GAP, MOB_LIST_WIDTH, MOB_TRACKED_HEIGHT,
        accent[1], accent[2], accent[3],
        MOB_TRACKED_FILL_ALPHA, MOB_TRACKED_BORDER_ALPHA))
    local trackedContentTop = page.y - MOB_TRACKED_GAP - MOB_TRACKED_INSET
    local trackedLabel = page.Add(Client.CreateSettingsHeading(parent, "",
        MOB_TRACKED_TEXT_INDENT, trackedContentTop - MOB_TRACKED_TEXT_DROP))
    page.y = trackedContentTop
    -- The quest log's red close button (QuestLogRedButton), not a text "X".
    local trackedClear = page.Add(Client.CreateSettingsCloseButton(parent,
        WidgetName("mobTrackedClear"),
        MOB_LIST_WIDTH - MOB_TRACKED_INSET - MOB_CLEAR_SIZE, page.y,
        MOB_CLEAR_SIZE,
        function()
            local pins = PQ:GetModule("NpcPins")
            local trackedId = pins and pins:GetTrackedMobId()
            if pins and trackedId then
                pins:SetMobTracked(trackedId, false)
                RefreshMobResults()
            end
        end))
    -- Past the cross, past the panel's lower inset, then the gap: the cursor
    -- has to clear the panel itself, not just the control on it.
    page.y = page.y - (MOB_CLEAR_SIZE + MOB_TRACKED_INSET + MOB_TRACKED_GAP)
    -- The cross is a named widget; the line beside it is a FontString, which
    -- has no name on this client. Published so the offline test can read what
    -- the band actually says.
    Settings.mobTrackedLabel = trackedLabel
    Settings.mobTrackedPanel = trackedPanel

    -- The results are a plain table (Client.CreateSettingsListRow): touching
    -- rows, every second one striped, no button chrome per line.
    --
    -- A host can hand this builder a panel much taller than the
    -- 428px content box, and its final height is only known a tick after the
    -- page is shown. So the row count is not fixed here: FitMobRows reads the
    -- host height on every refresh, makes rows on demand, and moves the
    -- counter and pager to sit under the last row in use.
    local listTop = page.y
    local mobGroup = page.currentGroup
    local mobRows = {}
    local mobRowsPerPage = 0
    local resultStatus, pager

    local function FittedRowCount()
        local availableHeight = AvailableHeight(parent)
        Settings.pageAvailableHeight = availableHeight
        local count = math.floor((availableHeight + listTop
            - MOB_TABLE_GAP - MOB_STATUS_ADVANCE - MOB_PAGING_ADVANCE
            - MOB_BOTTOM_MARGIN) / MOB_ROW_ADVANCE)
        if count < MOB_MIN_ROWS_PER_PAGE then
            count = MOB_MIN_ROWS_PER_PAGE
        end
        return count
    end

    local function MakeRow(rowIndex)
        local line = Client.CreateSettingsListRow(parent,
            WidgetName("mobResult" .. tostring(rowIndex)), 0,
            listTop - (rowIndex - 1) * MOB_ROW_ADVANCE,
            MOB_LIST_WIDTH, MOB_ROW_HEIGHT,
            rowIndex - math.floor(rowIndex / 2) * 2 == 0,
            function()
                local row = mobRows[rowIndex]
                local record = row and row.record
                local pins = PQ:GetModule("NpcPins")
                if record and pins then
                    pins:SetMobTracked(record.unitId,
                        not pins:IsMobTracked(record.unitId))
                    RefreshMobResults()
                end
            end, MOB_FIT.textDrop)
        -- A row made after the build still belongs to this section's group,
        -- so the internal tab strip hides it with the rest.
        local saved = page.currentGroup
        page.currentGroup = mobGroup
        page.Add(line)
        page.currentGroup = saved
        mobRows[rowIndex] = { button = line, record = nil }
    end

    -- Returns the page.y just below the pager.
    local function FitMobRows()
        local count = FittedRowCount()
        local made = table.getn(mobRows)
        while made < count do
            made = made + 1
            MakeRow(made)
        end
        mobRowsPerPage = count
        Settings.mobRowsPerPage = count
        local y = listTop - count * MOB_ROW_ADVANCE - MOB_TABLE_GAP
        if resultStatus then
            Client.AnchorObject(resultStatus, "TOPLEFT", parent, "TOPLEFT", 0, y)
        end
        y = y - MOB_STATUS_ADVANCE
        if pager and pager.frame then
            Client.AnchorObject(pager.frame, "TOPLEFT", parent, "TOPLEFT", 0, y)
        end
        return y - MOB_PAGING_ADVANCE
    end

    FitMobRows()
    page.y = listTop - mobRowsPerPage * MOB_ROW_ADVANCE
    page.Gap(MOB_TABLE_GAP)

    -- The result/page counter sits directly above the paging row it describes,
    -- under the results it counts. One reserved line, because its text is
    -- rewritten at runtime and everything below was placed from this height.
    resultStatus = page.Body(PQ.L("SETTINGS_MOB_READY"), 0, 1)

    -- Pagination centred under the table: previous arrow, "page / pages",
    -- next arrow (Client.CreateSettingsPager).
    pager = page.Add(Client.CreateSettingsPager(parent,
        WidgetName("mobPager"), 0, page.y, MOB_LIST_WIDTH, MOB_PAGER_HEIGHT,
        function()
            if Settings.mobSearchPage > 1 then
                Settings.mobSearchPage = Settings.mobSearchPage - 1
                RefreshMobResults()
            end
        end,
        function()
            Settings.mobSearchPage = Settings.mobSearchPage + 1
            RefreshMobResults()
        end))
    page.y = page.y - MOB_PAGING_ADVANCE

    -- One delayed re-fit after a refresh, for pandaUI's late canvas layout.
    -- It runs once and unschedules itself; it refreshes only when the page is
    -- still on screen and the fitted count actually changed.
    local function ScheduleRefit()
        local driver = PQ:GetModule("Driver")
        if not driver then
            return
        end
        driver:Schedule("settings.mobfit", MOB_FIT.refitDelay, function()
            local running = PQ:GetModule("Driver")
            if running then
                running:Unschedule("settings.mobfit")
            end
            if MobsShown() and Client.IsObjectVisible(mobSearchInput)
                and FittedRowCount() ~= mobRowsPerPage then
                RefreshMobResults()
            end
        end)
    end

    -- A creature's name as both surfaces say it: the name, then its level range
    -- when the data has one. `units[id].lvl` is a STRING here and may be a
    -- range, so it is printed rather than compared (docs/WORLD-DATA-NOTES.md).
    --
    -- NPC_DETAIL_LEVEL already carries its own parentheses in all four
    -- languages, so nothing is added around it here: doing that is what drew
    -- "Bayne ((level 10))".
    local function MobDisplayName(record)
        if type(record.level) == "string" and record.level ~= "" then
            return record.name .. " " .. PQ.L("NPC_DETAIL_LEVEL", record.level)
        end
        return record.name
    end

    -- Where to tell the player the tracked creature is.
    --
    -- The zone they are standing in wins when the creature is recorded there,
    -- because then the answer is "here" and that is the most useful thing the
    -- line can say. Otherwise the zone holding the most of its spawns wins.
    -- Only one zone is named: the band is a summary, and the maps are where
    -- every recorded spawn is already drawn.
    local function MobZoneName(database, unitId)
        local zones = database:GetUnitZones(unitId)
        local total = table.getn(zones)
        if total == 0 then
            return nil
        end
        local mapContext = PQ:GetModule("MapContext")
        local playerAreaId = mapContext and mapContext:GetCurrentZoneView()
        local index = 1
        while index <= total do
            if zones[index].areaId == playerAreaId then
                return zones[index].name
            end
            index = index + 1
        end
        return zones[1].name
    end

    RefreshMobResults = function()
        FitMobRows()
        if MobsShown() then
            ScheduleRefit()
        end
        local database = PQ:GetModule("Database")
        local pins = PQ:GetModule("NpcPins")
        local matches = database and database:SearchMobsByName(
            Settings.mobSearchQuery) or {}
        local total = table.getn(matches)
        local pages = math.ceil(total / mobRowsPerPage)
        if pages < 1 then pages = 1 end
        if Settings.mobSearchPage < 1 then
            Settings.mobSearchPage = 1
        elseif Settings.mobSearchPage > pages then
            Settings.mobSearchPage = pages
        end

        -- The band above the results. Shown only while something is tracked,
        -- and only on this tab: ApplyInternalTab shows every mob widget as a
        -- block before calling this, so hiding it again here is what keeps an
        -- empty band off the page.
        local trackedId = pins and pins:GetTrackedMobId()
        local trackedRecord = trackedId and database
            and database:GetMobSearchRecord(trackedId)
        if trackedRecord and MobsShown() then
            local zone = MobZoneName(database, trackedId)
            local banner
            if zone then
                banner = PQ.L("SETTINGS_MOB_TRACKED_ROW_ZONE",
                    MobDisplayName(trackedRecord), zone)
            else
                banner = PQ.L("SETTINGS_MOB_TRACKED_ROW",
                    MobDisplayName(trackedRecord))
            end
            Client.SetSettingsBodyText(trackedLabel, banner)
            SetRegionShown(trackedPanel, true)
            SetRegionShown(trackedLabel, true)
            SetRegionShown(trackedClear, true)
        else
            Client.SetSettingsBodyText(trackedLabel, "")
            SetRegionShown(trackedPanel, false)
            SetRegionShown(trackedLabel, false)
            SetRegionShown(trackedClear, false)
        end

        local trackedCount = pins and pins:GetTrackedMobCount() or 0
        Client.SetSettingsBodyText(resultStatus, PQ.L("SETTINGS_MOB_RESULTS",
            tostring(total), tostring(Settings.mobSearchPage), tostring(pages),
            tostring(trackedCount)))

        local first = (Settings.mobSearchPage - 1) * mobRowsPerPage + 1
        local index = 1
        local made = table.getn(mobRows)
        while index <= made do
            local row = mobRows[index]
            -- Rows past the fitted count stay hidden: the host got shorter.
            local record = index <= mobRowsPerPage
                and matches[first + index - 1] or nil
            row.record = record
            if record then
                local tracked = pins and pins:IsMobTracked(record.unitId)
                local action = PQ.L(tracked and "QUESTLOG_BUTTON_UNTRACK"
                    or "QUESTLOG_BUTTON_TRACK")
                Client.SetSettingsListRow(row.button, MobDisplayName(record),
                    action, tracked)
                if MobsShown() then
                    SetRegionShown(row.button, true)
                end
            else
                Client.SetSettingsListRow(row.button, "", "", false)
                SetRegionShown(row.button, false)
            end
            index = index + 1
        end

        Client.SetSettingsPager(pager, Settings.mobSearchPage, pages)
    end

    return RefreshMobResults, mobSearchInput
end

-- `section` nil builds the whole page, every section under the internal tab
-- strip: a pandaUI without settings groups. A named section builds that
-- section alone with no strip, for a page of the host's submenu, where the
-- sidebar rows are the tabs.
function Settings:BuildPage(parent, section)
    if not parent then
        return {}, nil
    end
    if section == "hud" and not HUD_MARKER_SETTINGS_VISIBLE then
        section = "general"
    end
    if section ~= "general" and section ~= "hud"
        and section ~= "dialogue" and section ~= "mobs"
        and section ~= "server" then
        section = nil
    end

    local page = NewPage(parent)
    -- A whole page replaces the live slider bindings; a section adds to them,
    -- because under the submenu the other section may already be built and
    -- bound, and dropping its sliders would stop them applying live.
    if not section then
        self.liveSliders = {}
    end
    local generalWidgets = {}
    local hudWidgets = {}
    local dialogueWidgets = {}
    local mobWidgets = {}
    local serverWidgets = {}
    local generalTab, hudTab, dialogueTab, mobTab, serverTab
    local RefreshMobResults, mobSearchInput

    -- The page draws no wordmark heading of its own: both hosts already title
    -- it with PageTitle in their page title (user request, 2026-09-23), so a
    -- heading here would show the same line twice.

    local function MobsShown()
        if section then
            return section == "mobs"
        end
        return Settings.activePageTab == "mobs"
    end

    local function ShowGroup(widgets, shown)
        local index = 1
        while index <= table.getn(widgets) do
            SetRegionShown(widgets[index], shown)
            index = index + 1
        end
    end

    local function ApplyInternalTab(tab)
        if (tab == "hud" and not HUD_MARKER_SETTINGS_VISIBLE)
            or (tab ~= "hud" and tab ~= "mobs"
                and tab ~= "dialogue" and tab ~= "server") then
            tab = "general"
        end
        Settings.activePageTab = tab
        ShowGroup(generalWidgets, tab == "general")
        ShowGroup(hudWidgets, tab == "hud")
        ShowGroup(dialogueWidgets, tab == "dialogue")
        ShowGroup(mobWidgets, tab == "mobs")
        ShowGroup(serverWidgets, tab == "server")
        Client.SetSettingsTabSelected(generalTab, tab == "general")
        Client.SetSettingsTabSelected(hudTab, tab == "hud")
        Client.SetSettingsTabSelected(dialogueTab, tab == "dialogue")
        Client.SetSettingsTabSelected(mobTab, tab == "mobs")
        Client.SetSettingsTabSelected(serverTab, tab == "server")
        if tab == "mobs" and type(RefreshMobResults) == "function" then
            RefreshMobResults()
        end
    end

    if not section then
        local tabLeft = 0
        local function AddInternalTab(key, name, label)
            local width = INTERNAL_TAB_WIDTHS[key]
            local tab = page.Add(Client.CreateSettingsTab(parent, WidgetName(name),
                PQ.L(label), tabLeft, page.y, width, INTERNAL_TAB_HEIGHT,
                function() ApplyInternalTab(key) end))
            tabLeft = tabLeft + width + INTERNAL_TAB_GAP
            return tab
        end
        generalTab = AddInternalTab("general", "generalTab", "SETTINGS_TAB_GENERAL")
        if HUD_MARKER_SETTINGS_VISIBLE then
            hudTab = AddInternalTab("hud", "hudTab", "SETTINGS_TAB_HUD")
        end
        dialogueTab = AddInternalTab("dialogue", "dialogueTab", "SETTINGS_TAB_DIALOGUE")
        mobTab = AddInternalTab("mobs", "mobTrackingTab", "SETTINGS_TAB_MOB_TRACKING")
        serverTab = AddInternalTab("server", "serverTab", "SETTINGS_TAB_IMPORT")
        page.y = page.y - INTERNAL_TAB_ADVANCE
    end
    local contentTop = page.y

    local generalHeight = 0
    if not section or section == "general" then
        page.Group(generalWidgets)
        BuildGeneralSection(page)
        generalHeight = -page.y
    end

    local hudHeight = 0
    if HUD_MARKER_SETTINGS_VISIBLE and (not section or section == "hud") then
        page.Group(hudWidgets)
        page.y = contentTop
        BuildHUDSection(page)
        hudHeight = -page.y
    end

    local dialogueHeight = 0
    if not section or section == "dialogue" then
        page.Group(dialogueWidgets)
        page.y = contentTop
        BuildDialogueSection(page)
        dialogueHeight = -page.y
    end

    local mobHeight = 0
    if not section or section == "mobs" then
        page.Group(mobWidgets)
        page.y = contentTop
        RefreshMobResults, mobSearchInput = BuildMobSection(page, MobsShown)
        mobHeight = -page.y
    end

    local serverHeight = 0
    if not section or section == "server" then
        page.Group(serverWidgets)
        page.y = contentTop
        BuildServerHistorySection(page)
        serverHeight = -page.y
    end
    page.Group(nil)

    -- Each open also records which section the player is on, so /pq config
    -- returns to it under either host.
    if section == "general" or section == "hud"
        or section == "dialogue" or section == "server" then
        page.Sync(function()
            Settings.activePageTab = section
        end)
    elseif section == "mobs" then
        page.Sync(function()
            Settings.activePageTab = "mobs"
            Client.SetSettingsEditText(mobSearchInput, Settings.mobSearchQuery)
            RefreshMobResults()
        end)
    else
        page.Sync(function()
            Client.SetSettingsEditText(mobSearchInput, Settings.mobSearchQuery)
            ApplyInternalTab(Settings.activePageTab)
        end)
    end

    -- Both hosts' canvases show a scroll bar, so an overflow there is not cut
    -- off; only a host that reports no page height is a fixed box.
    local availableHeight, hostScrolls = AvailableHeight(parent)
    self.pageHeight = generalHeight
    if hudHeight > self.pageHeight then
        self.pageHeight = hudHeight
    end
    if dialogueHeight > self.pageHeight then
        self.pageHeight = dialogueHeight
    end
    if mobHeight > self.pageHeight then
        self.pageHeight = mobHeight
    end
    if serverHeight > self.pageHeight then
        self.pageHeight = serverHeight
    end
    if not hostScrolls and self.pageHeight > availableHeight then
        PQ:Warn(PQ.L("SETTINGS_WARN_PAGE_TOO_TALL",
            math.floor(self.pageHeight), math.floor(availableHeight)))
    end

    return page.widgets, page.Refresh
end

-- pandaUI updates its slider's `current` value from its own shared driver;
-- the shared window and the compatibility import expose RefreshDrag for the same purpose. Comparing
-- that live display value here makes the setting and tracker texture follow
-- the thumb continuously, while the drag is still in progress.
function Settings:RefreshLiveSliders()
    local index = 1
    local total = table.getn(self.liveSliders)
    while index <= total do
        local entry = self.liveSliders[index]
        local control = entry.control
        if control and type(control.RefreshDrag) == "function" then
            control.RefreshDrag()
        end
        local value = control and control.current
        if type(value) == "number" and value ~= entry.last then
            entry.last = value
            Store(entry.key, value)
            if type(entry.onLive) == "function" then
                entry.onLive(value)
            end
        end
        index = index + 1
    end
end

-- Host resolution -----------------------------------------------------------

-- What the shared window reads beyond pandaUI's contract: this addon's stored
-- values (the window position and the shared minimap button), its languages
-- and the tooltip line of the panda button.
function Settings:AddSharedOptions(options)
    options.get = Setting
    options.set = Store
    options.languages = PQ.GetLanguages()
    options.getLanguage = PQ.GetLanguage
    options.setLanguage = function(code, quiet)
        if not PQ.SetLanguage(code) then
            return false
        end
        if not quiet then
            PQ:Print(PQ.L("SETTINGS_LANGUAGE_CHANGED", PQ.GetLanguageLabel(code)))
            PQ:Print(PQ.L("SETTINGS_LANGUAGE_RELOAD"))
        end
        return true
    end
    options.minimapTooltip = function()
        return PQ.L("SETTINGS_MINIMAP_TOOLTIP")
    end
end

-- Once per host. Where the host has settings groups, PandaQuest is a
-- "PandaQuest" submenu in its sidebar with one page per visible section --
-- the sidebar rows replace the internal tab strip. A pandaUI without
-- RegisterSettingsGroup gets the whole tabbed page as a single row instead.
-- The guard means a re-entered resolution cannot file a duplicate id and get
-- itself refused.
--
-- Both pages are placed explicitly `after` the group, so they sit under it
-- whatever the host's default placement for a new entry is.
function Settings:RegisterWithHost(host)
    if self.registeredHost == host then
        return true
    end

    if type(host.RegisterSettingsGroup) == "function" then
        -- `after = "profiles"` keeps the group last in pandaUI's sidebar
        -- (pandaUI slots groups ahead of profiles by default); `defaultPage`
        -- opens General when the group is clicked. A pandaUI that predates the
        -- options table ignores it and keeps its own placement.
        --
        -- `category`, `icon`, `version` and `title` make the group its own
        -- category in the Game Settings window, headed like pandaUI's own
        -- (logo, name, dimmed version) with the wordmark as page title.
        local options = {
            after = "profiles",
            defaultPage = GENERAL_PAGE_ID,
            category = true,
            icon = SETTINGS_LOGO_TEXTURE,
            watermark = SETTINGS_MASCOT_TEXTURE,
            pageWidth = CONTENT_WIDTH,
            version = function() return PQ.version end,
            title = PageTitle,
        }
        if host == SharedHost() then
            self:AddSharedOptions(options)
        end
        local ok, group = pcall(host.RegisterSettingsGroup, TAB_ID, TAB_LABEL, options)
        if not ok or not group then
            return false
        end
        local okGeneral, general = pcall(host.RegisterSettingsTab, GENERAL_PAGE_ID,
            PQ.L("SETTINGS_TAB_GENERAL"),
            function(content)
                return Settings:BuildPage(content, "general")
            end, { parent = TAB_ID, after = TAB_ID })
        local okHud, hud = true, true
        local dialogueAfter = GENERAL_PAGE_ID
        if HUD_MARKER_SETTINGS_VISIBLE then
            okHud, hud = pcall(host.RegisterSettingsTab, HUD_PAGE_ID,
                PQ.L("SETTINGS_TAB_HUD"),
                function(content)
                    return Settings:BuildPage(content, "hud")
                end, { parent = TAB_ID, after = GENERAL_PAGE_ID })
            dialogueAfter = HUD_PAGE_ID
        end
        local okDialogue, dialogue = pcall(host.RegisterSettingsTab, DIALOGUE_PAGE_ID,
            PQ.L("SETTINGS_TAB_DIALOGUE"),
            function(content)
                return Settings:BuildPage(content, "dialogue")
            end, { parent = TAB_ID, after = dialogueAfter })
        local okMobs, mobs = pcall(host.RegisterSettingsTab, MOBS_PAGE_ID,
            PQ.L("SETTINGS_TAB_MOB_TRACKING"),
            function(content)
                return Settings:BuildPage(content, "mobs")
            end, { parent = TAB_ID, after = DIALOGUE_PAGE_ID })
        local okServer, serverPage = pcall(host.RegisterSettingsTab, SERVER_PAGE_ID,
            PQ.L("SETTINGS_TAB_IMPORT"),
            function(content)
                return Settings:BuildPage(content, "server")
            end, { parent = TAB_ID, after = MOBS_PAGE_ID })
        if not okGeneral or not general or not okHud or not hud
            or not okDialogue or not dialogue
            or not okMobs or not mobs or not okServer or not serverPage then
            return false
        end
        self.registeredHost = host
        self.hostLayout = "group"
        return true
    end

    local ok, entry = pcall(host.RegisterSettingsTab, TAB_ID, TAB_LABEL,
        function(content)
            return Settings:BuildPage(content)
        end, { category = true, icon = SETTINGS_LOGO_TEXTURE,
            watermark = SETTINGS_MASCOT_TEXTURE, pageWidth = CONTENT_WIDTH,
            version = function() return PQ.version end, title = PageTitle })
    if not ok or not entry then
        return false
    end
    self.registeredHost = host
    self.hostLayout = "tab"
    return true
end

-- Leaves the shared window when pandaUI turns up later in the poll. Pages
-- built there go with it; pandaUI builds its own.
function Settings:LeaveSharedHost()
    if self.host ~= "shared" then
        return
    end
    local shared = SharedHost()
    if shared and type(shared.UnregisterSettingsGroup) == "function" then
        pcall(shared.UnregisterSettingsGroup, TAB_ID)
    end
    self.host = nil
    self.registeredHost = nil
    self.liveSliders = {}
end

-- pandaUI when it is there, the shared window otherwise. The shared window is
-- taken at once; `force` only ends the wait for a late pandaUI.
--
-- pandaUI being PRESENT ends the search either way -- if it is there and still
-- refuses the page, retrying would only repeat its own error output every half
-- second.
function Settings:ResolveHost(force)
    if self.host == "pandaui" or self.hostSettled then
        return self.host
    end

    local pandaUI = PandaUI()
    if pandaUI then
        self.hostSettled = true
        self:LeaveSharedHost()
        if self:RegisterWithHost(pandaUI) then
            self.host = "pandaui"
            PQ:DeclareCapability("pandaUISettingsHost", "detected",
                "pandaUI was found at runtime and accepted PandaQuest's options page "
                .. (self.hostLayout == "group"
                    and ("as a submenu (U.RegisterSettingsGroup '" .. TAB_ID .. "')")
                    or ("(U.RegisterSettingsTab, id '" .. TAB_ID .. "')"))
                .. ". The page is drawn inside "
                .. "pandaUI's settings window; /pq config opens it there. Detected by type-checking "
                .. "the function this needs, not by IsAddOnLoaded, which is "
                .. "DOCUMENTED_NOT_RUNTIME_VERIFIED here and would only report that files loaded")
            return self.host
        end
        PQ:DeclareCapability("pandaUISettingsHost", "missing",
            "pandaUI is present but refused the options page -- a page already registered under "
            .. "the id '" .. TAB_ID .. "' is the only documented reason. The shared Panda "
            .. "settings window is used instead")
        PQ:Warn(PQ.L("SETTINGS_WARN_UNREALUI_REFUSED"))
    end

    if self.host ~= "shared" then
        local shared = SharedHost()
        if shared and self:RegisterWithHost(shared) then
            self.host = "shared"
        end
    end
    if force and not pandaUI then
        self.hostSettled = true
        PQ:DeclareCapability("pandaUISettingsHost", "missing",
            "pandaUI was not present after " .. HOST_POLL_SECONDS .. "s of polling, so PandaQuest "
            .. "draws its options in the shared Panda settings window (Libs/PandaSettings), "
            .. "opened by the panda button on the minimap. Polled rather than read once at "
            .. "load: nothing establishes the two addons' load order, the client's TOC "
            .. "dependency fields have no record in the compatibility database, and "
            .. "ADDON_LOADED has no probed record here")
    end
    return self.host
end

-- Opening and closing -------------------------------------------------------

function Settings:Open()
    -- force: the player asked for the window now, so the decision cannot wait
    -- out the rest of the poll.
    local hostName = self:ResolveHost(true)
    self.opens = self.opens + 1
    local host = Host()
    if not host then
        PQ:Warn(PQ.L("SETTINGS_WARN_NO_WINDOW"))
        return false
    end

    -- Under the submenu, back to the section the player last opened.
    local pageId = TAB_ID
    if self.hostLayout == "group" then
        pageId = GENERAL_PAGE_ID
        if HUD_MARKER_SETTINGS_VISIBLE and self.activePageTab == "hud" then
            pageId = HUD_PAGE_ID
        elseif self.activePageTab == "mobs" then
            pageId = MOBS_PAGE_ID
        elseif self.activePageTab == "dialogue" then
            pageId = DIALOGUE_PAGE_ID
        elseif self.activePageTab == "server" then
            pageId = SERVER_PAGE_ID
        end
    end
    if type(host.OpenSettingsPage) == "function" then
        local ok, opened = pcall(host.OpenSettingsPage, pageId)
        if ok and opened then
            return true
        end
    end
    if hostName == "pandaui" then
        if type(host.OpenSettings) == "function" then
            -- Opens the panel without being able to select our row. Better
            -- than nothing: the row is in the list the player is now seeing.
            local ok = pcall(host.OpenSettings, true)
            if ok then
                return true
            end
        end
        PQ:Print(PQ.L("SETTINGS_IN_UNREALUI"))
    end
    return false
end

-- pandaUI's panel has no public close, and reaching past its API to hide its
-- frame would be exactly the coupling this module avoids.
function Settings:Close()
    local shared = self.host == "shared" and SharedHost()
    if not shared or type(shared.CloseSettings) ~= "function" then
        return false
    end
    local ok, closed = pcall(shared.CloseSettings)
    return ok and closed and true or false
end

function Settings:IsOpen()
    local shared = self.host == "shared" and SharedHost()
    if not shared or type(shared.IsSettingsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(shared.IsSettingsShown)
    return ok and shown and true or false
end

function Settings:Toggle()
    if self:IsOpen() then
        return self:Close()
    end
    return self:Open()
end

function Settings:GetReport()
    local shared = self.host == "shared" and SharedHost()
    local anchor
    if shared and type(shared.GetMinimapButtonAnchor) == "function" then
        local ok, value = pcall(shared.GetMinimapButtonAnchor)
        if ok then
            anchor = value
        end
    end
    return {
        host = self.host or "undecided",
        waited = self.hostWaited,
        registered = self.host == "pandaui",
        layout = self.hostLayout,
        window = self:IsOpen(),
        opens = self.opens,
        minimapButton = anchor ~= nil,
        minimapAnchor = anchor,
        minimapButtonShown = Setting("minimapButton") ~= false,
    }
end

-- Turns the shared panda button on or off for every Panda addon. `enabled`
-- nil toggles. Under pandaUI only the stored value changes: its own button is
-- the one beside the minimap.
function Settings:SetMinimapButtonEnabled(enabled)
    if enabled == nil then
        enabled = Setting("minimapButton") == false
    end
    enabled = enabled and true or false
    Store("minimapButton", enabled)
    local shared = self.host == "shared" and SharedHost()
    if shared and type(shared.SetMinimapButtonShown) == "function" then
        pcall(shared.SetMinimapButtonShown, enabled)
    end
    return enabled
end

-- Lifecycle -----------------------------------------------------------------

function Settings:OnInit()
    PQ:DeclareCapability("pandaUISettingsHost", "unverified",
        "whether pandaUI is installed and will host PandaQuest's options page. Resolved after the "
        .. "player is in the world, by polling for the PandaUI global and type-checking its "
        .. "RegisterSettingsTab; this line is what it says before that poll has answered")
    PQ:DeclareCapability("mobSearchEnterSubmit", "unverified",
        "whether the Enter key can submit the mob search. It needs a script on the EditBox, and "
        .. "the only measured EditBox here carried none (widgets.editbox_minimal_search.v1), while "
        .. "a bundle including OnEnterPressed is part of a confirmed uncatchable client crash "
        .. "(widgets.editbox_focus_crash). Client.SetSettingsEditSubmitHandler attaches nothing "
        .. "and returns false until a probe isolates OnEnterPressed on its own; only the button submits")
    PQ:DeclareCapability("mobSearchTextInput", "verified",
        "an addon-owned native EditBox with no scripts, no template, no SetNumeric, no "
        .. "HighlightText and no programmatic SetFocus survived two manual focus/type/GetText/"
        .. "ClearFocus cycles (widgets.editbox_minimal_search.v1, focused runtime probe, "
        .. "2026-09-09)")
end

function Settings:OnEnable()
    -- Settled at once: without pandaUI the shared window and its panda
    -- button come up straight away. The poll stays for a pandaUI whose files
    -- run after this one; finding it hands the pages over to it.
    self:ResolveHost(false)
    local driver = PQ:GetModule("Driver")
    if not driver then
        -- No driver means no poll is possible at all, so decide now.
        self:ResolveHost(true)
        return
    end
    driver:Schedule("settings.sliders", 0, function()
        Settings:RefreshLiveSliders()
    end)
    if self.hostSettled then
        return
    end
    driver:Schedule("settings.host", HOST_POLL_INTERVAL, function(elapsed)
        Settings.hostWaited = Settings.hostWaited + (elapsed or HOST_POLL_INTERVAL)
        Settings:ResolveHost(Settings.hostWaited >= HOST_POLL_SECONDS)
        if Settings.hostSettled then
            local running = PQ:GetModule("Driver")
            if running then
                running:Unschedule("settings.host")
            end
        end
    end)
end
