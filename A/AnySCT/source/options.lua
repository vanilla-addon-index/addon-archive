-- AnySCT options.lua -- options panel: every setting is a control with a tooltip, and the tooltip
-- also shows when hovering the control's label (checkbox / colour-swatch labels are part of the hit
-- rect, slider labels sit in an extended hit rect, dropdown labels get a named hover frame).
-- ESC closes it, dragging the panel moves it. Table-driven: adding a setting is one line.
-- Layout: fixed 520x460 panel with four bottom-edge tabs, grouped under section headers:
--   targetSCTs : General | What to show | GO / WAIT indicator   (left)   targetSCT list (right)
--   Text       : Text content | Size & motion
--   Colours    : Per-targetSCT colours | Text colours
--   Placement  : Placement | Fixed anchor
-- Defaults + Close on every tab. Choices are Blizzard dropdowns (UIDropDownMenuTemplate).

AnySCT_Options = {}
local O = AnySCT_Options

if CreateFrame then
    local W = AnySCT_W
    local C = AnySCT_Core

    local frame
    local checks, sliders, cycles, rows = {}, {}, {}, {}
    local moveButton, editBox
    local selected = nil

    -- { option key, label, tooltip }
    local CHECKS = {
        { "enabled", "Enable AnySCT", "Master switch. Off: no text and no GO / WAIT counting." },
        { "onlyWhileSourceFights", "Only while the targetSCT fights",
          "Hide text while the targetSCT (or other listed source) itself is not in combat. Off: always show. If the source's combat state cannot be read, the text is shown." },
        { "showHeals", "Show heals on targetSCTs",
          "Heals received by a listed targetSCT float over it as +amount with the healer's name. Needs the targetSCT to be listed; healers may be anyone. Uses nampower heal events when present, else the buff chat channels." },
        { "showHots", "Show HoT ticks",
          "Also show heal-over-time ticks (Renew, Rejuvenation, ...). Chat rows only; can be busy in a raid. Off by default." },
        { "showOwnHeals", "Include my own heals",
          "Show your own heals on listed targetSCTs too. The game never floats heals, so nothing is shown twice." },
        { "healShowHealer", "Show healer name",
          "Print the healer's name under the heal number." },
        { "colourize", "Colour coding",
          "Off: everything is orange like Blizzard's pet text. On: crit yellow, miss / dodge / parry red, block blue, absorb / resist / immune purple. A per-targetSCT colour (Colours tab) overrides this." },
        { "mergeHits", "Merge identical hits",
          "Identical attacks (same source, victim and ability, normal hit or crit) that arrive within the merge window become ONE line whose number is the running sum, updated in place. Tames Fire Strike style tick storms. Misses, dodges and the like are not summed; identical words collapse to one line. On by default." },
        { "mergeCount", "Show hit count",
          "Append the number of merged hits to a merged line, e.g. 12 x5. Off by default." },
        { "markGlancing", "Mark glancing / crushing",
          "Add the word glancing or crushing after the number (Blizzard style). Off: shown as a plain number." },
        { "showSpells", "Show special attacks",
          "Also show Heroic Strike, Stormstrike and other ability rows (gold, like pet spells). Off unregisters those chat channels." },
        { "guessTotemOwner", "Guess totem owner",
          "When no owner can be determined, assume a totem belongs to the only shaman on your list. This can misattribute an enemy shaman's totem or your own. Off by default." },
        { "classColours", "Class colours",
          "Numbers and words take the class colour of their source (pets and totems: the owner's class). Mobs and unknown sources keep the text colour below. A per-targetSCT colour overrides this. Off by default." },
        { "colorPerTarget", "Own colour per targetSCT",
          "Every listed targetSCT gets its own text colour (pets and totems use their owner's). Colours are picked automatically so they differ well; click the swatch in the targetSCT list to change one, or press Auto colours. Heals keep the heal colour. Special attacks use the same colour. Off by default: one orange." },
        { "includeTotems", "Include totems",
          "Also show totem damage when its owner is a listed targetSCT. Needs an owner lookup (SuperWoW owner suffix, or the only shaman among the listed targetSCTs). Totems have no nameplate: text appears over the victim." },
        { "showSpellName", "Show spell name",
          "Add the ability name (Heroic Strike, Stormstrike, ...) under the number for special attacks. Off by default." },
        { "showLabel", "Show targetSCT list label",
          "A 'targetSCTs: ...' line above the fixed anchor. Off by default." },
        { "extendRange", "Extend combat log range (200)",
          "Sets CombatLogRangeFriendlyPlayers and CombatLogRangeParty to 200 on login. Without it, raid targetSCTs outside your party are silent beyond roughly 50 yards. The server still caps the real range. On by default." },
        { "minimap", "Show minimap button",
          "Left click unlocks / locks the anchor, right click opens this window." },
        { "threatGo", "Enable GO / WAIT (experimental)",
          "Experimental. Shows GO or WAIT over your elite / boss target from the server's threat data (the same data TWThreat uses). Works only in a party or raid, only on your own target while it is an elite or boss in combat, and only for targetSCTs whose Threat switch is on. It shows your threat buffer, i.e. how far you are from pulling aggro off the targetSCT, before you pull it. Off by default. Needs no other addon, but also uses TWThreat's answers when TWThreat runs." },
        { "threatTrace", "Record threat trace",
          "Writes the received server threat data to <WoW>\imports\anysct_threat.txt (needs SuperWoW). For bug reports." },
        { "importMain", "Import CT_RA / oRA main tanks",
          "Imports every entry of the CT_RaidAssist / oRA main tank list that is in your group as a targetSCT." },
    }

    -- { option key, label, choices { {value, text}, ... }, tooltip }
    local CYCLES = {
        { "placement", "Placement",
          { { "clamp", "Nameplate, clamp" }, { "anchorOff", "Nameplate, else anchor" },
            { "anchor", "Always anchor" }, { "both", "Nameplate + anchor" } },
          "Where the text appears. Over the nameplate needs enemy nameplates on (V). Clamp keeps text along the screen edge when the plate is off screen. 'Nameplate + anchor' shows every line and the GO / WAIT label over the plate AND at the fixed anchor (separate line limits); without a plate it shows once at the anchor." },
        { "noPlate", "No nameplate",
          { { "anchor", "Anchor" }, { "hide", "Hide" } },
          "What to do when the targetSCT's target has no visible nameplate." },
        { "sourceNameMode", "targetSCT name",
          { { "never", "Never" }, { "multi", "Only with several targetSCTs" }, { "always", "Always" } },
          "Print the name of the targetSCT that caused the number (for its pets and totems: the owner's name) as the first part of the line under the number, before spell and victim: Source - Spell - Victim. 'Only with several targetSCTs' helps to tell them apart; 'Always' shows it even with a single one. Not shown on heals." },
        { "mobNameMode", "Victim name",
          { { "never", "Never" }, { "anchor", "Anchor only" }, { "always", "Always" } },
          "Show the victim's name under the text. Off by default; 'Anchor only' names it when the text falls back to the fixed anchor." },
        { "font", "Font",
          { { "CLIENT", "Client" }, { "FRIZQT", "FrizQT" }, { "SKURRI", "Skurri" },
            { "ARIALN", "Arial Narrow" } },
          "Font of the floating text. The client damage font (DAMAGE_TEXT_FONT, honours pfUI) matches the Blizzard text." },
        { "direction", "Direction",
          { { "up", "Up" }, { "down", "Down" } }, "Whether the text rises or sinks." },
    }

    -- { key, label, min, max, step, format, tooltip }. posX / posY edit the fixed anchor.
    local SLIDERS = {
        { "sizeFactor", "Number size", 0.5, 3, 0.05, "%.2f",
          "Size factor of damage numbers. Size = 0.018333 x screen diagonal x factor (crits 0.0275): 23 px at 1024x768, 54 px at 2560x1440." },
        { "wordFactor", "Word size", 0.5, 3, 0.05, "%.2f", "Size factor of Miss / Dodge / Parry / ..." },
        { "riseHeight", "Rise (px)", 0, 300, 5, nil,
          "How far a normal text rises (crits rise with the stack). The engine rises 2 yards; the screen distance depends on the camera." },
        { "mergeWindow", "Merge window (s)", 0.1, 1.5, 0.05, "%.2f",
          "How long a line keeps absorbing identical hits, counted from its first hit. Short: more, smaller lines. Long: fewer lines that update longer. Only used with Merge identical hits." },
        { "jitter", "Jitter (px)", 0, 40, 1, nil, "Random horizontal offset per line. 0 like the engine; lines stack instead." },
        { "maxLines", "Max lines", 3, 100, 1, nil, "Maximum number of lines on screen over all mobs; when it is reached the oldest line is recycled." },
        { "maxLinesPerTarget", "Max lines per mob", 1, 30, 1, nil, "Maximum number of lines over one mob. Lines live 1.5 s, so 16 shows every hit of a burst of about 10 per second; lower values recycle the oldest line early." },
        { "threatGoLead", "Required threat buffer", 0, 75, 1, nil,
          "Threat points you must still be below the pull threshold (110 % melee / 130 % ranged of the tank's threat) before the label says GO. Slider: 0-7500 in steps of 100. Default 1500 suits fresh level 60 and levelling characters. A typical raid burst over 3 s is a few thousand threat; Execute crits can exceed 10000 - raise it to match your own burst. 0 = GO as soon as the targetSCT holds aggro and you are below the pull threshold.",
          "lead" },

        { "xOffset", "Plate X offset", -150, 150, 5, nil,
          "Horizontal shift from the plate centre. +40 puts targetSCT numbers beside your own floating text." },
        { "yOffset", "Plate Y offset", -100, 100, 5, nil, "Vertical shift from the plate's top edge." },
        { "edgeMargin", "Edge margin (px)", 0, 200, 5, nil,
          "Distance to the screen edge at which a plate counts as off screen and the text is clamped." },
        { "posX", "Anchor X", -800, 800, 5, nil, "Horizontal position of the fixed anchor, from the screen centre." },
        { "posY", "Anchor Y", -500, 500, 5, nil, "Vertical position of the fixed anchor, from the screen centre." },
        { "plateRange", "Nameplate range", 0, 80, 5, nil,
          "Sets the SuperWoW NameplateRange and nampower NP_NameplateDistance CVars on login. 0 leaves them untouched (client default about 41-45 yards)." },
    }

    local function getVal(key)
        if key == "threatGoLead" then return C.PosFromLead(C.Opt(key) or 1500) end
        if key == "posX" then return math.floor(((C.Opt("pos") or {}).x or 0) + 0.5) end
        if key == "posY" then return math.floor(((C.Opt("pos") or {}).y or 0) + 0.5) end
        return C.Opt(key) or 0
    end

    local function setVal(key, v)
        if key == "threatGoLead" then
            C.SetOpt(key, C.LeadFromPos(v))
        elseif key == "posX" or key == "posY" then
            local p = C.Opt("pos") or {}
            local x, y = p.x or 0, p.y or 0
            if key == "posX" then x = v else y = v end
            C.SetOpt("pos", { point = "CENTER", x = x, y = y })
        else
            C.SetOpt(key, v)
        end
    end

    local function choiceText(d)
        local cur = C.Opt(d[1])
        for i = 1, table.getn(d[3]) do
            if d[3][i][1] == cur then return d[3][i][2], cur end
        end
        return d[3][1][2], d[3][1][1]
    end

    local swatches = {}
    local DEFAULT_COLOURS = { colorMelee = { 1.0, 0.518, 0.0 }, colorSpell = { 1.0, 0.871, 0.0 }, colorHeal = { 0.1, 1.0, 0.1 } }

    -- Blizzard's colour picker, raised above this panel (it opens behind it otherwise), live preview.
    -- onChange(r, g, b) applies a colour; onCancel() restores the colour from before.
    local function showPicker(r, g, b, onChange, onCancel)
        local cp = ColorPickerFrame
        cp.hasOpacity = false
        cp.opacityFunc = nil
        cp.func = nil
        cp:SetColorRGB(r, g, b)
        cp.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            onChange(nr, ng, nb)
            O.refresh()
        end
        cp.cancelFunc = function()
            onCancel()
            O.refresh()
        end
        -- Strata only: SetFrameLevel on a parent does not move its children and would bury the picker's
        -- own Okay/Cancel buttons. The options panel is at DIALOG, so FULLSCREEN_DIALOG is always above.
        cp:SetFrameStrata("FULLSCREEN_DIALOG")
        if cp:IsShown() then cp:Hide() end
        cp:Show()
    end

    local function openPicker(key)
        local cur = C.Opt(key) or DEFAULT_COLOURS[key]
        local prev = { cur[1], cur[2], cur[3] }
        showPicker(cur[1], cur[2], cur[3],
            function(r, g, b) C.SetOpt(key, { r, g, b }) end,
            function() C.SetOpt(key, prev) end)
    end

    -- Colour of one listed targetSCT (list row swatch); cancel restores the colour from before.
    local function openEntryPicker(name)
        local e = C.state.byName[name]
        if not e or not e.hex then return end
        local prev = e.hex
        local r, g, b = C.HexToRgb(prev)
        showPicker(r, g, b,
            function(nr, ng, nb) C.SetColour(name, C.RgbToHex(nr, ng, nb)) end,
            function() C.SetColour(name, prev) end)
    end

    O.openPicker = openPicker
    O.openEntryPicker = openEntryPicker

    local function refresh()
        if not frame then return end
        for i = 1, table.getn(swatches) do
            local c = C.Opt(swatches[i].asctKey) or DEFAULT_COLOURS[swatches[i].asctKey]
            swatches[i].tex:SetTexture(c[1], c[2], c[3])
        end
        for i = 1, table.getn(checks) do
            checks[i]:SetChecked(C.Opt(checks[i].asctKey) and 1 or nil)
        end
        for i = 1, table.getn(sliders) do
            local sl = sliders[i]
            local v = getVal(sl.asctKey)
            sl.asctBusy = true
            if (sl.asctKey == "posX" or sl.asctKey == "posY") and AnySCT_SCT and AnySCT_SCT.ScreenRect then
                local hw, hh = C.ScreenHalfRange(AnySCT_SCT.ScreenRect())
                local lim = sl.asctKey == "posX" and hw or hh
                -- never clamp a stored position: widen the range to hold it
                if math.abs(v) > lim then lim = math.ceil(math.abs(v) / 5) * 5 end
                sl:SetMinMaxValues(-lim, lim)
                getglobal(sl:GetName() .. "Low"):SetText(tostring(-lim))
                getglobal(sl:GetName() .. "High"):SetText(tostring(lim))
            end
            sl:SetValue(v)
            sl.asctBusy = false
            local txt = sl.asctFmt and string.format(sl.asctFmt, v) or tostring(v)
            if sl.asctMap then txt = tostring(C.LeadFromPos(v)) end
            getglobal(sl:GetName() .. "Text"):SetText(sl.asctLabel .. ": " .. txt)
        end
        for i = 1, table.getn(cycles) do
            local txt, val = choiceText(CYCLES[i])
            UIDropDownMenu_SetSelectedValue(cycles[i], val)
            UIDropDownMenu_SetText(txt, cycles[i])
        end
        local mv = AnySCT_SCT and AnySCT_SCT.IsMoveMode and AnySCT_SCT.IsMoveMode()
        moveButton:SetText(mv and "Lock anchor" or "Unlock anchor")
        local st = C.state
        for i = 1, table.getn(rows) do
            local name = st.order[i]
            local row = rows[i]
            if name then
                local e = st.byName[name]
                row.asctName = name
                row.text:SetText(e.src == "main" and (name .. " (import)") or name)
                if selected == name then row.text:SetTextColor(1, 0.82, 0) else row.text:SetTextColor(0.8, 0.8, 0.8) end
                local rgb = e.rgb or { 1, 1, 1 }
                row.sw.tex:SetTexture(rgb[1], rgb[2], rgb[3])
                row.th:SetChecked(e.threatOn and 1 or nil)
                row:Show()
            else
                row.asctName = nil
                row:Hide()
            end
        end
    end
    O.refresh = refresh

    -- Fixed panel geometry (UI scale 1): 520 x 460, four tabs hanging below the bottom edge, 16 px margins.
    local PANEL_W, PANEL_H = 520, 540
    local COLA, COLB = 20, 270            -- two content columns, 230-240 wide each
    local TOP = -48                       -- first content row, below the title

    local TAB_NAMES = { "targetSCTs", "Text", "Colours", "Placement" }
    local TAB_TIPS = {
        "The targetSCT list, what is shown, and general switches.",
        "What the lines say, plus fonts, sizes and timing of the text.",
        "Per-targetSCT colours, class colours and the colour scheme.",
        "Where the text appears, the fixed anchor and the nameplate offsets.",
    }
    local NUM_TABS = 4
    local pages, tabs = {}, {}

    -- which control lives on which tab (by option key)
    local function indexOf(list, key)
        for i = 1, table.getn(list) do
            if list[i][1] == key then return i end
        end
        return nil
    end

    -- Tabs are anchored to the panel one by one (x accumulated from their widths) so the inactive ones
    -- can sit higher than the active one, as in the Group Finder (owner: ~5 px).
    local TAB_Y_ACTIVE, TAB_Y_INACTIVE, TAB_X0, TAB_GAP = 4, 9, 13, -17
    local function placeTabs(active)
        if not frame then return end
        local x = TAB_X0
        for i = 1, NUM_TABS do
            local t = tabs[i]
            if t then
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x, (i == active) and TAB_Y_ACTIVE or TAB_Y_INACTIVE)
                local w = t:GetWidth()
                if type(w) ~= "number" then w = 0 end
                x = x + w + TAB_GAP
            end
        end
    end

    local function selectTab(n)
        if not pages[n] then n = 1 end
        placeTabs(n)
        for i = 1, NUM_TABS do
            if i == n then pages[i]:Show() else pages[i]:Hide() end
        end
        if frame and PanelTemplates_SetTab then PanelTemplates_SetTab(frame, n) end
        if type(AnySCTDB) == "table" then AnySCTDB.optionsTab = n end
    end

    local function build()
        if frame then return frame end
        local f = CreateFrame("Frame", "AnySCTOptionsFrame", UIParent)
        f:SetWidth(PANEL_W)
        f:SetHeight(PANEL_H)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        -- DIALOG sits above the HIGH strata where world nameplates (and AnySCT's own text) are drawn, so no
        -- plate shows through the panel; the colour picker (FULLSCREEN_DIALOG) stays above the panel.
        f:SetFrameStrata("DIALOG")
        if f.SetToplevel then f:SetToplevel(true) end
        -- Raised so the tabs (panel level - 1) stay at a valid level >= 0 and sit behind the dialog border.
        if f.SetFrameLevel then f:SetFrameLevel(10) end
        f:SetBackdrop(W.PANEL_BACKDROP)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        f:SetScript("OnShow", function() refresh() end)

        local title = W.MakeText(f, "AnySCTOptionsTitle", 14, W.COLORS.title)
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -20)
        title:SetText("AnySCT")
        local closeX = CreateFrame("Button", "AnySCTOptionsCloseX", f, "UIPanelCloseButton")
        closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

        -- Hidden font string with the button font: buttons are sized to their text + 24 px.
        local measure = f:CreateFontString("AnySCTOptionsMeasure", "ARTWORK", "GameFontNormal")
        measure:Hide()
        local function fitWidth(a, b)
            measure:SetText(a)
            local w = measure:GetStringWidth() or 0
            if b then
                measure:SetText(b)
                local w2 = measure:GetStringWidth() or 0
                if w2 > w then w = w2 end
            end
            return math.floor(w + 0.5) + 24
        end

        -- One content frame per tab, same size as the panel so coordinates are panel coordinates.
        for i = 1, NUM_TABS do
            local pg = CreateFrame("Frame", "AnySCTOptionsPage" .. i, f)
            pg:SetWidth(PANEL_W)
            pg:SetHeight(PANEL_H)
            pg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            pg:Hide()
            pages[i] = pg
        end

        -- Classic bottom-edge tabs (CharacterFrameTabButtonTemplate) hanging below the panel. The names must
        -- be <frame name> .. "Tab" .. i: PanelTemplates_SetTab finds them that way.
        f.numTabs = NUM_TABS
        if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, NUM_TABS) end
        for i = 1, NUM_TABS do
            local t = CreateFrame("Button", "AnySCTOptionsFrameTab" .. i, f, "CharacterFrameTabButtonTemplate")
            t:SetText(TAB_NAMES[i])
            -- Group Finder (LFT.xml) look: the template's top 10% of art (the lip) is cropped, so the visible
            -- tab starts flat under the border; tab 2 chains LEFT->RIGHT -17 there (-16 in the stock frames).
            local nm = "AnySCTOptionsFrameTab" .. i
            local l, m, r = getglobal(nm .. "Left"), getglobal(nm .. "Middle"), getglobal(nm .. "Right")
            if l and l.SetTexCoord then l:SetTexCoord(0.0, 0.15625, 0.1, 1.0) end
            if m and m.SetTexCoord then m:SetTexCoord(0.15625, 0.84375, 0.1, 1.0) end
            if r and r.SetTexCoord then r:SetTexCoord(0.84375, 1.0, 0.1, 1.0) end
            -- Like the Group Finder (LFT.xml): tabs drawn ABOVE the frame, the lip cropped away by the
            -- texcoords, the tab top sitting just under the border's bevel at the frame's outer edge.
            if t.SetFrameLevel and f.GetFrameLevel then t:SetFrameLevel(f:GetFrameLevel() + 1) end
            -- Position comes from placeTabs (called by selectTab) once the widths are known.
            t:SetPoint("TOPLEFT", f, "BOTTOMLEFT", TAB_X0, TAB_Y_INACTIVE)
            if PanelTemplates_TabResize then PanelTemplates_TabResize(0, t) end
            local hl = getglobal(nm .. "HighlightTexture")
            if hl and hl.SetWidth and t.GetTextWidth then hl:SetWidth((t:GetTextWidth() or 0) + 30) end
            t.asctTab = i
            t:SetScript("OnClick", function() selectTab(this.asctTab) end)
            W.AttachTooltip(t, TAB_NAMES[i], TAB_TIPS[i])
            tabs[i] = t
        end

        local function header(page, name, text, x, y)
            local h = W.MakeText(page, name, 12, W.COLORS.title)
            h:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
            h:SetText(text)
        end

        -- UIPanelButtonTemplate, default font; width fitted to label (alt = longer toggle text).
        local function makeButton(page, name, label, alt, px, py, tipTitle, tipBody, onClick)
            local b = CreateFrame("Button", name, page, "UIPanelButtonTemplate")
            b:SetWidth(fitWidth(label, alt))
            b:SetHeight(22)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", px, py)
            b:SetText(label)
            b:SetScript("OnClick", onClick)
            W.AttachTooltip(b, tipTitle, tipBody)
            return b
        end

        -- The label belongs to the hit rect: hovering it shows the tooltip, clicking it toggles.
        local function extendRight(btn, fs)
            if btn.SetHitRectInsets and fs and fs.GetStringWidth then
                btn:SetHitRectInsets(0, -((fs:GetStringWidth() or 0) + 4), 0, 0)
            end
        end

        local function makeCheck(page, key, px, py)
            local i = indexOf(CHECKS, key)
            local d = CHECKS[i]
            local name = "AnySCTOptionsCheck" .. i
            local cb = CreateFrame("CheckButton", name, page, "UICheckButtonTemplate")
            cb:SetWidth(24)
            cb:SetHeight(24)
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", px, py)
            local label = getglobal(name .. "Text")
            label:SetText(d[2])
            extendRight(cb, label)
            cb.asctKey = d[1]
            cb:SetScript("OnClick", function() C.SetOpt(this.asctKey, this:GetChecked() == 1) end)
            W.AttachTooltip(cb, d[2], d[3])
            checks[i] = cb
        end

        local function makeSlider(page, key, px, py)
            local i = indexOf(SLIDERS, key)
            local d = SLIDERS[i]
            local name = "AnySCTOptionsSlider" .. i
            local sl = CreateFrame("Slider", name, page, "OptionsSliderTemplate")
            sl:SetWidth(200)
            sl:SetHeight(16)
            sl:SetMinMaxValues(d[3], d[4])
            sl:SetValueStep(d[5])
            sl:SetPoint("TOPLEFT", f, "TOPLEFT", px, py)
            getglobal(name .. "Low"):SetText(d[6] and string.format(d[6], d[3]) or tostring(d[3]))
            getglobal(name .. "High"):SetText(d[6] and string.format(d[6], d[4]) or tostring(d[4]))
            sl.asctKey, sl.asctLabel, sl.asctStep, sl.asctFmt, sl.asctMap = d[1], d[2], d[5], d[6], d[8]
            if d[8] then getglobal(name .. "High"):SetText("7500") end
            sl:SetScript("OnValueChanged", function()
                if this.asctBusy then return end
                if AnySCT_SCT and AnySCT_SCT.IsDragging and AnySCT_SCT.IsDragging() then return end
                local v = math.floor(this:GetValue() / this.asctStep + 0.5) * this.asctStep
                local txt = this.asctFmt and string.format(this.asctFmt, v) or tostring(v)
                if this.asctFmt then v = tonumber(txt) end
                if this.asctMap then txt = tostring(C.LeadFromPos(v)) end
                setVal(this.asctKey, v)
                getglobal(this:GetName() .. "Text"):SetText(this.asctLabel .. ": " .. txt)
            end)
            W.AttachTooltip(sl, d[2], d[7])
            -- the value label sits above the bar: let it count as part of the slider
            if sl.SetHitRectInsets then sl:SetHitRectInsets(0, 0, -16, 0) end
            sliders[i] = sl
        end

        -- Label + Blizzard dropdown on one row (label in a named hover frame carrying the same tooltip).
        local function makeCycle(page, key, px, py)
            local i = indexOf(CYCLES, key)
            local d = CYCLES[i]
            local lbl = W.MakeText(page, "AnySCTOptionsDropLabel" .. i, 12, W.COLORS.ink)
            lbl:SetPoint("TOPLEFT", f, "TOPLEFT", px, py - 9)
            lbl:SetText(d[2])
            local name = "AnySCTOptionsDrop" .. i
            local dd = CreateFrame("Frame", name, page, "UIDropDownMenuTemplate")
            dd:SetPoint("TOPLEFT", f, "TOPLEFT", px + 104, py + 1)
            dd.asctIndex = i
            UIDropDownMenu_Initialize(dd, function()
                local def = CYCLES[dd.asctIndex]
                local cur = C.Opt(def[1])
                for j = 1, table.getn(def[3]) do
                    local info = {}
                    info.text = def[3][j][2]
                    info.value = def[3][j][1]
                    info.checked = (def[3][j][1] == cur)
                    info.func = function()
                        C.SetOpt(CYCLES[dd.asctIndex][1], this.value)
                        refresh()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetWidth(170, dd)
            local lines = ""
            for j = 1, table.getn(d[3]) do lines = lines .. "  " .. d[3][j][2] .. "\n" end
            local body = d[4] .. "\nChoices:\n" .. lines
            W.AttachTooltip(dd, d[2], body)
            local hover = CreateFrame("Frame", "AnySCTOptionsDropHover" .. i, page)
            hover:SetWidth(100)
            hover:SetHeight(16)
            hover:SetPoint("TOPLEFT", f, "TOPLEFT", px, py - 7)
            hover:EnableMouse(true)
            W.AttachTooltip(hover, d[2], body)
            local ddBtn = getglobal(name .. "Button")
            if ddBtn then
                -- The arrow button covers the dropdown; give it the tooltip but keep Blizzard's handlers.
                local oldEnter = ddBtn:GetScript("OnEnter")
                local oldLeave = ddBtn:GetScript("OnLeave")
                ddBtn.asctTitle, ddBtn.asctBody = d[2], body
                ddBtn:SetScript("OnEnter", function()
                    if oldEnter then oldEnter() end
                    if GameTooltip then
                        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                        GameTooltip:SetText(this.asctTitle, 1, 1, 1)
                        GameTooltip:AddLine(this.asctBody, 0.8, 0.8, 0.8, 1)
                        GameTooltip:Show()
                    end
                end)
                ddBtn:SetScript("OnLeave", function()
                    if oldLeave then oldLeave() end
                    if GameTooltip then GameTooltip:Hide() end
                end)
            end
            cycles[i] = dd
        end

        -- Colour swatch with its label; the label is part of the swatch's hit rect.
        local function makeSwatch(page, key, label, tip, px, py)
            local b = CreateFrame("Button", "AnySCTOptionsSwatch" .. key, page)
            b:SetWidth(26)
            b:SetHeight(18)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", px, py)
            local border = b:CreateTexture(nil, "BACKGROUND")
            border:SetTexture(1, 1, 1)
            border:SetAllPoints(b)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
            b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            b.asctKey = key
            b:SetScript("OnClick", function() openPicker(this.asctKey) end)
            W.AttachTooltip(b, label, tip)
            local t = W.MakeText(page, "AnySCTOptionsSwatchText" .. key, 12, W.COLORS.ink)
            t:SetPoint("LEFT", b, "RIGHT", 6, 0)
            t:SetText(label)
            extendRight(b, t)
            table.insert(swatches, b)
        end

        ------------------------------------------------------------------ tab 1: targetSCTs
        local p1 = pages[1]
        header(p1, "AnySCTOptionsHdrGeneral", "General", COLA, TOP)
        local y = TOP - 18
        local GENERAL = { "enabled", "onlyWhileSourceFights", "extendRange", "minimap" }
        for i = 1, table.getn(GENERAL) do
            makeCheck(p1, GENERAL[i], COLA, y)
            y = y - 21
        end
        y = y - 8
        header(p1, "AnySCTOptionsHdrShow", "What to show", COLA, y)
        y = y - 18
        local SHOW = { "showSpells", "includeTotems", "guessTotemOwner", "showHeals", "showHots", "showOwnHeals" }
        for i = 1, table.getn(SHOW) do
            makeCheck(p1, SHOW[i], COLA, y)
            y = y - 21
        end
        y = y - 8
        header(p1, "AnySCTOptionsHdrGo", "GO / WAIT indicator (experimental)", COLA, y)
        makeCheck(p1, "threatGo", COLA, y - 18)
        makeSlider(p1, "threatGoLead", COLA + 10, y - 62)

        header(p1, "AnySCTOptionsHdrList", "targetSCTs", COLB, TOP)
        local ty = TOP - 18
        local box = CreateFrame("Frame", "AnySCTOptionsListBox", p1)
        box:SetWidth(230)
        box:SetHeight(140)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", COLB, ty)
        box:SetBackdrop(W.SOLID_BACKDROP)
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
        for i = 1, 8 do
            local row = CreateFrame("Button", "AnySCTOptionsRow" .. i, box)
            row:SetWidth(214)
            row:SetHeight(16)
            row:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8 - (i - 1) * 16)
            row.text = row:CreateFontString("AnySCTOptionsRowText" .. i, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
            row.text:SetWidth(128)
            row.text:SetJustifyH("LEFT")
            row:SetScript("OnClick", function()
                selected = this.asctName
                refresh()
            end)
            W.AttachTooltip(row, "targetSCT", "Click to select, then Remove. Entries marked import are managed by the source addon; remove one to drop it for this session.")
            local sw = CreateFrame("Button", "AnySCTOptionsRowSwatch" .. i, row)
            sw:SetWidth(22)
            sw:SetHeight(12)
            sw:SetPoint("LEFT", row, "LEFT", 0, 0)
            local border = sw:CreateTexture(nil, "BACKGROUND")
            border:SetTexture(1, 1, 1)
            border:SetAllPoints(sw)
            sw.tex = sw:CreateTexture(nil, "ARTWORK")
            sw.tex:SetPoint("TOPLEFT", sw, "TOPLEFT", 1, -1)
            sw.tex:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -1, 1)
            sw.asctRow = row
            sw:SetScript("OnClick", function()
                local nm = this.asctRow.asctName
                if nm then openEntryPicker(nm) end
            end)
            W.AttachTooltip(sw, "targetSCT colour",
                "Click to pick this targetSCT's colour. It is used when 'Own colour per targetSCT' (Colours tab) is on, and kept until you press Auto colours.")
            row.sw = sw
            -- per-targetSCT threat switch (the label is part of the hit rect)
            local th = CreateFrame("CheckButton", "AnySCTOptionsRowThreat" .. i, row, "UICheckButtonTemplate")
            th:SetWidth(16)
            th:SetHeight(16)
            th:SetPoint("LEFT", row, "LEFT", 158, 0)
            local thLabel = getglobal("AnySCTOptionsRowThreat" .. i .. "Text")
            thLabel:SetText("Threat")
            extendRight(th, thLabel)
            th.asctRow = row
            th:SetScript("OnClick", function()
                local nm = this.asctRow.asctName
                if nm then C.SetThreatOn(nm, this:GetChecked() == 1) end
            end)
            W.AttachTooltip(th, "Threat (experimental)",
                "Use this targetSCT for the GO / WAIT threat label. On by default for players, off for pets, totems, mobs and hostile players. Only matters when 'Enable GO / WAIT' is on.")
            row.th = th
            rows[i] = row
        end
        ty = ty - 140 - 4
        editBox = CreateFrame("EditBox", "AnySCTOptionsAddBox", p1, "InputBoxTemplate")
        editBox:SetWidth(150)
        editBox:SetHeight(20)
        editBox:SetPoint("TOPLEFT", f, "TOPLEFT", COLB + 8, ty)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(32)
        editBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        editBox:SetScript("OnEnterPressed", function()
            if this:GetText() ~= "" then C.Slash("add " .. this:GetText()) end
            this:SetText("")
            this:ClearFocus()
            refresh()
        end)
        W.AttachTooltip(editBox, "Add a targetSCT", "Type a player name and press Enter, or click Add.")
        ty = ty - 24
        local bx = COLB
        local bAdd = makeButton(p1, "AnySCTOptionsAdd", "Add", nil, bx, ty, "Add targetSCT",
            "Add the typed name (or your target if the box is empty) to the list.",
            function()
                local t = editBox:GetText()
                C.Slash("add " .. t)
                editBox:SetText("")
                refresh()
            end)
        bx = bx + bAdd:GetWidth() + 6
        local bRem = makeButton(p1, "AnySCTOptionsRemove", "Remove", nil, bx, ty, "Remove targetSCT",
            "Remove the selected targetSCT.", function()
                if selected then C.RemoveSource(selected) selected = nil end
                refresh()
            end)
        bx = bx + bRem:GetWidth() + 6
        makeButton(p1, "AnySCTOptionsClearList", "Clear", nil, bx, ty, "Clear list",
            "Remove every targetSCT, including the saved manual list.", function()
                C.ClearSources()
                selected = nil
                refresh()
            end)
        ty = ty - 28
        makeButton(p1, "AnySCTOptionsAutoColours", "Auto colours", nil, COLB, ty, "Auto colours",
            "Give every listed targetSCT a new colour from the built-in palette, chosen so that they are easy to tell apart. Replaces colours you picked by hand.",
            function()
                C.AutoColours()
                refresh()
            end)
        ty = ty - 30
        makeCheck(p1, "importMain", COLB, ty)

        ------------------------------------------------------------------ tab 2: Text
        local p2 = pages[2]
        header(p2, "AnySCTOptionsHdrContent", "Text content", COLA, TOP)
        local y2 = TOP - 18
        makeCycle(p2, "sourceNameMode", COLA, y2)
        y2 = y2 - 30
        makeCycle(p2, "mobNameMode", COLA, y2)
        y2 = y2 - 30
        local CONTENT = { "showSpellName", "healShowHealer", "markGlancing", "mergeHits", "mergeCount" }
        for i = 1, table.getn(CONTENT) do
            makeCheck(p2, CONTENT[i], COLA, y2)
            y2 = y2 - 21
        end
        y2 = y2 - 8
        header(p2, "AnySCTOptionsHdrSize", "Size & motion", COLA, y2)
        y2 = y2 - 18
        makeCycle(p2, "font", COLA, y2)
        y2 = y2 - 30
        makeCycle(p2, "direction", COLA, y2)
        y2 = y2 - 48
        local LOOK = { "sizeFactor", "wordFactor", "riseHeight", "jitter", "maxLines", "maxLinesPerTarget", "mergeWindow" }
        for i = 1, table.getn(LOOK) do
            local col = COLA + 10
            if math.mod(i, 2) == 0 then col = COLB + 10 end
            makeSlider(p2, LOOK[i], col, y2)
            if math.mod(i, 2) == 0 then y2 = y2 - 46 end
        end

        ------------------------------------------------------------------ tab 3: Colours
        local p3 = pages[3]
        header(p3, "AnySCTOptionsHdrPerTarget", "Per-targetSCT colours", COLA, TOP)
        local y3 = TOP - 18
        makeCheck(p3, "colorPerTarget", COLA, y3)
        y3 = y3 - 40
        header(p3, "AnySCTOptionsHdrTextColours", "Text colours", COLA, y3)
        y3 = y3 - 18
        makeCheck(p3, "classColours", COLA, y3)
        makeCheck(p3, "colourize", COLB, y3)
        y3 = y3 - 32
        makeSwatch(p3, "colorMelee", "Melee colour", "Colour of damage numbers and words (melee). Opens the colour picker; changes preview live.", COLA, y3)
        makeSwatch(p3, "colorSpell", "Spell colour", "Colour of special attacks (Heroic Strike, ...).", COLA + 130, y3)
        makeButton(p3, "AnySCTOptionsResetColours", "Reset colours", nil, COLA + 270, y3 - 2,
            "Reset colours", "Orange FF8400 for melee, gold FFDE00 for spells (Blizzard defaults), green for heals.",
            function()
                C.SetOpt("colorMelee", { 1.0, 0.518, 0.0 })
                C.SetOpt("colorSpell", { 1.0, 0.871, 0.0 })
                C.SetOpt("colorHeal", { 0.1, 1.0, 0.1 })
                refresh()
            end)
        y3 = y3 - 30
        makeSwatch(p3, "colorHeal", "Heal colour", "Colour of heal numbers on listed targetSCTs.", COLA, y3)

        ------------------------------------------------------------------ tab 4: Placement
        local p4 = pages[4]
        header(p4, "AnySCTOptionsHdrPlacement", "Placement", COLA, TOP)
        local y4 = TOP - 18
        makeCycle(p4, "placement", COLA, y4)
        y4 = y4 - 30
        makeCycle(p4, "noPlate", COLA, y4)
        y4 = y4 - 46
        local PLATE = { "xOffset", "yOffset", "edgeMargin", "plateRange" }
        for i = 1, table.getn(PLATE) do
            local col = COLA + 10
            if math.mod(i, 2) == 0 then col = COLB + 10 end
            makeSlider(p4, PLATE[i], col, y4)
            if math.mod(i, 2) == 0 then y4 = y4 - 46 end
        end
        y4 = y4 - 4
        header(p4, "AnySCTOptionsHdrAnchor", "Fixed anchor", COLA, y4)
        y4 = y4 - 34
        makeSlider(p4, "posX", COLA + 10, y4)
        makeSlider(p4, "posY", COLB + 10, y4)
        y4 = y4 - 38
        local ax = COLA
        moveButton = makeButton(p4, "AnySCTOptionsMove", "Unlock anchor", "Lock anchor", ax, y4,
            "Move the fixed anchor", "Unlock to drag the anchor box and play a demo stream; lock when done.",
            function()
                if AnySCT_SCT then AnySCT_SCT.ToggleMove() end
                refresh()
            end)
        ax = ax + moveButton:GetWidth() + 6
        local bPos = makeButton(p4, "AnySCTOptionsResetPos", "Reset anchor", nil, ax, y4,
            "Reset anchor", "Put the fixed anchor back to the default spot (screen centre, 120 px up).",
            function()
                local p = AnySCT_DEFAULTS.pos
                C.SetOpt("pos", { point = p.point, x = p.x, y = p.y })
                refresh()
            end)
        ax = ax + bPos:GetWidth() + 6
        makeButton(p4, "AnySCTOptionsDemo", "Demo", nil, ax, y4, "Demo",
            "Plays a 2.5 s burst of your first targetSCT's class skills (a shaman demo tank without one) on your target's nameplate (fixed anchor without a target), using all your display settings. Fills the per-mob tower and previews the GO / WAIT threat label; click again to restart.",
            function() if AnySCT_SCT then AnySCT_SCT.Demo() end end)
        y4 = y4 - 28
        makeCheck(p4, "showLabel", COLA, y4)
        y4 = y4 - 26
        header(p4, "AnySCTOptionsHdrDebug", "Debug", COLA, y4)
        makeCheck(p4, "threatTrace", COLA, y4 - 18)

        ------------------------------------------------------------------ bottom row (all tabs)
        local yb = -(PANEL_H - 16 - 22)
        local bClose = makeButton(f, "AnySCTOptionsClose", "Close", nil, 0, yb, "Close", "Close this window (ESC works too).",
            function() f:Hide() end)
        local bDef = makeButton(f, "AnySCTOptionsReset", "Defaults", nil, 0, yb, "Defaults",
            "Restore every setting to its default (the targetSCT list and its colours are kept).",
            function() C.Slash("reset") refresh() end)
        local rx = PANEL_W - 16 - bClose:GetWidth()
        bClose:SetPoint("TOPLEFT", f, "TOPLEFT", rx, yb)
        bDef:SetPoint("TOPLEFT", f, "TOPLEFT", rx - 6 - bDef:GetWidth(), yb)

        table.insert(UISpecialFrames, "AnySCTOptionsFrame")
        frame = f
        local last = 1
        if type(AnySCTDB) == "table" and type(AnySCTDB.optionsTab) == "number" then last = AnySCTDB.optionsTab end
        selectTab(last)
        f:Hide()
        return f
    end

    function O.toggle()
        local f = build()
        if f:IsShown() then f:Hide() else f:Show() end
    end
end
