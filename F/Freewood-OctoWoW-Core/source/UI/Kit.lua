-- Freewood-OctoWoW-Core: UI-Bausteine im Stil "Azeroth Codex"
-- Alles aus Farbflaechen, 1-Pixel-Raendern und Spielschriften. Keine eigenen Bilddateien.
-- Farben stammen aus den DESIGN.md-Dateien der Projektideen.

local ADDON, FW = ...

local UI = {}
FW.UI = UI

------------------------------------------------------------------------
-- Farben
------------------------------------------------------------------------

UI.hex = {
    bgDeep      = "0c0e14",
    bg          = "0f131f",
    panel       = "141824",
    card        = "1a2030",
    hover       = "242b40",
    gold        = "c89b3c",
    goldLight   = "f0bf5c",
    goldAntique = "dfb75c",
    bronze      = "9d7826",
    text        = "e6e2d6",
    textDim     = "9a978c",
    danger      = "e0645a",
    success     = "6cc070",
}

UI.rarity = {
    [0] = "9d9d9d", -- Schlecht
    [1] = "ffffff", -- Gewoehnlich
    [2] = "1eff00", -- Ungewoehnlich
    [3] = "0070dd", -- Selten
    [4] = "a335ee", -- Episch
    [5] = "ff8000", -- Legendaer
    [6] = "e6cc80", -- Artefakt
    [7] = "00ccff", -- Erbstueck
}

local colorCache = {}

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

-- key: Name aus UI.hex oder ein Hex-Wert wie "ff8000". Rueckgabe: r, g, b, a
function UI.Color(key, alpha)
    local c = colorCache[key]
    if not c then
        c = { HexToRGB(UI.hex[key] or key) }
        colorCache[key] = c
    end
    return c[1], c[2], c[3], alpha or 1
end

function UI.Hex(key)
    return UI.hex[key] or key
end

function UI.RarityHex(quality)
    return UI.rarity[quality or 1] or UI.rarity[1]
end

------------------------------------------------------------------------
-- Schriften
------------------------------------------------------------------------

function UI.GetFontPath(kind)
    if kind == "heading" then
        return "Fonts\\FRIZQT__.TTF"
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function UI.SetFont(fontString, kind, size, flags)
    local ok = fontString:SetFont(UI.GetFontPath(kind), size or 12, flags or "")
    if not ok then
        fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
end

-- opts: font ("body"/"heading"), size, color, justify, justifyV, flags, layer
function UI.CreateLabel(parent, text, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
    UI.SetFont(fs, opts.font or "body", opts.size or 12, opts.flags)
    fs:SetTextColor(UI.Color(opts.color or "text"))
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetJustifyV(opts.justifyV or "MIDDLE")
    fs:SetText(text or "")
    return fs
end

------------------------------------------------------------------------
-- Flaechen und Raender
------------------------------------------------------------------------

function UI.AddBorder(frame, colorKey, alpha, thickness)
    thickness = thickness or 1
    local b = {}

    b.top = frame:CreateTexture(nil, "BORDER")
    b.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    b.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    b.top:SetHeight(thickness)

    b.bottom = frame:CreateTexture(nil, "BORDER")
    b.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    b.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    b.bottom:SetHeight(thickness)

    b.left = frame:CreateTexture(nil, "BORDER")
    b.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -thickness)
    b.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, thickness)
    b.left:SetWidth(thickness)

    b.right = frame:CreateTexture(nil, "BORDER")
    b.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -thickness)
    b.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, thickness)
    b.right:SetWidth(thickness)

    frame.fwBorder = b
    UI.SetBorderColor(frame, colorKey, alpha)
    return b
end

function UI.SetBorderColor(frame, colorKey, alpha)
    local b = frame.fwBorder
    if not b then
        return
    end
    local r, g, bl, a = UI.Color(colorKey, alpha)
    b.top:SetColorTexture(r, g, bl, a)
    b.bottom:SetColorTexture(r, g, bl, a)
    b.left:SetColorTexture(r, g, bl, a)
    b.right:SetColorTexture(r, g, bl, a)
end

function UI.CreatePanel(parent, bgKey, borderKey)
    local p = CreateFrame("Frame", nil, parent)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints()
    p.bg:SetColorTexture(UI.Color(bgKey or "panel"))
    if borderKey then
        UI.AddBorder(p, borderKey)
    end
    return p
end

function UI.CreateDivider(parent, colorKey, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(UI.Color(colorKey or "bronze", alpha or 0.6))
    return t
end

------------------------------------------------------------------------
-- Tooltips
------------------------------------------------------------------------

-- title: Text oder Funktion; lines: Text, Liste von Texten oder Funktion
function UI.AttachTooltip(frame, title, lines, anchor)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        local t = type(title) == "function" and title() or title
        GameTooltip:SetText(t or "", 1, 1, 1)
        local l = type(lines) == "function" and lines() or lines
        if type(l) == "string" then
            l = { l }
        end
        for _, line in ipairs(l or {}) do
            GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

------------------------------------------------------------------------
-- Knoepfe
------------------------------------------------------------------------

local BUTTON_STYLES = {
    default = { bg = "card", bgHover = "hover",     border = "bronze",    borderHover = "gold",        text = "text" },
    primary = { bg = "gold", bgHover = "goldLight", border = "goldLight", borderHover = "goldAntique", text = "bgDeep" },
    ghost   = { bg = "bg",   bgHover = "hover",     border = "bg",        borderHover = "bronze",      text = "text" },
    -- Zerstoerende Aktionen: normal unauffaellig, beim Darueberfahren rot
    danger       = { bg = "card", bgHover = "hover", border = "bronze", borderHover = "danger", text = "text" },
    dangerActive = { bg = "card", bgHover = "hover", border = "danger", borderHover = "danger", text = "danger" },
}

local function RefreshButton(b)
    local style = BUTTON_STYLES[b.fwStyleName] or BUTTON_STYLES.default
    local enabled = b:IsEnabled() and true or false
    local hovered = b.fwHover and enabled
    b.bg:SetColorTexture(UI.Color(hovered and style.bgHover or style.bg))
    UI.SetBorderColor(b, hovered and style.borderHover or style.border)
    b.label:SetTextColor(UI.Color(style.text))
    b:SetAlpha(enabled and 1 or 0.45)
end

-- styleName: "default", "primary" oder "ghost"
function UI.CreateButton(parent, text, width, height, onClick, styleName)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, height or 28)
    b.fwStyleName = styleName or "default"

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    UI.AddBorder(b, (BUTTON_STYLES[b.fwStyleName] or BUTTON_STYLES.default).border)

    b.label = UI.CreateLabel(b, text, { size = 12, justify = "CENTER" })
    b.label:SetPoint("CENTER", 0, 0)

    b:SetScript("OnEnter", function(self)
        self = self or this
        if not self then return end
        self.fwHover = true
        RefreshButton(self)
    end)
    b:SetScript("OnLeave", function(self)
        self = self or this
        if not self then return end
        self.fwHover = false
        RefreshButton(self)
    end)
    b:SetScript("OnClick", function(self, ...)
        if onClick then
            onClick(self, ...)
        end
    end)

    function b:SetLabel(newText)
        self.label:SetText(newText)
    end
    function b:SetStyle(name)
        self.fwStyleName = name
        RefreshButton(self)
    end
    function b:SetButtonEnabled(on)
        if on then
            self:Enable()
        else
            self:Disable()
        end
        RefreshButton(self)
    end

    RefreshButton(b)
    return b
end

-- Tab-Knopf mit Goldlinie fuer den aktiven Zustand
function UI.CreateTabButton(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(34)

    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(UI.Color("hover", 0.5))
    b.hl:Hide()

    b.under = b:CreateTexture(nil, "ARTWORK")
    b.under:SetHeight(2)
    b.under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.under:SetColorTexture(UI.Color("gold"))
    b.under:Hide()

    b.label = UI.CreateLabel(b, text, { font = "heading", size = 13, color = "textDim", justify = "CENTER" })
    b.label:SetPoint("CENTER", 0, 1)
    b:SetWidth(math.max(90, b.label:GetStringWidth() + 36))

    function b:SetActive(active)
        self.fwActive = active
        if active then
            self.label:SetTextColor(UI.Color("goldLight"))
            self.under:Show()
            self.hl:Hide()
        else
            self.label:SetTextColor(UI.Color("textDim"))
            self.under:Hide()
        end
    end
    function b:SetLabel(newText)
        self.label:SetText(newText)
        self:SetWidth(math.max(90, self.label:GetStringWidth() + 36))
    end

    b:SetScript("OnEnter", function(self)
        if not self.fwActive then
            self.hl:Show()
            self.label:SetTextColor(UI.Color("text"))
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.hl:Hide()
        if not self.fwActive then
            self.label:SetTextColor(UI.Color("textDim"))
        end
    end)
    return b
end

------------------------------------------------------------------------
-- Kontrollkaestchen
------------------------------------------------------------------------

-- Hoehe eines umbrochenen Textes (Zeilen mal Zeilenhoehe, falls die Schrift keine Hoehe meldet)
function UI.TextHeight(fs, minHeight)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) ~= "number" or h <= 0 then
        h = 14
    end
    return math.max(h, minHeight or 0)
end

-- Text auf eine Breite setzen und umbrechen; gibt die Hoehe zurueck
function UI.FitLabel(fs, width, minHeight)
    if width and width > 0 then
        fs:SetWidth(width)
    end
    fs:SetWordWrap(true)
    fs:SetJustifyV("TOP")
    fs:SetHeight(0)   -- feste Hoehe aufheben, sonst misst die Schrift nur die abgeschnittene Hoehe
    local h = UI.TextHeight(fs, minHeight)
    fs:SetHeight(h)
    return h
end

-- Kontrollkaestchen. c:Fit(breite) setzt die Breite, bricht den Text um und passt die Hoehe an
-- (Rueckgabe: Hoehe). Haengt das Kaestchen links und rechts an einem Rahmen, passt es sich
-- beim Aendern der Fenstergroesse selbst an.
local CHECK_TEXT_X = 28
local CHECK_MIN_H = 22

function UI.CreateCheckbox(parent, labelText, getFn, setFn)
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(24)

    local box = UI.CreatePanel(c, "card", "bronze")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", c, "LEFT", 0, 0)

    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    check:SetColorTexture(UI.Color("goldLight"))

    c.label = UI.CreateLabel(c, labelText, { size = 12 })
    c.label:SetPoint("LEFT", box, "RIGHT", 10, 0)
    c:SetWidth(math.max(120, c.label:GetStringWidth() + 40))
    c.fitWidth = nil
    c.isFit = true

    function c:Fit(width)
        width = width or self:GetWidth()
        if not width or width <= 0 then
            return self:GetHeight()
        end
        if not self.fitWidth then
            -- erstes Fit: Kaestchen und Text oben ausrichten (mehrzeiliger Text)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -2)
            self.label:ClearAllPoints()
            self.label:SetPoint("TOPLEFT", self, "TOPLEFT", CHECK_TEXT_X, -4)
        end
        self.fitWidth = width
        self:SetWidth(width)
        self.label:SetWidth(math.max(40, width - CHECK_TEXT_X))
        self.label:SetWordWrap(true)
        self.label:SetJustifyV("TOP")
        self.label:SetHeight(0)
        local h = math.max(CHECK_MIN_H, UI.TextHeight(self.label, 14) + 8)
        self.label:SetHeight(h - 4)
        self:SetHeight(h)
        return h
    end

    function c:SetLabel(text)
        self.label:SetText(text or "")
        if self.fitWidth then
            self:Fit(self.fitWidth)
        end
    end

    c:SetScript("OnSizeChanged", function(self)
        -- Breite immer vom Rahmen selbst lesen (die Argumente des Ereignisses sind im Client nicht verlaesslich)
        local w = self:GetWidth()
        if self.fitWidth and type(w) == "number" and w > 0 and math.abs(w - self.fitWidth) > 0.5 then
            self:Fit(w)
        end
    end)

    function c:Refresh()
        if getFn() then
            check:Show()
        else
            check:Hide()
        end
    end

    c:SetScript("OnClick", function(self)
        setFn(not getFn())
        self:Refresh()
    end)
    c:SetScript("OnEnter", function()
        UI.SetBorderColor(box, "gold")
    end)
    c:SetScript("OnLeave", function()
        UI.SetBorderColor(box, "bronze")
    end)

    c:Refresh()
    return c
end

------------------------------------------------------------------------
-- Vertikaler Stapel: ordnet Bausteine untereinander an und passt sich der Breite an
--   local stack = UI.CreateStack(frame, { gap = 6, x = 0, y = 0 })
--   stack:Add(widget, { gap = 10, indent = 0, stretch = true, fit = true, height = 30 })
--     fit      Kontrollkaestchen/Text: wird auf die Breite umgebrochen, Hoehe folgt dem Text
--     stretch  Baustein haengt auch am rechten Rand (Trennlinien, Textblock)
--     height   feste Hoehe (sonst die aktuelle Hoehe des Bausteins)
--   stack:Layout() ordnet neu; stack.height ist die Gesamthoehe. Aenderungen der Breite des
--   Rahmens ordnen automatisch neu an (stack.onHeight wird danach gerufen).
------------------------------------------------------------------------

function UI.CreateStack(parent, opts)
    opts = opts or {}
    local stack = { items = {}, gap = opts.gap or 6, x = opts.x or 0, y = opts.y or 0, pad = opts.pad or 0, height = 0 }

    function stack:Add(widget, o)
        o = o or {}
        self.items[#self.items + 1] = { w = widget, gap = o.gap, indent = o.indent or 0, stretch = o.stretch,
            fit = o.fit, height = o.height, minHeight = o.minHeight }
        return widget
    end

    function stack:Width()
        local w = parent.GetWidth and parent:GetWidth() or 0
        return math.max(0, (w or 0) - self.x - self.pad)
    end

    function stack:Layout()
        local width = self:Width()
        local y = self.y
        for _, it in ipairs(self.items) do
            local w = it.w
            if not w.stackHidden then
                local avail = width - it.indent
                local h
                if it.fit then
                    if w.isFit then
                        h = w:Fit(avail)
                    else
                        h = UI.FitLabel(w, avail, it.minHeight)
                    end
                elseif it.height then
                    h = it.height
                    w:SetHeight(h)
                else
                    h = w:GetHeight() or 0
                end
                y = y + (it.gap or self.gap)
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT", parent, "TOPLEFT", self.x + it.indent, -y)
                if it.stretch then
                    w:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -self.pad, -y)
                end
                y = y + h
            end
        end
        self.height = y + self.pad
        if self.onHeight then
            self.onHeight(self.height)
        end
        return self.height
    end

    function stack:Hook()
        local old = parent.GetScript and parent:GetScript("OnSizeChanged")
        parent:SetScript("OnSizeChanged", function(f, w, h)
            if old then old(f, w, h) end
            w = f:GetWidth()
            if type(w) == "number" and w > 0 and math.abs(w - (stack.lastW or 0)) > 0.5 then
                stack.lastW = w
                stack:Layout()
            end
        end)
    end
    stack:Hook()
    return stack
end

------------------------------------------------------------------------
-- Schieberegler (waagerecht). Der Wert wird beim Loslassen uebernommen (setFn), waehrend des
-- Ziehens zeigt nur die Anzeige den Wert; so ruckelt nichts, wenn der Regler selbst die Groesse aendert.
--   local s = UI.CreateSlider(parent, 150, { min = 50, max = 150, step = 5, get = fn, set = fn, format = fn })
------------------------------------------------------------------------

function UI.CreateSlider(parent, width, opts)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(width or 150, 20)
    local lo, hi, step = opts.min or 0, opts.max or 100, opts.step or 1

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(UI.Color("card"))
    track:SetHeight(4)
    track:SetPoint("LEFT", s, "LEFT", 0, 0)
    track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(UI.Color("bronze"))
    fill:SetHeight(4)
    fill:SetPoint("LEFT", s, "LEFT", 0, 0)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 16)
    thumb:SetColorTexture(UI.Color("goldLight"))

    local value = lo
    local function Snap(v)
        v = math.floor((v - lo) / step + 0.5) * step + lo
        return math.max(lo, math.min(hi, v))
    end
    local function Show(v)
        value = Snap(v)
        local frac = (hi > lo) and ((value - lo) / (hi - lo)) or 0
        local travel = math.max(1, (s:GetWidth() or width or 150) - 8)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", s, "LEFT", frac * travel, 0)
        fill:SetWidth(math.max(1, frac * travel + 4))
        if s.onText then s.onText(value) end
    end

    function s:SetValue(v) Show(v) end
    function s:GetValue() return value end
    function s:Refresh() Show(opts.get and opts.get() or lo) end

    local function FromCursor()
        local x = GetCursorPosition()
        local scale = s:GetEffectiveScale() or 1
        local left = s:GetLeft()
        if not x or not left then return value end
        local travel = math.max(1, (s:GetWidth() or 150) - 8)
        local frac = ((x / scale) - left - 4) / travel
        return lo + math.max(0, math.min(1, frac)) * (hi - lo)
    end

    s:SetScript("OnMouseDown", function(self)
        Show(FromCursor())
        self:SetScript("OnUpdate", function() Show(FromCursor()) end)
    end)
    s:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        Show(FromCursor())
        if opts.set then opts.set(value) end
    end)
    s:SetScript("OnSizeChanged", function() Show(value) end)
    s:SetScript("OnEnter", function() thumb:SetColorTexture(UI.Color("gold")) end)
    s:SetScript("OnLeave", function() thumb:SetColorTexture(UI.Color("goldLight")) end)
    return s
end

------------------------------------------------------------------------
-- Scrollbereich mit schmaler eigener Leiste
-- Ergebnis: holder (Frame). holder.child ist der Inhalt, holder:SetContentHeight(h)
-- passt die Hoehe an. Groesse ueber SetSize oder Anker festlegen.
------------------------------------------------------------------------

function UI.CreateScrollFrame(parent, width, height)
    local holder = CreateFrame("Frame", nil, parent)
    if width and height then
        holder:SetSize(width, height)
    end

    local sf = CreateFrame("ScrollFrame", nil, holder)
    sf:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -12, 0)

    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)

    local track = holder:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(UI.Color("card", 0.7))
    track:SetWidth(6)
    track:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)

    local thumb = CreateFrame("Button", nil, holder)
    thumb:SetWidth(6)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(UI.Color("bronze"))
    thumb:Hide()
    thumb:SetScript("OnEnter", function()
        thumbTex:SetColorTexture(UI.Color("gold"))
    end)
    thumb:SetScript("OnLeave", function()
        thumbTex:SetColorTexture(UI.Color("bronze"))
    end)

    local contentHeight = 1

    local function MaxScroll()
        return math.max(0, contentHeight - sf:GetHeight())
    end

    local function Update()
        -- Breite des Inhalts nachziehen, falls OnSizeChanged sie nicht (rechtzeitig) gesetzt hat
        local sw = sf:GetWidth()
        if sw and sw > 1 and math.abs((child:GetWidth() or 0) - sw) > 0.5 then
            child:SetWidth(sw)
        end
        local viewH = sf:GetHeight()
        local range = MaxScroll()
        if range <= 0 or viewH <= 0 then
            thumb:Hide()
            track:Hide()
            sf:SetVerticalScroll(0)
            return
        end
        track:Show()
        local current = math.min(math.max(sf:GetVerticalScroll(), 0), range)
        if current ~= sf:GetVerticalScroll() then
            sf:SetVerticalScroll(current)
        end
        local thumbH = math.max(24, viewH * viewH / contentHeight)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(current / range) * (viewH - thumbH))
        thumb:Show()
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * 48
        self:SetVerticalScroll(math.min(math.max(target, 0), MaxScroll()))
        Update()
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        w = tonumber(w) or self:GetWidth()
        if w and w > 0 then
            child:SetWidth(w)
        end
        Update()
    end)

    thumb:SetScript("OnMouseDown", function(self)
        local _, startY = GetCursorPosition()
        local startScroll = sf:GetVerticalScroll()
        local scale = self:GetEffectiveScale()
        self:SetScript("OnUpdate", function()
            local _, y = GetCursorPosition()
            local free = sf:GetHeight() - self:GetHeight()
            if free <= 0 then
                return
            end
            local target = startScroll + ((startY - y) / scale) * (MaxScroll() / free)
            sf:SetVerticalScroll(math.min(math.max(target, 0), MaxScroll()))
            Update()
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    holder.scroll = sf
    holder.child = child
    holder.UpdateScroll = Update

    function holder:SetContentHeight(h)
        contentHeight = math.max(1, h)
        child:SetHeight(contentHeight)
        Update()
    end
    function holder:ScrollToTop()
        sf:SetVerticalScroll(0)
        Update()
    end

    return holder
end

------------------------------------------------------------------------
-- Mehrzeiliges Textfeld (zum Kopieren und Einfuegen von Codes)
-- Ergebnis: area (Frame) mit area.edit (EditBox)
------------------------------------------------------------------------

function UI.CreateTextArea(parent, width, height)
    local area = UI.CreateScrollFrame(parent, width, height)

    local back = area:CreateTexture(nil, "BACKGROUND", nil, -1)
    back:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
    back:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -12, 0)
    back:SetColorTexture(UI.Color("bgDeep", 0.9))

    local frame = CreateFrame("Frame", nil, area)
    frame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -12, 0)
    UI.AddBorder(frame, "bronze")

    local edit = CreateFrame("EditBox", nil, area.child)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(420000)
    edit:SetTextInsets(8, 8, 6, 6)
    edit:SetPoint("TOPLEFT", area.child, "TOPLEFT", 0, 0)
    edit:SetPoint("TOPRIGHT", area.child, "TOPRIGHT", 0, 0)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then
        edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    end
    edit:SetTextColor(UI.Color("text"))

    local function Resize()
        local h = math.max(area.scroll:GetHeight(), edit:GetHeight() or 0)
        area:SetContentHeight(h)
    end

    edit:SetScript("OnTextChanged", function()
        C_Timer.After(0, Resize)
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Klick in den leeren Bereich setzt den Cursor ins Feld
    area.scroll:EnableMouse(true)
    area.scroll:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)

    area.edit = edit
    function area:SetText(text)
        edit:SetText(text or "")
        C_Timer.After(0, Resize)
    end
    function area:GetText()
        return edit:GetText()
    end
    function area:SelectAll()
        edit:SetFocus()
        edit:HighlightText()
    end

    return area
end

------------------------------------------------------------------------
-- Item-Platz (Symbol mit Seltenheitsrahmen)
------------------------------------------------------------------------

function UI.CreateItemSlot(parent, size)
    size = size or 44
    local slot = UI.CreatePanel(parent, "bgDeep", "bronze")
    slot:SetSize(size, size)

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    function slot:SetItem(itemID)
        self.itemID = itemID
        if not itemID then
            self.icon:SetTexture(nil)
            UI.SetBorderColor(self, "bronze")
            return
        end
        FW.Util.RequestItem(itemID, function(info)
            if self.itemID ~= itemID or not info then
                return
            end
            self.icon:SetTexture(info.icon)
            UI.SetBorderColor(self, UI.RarityHex(info.quality))
        end)
    end

    return slot
end

------------------------------------------------------------------------
-- Kennzahl-Karte (kleine Beschriftung oben, Wert darunter)
-- card:SetValue(text, colorKey)
------------------------------------------------------------------------

function UI.CreateStatCard(parent, labelText, width, height)
    local card = UI.CreatePanel(parent, "card", "bronze")
    card:SetSize(width or 150, height or 54)

    card.label = UI.CreateLabel(card, labelText, { size = 10, color = "textDim", flags = "" })
    card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)

    card.value = UI.CreateLabel(card, "-", { font = "heading", size = 15, color = "text" })
    card.value:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)

    function card:SetValue(text, colorKey)
        self.value:SetText(text or "-")
        self.value:SetTextColor(UI.Color(colorKey or "text"))
    end
    function card:SetLabel(text)
        self.label:SetText(text)
    end

    return card
end

------------------------------------------------------------------------
-- Marke (eckig, kein Pillenformat), z. B. fuer Raenge und Filter
-- chip:SetText(text, colorKey)
------------------------------------------------------------------------

function UI.CreateChip(parent, text, colorKey)
    local chip = UI.CreatePanel(parent, "bgDeep", colorKey or "bronze")
    chip:SetHeight(20)

    chip.label = UI.CreateLabel(chip, text, { size = 11, color = colorKey or "goldLight", justify = "CENTER" })
    chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
    chip:SetWidth(math.max(28, chip.label:GetStringWidth() + 16))

    function chip:SetText(newText, newColorKey)
        self.label:SetText(newText)
        if newColorKey then
            self.label:SetTextColor(UI.Color(newColorKey))
            UI.SetBorderColor(self, newColorKey)
        end
        self:SetWidth(math.max(28, self.label:GetStringWidth() + 16))
    end

    return chip
end

------------------------------------------------------------------------
-- Dropdown-Auswahl
--   opts.prefix      Text vor dem Wert, zum Beispiel "Typ" ergibt "Typ: Waffe"
--   opts.allText     Text fuer "keine Auswahl" (Wert nil); fehlt er, gibt es diesen Eintrag nicht
--   opts.getOptions  Funktion, die eine Liste { { value = ..., text = ... }, ... } liefert (beim Oeffnen gelesen)
--   opts.textOf      Funktion(value) -> Text, spart das Lesen der ganzen Liste fuer die Beschriftung (optional)
--   opts.onChange    Funktion(value) nach einer Auswahl durch den Benutzer
--   opts.maxRows     sichtbare Zeilen, bevor gescrollt wird (Standard 12)
-- Rueckgabe: Button mit :SetValue(v), :GetValue(), :Refresh(), :Open(), :Close()
------------------------------------------------------------------------

local DD_ROW = 20
local ddPopup, ddCatcher, ddOwner

local function CloseDropdown()
    if ddPopup then ddPopup:Hide() end
    if ddCatcher then ddCatcher:Hide() end
    local owner = ddOwner
    ddOwner = nil
    if owner and owner.Refresh then owner:Refresh() end
end
UI.CloseDropdown = CloseDropdown

local function EnsureDropdownPopup()
    if ddPopup then
        return
    end
    -- unsichtbare Flaeche hinter der Liste: ein Klick daneben schliesst sie
    ddCatcher = CreateFrame("Button", nil, UIParent)
    ddCatcher:SetAllPoints(UIParent)
    ddCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    ddCatcher:RegisterForClicks("AnyUp")
    ddCatcher:SetScript("OnClick", CloseDropdown)
    ddCatcher:Hide()

    ddPopup = UI.CreatePanel(UIParent, "bgDeep", "gold")
    ddPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    ddPopup:SetFrameLevel((ddCatcher:GetFrameLevel() or 1) + 5)
    ddPopup:EnableMouse(true)
    ddPopup.list = UI.CreateScrollFrame(ddPopup)
    ddPopup.list:SetPoint("TOPLEFT", ddPopup, "TOPLEFT", 2, -2)
    ddPopup.list:SetPoint("BOTTOMRIGHT", ddPopup, "BOTTOMRIGHT", -2, 2)
    ddPopup.rows = {}
    ddPopup:Hide()
end

local function DropdownRow(index)
    local row = ddPopup.rows[index]
    if row then
        return row
    end
    local child = ddPopup.list.child
    row = CreateFrame("Button", nil, child)
    row:SetHeight(DD_ROW)
    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(index - 1) * DD_ROW)
    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(index - 1) * DD_ROW)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(UI.Color("hover", 0.9))
    row.hl:Hide()
    row.label = UI.CreateLabel(row, "", { size = 12 })
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.label:SetWordWrap(false)
    row:SetScript("OnEnter", function(self) self.hl:Show() end)
    row:SetScript("OnLeave", function(self) self.hl:Hide() end)
    row:SetScript("OnClick", function(self)
        local owner = ddOwner
        local value = self.value
        CloseDropdown()
        if owner then
            owner:SetValue(value)
            if owner.fwOnChange then owner.fwOnChange(value) end
        end
    end)
    ddPopup.rows[index] = row
    return row
end

function UI.CreateDropdown(parent, width, height, opts)
    opts = opts or {}
    local dd = UI.CreateButton(parent, "", width or 150, height or 20, nil, "default")
    dd.fwOnChange = opts.onChange
    dd.fwValue = nil

    dd.label:ClearAllPoints()
    dd.label:SetPoint("LEFT", dd, "LEFT", 8, 0)
    dd.label:SetPoint("RIGHT", dd, "RIGHT", -20, 0)
    dd.label:SetJustifyH("LEFT")
    dd.label:SetWordWrap(false)
    dd.arrow = dd:CreateTexture(nil, "OVERLAY")
    dd.arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    dd.arrow:SetTexCoord(0, 1, 1, 0)      -- Pfeil nach unten
    dd.arrow:SetVertexColor(UI.Color("goldLight"))
    dd.arrow:SetSize(12, 12)
    dd.arrow:SetPoint("RIGHT", dd, "RIGHT", -5, -1)

    local function Options()
        local list = {}
        if opts.allText then
            list[1] = { value = nil, text = opts.allText }
        end
        local given = opts.getOptions and opts.getOptions() or {}
        for _, o in ipairs(given) do
            list[#list + 1] = o
        end
        return list
    end

    local function TextOf(value)
        if value == nil then
            return opts.allText or ""
        end
        if opts.textOf then
            return opts.textOf(value)
        end
        for _, o in ipairs(Options()) do
            if o.value == value then
                return o.text
            end
        end
        return tostring(value)
    end

    -- Beschriftung und Hervorhebung nach dem Wert richten
    function dd:Refresh()
        local text = TextOf(self.fwValue)
        if opts.prefix then
            text = opts.prefix .. ": " .. text
        end
        self:SetLabel(text)
        if self.fwValue ~= nil or ddOwner == self then
            self:SetStyle("primary")
        else
            self:SetStyle("default")
        end
    end

    function dd:SetValue(value)
        self.fwValue = value
        self:Refresh()
    end

    function dd:GetValue()
        return self.fwValue
    end

    function dd:Close()
        if ddOwner == self then CloseDropdown() end
    end

    function dd:Open()
        EnsureDropdownPopup()
        local list = Options()
        if #list == 0 then
            return
        end
        ddOwner = self
        local rows = math.min(#list, opts.maxRows or 12)
        local w = math.max(self:GetWidth() or 0, 150)
        ddPopup:SetSize(w, rows * DD_ROW + 4)
        ddPopup:ClearAllPoints()
        local bottom = self:GetBottom()
        if bottom and bottom - (rows * DD_ROW + 8) < 0 then
            ddPopup:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)     -- unten kein Platz: darueber oeffnen
        else
            ddPopup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        end
        for i, o in ipairs(list) do
            local row = DropdownRow(i)
            row.value = o.value
            row.label:SetText(o.text)
            if o.value == self.fwValue then
                row.label:SetTextColor(UI.Color("goldLight"))
            else
                row.label:SetTextColor(UI.Color("text"))
            end
            row:Show()
        end
        for i = #list + 1, #ddPopup.rows do
            ddPopup.rows[i]:Hide()
        end
        ddPopup.list:SetContentHeight(#list * DD_ROW)
        ddPopup.list:ScrollToTop()
        ddCatcher:Show()
        ddPopup:Show()
        self:Refresh()
    end

    dd:SetScript("OnClick", function(self)
        if ddOwner == self then
            CloseDropdown()
        else
            if ddOwner then CloseDropdown() end
            self:Open()
        end
    end)
    dd:SetScript("OnHide", function(self) self:Close() end)

    dd:Refresh()
    return dd
end
