-- Microchip-chat 0.8.8: individually detachable chat tabs.
-- Vanilla 1.12 / Lua 5.0: no modern chat API or automatic extra chat edit box.
-- The full channel buffers are shared; each window maintains only a 120-line
-- rendering page and its own independent scroll position.
MCWindows = {}

local C = nil
local windows = {}
local active = nil
local PAGE, STEP = 120, 24

local function clamped(value, lo, hi)
    value = tonumber(value) or lo
    if value < lo then value=lo end
    if value > hi then value=hi end
    return math.floor(value)
end

local function colors(role)
    if C and C.palette then return C.palette(role) end
    return 0.2,0.25,0.32
end

local function texture(frame, alpha, role)
    local t=frame:CreateTexture(nil,"BACKGROUND")
    t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    t:SetAllPoints(frame)
    local r,g,b=colors(role or "window")
    t:SetVertexColor(r,g,b,alpha)
    return t
end

local function label(parent, value, anchor, relative, rp, x, y)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    t:SetPoint(anchor,relative,rp,x,y)
    t:SetText(value)
    local r,g,b=colors("text")
    t:SetTextColor(r,g,b)
    return t
end

local function button(parent, caption, width, x, clicked)
    local b=CreateFrame("Button",nil,parent)
    b:SetWidth(width);b:SetHeight(24)
    b:SetPoint("LEFT",parent,"LEFT",x,0)
    b.back=texture(b,0.96,"button")
    local hot=b:CreateTexture(nil,"HIGHLIGHT")
    hot:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    hot:SetVertexColor(0.43,0.56,0.65,0.55)
    hot:SetAllPoints(b)
    b.caption=label(b,caption,"CENTER",b,"CENTER",0,0)
    b:SetScript("OnClick",clicked)
    return b
end

local function bucketEnabled(tab,key)
    if key=="LEGACY" then return true end
    if string.sub(key,1,8)=="CHANNEL:" then
        return C.enabled(tab,"CHANNEL",key)
    end
    return C.enabled(tab,key)
end

local function fetch(w,dir,pivot,amount)
    return MCHistory.Window(C.store,dir,pivot,amount,
        function(key) return bucketEnabled(w.tab,key) end,
        function(r) return C.matches(w.tab,r) end)
end

local function drawRows(w)
    w.log:Clear()
    local i,r,text,cr,cg,cb
    for i=1,table.getn(w.rows) do
        r=w.rows[i]
        text,cr,cg,cb=C.render(w.tab,r)
        w.log:AddMessage(text,cr,cg,cb)
    end
    w.count:SetText(table.getn(w.rows).." loaded / "..MCHistory.Count(C.store).." saved")
end

local function jump(w,where)
    local rows,more
    if where=="top" then
        rows,more=fetch(w,"newer",nil,PAGE)
        w.rows=rows;w.older=false;w.newer=more
        drawRows(w)
        w.log:ScrollToTop()
    else
        rows,more=fetch(w,"older",nil,PAGE)
        w.rows=rows;w.older=more;w.newer=false
        drawRows(w)
        w.log:ScrollToBottom()
    end
end

local function shift(w,dir)
    local rows=w.rows
    local n=table.getn(rows)
    if n==0 then return end
    local added,more,newRows,i,retain,first
    if dir=="older" then
        if not w.older then return end
        added,more=fetch(w,"older",rows[1].sequence,STEP)
        if table.getn(added)==0 then w.older=false;return end
        newRows={}
        for i=1,table.getn(added) do table.insert(newRows,added[i]) end
        retain=PAGE-table.getn(added)
        for i=1,math.min(n,retain) do table.insert(newRows,rows[i]) end
        w.older=more
        w.newer=w.newer or n>retain
        w.rows=newRows
        drawRows(w)
        w.log:ScrollToTop()
        for i=1,table.getn(added) do w.log:ScrollDown() end
    else
        if not w.newer then return end
        added,more=fetch(w,"newer",rows[n].sequence,STEP)
        if table.getn(added)==0 then w.newer=false;return end
        retain=PAGE-table.getn(added)
        first=math.max(1,n-retain+1)
        newRows={}
        for i=first,n do table.insert(newRows,rows[i]) end
        for i=1,table.getn(added) do table.insert(newRows,added[i]) end
        w.older=w.older or first>1
        w.newer=more
        w.rows=newRows
        drawRows(w)
        w.log:ScrollToBottom()
        for i=1,table.getn(added) do w.log:ScrollUp() end
    end
end

local function repaintLive(w)
    w.live:Clear()
    -- Fetch only recent matching records; do not expand every saved channel.
    local records=fetch(w,"older",nil,math.max(35,C.cfg.visible*4))
    local i,r,t,cr,cg,cb
    for i=1,table.getn(records) do
        r=records[i]
        if (r.sequence or 0)>(C.sessionStart or 0) and
           (not C.cfg.fading or ((GetTime()-(r.entered or 0)) < C.cfg.hold+C.cfg.fade and
                              (GetTime()-(r.entered or 0)) >= 0)) then
            t,cr,cg,cb=C.render(w.tab,r)
            w.live:AddMessage(t,cr,cg,cb)
        end
    end
end

local function resizeLayout(w)
    local font=clamped(w.tab.font or C.cfg.defaultFont,9,20)
    local combat=w.tab.isCombatTab and C.enabled(w.tab,"COMBAT")
    local bar=combat and 28 or 0
    w.root:SetWidth(w.geo.width)
    local available=(UIParent:GetHeight() or 768)-(w.root:GetBottom() or w.geo.y)-38
    local full=math.max(w.geo.height,available)
    if w.geo.historyHeight and w.geo.historyHeight>0 then
        full=math.max(w.geo.height,math.min(full,w.geo.historyHeight))
    end
    w.root:SetHeight(w.expanded and full or w.geo.height)
    w.live:ClearAllPoints()
    w.live:SetPoint("TOPLEFT",w.root,"TOPLEFT",11,-35-bar)
    w.live:SetPoint("BOTTOMRIGHT",w.root,"BOTTOMRIGHT",-11,32)
    w.log:ClearAllPoints()
    w.log:SetPoint("TOPLEFT",w.root,"TOPLEFT",11,-35-bar)
    w.log:SetPoint("BOTTOMRIGHT",w.root,"BOTTOMRIGHT",-11,32)
    w.live:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",font)
    w.log:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",font)
    w.live:SetMaxLines(C.cfg.visible)
    w.live:SetTimeVisible(C.cfg.hold)
    w.live:SetFadeDuration(C.cfg.fade)
    w.live:SetFading(C.cfg.fading)
    w.log:SetFading(false)
    if combat then w.combatBar:Show() else w.combatBar:Hide() end
    w.title:SetText(w.tab.name..(w.expanded and " / HISTORY" or ""))
    w.hist.caption:SetText(w.expanded and "END" or "HISTORY")
    if w.expanded then
        w.live:Hide();w.log:Show();w.top:Show();w.count:Show()
    else
        w.live:Show();w.log:Hide();w.top:Hide();w.count:Hide()
    end
    if C.cfg.locked then w.resize:Hide() else w.resize:Show() end
    local r,g,b=colors("window")
    w.back:SetVertexColor(r,g,b,w.expanded and 0.92 or 0.18)
    local tr,tg,tb=colors("text")
    w.title:SetTextColor(tr,tg,tb)
    w.count:SetTextColor(tr,tg,tb)
    w.resizetext:SetTextColor(tr,tg,tb)
    local i
    for i=1,table.getn(w.buttons) do
        local bb=w.buttons[i]
        local br,bg,bbg=colors("button")
        bb.back:SetVertexColor(br,bg,bbg,0.96)
        bb.caption:SetTextColor(tr,tg,tb)
    end
    w.all.caption:SetTextColor((w.tab.combatView or "all")=="all" and 1 or tr,
        (w.tab.combatView or "all")=="all" and 0.87 or tg,
        (w.tab.combatView or "all")=="all" and 0.52 or tb)
    w.me.caption:SetTextColor(w.tab.combatView=="me" and 1 or tr,
        w.tab.combatView=="me" and 0.87 or tg,
        w.tab.combatView=="me" and 0.52 or tb)
end

local function expand(w,on)
    w.expanded=on and true or false
    resizeLayout(w)
    if w.expanded then jump(w,"bottom") else repaintLive(w) end
end

local function wheel(w,delta)
    delta=tonumber(delta) or 0
    if delta>0 then
        if not w.expanded then expand(w,true) end
        if w.log:AtTop() and w.older then shift(w,"older") end
        local i
        for i=1,3 do w.log:ScrollUp() end
    elseif delta<0 then
        if w.expanded then
            if w.log:AtBottom() and w.newer then shift(w,"newer") end
            local i
            for i=1,3 do w.log:ScrollDown() end
        else w.live:ScrollToBottom() end
    end
end

local function saveGeometry(w)
    w.root:StopMovingOrSizing()
    w.geo.x=math.floor(w.root:GetLeft() or w.geo.x or 55)
    w.geo.y=math.floor(w.root:GetBottom() or w.geo.y or 100)
    w.geo.width=clamped(w.root:GetWidth(),400,900)
    if w.expanded then w.geo.historyHeight=clamped(w.root:GetHeight(),160,1200)
    else w.geo.height=clamped(w.root:GetHeight(),160,950) end
    w.root:ClearAllPoints()
    w.root:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",w.geo.x,w.geo.y)
    resizeLayout(w)
end

local function combatMode(w,mode)
    w.tab.combatView=mode
    resizeLayout(w)
    repaintLive(w)
    if w.expanded then jump(w,"bottom") end
end

local function hyperlink()
    if MCURLs and MCURLs.HandleClick(arg1) then return end
    if SetItemRef then SetItemRef(arg1,arg2,arg3) end
end

-- Vanilla 1.12 may not propagate SetAlpha to every child region; fade the
-- header and toolbar recursively so their labels do not remain faintly visible.
local function fadeControls(frame, alpha)
    frame:SetAlpha(alpha)
    local regions={frame:GetRegions()}
    local i
    for i=1,table.getn(regions) do
        if regions[i] then regions[i]:SetAlpha(alpha) end
    end
    local children={frame:GetChildren()}
    for i=1,table.getn(children) do
        if children[i] then fadeControls(children[i],alpha) end
    end
end

local function createWindow(tab)
    local w={tab=tab,rows={},older=false,newer=false,expanded=false,buttons={},
             controlsAlpha=1,lastHover=GetTime()}
    w.geo=tab.windowGeometry
    if type(w.geo)~="table" then
        w.geo={width=520,height=240,x=math.max(0,(UIParent:GetWidth() or 1024)-590),y=125}
        tab.windowGeometry=w.geo
    end
    w.geo.width=clamped(w.geo.width,400,900)
    w.geo.height=clamped(w.geo.height,160,950)
    w.geo.x=tonumber(w.geo.x) or 55
    w.geo.y=tonumber(w.geo.y) or 125
    w.root=CreateFrame("Frame",nil,UIParent)
    w.root:SetFrameStrata("MEDIUM")
    w.root:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",w.geo.x,w.geo.y)
    w.root:SetMovable(true);w.root:SetResizable(true)
    if w.root.SetMinResize then w.root:SetMinResize(400,160) end
    if w.root.SetMaxResize then w.root:SetMaxResize(900,1200) end
    w.root:SetClampedToScreen(true)
    w.root:EnableMouse(true);w.root:EnableMouseWheel(true)
    w.root:SetScript("OnMouseWheel",function() wheel(w,arg1) end)
    w.root:SetScript("OnEnter",function() active=tab end)
    w.back=texture(w.root,0.18,"window")
    w.header=CreateFrame("Button",nil,w.root)
    w.header:SetPoint("TOPLEFT",w.root,"TOPLEFT",0,0)
    w.header:SetPoint("TOPRIGHT",w.root,"TOPRIGHT",0,0)
    w.header:SetHeight(29)
    texture(w.header,0.98,"button")
    w.title=label(w.header,tab.name,"LEFT",w.header,"LEFT",12,0)
    w.header:RegisterForDrag("LeftButton")
    w.header:SetScript("OnDragStart",function()
        active=tab
        if not C.cfg.locked then w.root:StartMoving() end
    end)
    w.header:SetScript("OnDragStop",function()
        if not C.cfg.locked then saveGeometry(w) end
    end)
    w.header:SetScript("OnClick",function() active=tab end)
    w.combatBar=CreateFrame("Frame",nil,w.root)
    w.combatBar:SetHeight(26)
    w.combatBar:SetPoint("TOPLEFT",w.root,"TOPLEFT",9,-31)
    w.combatBar:SetPoint("TOPRIGHT",w.root,"TOPRIGHT",-9,-31)
    texture(w.combatBar,0.96,"button")
    w.all=button(w.combatBar,"ALL EVENTS",106,3,function() combatMode(w,"all") end)
    w.me=button(w.combatBar,"WHAT HAPPENED TO ME",181,114,function() combatMode(w,"me") end)
    table.insert(w.buttons,w.all);table.insert(w.buttons,w.me)
    w.live=CreateFrame("ScrollingMessageFrame",nil,w.root,"MicrochipChatLiveTemplate")
    w.live:SetJustifyH("LEFT")
    w.live:EnableMouse(true);w.live:EnableMouseWheel(true)
    if w.live.SetHyperlinksEnabled then w.live:SetHyperlinksEnabled(true) end
    w.live:SetScript("OnMouseWheel",function() wheel(w,arg1) end)
    w.live:SetScript("OnHyperlinkClick",hyperlink)
    w.log=CreateFrame("ScrollingMessageFrame",nil,w.root,"MicrochipChatHistoryTemplate")
    w.log:SetJustifyH("LEFT");w.log:SetFading(false)
    w.log:SetMaxLines(PAGE+8)
    w.log:EnableMouse(true);w.log:EnableMouseWheel(true)
    if w.log.SetHyperlinksEnabled then w.log:SetHyperlinksEnabled(true) end
    w.log:SetScript("OnMouseWheel",function() wheel(w,arg1) end)
    w.log:SetScript("OnHyperlinkClick",hyperlink)
    w.bar=CreateFrame("Frame",nil,w.root)
    w.bar:SetPoint("BOTTOMLEFT",w.root,"BOTTOMLEFT",0,0)
    w.bar:SetPoint("BOTTOMRIGHT",w.root,"BOTTOMRIGHT",0,0)
    w.bar:SetHeight(29)
    texture(w.bar,0.98,"button")
    w.hist=button(w.bar,"HISTORY",74,7,function() expand(w,not w.expanded) end)
    w.top=button(w.bar,"TOP",42,84,function() if w.expanded then jump(w,"top") end end)
    w.bottom=button(w.bar,"BOTTOM",62,130,function()
        if w.expanded then jump(w,"bottom") else w.live:ScrollToBottom() end
    end)
    w.dock=button(w.bar,"DOCK",54,199,function() MCWindows.Dock(w.tab) end)
    w.options=button(w.bar,"OPTIONS",68,260,function()
        active=w.tab
        if C.showOptions then C.showOptions(w.tab) end
    end)
    table.insert(w.buttons,w.hist);table.insert(w.buttons,w.top)
    table.insert(w.buttons,w.bottom);table.insert(w.buttons,w.dock)
    table.insert(w.buttons,w.options)
    w.count=label(w.root,"","TOPRIGHT",w.root,"TOPRIGHT",-12,-34)
    w.resize=CreateFrame("Button",nil,w.bar)
    w.resize:SetWidth(66);w.resize:SetHeight(25)
    w.resize:SetPoint("RIGHT",w.bar,"RIGHT",-3,0)
    texture(w.resize,0.96,"button")
    w.resizetext=label(w.resize,"RESIZE","CENTER",w.resize,"CENTER",0,0)
    w.resize:RegisterForDrag("LeftButton")
    w.resize:SetScript("OnDragStart",function()
        if not C.cfg.locked then w.resizing=true;w.root:StartSizing("BOTTOMRIGHT") end
    end)
    w.resize:SetScript("OnDragStop",function()
        if w.resizing then w.resizing=false;saveGeometry(w) end
    end)
    w.root:SetScript("OnUpdate",function()
        if not w.root:IsShown() then return end
        if MouseIsOver and MouseIsOver(w.root) then active=tab end
        local hovering=MouseIsOver and (MouseIsOver(w.header) or MouseIsOver(w.bar))
        if hovering then w.lastHover=GetTime() end
        local visible=hovering or w.resizing or
            ((GetTime()-w.lastHover)<(C.cfg.controlsHold or 5))
        local target=visible and 1 or 0
        local speed=(arg1 or 0)*2.8
        local before=w.controlsAlpha
        if before<target then w.controlsAlpha=math.min(target,before+speed)
        else w.controlsAlpha=math.max(target,before-speed) end
        if w.controlsAlpha~=before then
            fadeControls(w.header,w.controlsAlpha)
            fadeControls(w.bar,w.controlsAlpha)
        end
    end)
    resizeLayout(w)
    repaintLive(w)
    windows[tab]=w
    return w
end

function MCWindows.Initialize(callbacks)
    C=callbacks
    local i,tab
    -- A partially migrated profile must always have one usable main tab.
    local attached=0
    for i=1,table.getn(C.store.tabs) do
        if not C.store.tabs[i].detached then attached=attached+1 end
    end
    if attached==0 and C.store.tabs[1] then C.store.tabs[1].detached=false end
    for i=1,table.getn(C.store.tabs) do
        tab=C.store.tabs[i]
        if tab.detached then
            local w=windows[tab] or createWindow(tab)
            w.root:Show()
        end
    end
    if C.store.tabs[C.cfg.selected] and C.store.tabs[C.cfg.selected].detached then
        for i=1,table.getn(C.store.tabs) do
            if not C.store.tabs[i].detached then C.cfg.selected=i;break end
        end
    end
end

function MCWindows.IsDetached(tab)
    return tab and tab.detached==true
end

function MCWindows.Detach(tab)
    if not tab or not C then return false end
    if tab.detached then
        MCWindows.Focus(tab)
        return true
    end
    local attached=0
    local i,other
    for i=1,table.getn(C.store.tabs) do
        other=C.store.tabs[i]
        if other~=tab and not other.detached then attached=attached+1 end
    end
    if attached==0 then return false end -- Keep the original dock usable.
    tab.detached=true
    local w=windows[tab] or createWindow(tab)
    w.root:Show()
    w.lastHover=GetTime()
    resizeLayout(w)
    repaintLive(w)
    if w.expanded then jump(w,"bottom") end
    MCWindows.Focus(tab)
    return true
end

function MCWindows.Dock(tab)
    if not tab then return end
    tab.detached=false
    local w=windows[tab]
    if w then w.root:Hide() end
    if active==tab then active=nil end
    if C and C.onDock then C.onDock(tab) end
end

function MCWindows.Focus(tab)
    local w=windows[tab]
    if not w then return end
    w.root:Show()
    if w.root.Raise then w.root:Raise() end
    active=tab
end

function MCWindows.Remove(tab)
    if not tab then return end
    local w=windows[tab]
    if w then w.root:Hide();windows[tab]=nil end
    if active==tab then active=nil end
end

function MCWindows.GetInputAnchor()
    if not active or not active.detached then return nil end
    local w=windows[active]
    if w and w.root:IsShown() then return w.root end
    return nil
end

function MCWindows.UseMainInput()
    active=nil
end

function MCWindows.Refresh()
    if not C then return end
    local tab,w
    for tab,w in pairs(windows) do
        if tab.detached then
            resizeLayout(w)
            repaintLive(w)
            if w.expanded then
                local n=table.getn(w.rows)
                if n>0 then
                    -- Preserve the end of this history page, not the global
                    -- newest line, when settings or class colors change.
                    local pivot=(w.rows[n].sequence or 0)+1
                    local rows,more=fetch(w,"older",pivot,PAGE)
                    w.rows=rows;w.older=more;w.newer=true
                    drawRows(w)
                else jump(w,"bottom") end
            end
        end
    end
end

-- Refresh every detached window after the user explicitly deletes history.
-- Clear both the saved-history page and the transient visible message feed.
function MCWindows.ClearHistory()
    local tab,w
    for tab,w in pairs(windows) do
        w.rows={}
        w.older=false
        w.newer=false
        w.live:Clear()
        w.log:Clear()
        if w.count then w.count:SetText("0 loaded / 0 saved") end
    end
end

function MCWindows.Message(record)
    if not C then return end
    local tab,w,t,r,g,b
    for tab,w in pairs(windows) do
        if tab.detached and C.matches(tab,record) then
            t,r,g,b=C.render(tab,record)
            w.live:AddMessage(t,r,g,b)
            if w.expanded then
                if not w.newer and w.log:AtBottom() then
                    table.insert(w.rows,record)
                    if table.getn(w.rows)>PAGE then table.remove(w.rows,1);w.older=true end
                    w.log:AddMessage(t,r,g,b)
                else w.newer=true end
            end
        end
    end
end
