local EF
if EFrame == nil then 
    EFrame = {}
end
EF = EFrame

setmetatable(EF, {__index = getfenv() })
setfenv(1, EF)

Layout.AlignLeft = 1
Layout.AlignRight = 2
Layout.AlignHCenter = 4
Layout.AlignTop = 32
Layout.AlignBottom = 64
Layout.AlignVCenter = 128
Layout.AlignCenter = bit.bor(Layout.AlignHCenter, Layout.AlignVCenter)
Layout.AlignHorizontalMask = 15
Layout.AlignVerticalMask = 240

Layout:attach("hasFillWidth")
Layout:attach("hasFillHeight")

function Layout:new(parent)
    Item.new(self, parent)
end

function Layout:addChildItem(c)
    c.anchorTopLeft = self.topLeft
    c.Layout = LayoutAttached(c)
    Item.addChildItem(self, c)
end

function Layout:removeChildItem(c)
    Item.removeChildItem(self, c)
    c.Layout = nil
end

local function getItemNetHeight(f)
    return f.Layout.preferredHeight or f.implicitHeight
end

local function getItemExtraHeight(f)
    return (f.Layout.marginTop or f.Layout.margins) + (f.Layout.marginBottom or f.Layout.margins)
end

local function getItemTotalHeight(f)
    return getItemNetHeight(f) + getItemExtraHeight(f)
end

local function getItemNetWidth(f)
    return f.Layout.preferredWidth or f.implicitWidth
end

local function getItemExtraWidth(f)
    return (f.Layout.marginLeft or f.Layout.margins) + (f.Layout.marginRight or f.Layout.margins)
end

local function getItemTotalWidth(f)
    return getItemNetWidth(f) + getItemExtraWidth(f)
end

newClass("LayoutAttached", Object)

LayoutAttached:attach("alignment")
LayoutAttached:attach("fillWidth")
LayoutAttached:attach("fillHeight")
LayoutAttached:attach("preferredWidth")
LayoutAttached:attach("preferredHeight")
LayoutAttached:attach("margins")
LayoutAttached:attach("marginLeft")
LayoutAttached:attach("marginRight")
LayoutAttached:attach("marginTop")
LayoutAttached:attach("marginBottom")
LayoutAttached.__margins = 0

newClass("GridLayout", Layout)


function GridLayout:new(nr, nc, parent)
    self.__rowSpacing = 0
    self.__columnSpacing = 0
    nr, nc = nr or 0, nc or 0
    Layout.new(self, parent)
    self:attach("rows")
    self:attach("columns")
    self:attach("rowSpacing")
    self:attach("columnSpacing")
    self:attach("grid")
    self.rows = nr
    self.columns = nc
    self.grid = {}
    local a = bind(function() self:refreshLayout() end)
    a.parent = parent
    a:update()
end

function GridLayout:refreshLayout()
end



function RowLayout:new(parent)
    self.__spacing = 0
    Layout.new(self, parent)
    self:attach("spacing")
    self.implicitHeight = bind(RowLayout._getImplicitHeight)
    self.implicitWidth = bind(RowLayout._getImplicitWidth)
    local a = bind(RowLayout.refreshLayoutX)
    a.parent = self
    --a.lazy = true
    a:update()
    local b = bind(RowLayout.refreshLayoutY)
    b.parent = self
    --b.lazy = true
    b:update()
end

function RowLayout:_getImplicitHeight()
    assert(not self.ylock)
    self.ylock = true
    local cc = self.childrenItems
    if getn(cc) == 0 then self.ylock = false return 0 end
    local mh = 0
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            mh = math.max(getItemTotalHeight(f), mh)
        end
    end
    self.ylock = false
    return mh
end

function RowLayout:_getImplicitWidth()
    assert(not self.xlock)
    self.xlock = true
    local cc = self.childrenItems
    local spacing = self.spacing
    if getn(cc) == 0 then self.xlock = false return 0 end
    local n = 0
    local cx = 0
    for k, f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            cx = cx + getItemTotalWidth(f)
            n = n +1
        end
    end
    self.xlock = false
    return cx + (n - 1) * spacing
end

function RowLayout:refreshLayoutX()
    assert(not self.rxlock)
    self.rxlock = true
    local cc = self.childrenItems
    local spacing = self.spacing
    local nc = getn(cc)
    local tex = self.width
    if nc == 0 then self.rxlock = false return end
    local cx, fw = 0, 0
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            if f.Layout.fillWidth then
                fw = fw + 1
            else
                tex = tex - getItemTotalWidth(f)
            end
        else
            nc = nc -1
        end
    end
    tex = tex - spacing * (nc -1)
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            local ex = fw == 0 and tex/nc or 0
            local ha = not f.Layout.alignment and 0 or bit.band(f.Layout.alignment, Layout.AlignHorizontalMask)
            local width = f.Layout.fillWidth and math.max(tex/fw - getItemExtraWidth(f), 0) or getItemNetWidth(f) + ex
            if f.Layout.fillWidth then
                f.width = width
                f.marginLeft = cx + (f.Layout.marginLeft or f.Layout.margins)
            else
                f.width = getItemNetWidth(f)
                f.marginLeft = cx + (ha == Layout.AlignHCenter and ex/2 or
                        ha == Layout.AlignRight and ex or 0) + (f.Layout.marginLeft or f.Layout.margins)
            end
            cx = cx + width + spacing + getItemExtraWidth(f)
        end
    end
    self.rxlock = false
end

function RowLayout:refreshLayoutY()
    assert(not self.rylock)
    self.rylock = true
    local cc = self.childrenItems
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            if f.Layout.fillHeight then
                f.height = math.max(self.height - getItemExtraHeight(f), 0)
                f.marginTop = f.Layout.marginTop or f.Layout.margins
            else
                local va = not f.Layout.alignment and Layout.AlignVCenter or bit.band(f.Layout.alignment, Layout.AlignVerticalMask)
                f.marginTop = (va == Layout.AlignVCenter and (self.height - getItemTotalHeight(f))/2 or
                    va == Layout.AlignBottom and self.height - f.height or 0) + (f.Layout.marginTop or f.Layout.margins)
            end
        end
    end
    self.rylock = false
end

newClass("ColumnLayout", Layout)

function ColumnLayout:new(parent)
    self.__spacing = 0
    Layout.new(self, parent)
    self:attach("spacing")
    self.implicitHeight = bind(ColumnLayout._getImplicitHeight)
    self.implicitWidth = bind(ColumnLayout._getImplicitWidth)
    local a = bind(ColumnLayout.refreshLayoutX)
    a.parent = self
    --a.lazy = true
    a:update()
    local b = bind(ColumnLayout.refreshLayoutY)
    b.parent = self
    --b.lazy = true
    b:update()
end

function ColumnLayout:_getImplicitHeight()
    assert(not self.ylock)
    self.ylock = true
    local cc = self.childrenItems
    local spacing = self.spacing
    if getn(cc) == 0 then self.ylock = false return 0 end
    local n = 0
    local cy = 0
    for k, f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            cy = cy + getItemTotalHeight(f)
            n = n +1
        end
    end
    self.ylock = false
    return cy + (n - 1) * spacing
end

function ColumnLayout:_getImplicitWidth()
    assert(not self.xlock)
    self.xlock = true
    local cc = self.childrenItems
    if getn(cc) == 0 then self.xlock = false return 0 end
    local mw = 0
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            mw = math.max(getItemTotalWidth(f), mw)
        end
    end
    self.xlock = false
    return mw
end

function ColumnLayout:refreshLayoutX()
    assert(not self.rxlock)
    self.rxlock = true
    local cc = self.childrenItems
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            if f.Layout.fillWidth then
                f.width = math.max(self.width - getItemExtraWidth(f), 0)
            else
                local ha = not f.Layout.alignment and 0 or bit.band(f.Layout.alignment, Layout.AlignHorizontalMask)
                f.marginLeft = (ha == Layout.AlignHCenter and (self.width - getItemTotalWidth(f))/2 or
                    ha == Layout.AlignRight and self.width - f.width or 0) + (f.Layout.marginLeft or f.Layout.margins)
            end
        end
    end
    self.rxlock = false
end 

function ColumnLayout:refreshLayoutY()
    assert(not self.rylock)
    self.rylock = true
    local cc = self.childrenItems
    local spacing = self.spacing
    local nc = getn(cc)
    local tex = self.height
    if nc == 0 then self.rylock = false return end
    local cy, fh = 0, 0
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            if f.Layout.fillHeight then
                fh = fh + 1
            else
                tex = tex - getItemTotalHeight(f)
            end
        else
            nc = nc -1
        end
    end
    tex = tex - spacing * (nc -1)
    for _,f in ipairs(cc) do
        if f.visible or f.frame:IsShown() == 1 then
            local ex = fh == 0 and tex/nc or 0
            local va = not f.Layout.alignment and Layout.AlignVCenter or bit.band(f.Layout.alignment, Layout.AlignVerticalMask)
            local height = f.Layout.fillHeight and math.max(tex/fh - getItemExtraHeight(f), 0) or getItemNetHeight(f) + ex
            if f.Layout.fillHeight then
                f.height = height
                f.marginTop = cy + (f.Layout.marginTop or f.Layout.margins)
            else
                f.height = f.Layout.preferredHeight or f.implicitHeight
                f.marginTop = cy + (va == Layout.AlignTop and 0 or
                        va == Layout.AlignBottom and ex or ex/2) + (f.Layout.marginTop or f.Layout.margins)
            end
            cy = cy + height + spacing + getItemExtraHeight(f)
        end
    end
    self.rylock = false
end
