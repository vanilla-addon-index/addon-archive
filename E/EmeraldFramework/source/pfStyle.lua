if not pfUI then return end
local EF
if EFrame == nil then 
    EFrame = {}
end
EF = EFrame

setmetatable(EF, {__index = getfenv() })
setfenv(1, EF)

EF.pfStyle = newStyle("pfStyle")
setfenv(1, EF.pfStyle)

newClass("Button", AbstractButton)
Button:attach("flat")
Button.__flat = false

function Button:new(parent)
    AbstractButton.new(self, parent)
    self.marea = MouseArea(self)
    self.marea.anchorFill = self
    self.marea.enabled = bind(self, "enabled")
    self.textLabel = Label(self)
    self._text = alias(self.textLabel, "text")
    pfUI.GetEnvironment().SkinButton(self.marea.frame)
    self:connect("flatChanged", function (flat)
        if flat then
            self.marea.frame:SetBackdrop(nil)
        else
            pfUI.GetEnvironment().SkinButton(self.marea.frame)
        end
    end)
    self.marea:connect("clicked", self, "toggle")
    self.marea:connect("clicked", self, "clicked")
    self.pressed = bind(self.marea, "pressed")
    self.pressX = bind(self.marea, "mouseX")
    self.pressY = bind(self.marea, "mouseY")
    self.image = Image(self)
    self.image.layer = "artwork"
    self.textLabel.anchorFill = self
    self.textLabel.marginLeft = 6
    self.textLabel.marginRight = 6
    self.textLabel.marginTop = bind(function() return ((self.marea.containsPress or self.checked) and 7 or 6) - (self.flat and 4 or 0) end)
    self.textLabel.marginBottom = bind(function() return ((self.marea.containsPress or self.checked) and 5 or 6) - (self.flat and 4 or 0) end)
    self.textLabel.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or (not self.checked and {0.25,0.25,0.25} or {.66,.66,.66}) end)
    self._hAlignment = alias(self.textLabel, "hAlignment")
    self._vAlignment = alias(self.textLabel, "vAlignment")
    self.implicitWidth = bind(function() return self.textLabel.contentWidth + self.textLabel.marginLeft + self.textLabel.marginRight end)
    self.implicitHeight = bind(function() return self.textLabel.contentHeight + self.textLabel.marginBottom + self.textLabel.marginTop end)
    self.image.anchorFill = self
    self.image.margins = bind(function() return self.flat and 0 or 4 end)
    self._icon = alias(self.image, "source")
    self._iconColor = alias(self.image, "color")
end

newClass("CheckButton", AbstractButton)

CheckButton.__checkable = true

function CheckButton:new(parent)
    AbstractButton.new(self, parent)
    self.layout = RowLayout(self)
    self.layout.anchorFill = self
    self.layout.spacing = 2
    
    self.square = MouseArea(self.layout)
    self.square.enabled = bind(self, "enabled")
    self.square.implicitWidth = bind(function() return self.square.height end)
    self.square.Layout.fillHeight = true
    pfUI.GetEnvironment().SkinButton(self.square.frame)
    self.square:connect("clicked", self, "toggle")
        
    self.tick = Image(self.square)
    self.tick.anchorFill = self.square
    self.tick:setCoords(.125,.875,.125,.875)
    self.label = Label(self.layout)
    self.label.Layout.alignment = Layout.AlignVCenter
    self.label.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or {.25,.25,.25} end)
    self._text = alias(self.label, "text")
    self.implicitWidth = bind(function() return self.layout.implicitWidth end)
    self.implicitHeight = bind(function() return math.max(self.layout.implicitHeight, 16) end)
    self.tick.source = bind(function() return self.checked and (self.enabled and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Check-Disabled") end)
end

newClass("HScrollBar", Item)

function HScrollBar:new(parent)
    Item.new(self, parent)
    self.mouse = MouseArea(self)
    self.indicator = Item(self)
    self.anchorBottomLeft = self.parent.bottomLeft
    self.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self or self.mouse:clearAnchors() end)
    self.visible = bind(function() return self.parent.contentWidth > self.parent.width - (self.parent.contentHeight > self.parent.height and self.parent.vscrollbar.width + 2 or 0) end)
    self.height = 12
    self.mouse:connect("clicked",function ()
        if self.mouse.mouseX > self.indicator.marginLeft then
            self.parent.contentX = math.min(self.parent.contentX + self.parent.availableWidth, self.parent.contentWidth - self.parent.availableWidth)
        else
            self.parent.contentX = math.max(self.parent.contentX - self.parent.availableWidth, 0)
        end
    end)
    self.indicator.width = bind(function() return (self.parent.contentWidth == 0 or self.parent.contentWidth <= self.parent.availableWidth) and self.width or math.max(self.width*self.parent.availableWidth/self.parent.contentWidth, math.min(16, self.width * 0.2)) end)
    self.indicator.anchorTop = self.top
    self.indicator.marginLeft = bind(function() return (self.parent.contentWidth == 0 or self.parent.contentWidth <= self.parent.availableWidth) and 0 or (self.width - self.indicator.width) * self.parent.contentX/(self.parent.contentWidth - self.parent.availableWidth) end)
    self.indicator.anchorBottomLeft = self.bottomLeft
    self.indicator.mouse = MouseArea(self.indicator)
    self.indicator.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self.indicator or nil end)
    self.indicator.mouse:connect("pressedChanged",function(p) if p then self.indicator.mouse.x = self.indicator.mouse.mouseX else self.indicator.mouse.x = nil end end)
    self.indicator.mouse:connect("mouseXChanged",function (x)
        local ox = self.indicator.mouse.x
        if ox then
            self.parent.contentX = math.max(math.min(self.parent.contentX + (self.parent.contentWidth - self.parent.availableWidth)*(x - ox)/(self.width - self.indicator.width), self.parent.contentWidth - self.parent.availableWidth), 0)
        end
    end)
    
    self.indicatorLeft = Image(self.indicator)
    self.indicatorLeft.source = "Interface\\Buttons\\UI-ScrollBar-Knob"
    self.indicatorLeft.layer = "background"
    self.indicatorLeft:setCoords(.2, .4, .2, .8)
    self.indicatorLeft.anchorTop = self.indicator.top
    self.indicatorLeft.anchorBottom = self.indicator.bottom
    self.indicatorLeft.anchorLeft = self.indicator.left
    self.indicatorLeft.width = 4
    self.indicatorLeft.visible = bind(function() return not self.flat end)
    self.indicatorRight = Image(self.indicator)
    self.indicatorRight.source = bind(function() return self.indicatorLeft.source end)
    self.indicatorRight.layer = "background"
    self.indicatorRight:setCoords(0.6, .8, .2, .8)
    self.indicatorRight.anchorTop = self.indicator.top
    self.indicatorRight.anchorBottom = self.indicator.bottom
    self.indicatorRight.anchorRight = self.indicator.right
    self.indicatorRight.width = 4
    self.indicatorRight.visible = bind(function() return not self.flat end)
    self.indicatorMid = Image(self.indicator)
    self.indicatorMid.source = bind(function() return self.indicatorLeft.source end)
    self.indicatorMid.layer = "background"
    self.indicatorMid:setCoords(.4, .6, .2, .8)
    self.indicatorMid.anchorTop = self.indicator.top
    self.indicatorMid.anchorBottom = self.indicator.bottom
    self.indicatorMid.anchorLeft = self.indicatorLeft.right
    self.indicatorMid.anchorRight = self.indicatorRight.left
    self.indicatorMid.visible = bind(function() return not self.flat end)
end

newClass("VScrollBar", Item)

function VScrollBar:new(parent)
    Item.new(self, parent)
    self.mouse = MouseArea(self)
    self.indicator = Item(self)
    self.anchorTopRight = self.parent.topRight
    self.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self or nil end)
    self.visible = bind(function() return self.parent.contentHeight > self.parent.height - (self.parent.contentWidth > self.parent.width and self.parent.hscrollbar.height + 2 or 0) end)
    self.width = 12
    self.mouse:connect("clicked",function ()
        if self.mouse.mouseY > self.indicator.marginTop then
            self.parent.contentY = math.min(self.parent.contentY + self.parent.availableHeight, self.parent.contentHeight - self.parent.availableHeight)
        else
            self.parent.contentY = math.max(self.parent.contentY - self.parent.availableHeight, 0)
        end
    end)
    self.indicator.height = bind(function() return (self.parent.contentHeight == 0 or self.parent.contentHeight <= self.parent.availableHeight) and self.height or math.max(self.height*self.parent.availableHeight/self.parent.contentHeight, math.min(16, self.width * 0.2)) end)
    self.indicator.anchorLeft = self.left
    self.indicator.marginTop = bind(function() return (self.parent.contentHeight == 0 or self.parent.contentHeight <= self.parent.availableHeight) and 0 or (self.height - self.indicator.height) * self.parent.contentY/(self.parent.contentHeight - self.parent.availableHeight) end)
    self.indicator.anchorTopRight = self.topRight
    self.indicator.mouse = MouseArea(self.indicator)
    self.indicator.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self.indicator or nil end)
    self.indicator.mouse:connect("pressedChanged",function(p) if p then self.indicator.mouse.y = self.indicator.mouse.mouseY else self.indicator.mouse.y = nil end end)
    self.indicator.mouse:connect("mouseYChanged",function (y)
        local oy = self.indicator.mouse.y
        if oy then
            self.parent.contentY = math.max(math.min(self.parent.contentY + (self.parent.contentHeight - self.parent.availableHeight)*(y - oy)/(self.height - self.indicator.height), self.parent.contentHeight - self.parent.availableHeight), 0)
        end
    end)
    
    self.indicatorTop = Image(self.indicator)
    self.indicatorTop.source = "Interface\\Buttons\\UI-ScrollBar-Knob"
    self.indicatorTop.layer = "background"
    self.indicatorTop:setCoords(.2, .8, .2, .4)
    self.indicatorTop.anchorTop = self.indicator.top
    self.indicatorTop.anchorRight = self.indicator.right
    self.indicatorTop.anchorLeft = self.indicator.left
    self.indicatorTop.height = 4
    self.indicatorTop.visible = bind(function() return not self.flat end)
    self.indicatorBottom = Image(self.indicator)
    self.indicatorBottom.source = bind(function() return self.indicatorTop.source end)
    self.indicatorBottom.layer = "background"
    self.indicatorBottom:setCoords(0.2, .8, .6, .8)
    self.indicatorBottom.anchorLeft = self.indicator.left
    self.indicatorBottom.anchorBottom = self.indicator.bottom
    self.indicatorBottom.anchorRight = self.indicator.right
    self.indicatorBottom.height = 4
    self.indicatorBottom.visible = bind(function() return not self.flat end)
    self.indicatorMid = Image(self.indicator)
    self.indicatorMid.source = bind(function() return self.indicatorTop.source end)
    self.indicatorMid.layer = "background"
    self.indicatorMid:setCoords(.2, .8, .4, .6)
    self.indicatorMid.anchorTop = self.indicatorTop.bottom
    self.indicatorMid.anchorBottom = self.indicatorBottom.top
    self.indicatorMid.anchorLeft = self.indicator.right
    self.indicatorMid.anchorRight = self.indicator.left
    self.indicatorMid.visible = bind(function() return not self.flat end)
end

newClass("ComboBox", MouseArea)
ComboBox:attach("currentIndex")
ComboBox:attach("model")
ComboBox:attach("textRole")
ComboBox:attachSignal("activated")

function ComboBox:new(parent)
    MouseArea.new(self, parent)
    self.row = RowLayout(self)
    self.row.margins = 2
    self.row.anchorFill = self
    self.textLabel = Label(self.row)
    self.textLabel.Layout.marginLeft = 4
    self.icon = Image(self.row)
    self.icon.Layout.marginRight = 4
    pfUI.GetEnvironment().SkinButton(self.frame)
    pfUI.GetEnvironment().CreateBackdrop(self.icon.frame)
    self.icon.Layout.alignment = bit.bor(Layout.AlignRight, Layout.AlignVCenter)
    self.textLabel.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or {0.25,0.25,0.25} end)
    self.textLabel.text = bind(function() local idx, model = self.currentIndex, self.model return idx and model and idx >= 1 and idx <= getn(model) and (self.textRole and self.model[idx][self.textRole] or model[idx]) or "" end)
    self.icon.source = pfUI.media["img:down"]
    self.icon.implicitWidth = 14
    self.icon.implicitHeight = 14
    self.icon.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or (not self.checked and {0.25,0.25,0.25} or {.66,.66,.66}) end)
    self.implicitWidth = bind(function() return math.max(130, self.row.implicitWidth + 16) end)
    self.implicitHeight = bind(function() return math.max(30, self.row.implicitHeight + 4) end)
    self.dropdown = Item(self)
    self.dropdown.z = 10
    self.list = ListView(self.dropdown)
    self.list.spacing = 4
    self.dropdown.anchorTopLeft = self.bottomLeft
    pfUI.GetEnvironment().CreateBackdrop(self.dropdown.frame)
    self.dropdown.width = bind(function() return math.max(self.list.implicitWidth + 24, self.width + 12) end)
    self.dropdown.height = bind(function() return math.min(self.list.implicitHeight + 24, 120) end)
    self.list.margins = 12
    self.list.anchorFill = self.dropdown
    self.list.model = bind(function() return self.model end)
    self.list.delegate = function (parent, index)
        local btn = MouseArea(parent)
        btn.text = Label(btn)
        btn.text.text = bind(function() return self.textRole and self.model[index][self.textRole] or self.model[index] end)
        btn.implicitWidth = bind(btn.text, "implicitWidth")
        btn.implicitHeight = bind(btn.text, "implicitHeight")
        btn.text.anchorTopLeft = btn.topLeft
        btn.flat = true
        btn.hAlignment = "LEFT"
        btn:connect("clicked",function() self.currentIndex = index self:activated(self.currentIndex) end)
        local d = Image(btn)
        d.layer = "OVERLAY"
        d.blendMode = "ADD"
        d.source = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
        d.color = {1,1,0,.5}
        d.anchorFill = btn
        d.visible = bind(btn, "containsMouse")
        btn.hoverEnabled = true
        return btn
    end
    self.list.highlightDelegate = function (parent)
        local d = Image(parent)
        d.layer = "OVERLAY"
        d.source = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
        d.blendMode = "ADD"
        d.color = {1,1,0,.5}
        return d
    end
    self.list.currentIndex = bind(function() return self.currentIndex end)
    self.dropdown.visible = false
    self:connect("clicked",function() self.dropdown.visible = not self.dropdown.visible end)
    self:connect("activated",function() if not IsShiftKeyDown() then self.dropdown.visible = false end end)
    self:connect("enabledChanged",function(e) if not e then self.dropdown.visible = false end end)
end

newClass("Window", Item)

Window:attach("background",nil, "setBackground")
Window:attach("centralItem", nil, "setCentralItem")
Window:attach("minimized", nil, "minimize")
Window:attach("minimumHeight")
Window:attach("minimumWidth")
Window:attach("padding")
Window:attach("title")
Window.__padding = 12
Window.__minimized = false
Window.__minimumWidth = 1
Window.__minimumHeight = 1
Window.__title = ""

function Window:new(parent)
    Item.new(self, parent)
    self.style = pfStyle
    self.marea = MouseArea(self)
    self.marea.dragTarget = self
    self.decoration = Item(self.marea)
    self.decoration.anchorTop = self.marea.top
    self.decoration.anchorLeft = self.marea.left
    self.decoration.anchorRight = self.marea.right
    self.decoration.layout = RowLayout(self.decoration)
    self.decoration.layout.anchorFill = self.decoration
    self.decoration.layout.margins = 4
    self.decoration.layout.spacing = 6
    self.titleLabel = Label(self.decoration.layout)
    self.titleLabel.Layout.alignment = Layout.AlignVCenter
    self.titleLabel.Layout.marginLeft = 4
    self.titleLabel.Layout.fillWidth = true
    self.titleLabel.text = bind(self, "title")
    self.minimizeButton = Button(self.decoration.layout)
    self.minimizeButton.implicitWidth = bind(function() return self.minimizeButton.height end)
    self.minimizeButton.checkable = true
    self.minimizeButton.icon = bind(function() return pfUI.media[self.minimizeButton.checked and "img:down" or "img:up"] end)
    self.minimizeButton.implicitHeight = 15
    self.minimizeButton.implicitWidth = 15
    self.minimizeButton:connect("checkedChanged",function(c) self:minimize(c) end)
    self.minimizeButton.iconColor = bind(function() return self.minimizeButton.enabled and {GameFontNormal:GetTextColor()} or {0.25,0.25,0.25} end)
    self.closeButton = Button(self.decoration.layout)
    self.closeButton.implicitHeight = 15
    self.closeButton.implicitWidth = 15
    self.closeButton.marea.frame._CreateTexture = self.closeButton.marea.frame.CreateTexture
    function self.closeButton.marea.frame:CreateTexture()
        self.CreateTexture, self._CreateTexture = self._CreateTexture, self.CreateTexture
        local ret = EFrame:newObject("texture",self,"CreateTexture")
        self.CreateTexture, self._CreateTexture = self._CreateTexture, self.CreateTexture
        return ret
    end
    pfUI.GetEnvironment().SkinCloseButton(self.closeButton.marea.frame)
    self.closeButton.text = " "
    self.closeButton.implicitWidth = bind(function() return self.closeButton.height end)
    self.closeButton:connect("clicked",function() self.visible = false end)
    self.decoration.height = bind(function() return max(20, self.decoration.layout.implicitHeight + 8) end)
    self.background = Item(self)
    self.textChanged = bind(function() return self.titleLabel.textChanged end)
    self:connect("visibleChanged",function (v)
        if v then
            self.minimizeButton.checked = false
        end
    end)
    pfUI.GetEnvironment().CreateBackdrop(self.decoration.frame, nil, nil, .85)
    pfUI.GetEnvironment().CreateBackdrop(self.background.frame, nil, nil, .85)
    self.background.marginLeft = bind(function() return -self.padding end)
    self.background.marginRight = bind(function() return -self.padding end)
    self.background.marginBottom = bind(function() return -self.padding end)
    self.background.visible = bind(function() return not self.minimized end)
    self.resize_frame = Button(self.marea)
    self.resize_frame.flat = true
    self.resize_frame.icon = bind(function() return self.resize_frame.containsPress and "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" or "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"end)
    self.resize_frame:connect("pressedChanged",function(p)
        if p then
            self.resize_frame.ox = self.resize_frame.pressX
            self.resize_frame.oy = self.resize_frame.pressY
        end
    end)
    self.resize_frame:connect("pressXChanged",function (x)
        if self.resize_frame.__pressed then
            self.width = math.max(self.__width + (x - self.resize_frame.ox), math.max(self.minimumWidth, self.decoration.layout.implicitWidth + 8))
        end
    end)
    self.resize_frame:connect("pressYChanged",function (y)
        if self.resize_frame.__pressed then
            self.height = math.max(self.__height + (y - self.resize_frame.oy), self.minimumHeight)
        end
    end)
    
    self.resize_frame.width = 14
    self.resize_frame.height = 14
    self.resize_frame.anchorBottom = self.marea.bottom
    self.resize_frame.anchorRight = self.marea.right
    self.resize_frame.visible = bind(function() return not self.minimized end)
    self.marea.anchorFill = self
    self.marea.marginTop = bind(function() return -self.decoration.height - self.padding end)
    self.marea.marginBottom = bind(function() return (self.minimized and self.height or 0)  - self.padding end)
    self.marea.marginLeft = bind(function() return - self.padding end)
    self.marea.marginRight = bind(function() return - self.padding end)
    self.anchorTopLeft = root.topLeft
    self.marginLeft = 2
    self.marginTop = 30
    self.minimumHeight = bind(function() return self.centralItem and self.centralItem.implicitHeight or 1 end)
    self.minimumWidth = bind(function() return self.centralItem and self.centralItem.implicitWidth or 1 end)
    self.implicitWidth = bind(function() return math.max(self.centralItem and self.centralItem.implicitWidth or 1, self.decoration.layout.implicitWidth) end)
    self.implicitHeight = bind(function() return math.max(self.centralItem and self.centralItem.implicitHeight or 1, 1) end)
end

function Window:destroy()
    recycleObject(self.closeButton.marea.frame)
    Item.destroy(self)
end

function Window:setBackground(f)
    if self.background == f then
        return
    end
    self.__background = f
    if f then
        f.anchorTop = self.decoration.top
        f.anchorBottom = self.bottom
        f.anchorLeft = self.left
        f.anchorRight = self.right
    end
    return self:backgroundChanged(f)
end

function Window:setCentralItem(f)
    if f == self.centralItem then return end
    if f then
        f.anchorFill = self
    end
    self.__centralItem = f
    f.visible = not self.__minimized
    return self:centralItemChanged(f)
end

function Window:minimize(flag)
    if self.__minimized == flag then return end
    if self.centralItem then
        self.centralItem.visible = not flag
    end
    self.__minimized = flag
    return self:minimizedChanged(f)
end
