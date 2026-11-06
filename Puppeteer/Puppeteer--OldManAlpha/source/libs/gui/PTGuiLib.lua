-- A GUI library that wraps frames, making complex functionality easier, and facilitates frame aquisition and disposal.
-- It is currently only intended for use in Puppeteer because it's specific to what I want and I'm too lazy to implement 
-- more things devs would want in a GUI library.
PTGuiLib = {}
PTUtil.SetEnvironment(PTGuiLib)
local getn = table.getn

ComponentRegistry = {}
ComponentPool = {}

local function _Get(componentType)
    local pool = ComponentPool[componentType]
    local component
    if getn(pool) > 0 then
        component = table.remove(pool, getn(pool))
    else
        component = ComponentRegistry[componentType]:New()
    end
    component:OnAcquire()
    return component
end

function Get(componentType, parent)
    local component = _Get(componentType)
    if parent then
        component:SetParent(parent)
    end
    return component
end

function GetText(parent, text, fontSize)
    local component = Get("text", parent)
    component:SetText(text)
    if fontSize then
        component:SetFontSize(fontSize)
    end
    return component
end

function Recycle(component)
    table.insert(ComponentPool[component:Type()], component)
end

function RegisterComponent(class)
    ComponentRegistry[class:Type()] = class
    ComponentPool[class:Type()] = {}
end

function GetClass(componentType)
    return ComponentRegistry[componentType]
end