-- Freewood-OctoWoW-Core: Reiter "Kanaele" als Chatfenster (Kategorien links, Chat Mitte, Mitglieder rechts).
-- ALLES UNGEPRUEFT im Spiel. Datenschicht: Core/Channels.lua (Mitglieder) und Core/ChatLog.lua (Verlauf).

local ADDON, FW = ...

local UI = FW.UI
local Ch = FW.Channels
local CL = FW.ChatLog

local WIDE_W, NARROW_W, RIGHT_W = 270, 56, 220
local ROW = 24
local MAX_BUBBLES = 60
local LOG_CHARS = 4000
local LOGO = "Interface\\AddOns\\Freewood-OctoWoW-Core\\Media\\FreeWood_Logo.tga"
local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local ICONS = {
    general = "Interface\\Icons\\INV_Misc_Note_01",
    localdefense = "Interface\\Icons\\INV_Shield_06",
    world = "Interface\\Icons\\INV_Misc_Map_01",
    lookingforgroup = "Interface\\Icons\\INV_Misc_Eye_01",
    lft = "Interface\\Icons\\INV_Misc_Bell_01",
}
local ICON_GUILD = "Interface\\Icons\\INV_Shirt_GuildTabard_01"
local ICON_GROUP = "Interface\\Icons\\Spell_Holy_PrayerOfHealing"
local ICON_WHISPER = "Interface\\Icons\\INV_Letter_02"

local STD = { general = true, localdefense = true, world = true, lookingforgroup = true,
    allgemein = true, lokaleverteidigung = true }

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- Klassenbilder: normale Zaubersymbole (die Klassen-Bildtafel des Clients ist hier nicht brauchbar)
local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    MAGE = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    ROGUE = "Interface\\Icons\\Ability_Stealth",
    DRUID = "Interface\\Icons\\Spell_Nature_HealingTouch",
    HUNTER = "Interface\\Icons\\Ability_Marksmanship",
    SHAMAN = "Interface\\Icons\\Spell_Nature_BloodLust",
    PRIEST = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    WARLOCK = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    PALADIN = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

local function SetClassIcon(tex, token)
    tex:SetTexture((token and CLASS_ICONS[token]) or QMARK)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function SetIcon(tex, path)
    tex:SetTexture(path or QMARK)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local G_date = _G.date
local function TimeText(t)
    if not (t and G_date) then return "" end
    local ok, s = pcall(G_date, "%d.%m. %H:%M", t)
    return ok and s or ""
end

-- "Mo 02.11. 00:08"
local function Stamp(t, L)
    if not (t and G_date) then return "" end
    local ok, tb = pcall(G_date, "*t", t)
    local wd = (ok and type(tb) == "table" and tb.wday and L["CHAT_WD" .. tb.wday]) or ""
    local ok2, s = pcall(G_date, "%d.%m. %H:%M", t)
    return wd .. " " .. (ok2 and s or "")
end

local function DayKey(t)
    if not (t and G_date) then return "" end
    local ok, s = pcall(G_date, "%Y%m%d", t)
    return ok and s or ""
end

local function DayText(t, L)
    if not (t and G_date) then return "" end
    local ok, tb = pcall(G_date, "*t", t)
    local wd = (ok and type(tb) == "table" and tb.wday and L["CHAT_WD" .. tb.wday]) or ""
    local ok2, s = pcall(G_date, "%d.%m.%Y", t)
    return wd .. " " .. (ok2 and s or "")
end

-- Seitenleisten-Aufteilung (gespeichert im Konto)
local BUILTIN = { "std", "other", "guild", "group", "whisper", "service" }
local CHANNEL_CATS = { std = true, other = true, service = true }
local tmpLayout = { order = {}, cats = {}, assign = {} }

local function Layout()
    local d = _G.FreewoodDB
    local l
    if type(d) == "table" then
        if type(d.chatLayout) ~= "table" then d.chatLayout = {} end
        l = d.chatLayout
    else
        l = tmpLayout
    end
    if type(l.order) ~= "table" then l.order = {} end
    if type(l.cats) ~= "table" then l.cats = {} end
    if type(l.assign) ~= "table" then l.assign = {} end
    local have = {}
    local k = 1
    while k <= table.getn(l.order) do have[l.order[k]] = true; k = k + 1 end
    k = 1
    while k <= table.getn(BUILTIN) do
        if not have[BUILTIN[k]] then l.order[table.getn(l.order) + 1] = BUILTIN[k] end
        k = k + 1
    end
    return l
end

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    f:SetAllPoints(content)

    local selKey = nil
    local entries = {}
    local search = ""
    local seen = { cl = -1, ch = -1, w = 0 }
    local stick = true
    local lastH, lastViewH = 0, 0

    ------------------------------------------------------------------
    -- Kopierfeld und Menue (gemeinsam)
    ------------------------------------------------------------------
    local copy = UI.CreatePanel(UIParent, "bgDeep", "gold")
    copy:SetSize(560, 96)
    copy:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    copy:SetFrameStrata("FULLSCREEN_DIALOG")
    copy:Hide()
    local copyHint = UI.CreateLabel(copy, L.CHAT_COPY_HINT, { size = 11, color = "textDim" })
    copyHint:SetPoint("TOPLEFT", copy, "TOPLEFT", 12, -8)
    local cbox = UI.CreatePanel(copy, "bg", "bronze")
    cbox:SetPoint("TOPLEFT", copy, "TOPLEFT", 10, -28)
    cbox:SetPoint("TOPRIGHT", copy, "TOPRIGHT", -10, -28)
    cbox:SetHeight(26)
    local cedit = CreateFrame("EditBox", nil, cbox)
    cedit:SetAutoFocus(false)
    cedit:SetPoint("TOPLEFT", cbox, "TOPLEFT", 6, -3)
    cedit:SetPoint("BOTTOMRIGHT", cbox, "BOTTOMRIGHT", -6, 3)
    cedit:SetMaxLetters(600)
    if not cedit:SetFont(UI.GetFontPath("body"), 12, "") then cedit:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    cedit:SetTextColor(UI.Color("text"))
    cedit:SetScript("OnEscapePressed", function() copy:Hide() end)
    local copyMsg, copyUrl
    local bMsg = UI.CreateButton(copy, L.CHAT_COPY_MSG, 100, 24, function()
        if copyMsg then cedit:SetText(copyMsg); cedit:SetFocus(); cedit:HighlightText() end
    end)
    bMsg:SetPoint("BOTTOMLEFT", copy, "BOTTOMLEFT", 10, 8)
    local bUrl = UI.CreateButton(copy, L.CHAT_COPY_LINK, 100, 24, function()
        if copyUrl then cedit:SetText(copyUrl); cedit:SetFocus(); cedit:HighlightText() end
    end)
    bUrl:SetPoint("LEFT", bMsg, "RIGHT", 6, 0)
    local bX = UI.CreateButton(copy, "X", 30, 24, function() copy:Hide() end)
    bX:SetPoint("BOTTOMRIGHT", copy, "BOTTOMRIGHT", -10, 8)

    local function ShowCopy(text, url)
        copyMsg, copyUrl = text, url
        cedit:SetText(text or "")
        if url then bUrl:Show() else bUrl:Hide() end
        copy:Show()
        cedit:SetFocus()
        cedit:HighlightText()
    end

    local menu, menuCatcher, menuTitle
    local menuName
    local selectKey, Redraw
    local input
    local function HideMenu()
        if menu then menu:Hide() end
        if menuCatcher then menuCatcher:Hide() end
    end
    local function BuildMenu()
        menuCatcher = CreateFrame("Button", nil, UIParent)
        menuCatcher:SetAllPoints(UIParent)
        menuCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        menuCatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        menuCatcher:SetScript("OnClick", HideMenu)
        menuCatcher:Hide()
        menu = UI.CreatePanel(UIParent, "bgDeep", "gold")
        menu:SetSize(180, 28 + 6 * 24 + 8)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(menuCatcher:GetFrameLevel() + 5)
        menu:Hide()
        menuTitle = UI.CreateLabel(menu, "", { size = 12, color = "gold" })
        menuTitle:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8)
        local acts = {
            { L.CHAN_WHISPER, function(n)
                CL.OpenWhisper(n)
                if selectKey then selectKey("w:" .. n) end
                if input then input:SetFocus() end
            end },
            { L.CHAN_INVITE, function(n) Ch.Invite(n) end },
            { L.CHAN_IGNORE, function(n) Ch.Ignore(n) end },
            { L.CHAT_MENU_FRIEND, function(n) if _G.AddFriend then pcall(_G.AddFriend, n) end end },
            { L.CHAT_MENU_WHO, function(n) CL.Ask(n, true) end },
            { L.CHAT_MENU_COPY, function(n) ShowCopy(n, nil) end },
        }
        local i = 1
        while i <= 6 do
            local a = acts[i]
            local b = UI.CreateButton(menu, a[1], 164, 22, function()
                local n = menuName
                HideMenu()
                if n then a[2](n) end
            end)
            b:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -28 - (i - 1) * 24)
            i = i + 1
        end
    end
    local function ShowMenu(name)
        if not name or name == "" then return end
        if not menu then BuildMenu() end
        menuName = name
        menuTitle:SetText(name)
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc, y / sc)
        menuCatcher:Show()
        menu:Show()
    end

    ------------------------------------------------------------------
    -- Kleine Bausteine: Listenmenue und Eingabefenster
    ------------------------------------------------------------------
    local lmenu, lcatcher, ltitle, lbtns
    local function HideList()
        if lmenu then lmenu:Hide() end
        if lcatcher then lcatcher:Hide() end
    end
    local function ShowList(title, items)
        if not lmenu then
            lcatcher = CreateFrame("Button", nil, UIParent)
            lcatcher:SetAllPoints(UIParent)
            lcatcher:SetFrameStrata("FULLSCREEN_DIALOG")
            lcatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            lcatcher:SetScript("OnClick", HideList)
            lcatcher:Hide()
            lmenu = UI.CreatePanel(UIParent, "bgDeep", "gold")
            lmenu:SetWidth(280)
            lmenu:SetFrameStrata("FULLSCREEN_DIALOG")
            lmenu:SetFrameLevel(lcatcher:GetFrameLevel() + 5)
            lmenu:Hide()
            ltitle = UI.CreateLabel(lmenu, "", { size = 12, color = "gold" })
            ltitle:SetPoint("TOPLEFT", lmenu, "TOPLEFT", 10, -8)
            lbtns = {}
        end
        ltitle:SetText(title or "")
        local n = table.getn(items)
        local i = 1
        while i <= n do
            local b = lbtns[i]
            if not b then
                b = UI.CreateButton(lmenu, "", 264, 22, nil)
                b:SetPoint("TOPLEFT", lmenu, "TOPLEFT", 8, -28 - (i - 1) * 24)
                lbtns[i] = b
            end
            local it = items[i]
            b:SetLabel(it[1])
            b:SetScript("OnClick", function()
                HideList()
                it[2]()
            end)
            b:Show()
            i = i + 1
        end
        while lbtns[i] do lbtns[i]:Hide(); i = i + 1 end
        local h = 28 + n * 24 + 8
        lmenu:SetHeight(h)
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        lmenu:ClearAllPoints()
        if y / sc - h < 0 then
            lmenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / sc, y / sc)
        else
            lmenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc, y / sc)
        end
        lcatcher:Show()
        lmenu:Show()
    end

    local dlg, dlgTitle, dlgL1, dlgL2, dlgE1, dlgE2, dlgOk
    local function ShowDialog(title, label1, label2, preset, onOk)
        if not dlg then
            dlg = UI.CreatePanel(UIParent, "bgDeep", "gold")
            dlg:SetSize(360, 190)
            dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            dlg:SetFrameStrata("FULLSCREEN_DIALOG")
            dlg:Hide()
            dlgTitle = UI.CreateLabel(dlg, "", { font = "heading", size = 14, color = "gold" })
            dlgTitle:SetPoint("TOPLEFT", dlg, "TOPLEFT", 14, -12)
            local function MakeEdit(y)
                local lab = UI.CreateLabel(dlg, "", { size = 11, color = "textDim" })
                lab:SetPoint("TOPLEFT", dlg, "TOPLEFT", 14, y)
                local bx = UI.CreatePanel(dlg, "bg", "bronze")
                bx:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12, y - 16)
                bx:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -12, y - 16)
                bx:SetHeight(26)
                local e = CreateFrame("EditBox", nil, bx)
                e:SetAutoFocus(false)
                e:SetPoint("TOPLEFT", bx, "TOPLEFT", 6, -3)
                e:SetPoint("BOTTOMRIGHT", bx, "BOTTOMRIGHT", -6, 3)
                e:SetMaxLetters(40)
                if not e:SetFont(UI.GetFontPath("body"), 12, "") then e:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
                e:SetTextColor(UI.Color("text"))
                e:SetScript("OnEscapePressed", function() dlg:Hide() end)
                return lab, bx, e
            end
            local bx1, bx2
            dlgL1, bx1, dlgE1 = MakeEdit(-42)
            dlgL2, bx2, dlgE2 = MakeEdit(-90)
            dlg.bx2 = bx2
            local function Ok()
                local fn = dlg.onOk
                local v1 = dlgE1:GetText() or ""
                local v2 = dlgE2:GetText() or ""
                dlg:Hide()
                if fn then fn(v1, v2) end
            end
            dlgE1:SetScript("OnEnterPressed", Ok)
            dlgE2:SetScript("OnEnterPressed", Ok)
            dlgOk = UI.CreateButton(dlg, L.CHAT_OK, 100, 26, Ok, "primary")
            dlgOk:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -12, 12)
            local cancel = UI.CreateButton(dlg, L.CHAT_CANCEL, 100, 26, function() dlg:Hide() end)
            cancel:SetPoint("RIGHT", dlgOk, "LEFT", -8, 0)
        end
        dlg.onOk = onOk
        dlgTitle:SetText(title)
        dlgL1:SetText(label1 or "")
        dlgE1:SetText(preset or "")
        if label2 then
            dlgL2:SetText(label2); dlgL2:Show(); dlg.bx2:Show(); dlgE2:Show()
        else
            dlgL2:Hide(); dlg.bx2:Hide(); dlgE2:Hide()
        end
        dlgE2:SetText("")
        dlg:Show()
        dlgE1:SetFocus()
    end

    ------------------------------------------------------------------
    -- Linke Spalte: Kategorien und Chats
    ------------------------------------------------------------------
    local leftW = WIDE_W
    local narrow = false
    local visCats = {}
    local ApplyLayout

    local left = UI.CreateScrollFrame(f)
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -26)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 40)
    left:SetWidth(leftW)
    local lrows = {}

    local tog = UI.CreateButton(f, "<", 24, 20, function()
        narrow = not narrow
        Layout().narrow = narrow or nil
        ApplyLayout()
        Redraw()
    end)
    local addBtn

    local function CatName(id)
        local l = Layout()
        if l.cats[id] then return l.cats[id].name end
        if id == "std" then return L.CHAT_CAT_STD end
        if id == "other" then return L.CHAT_CAT_OTHER end
        if id == "guild" then return L.CHAT_CAT_GUILD end
        if id == "group" then return L.CHAT_CAT_GROUP end
        if id == "whisper" then return L.CHAT_CAT_WHISPER end
        if id == "service" then return L.CHAT_CAT_SERVICE end
        return tostring(id)
    end

    local function CatValid(id)
        local l = Layout()
        return id and (CHANNEL_CATS[id] or l.cats[id]) and true or false
    end

    local function MoveCat(id, dir)
        local l = Layout()
        local at
        local k = 1
        while k <= table.getn(visCats) do
            if visCats[k] == id then at = k end
            k = k + 1
        end
        local other = at and visCats[at + dir]
        if not other then return end
        local ia, ib
        k = 1
        while k <= table.getn(l.order) do
            if l.order[k] == id then ia = k end
            if l.order[k] == other then ib = k end
            k = k + 1
        end
        if ia and ib then l.order[ia], l.order[ib] = l.order[ib], l.order[ia] end
        Redraw()
    end

    local function DeleteCat(id)
        local l = Layout()
        l.cats[id] = nil
        local new, k = {}, 1
        while k <= table.getn(l.order) do
            if l.order[k] ~= id then new[table.getn(new) + 1] = l.order[k] end
            k = k + 1
        end
        l.order = new
        Redraw()
    end

    local function NewCat(name)
        name = string.gsub(name or "", "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        if name == "" then return end
        local l = Layout()
        l.seq = (l.seq or 0) + 1
        local id = "u" .. l.seq
        l.cats[id] = { name = name }
        l.order[table.getn(l.order) + 1] = id
        Redraw()
    end

    local function JoinDialog(catId)
        local title = L.CHAT_DLG_JOIN .. "  (" .. L.CHAT_SLOTS .. Ch.FreeSlots() .. ")"
        ShowDialog(title, L.CHAT_DLG_NAME, L.CHAT_DLG_PW, "", function(name, pw)
            name = string.gsub(name or "", "^%s+", "")
            name = string.gsub(name, "%s+$", "")
            if name == "" then return end
            local ok, why = Ch.Join(name, pw, catId)
            if not ok and why == "full" then FW:Print(L.CHAT_FULL) end
        end)
    end

    local function AddMenu()
        ShowList(L.CHAT_SLOTS .. Ch.FreeSlots(), {
            { L.CHAT_MENU_JOIN, function() JoinDialog(nil) end },
            { L.CHAT_MENU_NEWCAT, function()
                ShowDialog(L.CHAT_DLG_NEWCAT, L.CHAT_DLG_CATNAME, nil, L.CHAT_NEWCAT_DEFAULT, NewCat)
            end },
        })
    end

    addBtn = UI.CreateButton(f, L.CHAT_ADD, WIDE_W - 6, 30, AddMenu, "primary")

    local function ChannelMenu(en)
        local l = Layout()
        local items = {}
        local k = 1
        while k <= table.getn(l.order) do
            local id = l.order[k]
            if CatValid(id) and id ~= en.cat then
                local target = id
                items[table.getn(items) + 1] = { L.CHAT_MOVE_TO .. CatName(id), function()
                    l.assign[en.key] = target
                    Redraw()
                end }
            end
            k = k + 1
        end
        if l.assign[en.key] then
            items[table.getn(items) + 1] = { L.CHAT_MOVE_RESET, function()
                l.assign[en.key] = nil
                Redraw()
            end }
        end
        if en.e and not string.find(en.e.name, "^Freewood") then
            local nm = en.e.name
            items[table.getn(items) + 1] = { L.CHAT_LEAVE, function() Ch.Leave(nm) end }
        end
        if table.getn(items) > 0 then ShowList(en.label, items) end
    end

    local function LeftRow(i)
        local r = lrows[i]
        if not r then
            r = CreateFrame("Button", nil, left.child)
            r:SetHeight(ROW)
            r:SetPoint("TOPLEFT", left.child, "TOPLEFT", 0, -(i - 1) * ROW)
            r:SetPoint("TOPRIGHT", left.child, "TOPRIGHT", 0, -(i - 1) * ROW)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r.sel = r:CreateTexture(nil, "BACKGROUND")
            r.sel:SetAllPoints()
            r.sel:SetColorTexture(UI.Color("bronze", 0.35))
            r.hl = r:CreateTexture(nil, "HIGHLIGHT")
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(UI.Color("gold", 0.15))
            r.line = r:CreateTexture(nil, "ARTWORK")
            r.line:SetColorTexture(UI.Color("bronze", 0.6))
            r.line:SetHeight(1)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(20, 20)
            r.text = UI.CreateLabel(r, "", { size = 12, justify = "LEFT" })
            r.x = CreateFrame("Button", nil, r)
            r.x:SetSize(18, 18)
            r.x:SetPoint("RIGHT", r, "RIGHT", -4, 0)
            r.xt = UI.CreateLabel(r.x, "x", { size = 13, color = "textDim" })
            r.xt:SetPoint("CENTER", r.x, "CENTER", 0, 0)
            r.x:SetScript("OnEnter", function() r.xt:SetTextColor(UI.Color("danger")) end)
            r.x:SetScript("OnLeave", function() r.xt:SetTextColor(UI.Color("textDim")) end)
            r.hb = {}
            local labels = { "+", "^", "v", "x" }
            local j = 1
            while j <= 4 do
                local b = CreateFrame("Button", nil, r)
                b:SetSize(18, 18)
                b.t = UI.CreateLabel(b, labels[j], { size = 13, color = "textDim" })
                b.t:SetPoint("CENTER", b, "CENTER", 0, 0)
                b:SetScript("OnEnter", function() b.t:SetTextColor(UI.Color("gold")) end)
                b:SetScript("OnLeave", function() b.t:SetTextColor(UI.Color("textDim")) end)
                b:Hide()
                r.hb[j] = b
                j = j + 1
            end
            lrows[i] = r
        end
        return r
    end

    local function BuildEntries()
        local l = Layout()
        -- neu beigetretene Kanaele ihrer gewuenschten Kategorie zuordnen
        local k = 1
        while k <= table.getn(Ch.list) do
            local lowName = string.lower(Ch.list[k].name)
            local pc = Ch.pendingCat[lowName]
            if pc then
                l.assign["c:" .. Ch.list[k].name] = pc
                Ch.pendingCat[lowName] = nil
            end
            k = k + 1
        end
        local items = {}
        local function Put(cat, en)
            if not items[cat] then items[cat] = {} end
            en.cat = cat
            items[cat][table.getn(items[cat]) + 1] = en
        end
        k = 1
        while k <= table.getn(Ch.list) do
            local e = Ch.list[k]
            local low = string.lower(e.name)
            local en = { key = "c:" .. e.name, kind = "channel", num = e.num, label = e.num .. ". " .. e.name,
                count = e.stamp and e.count or nil, e = e, mode = "bubble", icon = ICONS[low] or ICONS.general }
            local def
            if string.find(e.name, "^Freewood") then
                en.mode = "data"; en.logo = true; def = "service"
            elseif low == "lft" then
                en.mode = "log"; en.icon = ICONS.lft; def = "service"
            elseif STD[low] then
                def = "std"
            else
                def = "other"
            end
            local cat = l.assign[en.key]
            if not CatValid(cat) then cat = def end
            Put(cat, en)
            k = k + 1
        end
        Put("guild", { key = "guild", kind = "guild", mode = "bubble", label = L.CHAT_GUILD, icon = ICON_GUILD,
            count = table.getn(CL.guild) })
        Put("group", { key = "group", kind = "group", mode = "bubble", label = L.CHAT_GROUP, icon = ICON_GROUP })
        local ws = CL.OpenWhispers()
        k = 1
        while k <= table.getn(ws) do
            Put("whisper", { key = "w:" .. ws[k].name, kind = "whisper", mode = "bubble", label = ws[k].name,
                icon = ICON_WHISPER, closable = true, name = ws[k].name })
            k = k + 1
        end

        local out = {}
        visCats = {}
        k = 1
        while k <= table.getn(l.order) do
            local id = l.order[k]
            local custom = l.cats[id] ~= nil
            local known = custom or id == "std" or id == "other" or id == "guild" or id == "group"
                or id == "whisper" or id == "service"
            local list = items[id]
            local cnt = list and table.getn(list) or 0
            if known and (custom or cnt > 0 or id == "whisper") then
                visCats[table.getn(visCats) + 1] = id
                out[table.getn(out) + 1] = { head = CatName(id), cat = id, custom = custom }
                local m = 1
                while m <= cnt do out[table.getn(out) + 1] = list[m]; m = m + 1 end
                if cnt == 0 then
                    if id == "whisper" then
                        out[table.getn(out) + 1] = { note = L.CHAT_NOWHISPER }
                    else
                        out[table.getn(out) + 1] = { note = L.CHAT_EMPTY_CAT }
                    end
                end
            end
            k = k + 1
        end
        return out
    end

    local function EntryByKey(key)
        local k = 1
        while k <= table.getn(entries) do
            if entries[k].key == key then return entries[k] end
            k = k + 1
        end
        return nil
    end

    local function FirstEntry()
        local k = 1
        while k <= table.getn(entries) do
            if entries[k].key then return entries[k] end
            k = k + 1
        end
        return nil
    end

    local function Tip(r, text)
        r:SetScript("OnEnter", function()
            if GameTooltip then
                pcall(GameTooltip.SetOwner, GameTooltip, r, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetText, GameTooltip, text)
                pcall(GameTooltip.Show, GameTooltip)
            end
        end)
        r:SetScript("OnLeave", function()
            if GameTooltip then pcall(GameTooltip.Hide, GameTooltip) end
        end)
    end

    local function DrawLeft()
        entries = BuildEntries()
        if not selKey or not EntryByKey(selKey) then
            local fe = FirstEntry()
            selKey = fe and fe.key or nil
            stick = true
        end
        local n = table.getn(entries)
        local i = 1
        local y = 0
        while i <= n do
            local en = entries[i]
            local r = LeftRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", left.child, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", left.child, "TOPRIGHT", 0, -y)
            r.x:Hide()
            r.line:Hide()
            r:SetScript("OnEnter", nil)
            r:SetScript("OnLeave", nil)
            local j = 1
            while j <= 4 do r.hb[j]:Hide(); j = j + 1 end
            r.text:ClearAllPoints()
            r.icon:ClearAllPoints()
            if en.head then
                r.sel:Hide(); r.hl:Hide(); r.icon:Hide()
                r:SetScript("OnClick", nil)
                if narrow then
                    r:SetHeight(14)
                    r.text:SetText("")
                    r.line:ClearAllPoints()
                    r.line:SetPoint("LEFT", r, "LEFT", 8, -2)
                    r.line:SetPoint("RIGHT", r, "RIGHT", -8, -2)
                    r.line:Show()
                    Tip(r, en.head)
                    y = y + 14
                else
                    r:SetHeight(26)
                    r.text:SetText(Hex(UI.Color("gold")) .. string.upper(en.head) .. "|r")
                    local cat = en.cat
                    local btns = en.custom and { r.hb[4], r.hb[3], r.hb[2], r.hb[1] } or { r.hb[3], r.hb[2] }
                    local x = -4
                    j = 1
                    while j <= table.getn(btns) do
                        btns[j]:ClearAllPoints()
                        btns[j]:SetPoint("RIGHT", r, "RIGHT", x, -4)
                        btns[j]:Show()
                        x = x - 18
                        j = j + 1
                    end
                    r.text:SetPoint("LEFT", r, "LEFT", 8, -4)
                    r.text:SetPoint("RIGHT", r, "RIGHT", x - 2, -4)
                    r.hb[3]:SetScript("OnClick", function() MoveCat(cat, 1) end)
                    r.hb[2]:SetScript("OnClick", function() MoveCat(cat, -1) end)
                    if en.custom then
                        r.hb[1]:SetScript("OnClick", function() JoinDialog(cat) end)
                        r.hb[4]:SetScript("OnClick", function() DeleteCat(cat) end)
                        r:SetScript("OnClick", function()
                            ShowDialog(L.CHAT_DLG_RENAME, L.CHAT_DLG_CATNAME, nil, CatName(cat), function(v)
                                v = string.gsub(v or "", "^%s+", "")
                                v = string.gsub(v, "%s+$", "")
                                if v ~= "" then Layout().cats[cat].name = v; Redraw() end
                            end)
                        end)
                    end
                    y = y + 26
                end
            elseif en.note then
                r.sel:Hide(); r.hl:Hide(); r.icon:Hide()
                r:SetScript("OnClick", nil)
                if narrow then
                    r:SetHeight(4)
                    r.text:SetText("")
                    y = y + 4
                else
                    r:SetHeight(46)
                    r.text:SetPoint("LEFT", r, "LEFT", 10, 0)
                    r.text:SetPoint("RIGHT", r, "RIGHT", -8, 0)
                    r.text:SetText("|cff9a978c" .. en.note .. "|r")
                    y = y + 46
                end
            else
                r:SetHeight(ROW)
                r.hl:Show(); r.icon:Show()
                if en.logo then
                    r.icon:SetTexture(LOGO); r.icon:SetTexCoord(0, 1, 0, 1)
                else
                    SetIcon(r.icon, en.icon)
                end
                if narrow then
                    r.icon:SetPoint("CENTER", r, "CENTER", 0, 0)
                    r.text:SetText("")
                    local txt = en.label
                    Tip(r, txt)
                else
                    r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
                    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
                    r.text:SetPoint("RIGHT", r, "RIGHT", en.closable and -26 or -6, 0)
                    local txt = en.label
                    if en.count then txt = txt .. "  |cff9a978c(" .. en.count .. ")|r" end
                    local un = CL.unread[en.key]
                    if un and un > 0 and en.key ~= selKey then txt = txt .. "  |cffc89b3c+" .. un .. "|r" end
                    r.text:SetText(txt)
                end
                if en.key == selKey then r.sel:Show() else r.sel:Hide() end
                local key = en.key
                local ent = en
                r:SetScript("OnClick", function(_, btn)
                    btn = btn or arg1
                    if btn == "RightButton" and ent.kind == "channel" then
                        ChannelMenu(ent)
                    else
                        selectKey(key)
                    end
                end)
                if en.closable and not narrow then
                    local nm = en.name
                    r.x:Show()
                    r.x:SetScript("OnClick", function()
                        CL.CloseWhisper(nm)
                        if selKey == "w:" .. nm then selKey = nil end
                        Redraw()
                    end)
                end
                y = y + ROW
            end
            r:Show()
            i = i + 1
        end
        while lrows[i] do lrows[i]:Hide(); i = i + 1 end
        left:SetContentHeight(math.max(1, y))
    end

    ------------------------------------------------------------------
    -- Mitte: Kopf, Chat (Blasen / Log), Eingabe
    ------------------------------------------------------------------
    local head = UI.CreateLabel(f, "", { font = "heading", size = 15, color = "gold", justify = "LEFT" })
    head:SetPoint("TOPLEFT", f, "TOPLEFT", leftW + 14, -2)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 14), -2)
    local sub = UI.CreateLabel(f, "", { size = 11, color = "textDim", justify = "LEFT" })
    sub:SetPoint("TOPLEFT", f, "TOPLEFT", leftW + 14, -24)
    sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 14), -24)

    local chat = UI.CreateScrollFrame(f)
    chat:SetPoint("TOPLEFT", f, "TOPLEFT", leftW + 14, -44)
    chat:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14), 40)

    local logArea = UI.CreateTextArea(f)
    logArea:SetPoint("TOPLEFT", f, "TOPLEFT", leftW + 14, -44)
    logArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14), 40)
    logArea:Hide()

    local empty = UI.CreateLabel(f, "", { size = 12, color = "textDim", justify = "LEFT", justifyV = "TOP" })
    empty:SetPoint("TOPLEFT", f, "TOPLEFT", leftW + 24, -56)
    empty:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 24), -56)
    empty:SetHeight(60)

    local measure = f:CreateFontString(nil, "OVERLAY")
    UI.SetFont(measure, "body", 12)
    measure:Hide()

    local ibox = UI.CreatePanel(f, "bgDeep", "bronze")
    ibox:SetHeight(28)
    ibox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", leftW + 14, 6)
    ibox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14 + 96), 6)
    input = CreateFrame("EditBox", nil, ibox)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", ibox, "TOPLEFT", 8, -3)
    input:SetPoint("BOTTOMRIGHT", ibox, "BOTTOMRIGHT", -8, 3)
    input:SetMaxLetters(255)
    if not input:SetFont(UI.GetFontPath("body"), 12, "") then input:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    input:SetTextColor(UI.Color("text"))
    local ihint = UI.CreateLabel(ibox, L.CHAT_INPUT, { size = 12, color = "textDim" })
    ihint:SetPoint("LEFT", ibox, "LEFT", 10, 0)
    local function DoSend()
        local txt = input:GetText() or ""
        local en = selKey and EntryByKey(selKey)
        if txt == "" or not en then return end
        if en.kind == "channel" then CL.Send("channel", en.num, txt)
        elseif en.kind == "guild" then CL.Send("guild", nil, txt)
        elseif en.kind == "group" then CL.Send("group", nil, txt)
        elseif en.kind == "whisper" then CL.Send("whisper", en.name, txt) end
        input:SetText("")
    end
    input:SetScript("OnEnterPressed", function() DoSend(); input:SetFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then ihint:Show() else ihint:Hide() end
    end)
    local sendBtn = UI.CreateButton(f, L.CHAT_SEND, 88, 28, DoSend)
    sendBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14), 6)

    -- Blasen-Pool
    local bubbles = {}
    local seps = {}
    local function Bubble(i)
        local b = bubbles[i]
        if b then return b end
        b = CreateFrame("Frame", nil, chat.child)
        b:SetHeight(60)
        b.avBtn = CreateFrame("Button", nil, b)
        b.avBtn:SetSize(36, 36)
        b.avBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.av = b.avBtn:CreateTexture(nil, "ARTWORK")
        b.av:SetAllPoints()
        b.lvl = UI.CreateLabel(b, "", { size = 11, color = "textDim" })
        b.panel = CreateFrame("Button", nil, b)
        b.panel:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = b.panel:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.hl = b.panel:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.05)
        b.name = UI.CreateLabel(b.panel, "", { size = 12, justify = "LEFT" })
        b.name:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -7)
        b.time = UI.CreateLabel(b.panel, "", { size = 10, color = "textDim", justify = "RIGHT" })
        b.time:SetPoint("TOPRIGHT", b.panel, "TOPRIGHT", -8, -8)
        b.text = UI.CreateLabel(b.panel, "", { size = 12, justify = "LEFT", justifyV = "TOP" })
        b.text:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -24)
        bubbles[i] = b
        return b
    end

    local function Plain(t) return CL.Plain(t) end

    -- Links (Items, Quests, Zauber) aus einer Nachricht holen und anzeigen
    local function ParseLinks(text)
        local out = {}
        local pos = 1
        text = text or ""
        while true do
            local a, b, data, name = string.find(text, "|H([^|]+)|h%[(.-)%]|h", pos)
            if not a then break end
            out[table.getn(out) + 1] = { data = data, name = name }
            pos = b + 1
            if table.getn(out) >= 8 then break end
        end
        return out
    end

    local function ShowLink(lk)
        local full = "|cffffffff|H" .. lk.data .. "|h[" .. lk.name .. "]|h|r"
        if SetItemRef then pcall(SetItemRef, lk.data, full, "LeftButton") end
    end

    -- Rechtsklick auf eine Blase: Nachricht kopieren plus Spieleraktionen
    local function MsgMenu(sender, msg, url)
        local items = {}
        local function Add(t, fn) items[table.getn(items) + 1] = { t, fn } end
        Add(L.CHAT_COPY_MSG .. " " .. L.CHAT_COPY_HINT_SHORT, function() ShowCopy(msg, url) end)
        if url then Add(L.CHAT_COPY_LINK, function() ShowCopy(url, nil) end) end
        Add(L.CHAN_WHISPER, function()
            CL.OpenWhisper(sender)
            selectKey("w:" .. sender)
            input:SetFocus()
        end)
        Add(L.CHAN_INVITE, function() Ch.Invite(sender) end)
        Add(L.CHAN_IGNORE, function() Ch.Ignore(sender) end)
        Add(L.CHAT_MENU_FRIEND, function() if _G.AddFriend then pcall(_G.AddFriend, sender) end end)
        Add(L.CHAT_MENU_WHO, function() CL.Ask(sender, true) end)
        Add(L.CHAT_MENU_COPY, function() ShowCopy(sender, nil) end)
        ShowList(sender, items)
    end

    local function DrawBubbles(key)
        local lines = CL.Lines(key) or {}
        local n = table.getn(lines)
        local first = math.max(1, n - MAX_BUBBLES + 1)
        local areaW = chat.child:GetWidth()
        if not areaW or areaW < 200 then areaW = 560 end
        seen.w = areaW
        local maxBub = math.floor(areaW * 0.68)
        local atBottom = stick or (chat.scroll:GetVerticalScroll() >= lastH - lastViewH - 8)
        local y = 6
        local idx = 0
        local sidx = 0
        local prevDay = nil
        local i = first
        while i <= n do
            local ln = lines[i]
            local dk = DayKey(ln.t)
            if dk ~= prevDay then
                prevDay = dk
                sidx = sidx + 1
                local sp = seps[sidx]
                if not sp then
                    sp = CreateFrame("Frame", nil, chat.child)
                    sp:SetHeight(20)
                    sp.t = UI.CreateLabel(sp, "", { size = 11, color = "textDim", justify = "CENTER" })
                    sp.t:SetPoint("CENTER", sp, "CENTER", 0, 0)
                    seps[sidx] = sp
                end
                sp:SetWidth(areaW - 8)
                sp:ClearAllPoints()
                sp:SetPoint("TOPLEFT", chat.child, "TOPLEFT", 0, -y)
                sp.t:SetText("- " .. DayText(ln.t, L) .. " -")
                sp:Show()
                y = y + 24
            end
            idx = idx + 1
            local b = Bubble(idx)
            local own = ln.o ~= nil
            local who = ln.s or "?"
            local cls, lv = CL.Info(who)
            SetClassIcon(b.av, cls)
            b.lvl:SetText(lv and tostring(lv) or "?")
            local r, g, bl = CL.ClassColor(cls)
            b.name:SetTextColor(r, g, bl)
            b.name:SetText(who)
            b.time:SetText(Stamp(ln.t, L))
            local txt = ln.m or ""
            measure:SetText(Plain(txt))
            local tw = measure:GetStringWidth() or 0
            if tw <= 0 then tw = maxBub end
            local nameW = (b.name:GetStringWidth() or 60) + (b.time:GetStringWidth() or 80) + 40
            local pw = math.floor(math.max(math.min(math.max(tw, nameW) + 22, maxBub), 110))
            b.text:SetWidth(pw - 20)
            b.text:SetText(txt)
            local th = (b.text.GetStringHeight and b.text:GetStringHeight()) or b.text:GetHeight() or 14
            if not th or th < 14 then th = 14 end
            local ph = math.floor(th + 38)
            b.panel:SetSize(pw, ph)
            if own then b.bg:SetColorTexture(0.13, 0.27, 0.46, 0.95) else b.bg:SetColorTexture(UI.Color("card", 0.95)) end
            local rowH = math.max(ph, 56)
            b:SetSize(areaW - 8, rowH)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", chat.child, "TOPLEFT", 0, -y)
            b.avBtn:ClearAllPoints(); b.lvl:ClearAllPoints(); b.panel:ClearAllPoints()
            if own then
                b.avBtn:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, 0)
                b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
                b.panel:SetPoint("TOPRIGHT", b.avBtn, "TOPLEFT", -8, 0)
            else
                b.avBtn:SetPoint("TOPLEFT", b, "TOPLEFT", 6, 0)
                b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
                b.panel:SetPoint("TOPLEFT", b.avBtn, "TOPRIGHT", 8, 0)
            end
            local msg, sender = Plain(txt), who
            local url = CL.FirstUrl(txt)
            local links = ParseLinks(txt)
            local nl = table.getn(links)
            b.avBtn:SetScript("OnClick", function() ShowMenu(sender) end)
            b.panel:SetScript("OnClick", function(_, btn)
                btn = btn or arg1
                if btn == "RightButton" then
                    MsgMenu(sender, msg, url)
                elseif nl == 1 then
                    ShowLink(links[1])
                elseif nl > 1 then
                    local its, q = {}, 1
                    while q <= nl do
                        local lk = links[q]
                        its[q] = { "[" .. lk.name .. "]", function() ShowLink(lk) end }
                        q = q + 1
                    end
                    ShowList(sender, its)
                else
                    ShowCopy(msg, url)
                end
            end)
            if nl == 1 then
                local lk = links[1]
                b.panel:SetScript("OnEnter", function()
                    if GameTooltip then
                        pcall(GameTooltip.SetOwner, GameTooltip, b.panel, "ANCHOR_RIGHT")
                        pcall(GameTooltip.SetHyperlink, GameTooltip, lk.data)
                        pcall(GameTooltip.Show, GameTooltip)
                    end
                end)
                b.panel:SetScript("OnLeave", function()
                    if GameTooltip then pcall(GameTooltip.Hide, GameTooltip) end
                end)
            else
                b.panel:SetScript("OnEnter", nil)
                b.panel:SetScript("OnLeave", nil)
            end
            b:Show()
            y = y + rowH + 8
            i = i + 1
        end
        idx = idx + 1
        while bubbles[idx] do bubbles[idx]:Hide(); idx = idx + 1 end
        sidx = sidx + 1
        while seps[sidx] do seps[sidx]:Hide(); sidx = sidx + 1 end
        local viewH = chat.scroll:GetHeight() or 300
        chat:SetContentHeight(math.max(1, y))
        lastH, lastViewH = y, viewH
        if atBottom then
            chat.scroll:SetVerticalScroll(math.max(0, y - viewH))
            chat.UpdateScroll()
            stick = false
        end
        return n
    end

    local logT = 0
    local function DrawLog(key)
        local lines = CL.Lines(key) or {}
        local n = table.getn(lines)
        -- nur die letzten ca. LOG_CHARS Zeichen zeigen, damit das Fenster ruhig bleibt
        local parts = {}
        local total = 0
        local i = n
        while i >= 1 do
            local ln = lines[i]
            local row = "[" .. Stamp(ln.t, L) .. "] " .. (ln.s or "?") .. ": " .. Plain(ln.m or "")
            total = total + string.len(row) + 1
            if total > LOG_CHARS and table.getn(parts) > 0 then break end
            parts[table.getn(parts) + 1] = row
            i = i - 1
        end
        -- Reihenfolge umdrehen (aelteste oben)
        local ordered, k = {}, table.getn(parts)
        while k >= 1 do ordered[table.getn(ordered) + 1] = parts[k]; k = k - 1 end
        local text = table.concat(ordered, "\n")
        local now = (GetTime and GetTime()) or 0
        local h = logArea.child:GetHeight() or 0
        local v = logArea.scroll:GetHeight() or 0
        local atBottom = (logArea.scroll:GetVerticalScroll() >= h - v - 24)
        -- beim Lesen (oben/markiert) nichts verschieben; sonst hoechstens alle 1,5 s aktualisieren
        local calm = logArea.edit:HasFocus() or (not atBottom and logArea.lastText ~= nil)
        if not calm and logArea.lastText ~= text and (now - logT >= 1.5 or logArea.lastText == nil) then
            logT = now
            logArea.lastText = text
            logArea:SetText(text)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    local h2 = logArea.child:GetHeight() or 0
                    local v2 = logArea.scroll:GetHeight() or 0
                    logArea.scroll:SetVerticalScroll(math.max(0, h2 - v2))
                    logArea.UpdateScroll()
                end)
            end
        end
        return n
    end

    local function DrawCenter()
        local en = selKey and EntryByKey(selKey)
        if not en then
            head:SetText(""); sub:SetText(""); empty:SetText("")
            chat:Hide(); logArea:Hide(); ibox:Hide(); sendBtn:Hide()
            return
        end
        local title = en.label
        if en.kind == "whisper" then
            local c, lv = CL.Info(en.name)
            title = en.name
            sub:SetText((lv and (tostring(lv)) or "?") .. "  -  " .. L.CHAT_KEPT)
        else
            sub:SetText(L.CHAT_KEPT)
        end
        head:SetText(title)
        local canWrite = en.mode ~= "data"
        if canWrite then ibox:Show(); sendBtn:Show() else ibox:Hide(); sendBtn:Hide() end
        if en.mode == "data" then
            chat:Hide(); logArea:Hide()
            empty:SetText(L.CHAT_DATA)
        elseif en.mode == "log" then
            chat:Hide(); logArea:Show()
            local n = DrawLog(en.key)
            if n == 0 then empty:SetText(L.CHAT_EMPTY) else empty:SetText("") end
        else
            logArea:Hide(); chat:Show()
            local n = DrawBubbles(en.key)
            if n == 0 then empty:SetText(L.CHAT_EMPTY) else empty:SetText("") end
        end
        if en.kind == "guild" and not (IsInGuild and IsInGuild()) then empty:SetText(L.CHAT_NOGUILD) end
    end

    ------------------------------------------------------------------
    -- Rechte Spalte: Suche und Mitglieder
    ------------------------------------------------------------------
    local box = UI.CreatePanel(f, "bgDeep", "bronze")
    box:SetHeight(26)
    box:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    box:SetWidth(RIGHT_W)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -2)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    edit:SetMaxLetters(40)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local hint = UI.CreateLabel(box, L.CHAN_SEARCH, { size = 11, color = "textDim" })
    hint:SetPoint("LEFT", box, "LEFT", 8, 0)
    hint:SetPoint("RIGHT", box, "RIGHT", -4, 0)

    local rhead = UI.CreateLabel(f, "", { size = 11, color = "textDim", justify = "LEFT" })
    rhead:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -34)
    rhead:SetWidth(RIGHT_W)
    local refresh = UI.CreateButton(f, L.CHAN_REFRESH, RIGHT_W, 24, function()
        Ch.RefreshAll()
        CL.RequestGuild()
    end)
    refresh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 6)

    local right = UI.CreateScrollFrame(f)
    right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -54)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 36)
    right:SetWidth(RIGHT_W)
    local rrows = {}
    local function RightRow(i)
        local r = rrows[i]
        if not r then
            r = CreateFrame("Button", nil, right.child)
            r:SetHeight(22)
            r:SetPoint("TOPLEFT", right.child, "TOPLEFT", 0, -(i - 1) * 22)
            r:SetPoint("TOPRIGHT", right.child, "TOPRIGHT", 0, -(i - 1) * 22)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r.hl = r:CreateTexture(nil, "HIGHLIGHT")
            r.hl:SetAllPoints()
            r.hl:SetColorTexture(UI.Color("gold", 0.15))
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
            r.text = UI.CreateLabel(r, "", { size = 12, justify = "LEFT" })
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
            rrows[i] = r
        end
        return r
    end

    local function MembersOf(en)
        local out = {}
        if not en then return out end
        if en.kind == "channel" and en.e then
            local k = 1
            while k <= table.getn(en.e.members) do
                out[table.getn(out) + 1] = { name = en.e.members[k], spk = en.e.extra and en.e.extra[en.e.members[k]] or nil }
                k = k + 1
            end
        elseif en.kind == "guild" then
            local k = 1
            while k <= table.getn(CL.guild) do
                local g = CL.guild[k]
                out[table.getn(out) + 1] = { name = g.name, class = g.class, level = g.level }
                k = k + 1
            end
        elseif en.kind == "group" then
            out = CL.ScanGroup()
        elseif en.kind == "whisper" then
            out[1] = { name = en.name }
        end
        return out
    end

    local function DrawRight()
        local en = selKey and EntryByKey(selKey)
        local items = {}
        if search ~= "" then
            local hits = Ch.Find(search, 300)
            local h = 1
            while h <= table.getn(hits) do
                items[h] = { name = hits[h].name, extra = table.concat(hits[h].chans, ", ") }
                h = h + 1
            end
            rhead:SetText(table.getn(items) == 0 and L.CHAN_NO_HITS or (Ch.moreFound and L.CHAN_MORE or ""))
            Ch.moreFound = nil
        else
            items = MembersOf(en)
            local title = (en and en.kind == "guild") and L.CHAT_ONLINE_HDR or L.CHAT_MEMBERS_HDR
            rhead:SetText(title .. " (" .. table.getn(items) .. ")")
            if en and en.kind == "group" and table.getn(items) <= 1 then rhead:SetText(L.CHAT_NOGROUP) end
        end
        local cnt = math.min(table.getn(items), 400)
        local i = 1
        while i <= cnt do
            local it = items[i]
            local r = RightRow(i)
            local nm = it.name
            local cls, lv = it.class, it.level
            if not cls or not lv then
                local c2, l2 = CL.Info(nm)
                cls = cls or c2; lv = lv or l2
            end
            if (not cls or not lv) and not (en and en.mode == "data") and search == "" then CL.Ask(nm, false, true) end
            SetClassIcon(r.icon, cls)
            local cr, cg, cb = CL.ClassColor(cls)
            if it.spk then cr, cg, cb = cr * 0.65, cg * 0.65, cb * 0.65 end
            local txt = Hex(cr, cg, cb) .. nm .. "|r"
            if lv then txt = txt .. " |cff9a978c" .. lv .. "|r" end
            if it.extra then txt = txt .. " |cff9a978c" .. it.extra .. "|r" end
            r.text:SetText(txt)
            r:SetScript("OnClick", function() ShowMenu(nm) end)
            r:Show()
            i = i + 1
        end
        while rrows[i] do rrows[i]:Hide(); i = i + 1 end
        right:SetContentHeight(math.max(1, cnt * 22))
    end

    edit:SetScript("OnTextChanged", function(self)
        search = self:GetText() or ""
        if search == "" then hint:Show() else hint:Hide() end
        right:ScrollToTop()
        DrawRight()
    end)

    ApplyLayout = function()
        leftW = narrow and NARROW_W or WIDE_W
        left:SetWidth(leftW)
        tog:ClearAllPoints()
        tog:SetPoint("TOPLEFT", f, "TOPLEFT", leftW - 28, 0)
        tog:SetLabel(narrow and ">" or "<")
        Tip(tog, narrow and L.CHAT_EXPAND or L.CHAT_COLLAPSE)
        addBtn:ClearAllPoints()
        addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
        addBtn:SetWidth(leftW - 6)
        addBtn:SetLabel(narrow and "+" or L.CHAT_ADD)
        local lx = leftW + 14
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -2)
        head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 14), -2)
        sub:ClearAllPoints()
        sub:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -24)
        sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 14), -24)
        chat:ClearAllPoints()
        chat:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -44)
        chat:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14), 40)
        logArea:ClearAllPoints()
        logArea:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -44)
        logArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14), 40)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", f, "TOPLEFT", lx + 10, -56)
        empty:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(RIGHT_W + 24), -56)
        ibox:ClearAllPoints()
        ibox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", lx, 6)
        ibox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(RIGHT_W + 14 + 96), 6)
        stick = true
    end
    narrow = Layout().narrow and true or false
    ApplyLayout()

    ------------------------------------------------------------------
    -- Zusammenspiel
    ------------------------------------------------------------------
    Redraw = function()
        seen.cl, seen.ch = CL.version, Ch.version
        DrawLeft()
        CL.viewKey = selKey
        if selKey then CL.unread[selKey] = nil end
        DrawCenter()
        DrawRight()
    end

    selectKey = function(key)
        selKey = key
        stick = true
        CL.unread[key] = nil
        Redraw()
    end

    f.Refresh = function()
        CL.viewVisible = true
        if Ch.dirty or table.getn(Ch.list) == 0 then
            Ch.dirty = nil
            Ch.RefreshAll()
        else
            Ch.Rescan()
        end
        CL.RequestGuild()
        stick = true
        if CL.requestKey then
            selKey = CL.requestKey
            CL.requestKey = nil
        end
        Redraw()
    end

    f:SetScript("OnHide", function()
        CL.viewVisible = false
        CL.ClearMemberQueue()
        HideMenu()
        HideList()
        copy:Hide()
    end)

    local acc = 0
    local lastAuto = 0
    f:SetScript("OnUpdate", function(_, el)
        acc = acc + (el or arg1 or 0)
        if acc < 0.4 then return end
        acc = 0
        if not f:IsShown() then return end
        if Ch.dirty then Ch.dirty = nil; Ch.RefreshAll() end
        -- den angezeigten Kanal alle 45 s neu abfragen
        local cur = selKey and EntryByKey(selKey)
        if cur and cur.kind == "channel" and cur.mode ~= "data" and Ch.Pending() == 0 then
            local now = (GetTime and GetTime()) or 0
            if now - lastAuto >= 45 then
                lastAuto = now
                Ch.RefreshOne(cur.num)
            end
        end
        local w = chat.child:GetWidth()
        if seen.cl ~= CL.version or seen.ch ~= Ch.version or (w and math.abs(w - seen.w) > 4) then
            Redraw()
        end
    end)

    return f
end

UI:RegisterTab("channels", {
    label = function() return FW.L.TAB_CHANNELS end,
    order = 115,
    build = Build,
    onShow = function(f) f.Refresh() end,
})
