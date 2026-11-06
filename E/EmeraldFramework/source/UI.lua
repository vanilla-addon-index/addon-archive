local EF
if EFrame == nil then 
    EFrame = {}
end
EF = EFrame

setmetatable(EF, {__index = getfenv() })
setfenv(1, EF)

local EFrame = EFrame

function fuzzyCmp(a, b)
    return not (a or b) or (a and b) and math.abs(a - b) < 0.001
end

local defaultSettings = {
}
local defaultTheme = {
    color = {0,1,0}
}

function newStyle(name)
    if not EF.styles then
        EF.styles = {}
    end
    local t = { name = name }
    EF.styles[name] = t
    setmetatable(t, {__index = EF})
    return t
end
newStyle("Default")

function shaded(primary, shade)
    return {(primary[1] + shade[1])/2, (primary[2] + shade[2])/2, (primary[3] + shade[3])/2, primary[4]}
end

function reversed(primary)
    return {1 - primary[1], 1 - primary[2], 1 - primary[3], primary[4]}
end

function faded(primary, alpha)
    return {primary[1], primary[2], primary[3], (primary[4] or 1) * alpha}
end

shades = {}
setmetatable(shades, {__index = function (self, k)
        shades[k] = {k/1000, k/1000, k/1000}
        return shades[k]
    end
})

Theme = Object()

Theme:attach("color")
Theme:attach("decorationColor")
Theme:attach("backgroundColor")
Theme:attach("borderColor")
Theme:attach("disabledPressed")
Theme:attach("disabled")
Theme:attach("button")
Theme:attach("pressed")
Theme:attach("fontColor")
Theme:attach("font")
Theme:attach("fontSize")
Theme:attach("fontColor")
Theme:attach("borderWidth")
Theme:attach("buttonBorderWidth")
Theme:attach("buttonBorderColor")
Theme.__color = {1,1,1}
Theme.__borderWidth = 1
Theme.__buttonBorderWidth = 0
Theme.__buttonBorderColor = {1,1,1}
Theme.decorationColor = bind(function() return faded(Theme.color, 0.5) end)
Theme.backgroundColor = bind(function() return faded(Theme.color, 0.25) end)
Theme.borderColor = bind(function() return faded(Theme.color, 0.5) end)
Theme.button = bind(function() return shaded(Theme.color, shades[500]) end)
Theme.pressed = bind(function() return shaded(Theme.color, shades[300]) end)
Theme.disabledPressed = bind(function() return shaded(Theme.color, shades[200]) end)
Theme.disabled = bind(function() return shaded(Theme.color, shades[0]) end)



frameRecycler = {}
objectRecycler = {}
EF.rootFrame = EF.rootFrame or CreateFrame("frame")
function EFrame:recycle(f)
    f.eframe = nil
    if not f.owned then return end
    f:SetWidth(0)
    f:SetHeight(0)
    f:ClearAllPoints()
    f:Hide()
    f:SetParent(nil)
    f:SetAlpha(1)
    f:SetScale(1)
    f:SetFrameLevel(0)
    f:SetBackdrop(nil)
    f:SetBackdropColor(1,1,1,1)
    for k in pairs(f) do
        if k ~= 0 then
            f[k] = nil
        end
    end
    local t = strlower(f:GetObjectType())
    if not self.frameRecycler[t] then
        self.frameRecycler[t] =  {}
    end
    if t == "scrollframe" then return end
    tinsert(self.frameRecycler[t],f)
end
function EFrame:recycleObject(f, t)
    f:ClearAllPoints()
    f:SetParent(rootFrame)
    f:SetPoint("TOPLEFT", rootFrame, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", rootFrame, "TOPLEFT")
--    f:SetParent(nil)
    local t = t or strlower(f:GetObjectType())
    self.objectRecycler[t] = self.objectRecycler[t] or {}
    tinsert(self.objectRecycler[t],f)
end

function EFrame:newFrame(t, parent)
    t = strlower(t)
    local f = self.frameRecycler[ti or t] and tremove(self.frameRecycler[ti or t]) or CreateFrame(t)
    f:SetParent(parent)
    f.owned = true
    return f
end

function EFrame:newObject(t,p,m, t2)
    t = strlower(t)
    local r = self.objectRecycler[t2 or t] and tremove(self.objectRecycler[t2 or t])
    if not r then
        return p[m](p)
    end
    r:SetParent(p)
    r:ClearAllPoints()
    r:SetAllPoints(p)
    r:Show()
    return r
end

newClass("Item", Object)

Item.isItem = true

local function colorComp(c1,c2)
    return not (c1 or c2) or c1 and c2 and c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3] and c1[4] == c2[4]
end

Item:attach("marginLeft", nil, Property.Integer)
Item:attach("marginTop", nil, Property.Integer)
Item:attach("marginRight", nil, Property.Integer)
Item:attach("marginBottom", nil, Property.Integer)
Item:attach("hoffset", nil, Property.Integer)
Item:attach("voffset", nil, Property.Integer)
Item:attach("rotation")
Item:attach("implicitWidth", nil, Property.Integer)
Item:attach("implicitHeight", nil, Property.Integer)
Item:attach("width", nil,"setWidth")
Item:attach("height", nil,"setHeight")
Item:attach("visible", nil, "setVisible")
Item:attach("z","getZ","setZ")
Item:attach("margins", nil, "setAllMargins")
Item:attach("opacity", "getOpacity", "setOpacity")
Item:attach("visibleChildren")
Item:attach("childrenItems", nil, Property.ReadOnly)
Item:attach("keyboardEnabled", "getKeyboardEnabled", "setKeyboardEnabled")
Item:attach("scale", nil, "setScale")
Item:attach("anchorFill", nil, "setAnchorFill")
Item:attach("backdrop", nil, "setBackdrop")
Item:attach("backdropColor", nil, "setBackdropColor")
Item:attachSignal("keyPressed")
Item:attachSignal("keyReleased")
Item:attachSignal("effectiveScaleChanged")

Item.__implicitWidth = 0
Item.__implicitHeight = 0
Item.__margins = 0
Item.__marginTop = 0
Item.__marginBottom = 0
Item.__marginRight = 0
Item.__marginLeft = 0
Item.__hoffset = 0
Item.__voffset = 0
Item.__scale = 1
Item.__height = 0
Item.__width = 0

local points = {
    TOP         = { anchor = "anchorTop"        , point = "top"         , v = "marginTop", h = nil, vc = -1, sides = {"top"}},
    BOTTOM      = { anchor = "anchorBottom"     , point = "bottom"      , v = "marginBottom", h = nil, vc = 1, sides = {"bottom"}},
    LEFT        = { anchor = "anchorLeft"       , point = "left"        , v = nil, h = "marginLeft", hc = 1, sides = {"left"}},
    RIGHT       = { anchor = "anchorRight"      , point = "right"       , v = nil , h = "marginRight", hc = -1, sides = {"right"}},
    TOPLEFT     = { anchor = "anchorTopLeft"    , point = "topLeft"     , v = "marginTop", h = "marginLeft", vc = -1, hc = 1, sides = {"top","left"}},
    TOPRIGHT    = { anchor = "anchorTopRight"   , point = "topRight"    , v = "marginTop", h = "marginRight", vc = -1, hc = -1, sides = {"top","right"}},
    BOTTOMLEFT  = { anchor = "anchorBottomLeft" , point = "bottomLeft"  , v = "marginBottom" , h = "marginLeft", vc = 1, hc = 1, sides = {"bottom","left"}},
    BOTTOMRIGHT = { anchor = "anchorBottomRight", point = "bottomRight" , v = "marginBottom" , h = "marginRight", vc = 1, hc = -1, sides = {"bottom","right"}},
    CENTER      = { anchor = "anchorCenter"     , point = "center"      , v = "voffset", h =  "hoffset", vc = 1, hc = 1}
}

function toString(a, loop, depth)
  loop = loop or {}
    if a == nil then return "nil" end
    if a == true then return "TRUE" end
    if a == false then return "FALSE" end
    if type(a) == "string" then return "\""..a.."\"" end
    if type(a) == "table" then
        local address = tostring(a)
        if loop[address] or depth == 0 then
            return address
        else
            loop[address] = true
        end
        local out = format("%s {", a.GetName and a:GetName() or address)
        local sep = ""
        for k,v in a do
            out = out..sep..toString(k, loop, depth -1)..": "..toString(v, loop, depth -1)
            sep = ", "
        end
        return out.."}"
    end
    return tostring(a)
end
function print(a,depth)
  DEFAULT_CHAT_FRAME:AddMessage(toString(a, nil, depth or  -1))
end

for k, v in pairs(points) do
    local setter = "set" .. string.upper(string.sub(v.anchor,1,1)) .. string.sub(v.anchor,2)
    v.__anchor = "__" .. v.anchor
    v.signal = v.anchor .. "Changed"
    Item:attach(v.anchor, nil, setter)
    local k, v = k, v
    Item[setter] = function (self, target)
        if self[v.__anchor] == target or not target then return end
        if not v.sides then
            self:clearAnchors()
        else
            for _,s in ipairs(v.sides) do
                if self.anchors[s] then
                    self[self.anchors[s].__anchor] = nil
                    self[self.anchors[s].signal](self, nil)
                end
                self.anchors[s] = v
            end
        end
        self[v.__anchor] = target
        return self[v.signal](self, target)
    end
    v.bind = v.anchor .. "Bind"
    Item[v.bind] = function (self)
        local a = self[v.anchor]
        if a then
            self.frame:SetPoint(k, a.frame, a.point, v.h and round(v.hc * self[v.h] / self.scale) or 0, v.v and round(v.vc * self[v.v] / self.scale) or 0)
        end
    end
end

local function refreshSize()
    if this == EFrame.root.frame then return EFrame.root:rescale() end
    
    local w, h = round(this:GetWidth()/this:GetEffectiveScale()), round(this:GetHeight()/this:GetEffectiveScale())
    local eframe = this.eframe
    if w ~= eframe.__width and (eframe.anchors.right and eframe.anchors.left or this.autoWidth or this.owned == false) then
        eframe.__width = w
        eframe:widthChanged(w)
    end
    if h ~= eframe.__height and (eframe.anchors.top and eframe.anchors.bottom or this.autoHeight or this.owned == false) then
        eframe.__height = h
        eframe:heightChanged(h)
    end
    local scale = this:GetEffectiveScale()
    if eframe.lastEScale ~= scale then
        eframe.lastEScale = scale
        eframe:effectiveScaleChanged(scale)
    end
end

local function updateVisible()
    local self = this.eframe
    if self.__visible == (this:IsVisible() == 1) then return end
    if this:IsVisible() == 1 then
        self.__visible = true
        self:visibleChanged(true)
    else
        self.__visible = false
        self:visibleChanged(false)
    end
end

function Item:new(parent, wrap, mode)
    self.__childrenItems = {}
    self.anchors = {}
    parent = parent or root
    self.style = parent and parent.style or EFrame.style or EFrame
    assert(wrap == rootFrame or parent)
    assert(not parent or parent.isItem)
    self.frame = wrap or EFrame:newFrame("frame")
    self.frame.lastEScale = self.frame:GetEffectiveScale()
    self.frame.owned = mode == nil or mode
    self.frame.eframe = self
    self.frame:SetScript("OnSizeChanged", EFrame:makeAtomic(refreshSize))
    self.frame:SetScript("OnShow", updateVisible)
    self.frame:SetScript("OnHide", updateVisible)
    
    Object.new(self)
    self.parent = parent
    self.width = bind(function() return self.implicitWidth end)
    self.height = bind(function() return self.implicitHeight end)
    self.visible = true
    if mode == false then
        for i=1, wrap:GetNumPoints() do
            local p, t, tp, x, y = wrap:GetPoint(i)
            local pt = points[p]
            assert(type(t)~="function")
            self[pt.anchor] = {frame = t, point = tp}
            if pt.h then
                self[pt.h] = pt.hc * x
            end
            if pt.v then
                self[pt.v] = pt.vc * y
            end
        end
    end
    self:refreshAnchors()
    self.visibleChildren = bind(Item.getVisibleChildren)
end

function Item:refreshAnchors()
    self.frame:ClearAllPoints()
    for k, v in pairs(points) do
        assert(type(self.frame)~="function")
        self[v.point] = {frame = self.frame, point = k}
        local ab = bind(self[v.bind])
        ab.parent = self
      --  ab.lazy=true
        ab:update()
    end
end

function Item:setParent(p)
    if not p then Object.setParent(self) return end
    Object.setParent(self, p)
    self:updateVisible()
end

function Item:addChild(c)
    Object.addChild(self, c)
    if c.isItem then
        self:addChildItem(c)
        return
    end
end

function Item:removeChild(c)
    if c.isItem then
        self:removeChildItem(c)
    end
    Object.removeChild(self, c)
    return
end

function Item:addChildItem(c)
    tinsert(self.__childrenItems, c)
    self:childrenItemsChanged(self.__childrenItems)
end

function Item:getVisibleChildren()
    local vc = {}
    for _,c in pairs(self.childrenItems) do
        if c.visible then
            tinsert(vc, c)
        end
    end
    return vc
end

function Item:setAllMargins(v)
    self.marginTop = v
    self.marginBottom = v
    self.marginLeft = v
    self.marginRight = v
end

function Item:destroy()
    local f = self.frame
    f:SetScript("OnSizeChanged",nil)
    f:SetScript("OnShow", nil)
    f:SetScript("OnHide", nil)
    EFrame:recycle(f)
    self.frame = nil
    Object.destroy(self)
end

function Item:setParent(p)
    if self.frame.owned == false then return end
    if not p then Object.setParent(self) return end
    self.frame:SetParent(p.frame)
    Object.setParent(self, p)
end

function Item:setVisible(v)
    if v then
        self.frame:Show()
    else
        self.frame:Hide()
    end
    if not self.__visible ~= not v then
        self.__visible = v
        self:visibleChanged(self.__visible)
    end
end

function Item:getOpacity()
    return self.frame:GetAlpha()
end

function Item:setOpacity(o)
    local old = self:getOpacity()
    if old == o then return end
    self.frame:SetAlpha(o)
    self:opacityChanged(o)
end

function Item:getKeyboardEnabled()
    return self.frame:IsKeyboardEnabled() == 1
end

function Item:setKeyboardEnabled(e)
    if self.keyboardEnabled == e then return end
    self.frame:EnableKeyboard(e and 1 or 0)
    self:keyboardEnabledChanged(e)
end

function Item:removeChildItem(f)
    for k,c in pairs(self.__childrenItems) do
        if c == f then
            tremove(self.__childrenItems, k)
            self:childrenItemsChanged(self.__childrenItems)
        end
    end
end

function Item:getVisibleChildren()
    local vc = {}
    for _,c in pairs(self.childrenItems) do
        if c.visible then
            tinsert(vc, c)
        end
    end
    return vc
end

function Item:setZ(z)
    if self:getZ() == z then return end
    
    self.frame:SetFrameLevel(z)
    self:zChanged(z)
end

function Item:getZ()
    return self.frame:GetFrameLevel()
end

function Item:setWidth(w)
    w = round(w)
    if self.__width == w or (self.anchors.left and self.anchors.right) then return end
    self.frame:SetWidth(w)
    self.__width = w
    self:widthChanged(w)
end

function Item:setHeight(h)
    h = round(h)
    if self.__height == h or (self.anchors.top and self.anchors.bottom) then return end
    self.frame:SetHeight(h)
    self.__height = h
    self:heightChanged(h)
end

function Item:setScale(s)
    if self.__scale == s then return end
    self.__scale = s
    self.frame:SetScale(s)
    self:scaleChanged(s)
end

function Item:setAnchorFill(t)
    if self.__anchorFill == t then return end
    self:clearAnchors()
    self.__anchorFill = t
    if not t then return end
    self.anchorTopLeft = t.topLeft
    self.anchorBottomRight = t.bottomRight
    self:anchorFillChanged(t)
end

function Item:clearAnchors()
    self.frame:ClearAllPoints()
    for k,v in pairs(self.anchors) do
        self[v.__anchor] = nil
        self[v.signal](self, nil)
        self.anchors[k] = nil
    end
    self.__anchorFill = nil
    self:anchorFillChanged(nil)
    if self.__anchorCenter then
        self.__anchorCenter = nil
        self:anchorCenterChanged(nil)
    end
end

function Item:setBackdrop(b)
    if self.__backdrop == b then return end
    self.__backdrop = b
    self.frame:SetBackdrop(b)
    self:backdropChanged(b)
end

function Item:setBackdropColor(color)
    if colorComp(self.__color, color) then
        return
    end
    self.__backdropColor = color
    self.frame:SetBackdropColor(unpack(color))
    self:backdropColorChanged(color)
end

newClass("Rectangle", Item)

Rectangle:attach("color", nil,"setColor")
Rectangle:attach("borderColor", nil, "setBorderColor")
Rectangle:attach("borderWidth", nil, "setBorderWidth")
Rectangle:attach("layer", "getLayer", "setLayer")
Rectangle:attach("blendMode", "getBlendMode","setBlendMode")

function Rectangle:new(parent)
    Item.new(self, parent)
    self._texture = EFrame:newObject("texture",self.frame,"CreateTexture")
    self._texture:SetAllPoints()
    self.layer = "ARTWORK"
    self.blendMode = "BLEND"
    self.color = bind(Theme, "color")
end

function Rectangle:destroy()
    EFrame:recycleObject(self._texture)
    self._texture:SetTexture(nil)
    if self._borderTop then
        self._borderTop:SetTexture(nil)
        self._borderBottom:SetTexture(nil)
        self._borderRight:SetTexture(nil)
        self._borderLeft:SetTexture(nil)
        EFrame:recycleObject(self._borderTop)
        EFrame:recycleObject(self._borderBottom)
        EFrame:recycleObject(self._borderRight)
        EFrame:recycleObject(self._borderLeft)
    end
    Item.destroy(self)
end

function Rectangle:_borderSetup()
    if not self._borderTop then
        self._borderTop = EFrame:newObject("texture", self.frame, "CreateTexture", self:getLayer())
        self._borderBottom = EFrame:newObject("texture", self.frame, "CreateTexture", self:getLayer())
        self._borderRight = EFrame:newObject("texture", self.frame, "CreateTexture", self:getLayer())
        self._borderLeft = EFrame:newObject("texture", self.frame, "CreateTexture", self:getLayer())
        
        self._borderTop:SetPoint("TOP", self.frame,"TOP")
        self._borderTop:SetPoint("LEFT", self.frame,"LEFT")
        self._borderTop:SetPoint("RIGHT", self.frame,"RIGHT")
        
        self._borderRight:SetPoint("RIGHT", self.frame,"RIGHT")
        self._borderRight:SetPoint("TOP", self._borderTop,"BOTTOM")
        self._borderRight:SetPoint("BOTTOM", self._borderBottom,"TOP")
        
        self._borderBottom:SetPoint("BOTTOM", self.frame,"BOTTOM")
        self._borderBottom:SetPoint("LEFT", self.frame,"LEFT")
        self._borderBottom:SetPoint("RIGHT", self.frame,"RIGHT")
        
        self._borderLeft:SetPoint("LEFT", self.frame,"LEFT")
        self._borderLeft:SetPoint("TOP", self._borderTop,"BOTTOM")
        self._borderLeft:SetPoint("BOTTOM", self._borderBottom,"TOP")
    end
end

function Rectangle:setColor(color)
    if colorComp(self.__color, color) then
        return
    end
    self.__color = color
    self._texture:SetTexture(unpack(color))
    self:colorChanged(color)
end

function Rectangle:setBorderColor(color)
    if colorComp(self.__borderColor, color) then
        return
    end
    self:_borderSetup()
    self.__borderColor = color
    self._borderTop:SetTexture(unpack(color))
    self._borderRight:SetTexture(unpack(color))
    self._borderBottom:SetTexture(unpack(color))
    self._borderLeft:SetTexture(unpack(color))
    self:borderColorChanged(color)
end

function Rectangle:setBorderWidth(width)
    width = round(width)
    if self.__borderWidth == width then return end
    self:_borderSetup()
    self._texture:ClearAllPoints()
    if width == 0 then
        self._borderTop:Hide()
        self._borderBottom:Hide()
        self._borderRight:Hide()
        self._borderLeft:Hide()
        self._texture:SetAllPoints()
    else
        self._borderTop:SetHeight(width)
        self._borderBottom:SetHeight(width)
        self._borderRight:SetWidth(width)
        self._borderLeft:SetWidth(width)
        self._borderTop:Show()
        self._borderBottom:Show()
        self._borderRight:Show()
        self._borderLeft:Show()
        self._texture:SetPoint("TOP", self._borderTop, "BOTTOM")
        self._texture:SetPoint("RIGHT", self._borderRight, "LEFT")
        self._texture:SetPoint("BOTTOM", self._borderBottom, "TOP")
        self._texture:SetPoint("LEFT", self._borderLeft, "RIGHT")
    end
    self.__borderWidth = width
    self:borderWidthChanged(width)
end


function Rectangle:getLayer()
    return self._texture:GetDrawLayer()
end

function Rectangle:setLayer(l)
    if self:getLayer() == strupper(l) then
        return
    end
    self._texture:SetDrawLayer(l)
    if self._borderTop then
        self._borderTop:SetDrawLayer(l)
        self._borderBottom:SetDrawLayer(l)
        self._borderRight:SetDrawLayer(l)
        self._borderLeft:SetDrawLayer(l)
    end
    self:layerChanged(l)
end

function Rectangle:getBlendMode()
    return self._texture:GetBlendMode()
end

function Rectangle:setBlendMode(m)
    if self:getBlendMode() == strupper(m) then
        return
    end
    self._texture:SetBlendMode(m)
    self:blendModeChanged(m)
end

newClass("Image", Item)

Image:attach("source", "getSource","setSource")
Image:attach("color", nil, "setColor")
Image:attach("layer", "getLayer", "setLayer")
Image:attach("blendMode", "getBlendMode","setBlendMode")
Image:attach("rotation",nil, "setRotation")

function Image:new(parent)
    Item.new(self, parent)
    self._texture = EFrame:newObject("texture",self.frame,"CreateTexture", "image")
    self._texture:SetAllPoints()
    self.layer = "ARTWORK"
    self.blendMode = "BLEND"
end

function Image:destroy()
    self._texture:SetVertexColor(1,1,1,1)
    self._texture:SetTexture(nil)
    self._texture:SetTexCoord(0,1,0,1)
    EFrame:recycleObject(self._texture, "image")
    Item.destroy(self)
end

function Image:getSource()
    return self._texture:GetTexture()
end

function Image:setSource(src)
    if src == self.__source then
        return
    end
    
    self._texture:SetTexture(src)
    self:sourceChanged(src)
end

local function rotate(this, r)
    local function c(x,y)
        local sin = math.sin(r)
        local cos = math.cos(r)
        return (x*cos - y * sin)/2+0.5, -(x*sin + y * cos)/2 + 0.5
    end
    local ulx, uly = c(-1,1)
    local llx, lly = c(-1,-1)
    local urx, ury = c(1,1)
    local lrx, lry = c(1,-1)
    this:SetTexCoord(
        ulx,uly,
        llx,lly,
        urx,ury,
        lrx,lry)
end

function Image:setRotation(r)
    if r == self.rotation then
        return
    end
    
    rotate(self._texture, r)
    self:rotationChanged(r)
end

function Image:setColor(color)
    if colorComp(self.__color, color) then
        return
    end
    self.__color = color
    self._texture:SetVertexColor(unpack(color))
    self:colorChanged(color)
end

function Image:getLayer()
    return self._texture:GetDrawLayer()
end

function Image:setLayer(l)
    if self:getLayer() == strupper(l) then
        return
    end
    self._texture:SetDrawLayer(l)
    self:layerChanged(l)
end

function Image:getBlendMode()
    return self._texture:GetBlendMode()
end

function Image:setBlendMode(m)
    if self:getBlendMode() == strupper(m) then
        return
    end
    self._texture:SetBlendMode(m)
    self:blendModeChanged(m)
end

function Image:setCoords(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if arg5 then
        self._texture:SetTexCoord(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    else
        self._texture:SetTexCoord(arg1, arg2, arg3, arg4)
    end
end

newClass("Label", Item)

Label.NoFit = 0
Label.HorizontalFit = 1
Label.VerticalFit = 16
Label.Fit = 17

Label:attach("text",nil ,"setText")
Label:attach("color",nil,"setColor")
Label:attach("shadowColor","getShadowColor","setShadowColor")
Label:attach("shadowOffset","getShadowOffset","setShadowOffset")
Label:attach("outline","getOutline","setOutline")
Label:attach("hAlignment","getHAlignment","setHAlignment")
Label:attach("vAlignment","getVAlignment","setVAlignment")
Label:attach("contentWidth")
Label:attach("contentHeight")
Label:attach("sizeMode")
Label:attach("fontSize", nil, "setFontSize")
Label.__contentWidth = 0
Label.__contentHeight = 0
Label.__oldHeight = 0
Label.__text = ""
Label.__sizeMode = Label.NoFit


function Label:new(parent)
    Item.new(self, parent)
    self.n_text = EFrame:newObject("fontstring",self.frame,"CreateFontString")
    self.n_text:SetFontObject("GameFontNormal")
    _, self.__fontSize = self.n_text:GetFont()
    self.n_text:SetAllPoints()
    self.implicitWidth = bind(function() return bit.band(self.sizeMode, Label.HorizontalFit) ~= 0 and 0 or self.contentWidth end)
    self.implicitHeight = bind(function() return bit.band(self.sizeMode, Label.VerticalFit) ~= 0 and 0 or self.contentHeight end)
    self.color = {GameFontNormal:GetTextColor()}
end

function Label:destroy()
    self.n_text:SetJustifyH("CENTER")
    self.n_text:SetJustifyV("CENTER")
    self.n_text:SetText("")
    self.frame:SetScript("OnUpdate", nil)
    EFrame:recycleObject(self.n_text)
    Item.destroy(self)
end

function Label:effectiveScaleChanged()
    self:refreshContentWidth() self:refreshContentHeight()
end

function Label:onWidthChanged(w)
    if bit.band(self.__sizeMode, Label.HorizontalFit) ~= 0 then
        self:fitH()
    else
        self:refreshContentHeight()
    end 
end

function Label:onHeightChanged(h)
    if self.__sizeMode == Label.Fit and h > self.__oldHeight then
        self:fitH()
    elseif bit.band(self.__sizeMode, Label.VerticalFit) ~= 0 then
        self:fitV()
    end
    self.__oldHeight = self.__height
end

function Label:onFontSizeChanged()
    self:refreshContentWidth()
    self:refreshContentHeight()
end

function Label:getText()
    return self.n_text:GetText()
end

function Label:setText(t)
    if self.__text == t then return end
    self.__text = t
    self.n_text:SetText(t)
    self:refreshContentWidth()
    self:refreshContentHeight()
    if self.__sizeMode == Label.Fit or bit.band(self.__sizeMode, Label.HorizontalFit) ~= 0 then
        self:fitH()
    elseif bit.band(self.__sizeMode, Label.VerticalFit) ~= 0 then
        self:fitV()
    end
    self:textChanged(t)
end

function Label:setColor(color)
    if colorComp(self.__color, color) then
        return
    end
    self.__color = color
    self.n_text:SetTextColor(unpack(color))
    self:colorChanged(color)
end

function Label:getShadowColor()
    return {self.n_text:GetShadowColor()}
end
    
function Label:setShadowColor(c)
    local old = self:getShadowColor()
    if colorComp(old, c) then return end
    self.n_text:SetShadowColor(unpack(c))
    self:shadowColorChanged(c)
end

function Label:refreshContentWidth(rec)
    local w = math.ceil(self.n_text:GetStringWidth()-0.001)
    self.frame.lastEScale = self.frame:GetEffectiveScale()
    if w ~= self.__contentWidth then
        self.__contentWidth = w
        self:contentWidthChanged(w)
    end
end

function Label:refreshContentHeight(rec)
    self.n_text:ClearAllPoints()
    self.n_text:SetWidth(self.__width)
    local h = math.ceil(self.n_text:GetHeight()-0.001)
    self.n_text:SetAllPoints()
    if h ~= self.__contentHeight then
        self.__contentHeight = h
        self:contentHeightChanged(h)
    end
end

function Label:fitH()
    if self.__width <= 0 or self.__height <= 0 then return end
    
    local w = self.n_text:GetStringWidth()
    local f, fhw = self.n_text:GetFont()
    fhw = fhw * (self.__width/w)
    local fs = math.floor(fhw+0.001)
    if fs == 0 then
        self.fontSize = 1
        return
    end
    
    self.n_text:SetFont(f, fs)
    local old
    while self.__width > math.ceil(self.n_text:GetStringWidth()-0.001) and self.n_text:GetStringWidth() ~= old and (self.__height <= math.ceil(self.n_text:GetHeight()-0.001) or self.__sizeMode ~= Label.Fit) do
        old = self.n_text:GetStringWidth()
        fs = fs + 1
        self.n_text:SetFont(f, fs)
    end
    while self.__width < math.ceil(self.n_text:GetStringWidth()-0.001) and fs > 1 do
        fs = fs - 1
        self.n_text:SetFont(f, fs)
    end
    if self.__fontSize ~= fs then
        self.fontSize = fs
    end
    if self.__sizeMode == Label.Fit then
        self:fitV()
    end
end

function Label:fitV()
    if self.__width <= 0 or self.__height <= 0 then return end
    
    self.n_text:ClearAllPoints()
    if self.__sizeMode == Label.Fit then
        self.n_text:SetWidth(self.__width)
    else
        self.n_text:SetWidth(root.width/root.scale)
    end
    local h = self.n_text:GetHeight()
    if h == 0 then
        self.n_text:SetAllPoints()
        return
    end
    if self.__sizeMode == Label.Fit then
        if math.ceil(self.n_text:GetHeight()-0.001) <= self.__height then
            self.n_text:SetAllPoints()
            return
        end
    end
    local f, fs = self.n_text:GetFont()
    local fh = math.floor(fs * (self.__height/h)+0.001)
    if fh == 0 then
        self.fontSize = 1
        return
    end
    if self.__sizeMode ~= Label.Fit or fh < self.__fontSize then
        self.n_text:SetFont(f, fh)
    end
    local old
    while self.__height > math.ceil(self.n_text:GetHeight()-0.001) and self.n_text:GetHeight() ~= old and self.__sizeMode ~= Label.Fit do
        old = self.n_text:GetHeight()
        fh = fh + 1
        self.n_text:SetFont(f, fh)
    end
    while self.__height < math.ceil(self.n_text:GetHeight()-0.001) and fh > 1 do
        fh = fh - 1
        self.n_text:SetFont(f, fh)
    end
    self.n_text:SetAllPoints()
    if self.__fontSize ~= fh then
        self.fontSize = fh
    end
end

function Label:setFontSize(s)
    if s == self.__fontSize or s <= 0 then return end
    local f = self.n_text:GetFont()
    self.n_text:SetFont(f, s)
    self.__fontSize = s
    self:refreshContentWidth(true)
    self:refreshContentHeight(true)
    self:fontSizeChanged(s)
end

function Label:getHAlignment()
    return self.n_text:GetJustifyH()
end

function Label:setHAlignment(a)
    if strupper(a) == self:getHAlignment() then return end
    self.n_text:SetJustifyH(a)
    self:hAlignmentChanged(a)
end

function Label:getVAlignment()
    return self.n_text:GetJustifyV()
end

function Label:setVAlignment(a)
    if strupper(a) == self:getVAlignment() then return end
    self.n_text:SetJustifyV(a)
    self:vAlignmentChanged(a)
end

newClass("Cooldown", Item)
Cooldown:attach("duration")
Cooldown:attach("start")
Cooldown:attach("enabled")
Cooldown.__start = 0
Cooldown.__enabled = 0
Cooldown.__duration = 0

function Cooldown:new(parent)
    Item.new(self, parent, EFrame:newFrame("Model"))
    self.frame:SetModel("Interface\\Cooldown\\UI-Cooldown-Indicator.mdx")
    local a = bind(function ()
        CooldownFrame_SetTimer(self.frame, self.start, self.duration, self.enabled and 1 or 0)
    end)
    a.parent = self
    a:update()
    self.frame:SetScript("OnUpdateModel", CooldownFrame_OnUpdateModel)
    self.frame:SetScript("OnAnimFinished", CooldownFrame_OnAnimFinished)
    self:connect("heightChanged", function(v) self.frame:SetModelScale(v/48) end)
end


function Cooldown:destroy()
    self.frame:SetScript("OnUpdateModel", nil)
    self.frame:SetScript("OnAnimFinished", nil)
    Item.destroy(self)
end

newClass("MouseArea", Item)

MouseArea:attach("pressed")
MouseArea:attach("dragTarget", nil, "setDragTarget")
MouseArea:attach("dragActive")
MouseArea:attach("enabled", "getEnabled", "setEnabled")
MouseArea:attach("containsMouse")
MouseArea:attach("hoverEnabled")
MouseArea:attach("containsPress")
MouseArea:attach("mouseX", nil, Property.Integer)
MouseArea:attach("mouseY", nil, Property.Integer)

function MouseArea:new(parent)
    Item.new(self, parent, EFrame:newFrame("Button"))
    self:attachSignal("clicked")
    self.frame:RegisterForClicks("LeftButtonDown","LeftButtonUp")
    self.frame:SetScript("OnClick", EFrame:makeAtomic(function ()
        if self.frame:GetButtonState() == "NORMAL" then
            local x, y = GetCursorPosition()
            x = x / self.frame:GetEffectiveScale() - this:GetLeft()
            y = (this:GetTop() - y / self.frame:GetEffectiveScale())
            self.mouseX = x
            self.mouseY = y
            self.pressed = button
        else
            self:clicked(button)
            self.pressed = false
        end
    end))
    local ox, oy
    self.frame:SetScript("OnDragStart", EFrame:makeAtomic(function ()
        local x, y = GetCursorPosition()
        ox = x
        oy = y
        for k,v in pairs(points) do
            if self.dragTarget[v.anchor] then
                if v.h then
                    ol = v.hc * self.dragTarget:get(v.h) * self.dragTarget.parent.frame:GetEffectiveScale()
                end
                if v.v then
                    ot = v.vc * self.dragTarget:get(v.v) * self.dragTarget.parent.frame:GetEffectiveScale()
                end
            end
        end
        self.dragActive = true
    end))
    self.frame:SetScript("OnDragStop", EFrame:makeAtomic(function ()
        ox = nil
        oy = nil
        self.dragActive = false
        if not self.containsPress or button ~= self.pressed then
            self.pressed = false
        end
    end))
    self.frame:SetScript("OnUpdate", EFrame:makeAtomic(function ()
        if (self.pressed or self.hoverEnabled) and this:GetLeft() then
            local x, y = GetCursorPosition()
            self.mouseX = x / self.frame:GetEffectiveScale() - this:GetLeft()
            self.mouseY = this:GetTop() - y / self.frame:GetEffectiveScale()
            if self.pressed or self.hoverEnabled then
                self.containsMouse = MouseIsOver(self.frame) and true or false
            end
            if self.dragActive then
                for k,v in pairs(points) do
                    if self.dragTarget[v.anchor] then
                        if v.h then
                            self.dragTarget[v.h] = normalizedBind(v.hc * (ol + (x - ox)) / self.dragTarget.parent.frame:GetEffectiveScale())
                        end
                        if v.v then
                            self.dragTarget[v.v] = normalizedBind(v.vc * (ot + (y - oy)) / self.dragTarget.parent.frame:GetEffectiveScale())
                        end
                    end
                end
            end
        end
    end))
    self.frame:SetScript("OnMouseUp", EFrame:makeAtomic(function ()
        self.pressed = false
    end))
    self.enabled = true
    self.hoverEnabled = false
    self.dragActive = false
    self.pressed = false
    self.containsPress = bind(function() return self.pressed and self.containsMouse end)
    self:connect("visibleChanged", function() self.frame:SetButtonState("NORMAL") self.pressed = false end)
end

function MouseArea:destroy()
    self.frame:SetScript("OnClick",nil)
    self.frame:SetScript("OnMouseUp",nil)
    self.frame:SetScript("OnUpdate",nil)
    self.frame:SetScript("OnDragStart",nil)
    self.frame:SetScript("OnDragStop",nil)
    self.frame:SetButtonState("NORMAL")
    self.frame:Disable()
    self.frame:RegisterForDrag()
    Item.destroy(self)
end

function MouseArea:setDragTarget(target)
    if self.dragTarget == target then return end
    
    if not self.dragTarget then
        self.frame:RegisterForDrag("LeftButton")
    elseif not target then
        self.frame:RegisterForDrag()
    end
    self.__dragTarget = target
    self:dragTargetChanged(target)
end

function MouseArea:getEnabled()
    return self.frame:IsEnabled() == 1
end

function MouseArea:setEnabled(e)
    if e == self.enabled then return end
    if e then
        self.frame:Enable()
    else
        self.frame:Disable()
    end
    self:enabledChanged(e)
end

newClass("AbstractButton", MouseArea)


AbstractButton:attach("checkable")
AbstractButton:attach("checked")
AbstractButton:attach("autoExclusive", nil, "setAutoExclusive")
AbstractButton:attachSignal("toggled")
AbstractButton.__checkable = false
AbstractButton.__checked = false
AbstractButton.__autoExclusive = false

function AbstractButton:new(parent)
    MouseArea.new(self, parent)
    self:connect("clicked", function ()
        if self.checkable and not (self.exclusive and self.__checked) then
            self:set("checked", not self.__checked)
            self:toggled()
        end
    end)
    self:connect("checkableChanged", function (c)
        if not c then
            self:set("checked", false)
        end
    end)
end
function AbstractButton:setAutoExclusive(b)
    if b == self.__autoExclusive then return end
    self.__autoExclusive = b
    if b then
        if not self.parent.autoExclusiveGroup then
            self.parent.autoExclusiveGroup = ExclusiveGroup(self.parent)
        end
        self.parent.autoExclusiveGroup:addButton(self)
    else
        self.parent.autoExclusiveGroup:removeButton(self)
    end
    self:autoExclusiveChanged(b)
end

newClass("Button", AbstractButton)

Button:attach("background",nil, "setBackground")
Button:attach("flat")
Button.__flat = false

function Button:new(parent)
    AbstractButton.new(self, parent)
    self.textLabel = Label(self)
    self._text = alias(self.textLabel, "text")
    self.background = Rectangle(self)
    self.background.layer = "background"
    self.image = Image(self)
    self.image.layer = "artwork"
    self.background.color = bind(function () return self.flat and {0, 0, 0, 0} or not self.enabled and (not self.checked and Theme.disabledPressed or Theme.disabled) or (self.containsPress or self.checked) and Theme.pressed or Theme.button end)
    self.textLabel.anchorFill = self
    self.textLabel.marginLeft = 2
    self.textLabel.marginRight = 2
    self.textLabel.marginTop = bind(function() return self.containsPress and 2 or self.checked and 1 or 0 end)
    self.textLabel.marginBottom = bind(function() return self.containsPress and 1 or self.checked and 2 or 3 end)
    self.textLabel.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or (not self.checked and {0.25,0.25,0.25} or {.66,.66,.66}) end)
    self._hAlignment = alias(self.textLabel, "hAlignment")
    self._vAlignment = alias(self.textLabel, "vAlignment")
    self.implicitWidth = bind(function() return self.textLabel.contentWidth + self.textLabel.marginLeft + self.textLabel.marginRight end)
    self.implicitHeight = bind(function() return self.textLabel.contentHeight + self.textLabel.marginBottom + self.textLabel.marginTop end)
    self.image.anchorFill = self
    self.image.color = bind(function () local up = self.checked or self.containsPress return self.flat and (up and Theme.pressed or Theme.color) or up and Theme.color or Theme.pressed end)
    self._icon = alias(self.image, "source")
end

function Button:setBackground(f)
    if self.__background == f then
        return
    end
    self.__background = f
    if f then
        f.anchorFill = self
    end
    self:backgroundChanged(f)
end

newClass("ExclusiveGroup", Object)

ExclusiveGroup:attach("current", nil, "setCurrent")
ExclusiveGroup:attach("buttons")
ExclusiveGroup:attachSignal("clicked")

function ExclusiveGroup:new(parent)
    Object.new(self, parent)
    self.__buttons = {}
    self.__buttonsConnections = {}
end

function ExclusiveGroup:addButton(b)
    if not self.__buttons[b] then
        b.exclusive = true
        self.__buttons[b] = b
        self:buttonsChanged(self.__buttons)
        self.__buttonsConnections[b] = {
            b:connect("checkedChanged", function(c) if c then self:setCurrent(b) else if self.current == b then self:setCurrent() end end end),
            b:connect("clicked", function() self:clicked(b) end)
        }
        if b.checked then
            self.current = b
        end
    end
end

function ExclusiveGroup:removeButton(b)
    if self.__buttons[b] then
        self.__buttons[b] = nil
        self:buttonsChanged(self.__buttons)
        for _,c in ipairs(self.__buttonsConnections[b]) do
            c:disconnect()
        end
        self.__buttonsConnections[b] = nil
    end
end

function ExclusiveGroup:setCurrent(b)
    local old = self.__current
    if old == b then return end
    self.__current = b
    self:currentChanged(b)
    if old then
        old:set("checked", false)
    end
    if b then
        b:set("checked", true)
    end
end

newClass("CheckButton", AbstractButton)

CheckButton.__checkable = true

function CheckButton:new(parent)
    AbstractButton.new(self, parent)
    self.layout = RowLayout(self)
    self.layout.anchorFill = self
    self.layout.spacing = 2
    self.square = Rectangle(self.layout)
    self.square.color = bind(Theme, "backgroundColor")
    self.square.borderWidth = 2
    self.square.borderColor = bind(function() return self.enabled and Theme.color or Theme.disabled end)
    self.square.implicitWidth = bind(function() return self.square.height end)
    self.square.Layout.fillHeight = true
    self.tick = Rectangle(self.square)
    self.tick.anchorFill = self.square
    self.tick.margins = 4
    self.label = Label(self.layout)
    self.label.Layout.alignment = Layout.AlignVCenter
    self.label.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or {.25,.25,.25} end)
    self._text = alias(self.label, "text")
    self.implicitWidth = bind(function() return self.layout.implicitWidth end)
    self.implicitHeight = bind(function() return self.layout.implicitHeight end)
    self.tick.color = bind(function() return self.containsPress and Theme.disabled or self.checked and (self.enabled and Theme.color or Theme.disabled) or {0, 0, 0, 0} end)
end

newClass("RadioButton", CheckButton)

function RadioButton:new(parent)
    parent.style.CheckButton.new(self, parent)
    self.autoExclusive = true
end

newClass("HScrollBar", Item)

function HScrollBar:new(parent)
    Item.new(self, parent)
    self.mouse = MouseArea(self)
    self.indicator = Rectangle(self)
    self.anchorBottomLeft = self.parent.bottomLeft
    self.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self or self.mouse:clearAnchors() end)
    self.visible = bind(function() return self.parent.contentWidth > self.parent.width - (self.parent.contentHeight > self.parent.height and self.parent.vscrollbar.width + 2 or 0) end)
    self.height = 4
    self.mouse:connect("clicked", function ()
        if self.mouse.mouseX > self.indicator.marginLeft then
            self.parent.contentX = math.min(self.parent.contentX + self.parent.availableWidth, self.parent.contentWidth - self.parent.availableWidth)
        else
            self.parent.contentX = math.max(self.parent.contentX - self.parent.availableWidth, 0)
        end
    end)
    self.indicator.width = bind(function() return math.max(self.width*self.parent.availableWidth/self.parent.contentWidth, math.min(16, self.width * 0.2)) end)
    self.indicator.anchorTop = self.top
    self.indicator.marginLeft = bind(function() return (self.width - self.indicator.width) * self.parent.contentX/(self.parent.contentWidth - self.parent.availableWidth) end)
    self.indicator.anchorBottomLeft = self.bottomLeft
    self.indicator.color = bind(function() return faded(Theme.color, .666) end)
    self.indicator.mouse = MouseArea(self.indicator)
    self.indicator.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self.indicator or nil end)
    self.indicator.mouse:connect("pressedChanged", function(p) if p then self.indicator.mouse.x = self.indicator.mouse.mouseX else self.indicator.mouse.x = nil end end)
    self.indicator.mouse:connect("mouseXChanged", function (x)
        local ox = self.indicator.mouse.x
        if ox then
            self.parent.contentX = math.max(math.min(self.parent.contentX + (self.parent.contentWidth - self.parent.availableWidth)*(x - ox)/(self.width - self.indicator.width), self.parent.contentWidth - self.parent.availableWidth), 0)
        end
    end)
end

newClass("VScrollBar", Item)

function VScrollBar:new(parent)
    Item.new(self, parent)
    self.mouse = MouseArea(self)
    self.indicator = Rectangle(self)
    self.anchorTopRight = self.parent.topRight
    self.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self or nil end)
    self.visible = bind(function() return self.parent.contentHeight > self.parent.height - (self.parent.contentWidth > self.parent.width and self.parent.hscrollbar.height + 2 or 0) end)
    self.width = 4
    self.mouse:connect("clicked", function ()
        if self.mouse.mouseY > self.indicator.marginTop then
            self.parent.contentY = math.min(self.parent.contentY + self.parent.availableHeight, self.parent.contentHeight - self.parent.availableHeight)
        else
            self.parent.contentY = math.max(self.parent.contentY - self.parent.availableHeight, 0)
        end
    end)
    self.indicator.height = bind(function() return math.max(self.height*self.parent.availableHeight/self.parent.contentHeight, math.min(16, self.width * 0.2)) end)
    self.indicator.anchorLeft = self.left
    self.indicator.marginTop = bind(function() return (self.height - self.indicator.height) * self.parent.contentY/(self.parent.contentHeight - self.parent.availableHeight) end)
    self.indicator.anchorTopRight = self.topRight
    self.indicator.color = bind(function() return faded(Theme.color, .666) end)
    self.indicator.mouse = MouseArea(self.indicator)
    self.indicator.mouse.anchorFill = bind(function() return self.parent.interactiveBars and self.indicator or nil end)
    self.indicator.mouse:connect("pressedChanged", function(p) if p then self.indicator.mouse.y = self.indicator.mouse.mouseY else self.indicator.mouse.y = nil end end)
    self.indicator.mouse:connect("mouseYChanged", function (y)
        local oy = self.indicator.mouse.y
        if oy then
            self.parent.contentY = math.max(math.min(self.parent.contentY + (self.parent.contentHeight - self.parent.availableHeight)*(y - oy)/(self.height - self.indicator.height), self.parent.contentHeight - self.parent.availableHeight), 0)
        end
    end)
end

newClass("Flickable", Item)

Flickable:attach("contentItem", nil, "setContentItem")
Flickable:attach("contentWidth")
Flickable:attach("contentHeight")
Flickable:attach("contentImplicitWidth")
Flickable:attach("contentImplicitHeight")
Flickable:attach("interactiveBars")
Flickable:attach("contentX", nil, "setContentX")
Flickable:attach("contentY", nil, "setContentY")
Flickable:attach("availableWidth")
Flickable:attach("availableHeight")
Flickable:attach("needVScroll")
Flickable:attach("needHScroll")
Flickable:attach("availableHeight")
Flickable.__contentHeight = 0
Flickable.__contentWidth = 0
Flickable.__availableHeight = 0
Flickable.__availableWidth = 0
Flickable.__contentImplicitHeight = 0
Flickable.__contentImplicitWidth = 0
Flickable.__contentX = 0
Flickable.__contentY = 0
Flickable.__interactiveBars = true

function Flickable:new(parent)
    Item.new(self, parent, EFrame:newFrame("ScrollFrame"))
    self.frame:EnableMouseWheel(1)
    self.frame:SetScript("OnMouseWheel", EFrame:makeAtomic( function ()
        if IsShiftKeyDown() then
            self.contentX = math.max(math.min(self.contentX - 25 * delta, self.contentWidth - self.availableWidth), 0)
        else
            self.contentY = math.max(math.min(self.contentY - 25 * delta, self.contentHeight - self.availableHeight), 0)
        end
    end))
    self.hscrollbar = self.style.HScrollBar(self)
    self.vscrollbar = self.style.VScrollBar(self)
    self.hscrollbar.width = bind(function() return self.width - (self.needVScroll and self.interactiveBars and self.vscrollbar.width + 2 or 0) end)
    self.vscrollbar.height = bind(function() return self.height - (self.needHScroll and self.interactiveBars and self.hscrollbar.height + 2 or 0) end)
    self.availableWidth = bind(function() return self.width - (self.needVScroll and self.interactiveBars and self.vscrollbar.width + 2 or 0) end)
    self.availableHeight = bind(function() return self.height - (self.needHScroll and self.interactiveBars and self.hscrollbar.height + 2 or 0) end)
    self.contentWidth = bind(function() return self.contentItem and self.contentItem.width or 0 end)
    self.contentHeight = bind(function() return self.contentItem and self.contentItem.height or 0 end)
    self.contentImplicitWidth = bind(function() return self.contentItem and self.contentItem.implicitWidth or 0 end)
    self.contentImplicitHeight = bind(function() return self.contentItem and self.contentItem.implicitHeight or 0 end)
    self.implicitWidth = bind(function() return self.contentImplicitWidth + (self.needVScroll and self.interactiveBars and self.vscrollbar.width + 2 or 0) end)
    self.implicitHeight = bind(function() return self.contentImplicitHeight + (self.needHScroll and self.interactiveBars and self.hscrollbar.height + 2 or 0) end)
    self:connect("contentWidthChanged", function() self.frame:UpdateScrollChildRect() end)
    self:connect("contentHeightChanged", function() self.frame:UpdateScrollChildRect() end)
    self:connect("widthChanged", function() self.frame:UpdateScrollChildRect() end)
    self:connect("heightChanged", function() self.frame:UpdateScrollChildRect() end)
    self.needHScroll = bind(function() return self.contentImplicitWidth > self.width - (self.interactiveBars and self.contentImplicitHeight > self.height and self.vscrollbar.width + 2 or 0) end)
    self.needVScroll = bind(function() return self.contentImplicitHeight > self.height - (self.interactiveBars and self.contentImplicitWidth > self.width and self.hscrollbar.height + 2 or 0) end)
end

function Flickable:destroy()
    self.frame:SetScrollChild(nil)
    self.frame:EnableMouseWheel(0)
    self.frame:SetScript("OnMouseWheel", nil)
    Item.destroy(self)
end

function Flickable:setContentItem(citem)
    if citem == bind(function() return self.contentItem end) then return end
    self.__contentItem = citem
    self.frame:SetScrollChild(citem.frame)
    self:contentItemChanged(citem)
end

function Flickable:setContentX(x)
    x = round(x)
    if x == self.__contentX then return end
    self.frame:SetHorizontalScroll(x)
    self.__contentX = round(x)
    self:contentXChanged(x)
end

function Flickable:setContentY(y)
    y = round(y)
    if y == self.__contentY then return end
    self.frame:SetVerticalScroll(y)
    self.__contentY = round(y)
    self:contentYChanged(y)
end

newClass("TextEdit", Item)

TextEdit:attach("text", nil,"setText")
TextEdit:attach("focus", nil, "setFocus")
TextEdit:attach("color",nil,"setColor")
TextEdit:attach("multiLine",nil,"setMultiLine")
TextEdit:attach("numeric",nil,"setNumeric")
TextEdit:attach("shadowColor","getShadowColor","setShadowColor")
TextEdit:attach("shadowOffset","getShadowOffset","setShadowOffset")
TextEdit:attach("outline","getOutline","setOutline")
TextEdit:attach("justifyH","getJustifyH","setJustifyH")
TextEdit:attach("justifyV","getJustifyV","setJustifyV")
TextEdit:attach("fontSize", nil, "setFontSize")
TextEdit:attach("readOnly")
TextEdit:attachSignal("enterPressed")
TextEdit.__multiLine = false
TextEdit.__text = ""

function TextEdit:new(parent)
    Item.new(self, parent, EFrame:newFrame("EditBox"))
    self.frame:SetFontObject("ChatFontNormal")
    self.frame:SetAutoFocus(false)
    self.frame.autoHeight = true
    self.off = Label(self)
    self.off.text = bind(function() return self.text end)
    self.readOnly = false
    self.__focus = false
    self.frame:SetScript("OnTextChanged", EFrame:makeAtomic( function() if self.readOnly then this:SetText(self.__text) else self:setText(this:GetText()) end end))
    self.frame:SetScript("OnKeyDown", EFrame:makeAtomic( function() this:SetPropagateKeyboardInput(self.readOnly) end))
    self.frame:SetScript("OnKeyUp", EFrame:makeAtomic( function() this:SetPropagateKeyboardInput(self.readOnly) end))
    self.frame:SetScript("OnEditFocusGained", EFrame:makeAtomic( function() self.focus = true end))
    self.frame:SetScript("OnEditFocusLost", EFrame:makeAtomic( function() self.focus = false end))
    self.frame:SetScript("OnEnterPressed", EFrame:makeAtomic( function() if self.__multiLine then this:Insert("\n") else self:enterPressed() end end))
    self.frame:SetScript("OnEscapePressed", EFrame:makeAtomic( function() this:ClearFocus() end))
    self.implicitHeight = bind(function() return self.multiLine and self.height or self.off.contentHeight end)
    local function refreshCursorPosition() this:SetCursorPosition(this.p) self.frame:SetScript("OnUpdate", nil) end
  --  self:connect("widthChanged", function() if not self.frame:GetScript("OnUpdate") then self.frame.p = self.frame:GetCursorPosition() self.frame:SetScript("OnUpdate", EFrame:makeAtomic(refreshCursorPosition)) end end)
  --  self:connect("effectiveScaleChanged", function() if not self.frame:GetScript("OnUpdate") then self.frame.p = self.frame:GetCursorPosition() self.frame:SetScript("OnUpdate", EFrame:makeAtomic(refreshCursorPosition)) end end)
end

function TextEdit:destroy()
    self.frame:SetScript("OnUpdate", nil)
    self.frame:SetScript("OnTextChanged", nil)
    self.frame:SetScript("OnKeyDown", nil)
    self.frame:SetScript("OnKeyUp", nil)
    self.frame:SetScript("OnEditFocusGained", nil)
    self.frame:SetScript("OnEditFocusLost", nil)
    self.frame:SetNumeric(false)
    self.frame:SetMultiLine(false)
    Item.destroy(self)
end

function TextEdit:setText(t)
    if t == self.__text then return end
    self.__text = t
    self.frame:SetText(t)
    self:textChanged(t)
end

function TextEdit:setFocus(f)
    if self.focus == f then return end
    self.__focus = f
    if f then
        self.frame:SetFocus()
    else
        self.frame:ClearFocus()
    end
    self:focusChanged(f)
end

function TextEdit:setColor(color)
    if colorComp(self.__color, color) then
        return
    end
    self.__color = color
    self.frame:SetTextColor(unpack(color))
    self:colorChanged(color)
end

function TextEdit:getShadowColor()
    return {self.frame:GetShadowColor()}
end
    
function TextEdit:setShadowColor(c)
    local old = self:getShadowColor()
    if colorComp(old, c) then return end
    self.frame:SetShadowColor(unpack(c))
    self:shadowColorChanged(c)
end
    
function TextEdit:setMultiLine(m)
    if self.__multiLine == m then return end
    self.frame:SetMultiLine(m)
    self.__multiLine = m
    self:multiLineChanged(m)
end
    
function TextEdit:setNumeric(n)
    if self.__numeric == n then return end
    self.frame:SetNumeric(n)
    self:numericChanged(c)
end

function TextEdit:setFontSize(s)
    if s == self.__fontSize or s <= 0 then return end
    local f = self.frame:GetFont()
    self.frame:SetFont(f, s)
    self.__fontSize = s
    self:fontSizeChanged(s)
end

function TextEdit:selectText(p0, p1)
    self.frame:HighlightText(p0,p1)
end

newClass("TextArea", Flickable)

function TextArea:new(parent)
    Flickable.new(self, parent)
    self.contentItem = TextEdit(self)
    self.contentItem.multiLine = true
    self._text = alias(self.contentItem, "text")
    self._focus = alias(self.contentItem, "focus")
    self._color = alias(self.contentItem, "color")
    self._multiLine = alias(self.contentItem, "multiLine")
    self._numeric = alias(self.contentItem, "numeric")
    self._shadowColor = alias(self.contentItem, "shadowColor")
    self._outline = alias(self.contentItem, "outline")
    self._justifyH = alias(self.contentItem, "justifyH")
    self._justifyV = alias(self.contentItem, "justifyV")
    self._readOnly = alias(self.contentItem, "readOnly")
    self._fontSize = alias(self.contentItem, "fontSize")
    self.contentItem.width = bind(function() return self.width end)
end

Slider = {}

function TextArea:selectText(p0, p1)
    self.contentItem:selectText(p0, p1)
end

newClass("Layout", Item)
newClass("RowLayout", Layout)
newClass("SpinBox", RowLayout)

SpinBox:attach("to")
SpinBox:attach("from")
SpinBox:attach("step")
SpinBox:attach("value")
SpinBox:attach("integer")
SpinBox:attachSignal("valueModified")
SpinBox.__value = 0
SpinBox.__step = 1

function SpinBox:new(parent)
self.debug = true
    self.__suspend = true
    RowLayout.new(self, parent)
    self.less = self.style.Button(self)
    self.less.text = "-"
    self.less.Layout.preferredWidth = bind(function() return self.less.height end)
    self.text = TextEdit(self)
    self.text.numeric = bind(function() return self.integer end)
    self.text.Layout.preferredWidth = 30
    self.text.Layout.fillHeight = true
    self.text.Layout.fillWidth = true
    self.text.text = bind(function() return self.value end)
    self.text.interactiveBars = false
    self.more = self.style.Button(self)
    self.more.text = "+"
    self.more.Layout.preferredWidth = bind(function() return self.more.height end)
    self.less.enabled = bind(function() return not self.from or self.value ~= self.from end)
    self.more.enabled = bind(function() return not self.to or self.value ~= self.to end)
    self.less:connect("clicked", function() local f = math.floor((self.__value - self.__step)*1000+0.5)/1000 if self.__from and f < self.__from then f = self.__from end self:setValue(f) self:valueModified(f) end)
    self.more:connect("clicked", function() local f = math.floor((self.__value + self.__step)*1000+0.5)/1000 if self.__to and f > self.__to then f = self.__to end self:setValue(f) self:valueModified(f) end)
    self.text:connect("enterPressed", function() local n = tonumber(self.text.__text) if n and (not self.__from or n >= self.__from) and (not self.__to or n <= self.__to) then self:setValue(n) self:valueModified(self.__value) end end)
    self.suspend = false
end

newClass("ListModel", Object)
ListModel:attach("count")
ListModel.__count = 0

function ListModel:new(init)
    Object.new(self)
    self.roles = {}
    if init then
        for k, v in ipairs(init) do
            if type(v) == "table" then
                self:appendFromTable(v)
            end
        end
        self.count = getn(init)
    end
end

function ListModel:appendFromTable(t)
    local obj = Object(self)
    for k, v in pairs(t) do
        assert(getn(self) == 0 or self.roles[k])
        obj:attach(k)
        obj["__"..k] = v
        self.roles[k] = true
    end
    tinsert(self, obj)
end

function ListModel:appendEmpty()
    local obj = Object(self)
    for k in pairs(self.roles) do
        obj:attach(k)
    end
    tinsert(self,obj)
end

function ListModel:move(from, to)
    for k in pairs(self.roles) do
        to[k] = from[k]
    end
end

function ListModel:shiftLeft(p)
    for i = math.min(self.__count, getn(self) -1), p, -1 do
        self:move(self[i], self[i+1])
    end
end

function ListModel:shiftRight(p)
    for i = p, self.__count do
        self:move(self[i], self[i-1])
    end
end

function ListModel:add(i, p)
    local c = self.__count
    p = p or c + 1
    if getn(self) +1 == p then
        self:appendFromTable(i)
    else
        if c == getn(self) then
            self:appendEmpty()
        end
        if c >= p then
            self:shiftLeft(p)
        end
        self:move(i, self[p])
    end
    self.count = c +1
end

function ListModel:remove(p)
    local c = self.__count
    p = p or c
    self:shiftRight(p+1)
    self.count = c -1
end

newClass("ListView", Flickable)

ListView:attach("currentIndex")
ListView:attach("delegate")
ListView:attach("spacing")
ListView:attach("model", nil, "setModel")
ListView:attach("highlightDelegate", nil, "setHighlightDelegate")
ListView.__spacing = 0

function ListView:new(parent)
    Flickable.new(self, parent)
    self.contentItem = Item(self)
    self.list = ColumnLayout(self.contentItem)
    self.list.spacing = bind(self, "spacing")
    self.contentItem.implicitWidth = bind(function() return self.list.implicitWidth end)
    self.contentItem.width = bind(function() return math.max(self.contentItem.implicitWidth, self.availableWidth) end)
    self.contentItem.implicitHeight = bind(function() return self.list.implicitHeight end)
    self.list.anchorFill = self.contentItem
    self.entries = {}
    local b = bind(function ()
        if not self.delegate then return end
        local n = self.model and (self.model.count or getn(self.model)) or 0
        for i = getn(self.entries) +1, n do
            local f = self.delegate(self.list, i)
            f.Layout.fillWidth = true
            tinsert(self.entries, f)
        end
        for i = getn(self.entries), n+1, -1 do
            self.entries[i]:deleteLater()
            self.entries[i] = nil
        end
        if self.__currentIndex and self.__currentIndex > n then
            self.currentIndex = n
        end
    end)
    b.parent = self
    b:update()
end

function ListView:setModel(m)
    if self.__model == m then return end
    self.__model = m
    self:modelChanged(m)
end
    
function ListView:setHighlightDelegate(d)
    local old = self.__highlightDelegate
    if old == d then return end
    if old then
        old:deleteLater()
    end
    self.__highlightDelegate = d
    if d then
        self.highlight = d(self.contentItem)
        self.highlight.anchorFill = bind(function() local i = self.currentIndex if not i then self.highlight:clearAnchors() else return self.list.childrenItems[i] end end)
    end
end

newClass("ComboBox", MouseArea)
ComboBox:attach("currentIndex")
ComboBox:attach("model")
ComboBox:attach("textRole")
ComboBox:attachSignal("activated")

function ComboBox:new(parent)
    MouseArea.new(self, parent)
    self.background = Rectangle(self)
    self.background.borderColor = bind(function() return self.enabled and Theme.color or Theme.disabledPressed end)
    self.background.color = {0, 0, 0, 0}
    self.background.borderWidth = 2
    self.background.anchorFill = self
    self.row = RowLayout(self)
    self.row.margins = 4
    self.row.anchorFill = self
    self.textLabel = Label(self.row)
    self.textLabel.color = bind(function() return self.enabled and {GameFontNormal:GetTextColor()} or (not self.checked and {0.25,0.25,0.25} or {.66,.66,.66}) end)
    self.textLabel.text = bind(function() local idx, model = self.currentIndex, self.model return idx and model and idx >= 1 and idx <= getn(model) and (self.textRole and self.model[idx][self.textRole] or model[idx]) or "" end)
    self.textLabel.Layout.preferredWidth = bind(function() return math.max(self.textLabel.implicitWidth, 30) end)
    self.textLabel.Layout.preferredHeight = bind(function() return math.max(self.textLabel.implicitHeight, 8) end)
    self.icon = Image(self.row)
    self.icon.color = bind(Theme, "color")
    self.icon.source = "Interface\\AddOns\\EmeraldFramework\\Textures\\ArrowDownward"
    self.icon.Layout.fillHeight = true
    self.icon.Layout.aligniment = Layout.AlignRight
    self.icon.Layout.preferredWidth = bind(function() return self.icon.height end)
    self.implicitWidth = bind(function() return self.row.implicitWidth + 8 end)
    self.implicitHeight = bind(function() return self.row.implicitHeight + 8 end)
    self.dropdown = Rectangle(self)
    self.dropdown.z = 10
    self.list = ListView(self.dropdown)
    self.dropdown.anchorTopLeft = self.bottomLeft
    self.dropdown.borderColor = bind(Theme, "color")
    self.dropdown.borderWidth = 2
    self.dropdown.color = bind(Theme, "backgroundColor")
    self.dropdown.width = bind(function() return math.max(self.list.implicitWidth + 8, self.width) end)
    self.dropdown.height = bind(function() return math.min(self.list.implicitHeight + 8, 120) end)
    self.list.margins = 4
    self.list.anchorFill = self.dropdown
    self.list.model = bind(function() return self.model end)
    self.list.delegate = function (parent, index)
        local btn = Button(parent)
        btn.text = bind(function() return self.textRole and self.model[index][self.textRole] or self.model[index] end)
        btn.flat = true
        btn.hAlignment = "LEFT"
        btn:connect("clicked", function() self.currentIndex = index self:activated(self.__currentIndex) end)
        return btn
    end
    self.dropdown.visible = false
    self:connect("clicked", function() self.dropdown.visible = not self.dropdown.__visible end)
    self:connect("activated", function() if not IsShiftKeyDown() then self.dropdown.visible = false end end)
    self:connect("enabledChanged", function(e) if not e then self.dropdown.visible = false end end)
end

newClass("Window", Item)

Window:attach("background",nil, "setBackground")
Window:attach("centralItem", nil, "setCentralItem")
Window:attach("minimized", nil, "minimize")
Window:attach("minimumHeight")
Window:attach("minimumWidth")
Window:attach("padding")
Window:attach("title")
Window.__padding = 0
Window.__minimized = false
Window.__minimumWidth = 1
Window.__minimumHeight = 1
Window.__title = ""

function Window:new(parent)
    Item.new(self, parent)
    self.marea = MouseArea(self)
    self.marea.visible = bind(function() return not self.locked end)
    self.marea.dragTarget = self
    self.decoration = Rectangle(self.marea)
    self.decoration.anchorTop = self.marea.top
    self.decoration.anchorLeft = self.marea.left
    self.decoration.anchorRight = self.marea.right
    self.decoration.color = bind(Theme, "decorationColor")
    self.decoration.layout = RowLayout(self.decoration)
    self.decoration.layout.margins = 2
    self.decoration.layout.anchorFill = self.decoration
    self.decoration.visible = bind(function() return not self.borderless end)
    self.titleLabel = Label(self.decoration.layout)
    self.titleLabel.Layout.alignment = Layout.AlignVCenter
    self.titleLabel.Layout.fillWidth = true
    self.titleLabel.text = bind(self, "title")
    self.minimizeButton = self.style.Button(self.decoration.layout)
    self.minimizeButton.Layout.fillHeight = true
    self.minimizeButton.flat = true
    self.minimizeButton.implicitWidth = bind(function() return self.minimizeButton.height end)
    self.minimizeButton.checkable = true
    self.minimizeButton.icon = "Interface\\Addons\\EmeraldFramework\\Textures\\MinimizeButton"
    self.minimizeButton:connect("checkedChanged", function(c) self:minimize(c) end)
    self.closeButton = self.style.Button(self.decoration.layout)
    self.closeButton.Layout.fillHeight = true
    self.closeButton.flat = true
    self.closeButton.implicitWidth = bind(function() return self.closeButton.height end)
    self.closeButton.icon = "Interface\\Addons\\EmeraldFramework\\Textures\\CloseButton"
    self.closeButton:connect("clicked", function() self.visible = false end)
    self.decoration.height = bind(function() return max(20, self.titleLabel.contentHeight) end)
    self.background = Rectangle(self)
    self:connect("visibleChanged", function (v)
        if v then
            self.minimizeButton.checked = false
        end
    end)
    self.background.borderColor = bind(Theme, "borderColor")
    self.background.color = bind(Theme, "backgroundColor")
    self.background.borderWidth = 2
    self.background.margins = bind(function() return -self.background.borderWidth -self.padding end)
    self.background.visible = bind(function() return not self.minimized end)
    self.resize_frame = self.style.Button(self.marea)
    self.resize_frame.icon = "Interface\\Addons\\EmeraldFramework\\Textures\\ResizeHandle_small"
    self.resize_frame:connect("pressedChanged", function(p)
        if p then
            self.resize_frame.ox = self.resize_frame.mouseX
            self.resize_frame.oy = self.resize_frame.mouseY
        end
    end)
    self.resize_frame:connect("mouseXChanged", function (x)
        if self.resize_frame.__pressed then
            self.width = math.max(self.__width + (x - self.resize_frame.ox), math.max(self.minimumWidth, self.decoration.layout.implicitWidth))
        end
    end)
    self.resize_frame:connect("mouseYChanged", function (y)
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
    self.marea.marginTop = bind(function() return self.borderless and 0 or -self.decoration.height - self.background.borderWidth - self.padding end)
    self.marea.marginBottom = bind(function() return self.borderless and 0 or (self.minimized and self.height or -self.background.borderWidth)  - self.padding end)
    self.marea.marginLeft = bind(function() return self.borderless and 0 or -self.background.borderWidth - self.padding end)
    self.marea.marginRight = bind(function() return self.borderless and 0 or -self.background.borderWidth - self.padding end)
    self.anchorTopLeft = root.topLeft
    self.marginLeft = 2
    self.marginTop = 30
    self.minimumHeight = bind(function() return self.centralItem and self.centralItem.implicitHeight or 1 end)
    self.minimumWidth = bind(function() return self.centralItem and self.centralItem.implicitWidth or 1 end)
    self.implicitWidth = bind(function() return math.max(self.centralItem and self.centralItem.implicitWidth or 1, self.decoration.layout.implicitWidth) end)
    self.implicitHeight = bind(function() return math.max(self.centralItem and self.centralItem.implicitHeight or 1, 1) end)
end

function Window:setBackground(f)
    if self.background == f then
        return
    end
    self.__background = f
    if f then
        f.anchorFill = self
    end
    self:backgroundChanged(f)
end

function Window:setCentralItem(f)
    if f == self.centralItem then return end
    if f then
        f.anchorFill = self
    end
    self.__centralItem = f
    f.visible = not self.__minimized
    self:centralItemChanged(f)
end

function Window:minimize(flag)
    if self.__minimized == flag then return end
    if self.centralItem then
        self.centralItem.visible = not flag
    end
    self.__minimized = flag
    self:minimizedChanged(f)
end

newClass("PropertyAnimation", Object)

PropertyAnimation:attach("duration")
PropertyAnimation:attach("running", nil, "setRunning")
PropertyAnimation:attach("property")
PropertyAnimation:attach("easingCurve")
PropertyAnimation:attach("from")
PropertyAnimation:attach("to")
PropertyAnimation:attach("amplitude")
PropertyAnimation:attach("looping")
PropertyAnimation:attachSignal("finished")
PropertyAnimation.__running = false
PropertyAnimation.__duration = 1
PropertyAnimation.__from = 0
PropertyAnimation.__to = 0
PropertyAnimation.__amplitude = 1
PropertyAnimation.elapsed = 0

-- function PropertyAnimation:new(parent)
--     Object.new(self, parent)
-- end

function PropertyAnimation:setRunning(v)
    if v == self.__running then return end
    if v then
        root:connect("update", self, "update")
        self.__lastUpdate = GetTime()
        self.elapsed = 0
    else
        root:disconnect("update", self, "update")
    end
    self.__running = v
    self:runningChanged(v)
end

function PropertyAnimation:update()
    self.elapsed = self.elapsed + (GetTime() - self.__lastUpdate)/self.__duration
    self.__lastUpdate = GetTime()
    if self.elapsed > 1 then
        if self.__looping then
            self.elapsed = mod(self.elapsed,1)
        else
            self.elapsed = 1
            self.running = false
            self:finished()
        end
    end
    if not self.__property or not self.__parent then return end
    self.__easingCurve(self)
end

function PropertyAnimation:Linear()
    self.__parent[self.__property] = self.__from + (self.__to - self.__from) * self.elapsed
end
function PropertyAnimation:OutElastic()
    local t = self.elapsed
    local b = self.__from 
    local c = self.__to
    assert(not self.__amplitude or self.__amplitude >= 1)
    local a = (c-b)*(self.__amplitude or 1)
    local f = math.acos((c-b)/(a))
    self.__parent[self.__property] = ((c-b)-math.exp(-t*6)*math.cos((t)*2*math.pi+f)*a)+b
end
PropertyAnimation.__easingCurve = PropertyAnimation.Linear


newClass("ProgressBar", Item)

ProgressBar:attach("value", nil, "setValue")
ProgressBar:attach("from", nil, "setFrom")
ProgressBar:attach("to", nil, "setTo")
ProgressBar:attach("orientation", nil, "setOrientation")
ProgressBar:attach("texture", nil, "setTexture")
ProgressBar:attach("color", nil, "setColor")
ProgressBar.__from = 0
ProgressBar.__to = 0
ProgressBar.__value = 1
ProgressBar.__color = {1,1,1}
ProgressBar.__orientation = "HORIZANTAL"

function ProgressBar:new(parent)
    Item.new(self, parent, EFrame:newFrame("StatusBar"))
end

function ProgressBar:destroy()
    self.frame:SetOrientation("HORIZONTAL")
    self.frame:SetMinMaxValues(0, 100)
    self.frame:SetValue(0)
    self.frame:SetStatusBarColor(1,1,1,1)
    self.frame:SetStatusBarTexture(nil)
    Item.destroy(self)
end

function ProgressBar:setValue(v)
    v = math.floor(v+0.001)
    if v == self.__value then return end
    self.frame:SetValue(v)
    self.__value = v
    self:valueChanged(v)
end

function ProgressBar:setFrom(v)
    if v == self.__from then return end
    self.frame:SetMinMaxValues(v, self.__to)
    self.__from = v
    self:fromChanged(v)
end

function ProgressBar:setTo(v)
    if v == self.__to then return end
    self.frame:SetMinMaxValues(self.__from, v)
    self.__to = v
    self:toChanged(v)
end

function ProgressBar:setTexture(v)
    if v == self.__texture then return end
    self.frame:SetStatusBarTexture(v)
    self.__texture = v
    self:textureChanged(v)
end

function ProgressBar:setOrientation(v)
    if strupper(v) == self.__orientation then return end
    self.frame:SetOrientation(v)
    self.__orientation = v
    self:orientationChanged(v)
end

function ProgressBar:setColor(color)
    if colorComp(self.__color, color) then return end
    self.__color = color
    self.frame:SetStatusBarColor(unpack(color))
    self:colorChanged(color)
end

rootFrame:RegisterEvent("ADDON_LOADED")

rootFrame:SetScript("OnEvent", function ()
    if event == "ADDON_LOADED" then
        rootFrame:SetAllPoints()
        rootFrame:UnregisterEvent("ADDON_LOADED")
        rootFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
        if not EmeraldFrameworkSettings then
            setglobal("EmeraldFrameworkSettings", { theme = {} })
        end
        setmetatable(EmeraldFrameworkSettings, { __index = defaultSettings })
        if not EmeraldFrameworkSettings.theme then
            EmeraldFrameworkSettings.theme = {}
        end
        setmetatable(EmeraldFrameworkSettings.theme, { __index = defaultTheme })
        Theme.color = EmeraldFrameworkSettings.theme.color
        
        setglobal("EFrame", EFrame.styles[EmeraldFrameworkSettings.defaultStyle] or EF)
    else
        root:rescale()
    end 
end)

-- rootFrame:SetAllPoints()
-- UIParent:SetScript("OnShow", function() rootFrame:Show() end)
-- UIParent:SetScript("OnHide", function() rootFrame:Hide() end)
root = Item(nil, rootFrame, false)
root:attach("relativeUIScale")
root.__relativeUIScale = UIParent:GetScale()
root:attach("uiScale")
root.uiScale = bind(function() return root.relativeUIScale/root.scale end)
root:attachSignal("update")
root.name = "EFFrame.root"

function normalize(x)
    return x / root.scale
end

function normalizeUI(x)
    return x * root.uiScale
end

function normalizeBind(x)
    return bind(function() return x / root.scale end)
end

function normalizedBind(x)
    x = normalized(x)
    return bind(function() return x / root.scale end)
end

function normalized(x)
    return  x * root.scale
end

function root:rescale()
    local _,_,resx, resy = strfind(({GetScreenResolutions()})[GetCurrentResolution()],"^(%d+)x(%d+)$")
    self.scale =  768/resy
    root.relativeUIScale = UIParent:GetScale()
    self.__width = resx
    self:widthChanged(resx)
    self.__height = resy
    self:heightChanged(resy)
end

--local last = GetTime()
--local tt = 0
rootFrame:SetScript("OnUpdate", function ()
--     local t = debugprofilestop()
    root:update()
    EFrame:process()
--     tt = tt * 0.99 + (debugprofilestop() - t) * 0.01
--     if GetTime() - last > 1 then
--     --    print(tt)
--         last = GetTime()
--     end
end)
