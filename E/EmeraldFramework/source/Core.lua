local EF
if EFrame == nil then 
    EFrame = {}
end
EF = EFrame

setmetatable(EF, {__index = getfenv() })
setfenv(1, EF)

local EFrame = EFrame

EFrame.debug = false

rootFrame = rootFrame or CreateFrame("frame")

function round(x)
    return math.floor(x+0.5)
end

local function weakTable()
    local t = {}
    setmetatable(t, {__mode = 'v'})
    return t
end

local bindLoop
local cnames = {}
setmetatable(cnames, {__index = function(self,k) local n = strupper(strsub(k,1,1)) .. strsub(k,2) self[k] = n return n end})
local gcnames = {}
setmetatable(gcnames, {__index = function(self,k) local n = 'get'..cnames[k] self[k] = n return n end})
local scnames = {}
setmetatable(scnames, {__index = function(self,k) local n = 'set'..cnames[k] self[k] = n return n end})
local mnames = {}
setmetatable(mnames, {__index = function(self,k) local n = '_'..k self[k] = n return n end})
local mmnames = {}
setmetatable(mmnames, {__index = function(self,k) local n = '__'..k self[k] = n return n end})
local asnames = {}
setmetatable(asnames, {__index = function(self,k) local n = "on" .. cnames[k] self[k] = n return n end})
local snames = {}
setmetatable(snames, {__index = function(self,k) local n = k.."Changed" self[k] = n return n end})

function EFrame:atomic(f, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    if not self.lock then
        local ret
        self.lock = true
        ret = f(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
        self:process()
        self.lock = nil
        return ret
    else
        return f(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    end
end

EFrame.stack = {}
local loading = GetTime()
local function sunpack(t)
    if t then
        return unpack(t)
    end
end
function EFrame:process()
--     if debugprofilestop() / 1000 - GetTime() > 1/(GetFramerate()*.8) and GetTime() ~= loading then
--         return
--     end
    local owns = not self.lock
    if owns then
        self.lock = true
    end
    local l = EFrame.procced
    while l.next do
        local f = l.next
        l.next = f.next
        local call = EFrame.debug and xpcall or pcall
        local fun, args
        if f.obj then
            local call = EFrame.debug and xpcall or pcall
            local ofun = f.obj[f.fun]
            fun = EFrame.debug and function() ofun(f.obj, sunpack(f.args)) end or ofun
            args = EFrame.debug and {geterrorhandler()} or {f.obj, sunpack(f.args)}
        else
            local call = EFrame.debug and xpcall or pcall
            fun = EFrame.debug and function() f.fun(sunpack(f.args)) end or f.fun
            args = EFrame.debug and {geterrorhandler()} or {sunpack(f.args)}
        end
        call(fun, unpack(args))
    end
    EFrame.procced.head = l
    if owns then
        self.lock = nil
    end
    if EFrame.debug then
        EFrame.stack = {}
    end
end

function EFrame:deleteEventsFor(o)
    local f = EFrame.procced
    while f.next do
        if f.next.obj == o then
            f.next = f.next.next
        else
            f = f.next
        end
    end
    EFrame.procced.head = f
end

collector = {}
objects = weakTable()

local statsCache = {total = 0, garbage = {}}
function EFrame:stats()
    local t = statsCache
    for k in pairs(t) do
        if k ~= "garbage" then
            t[k] = 0
            t.garbage[k] = 0
        end
    end
    t.garbage.total = 0
    for _,o in pairs(self.objects) do
        if o._destroyed then
            t.garbage[o.type] = (t.garbage[o.type] or 0) +1
            t.garbage.total = t.garbage.total +1
        else
            t[o.type] = (t[o.type] or 0) +1
            t.total = t.total +1
        end
    end
    return t
end

function EFrame:addObject(o)
    tinsert(objects,o)
end

function EFrame:addGarbage(o)
    tinsert(collector, o)
end

function EFrame:makeAtomic(f)
    return function (arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
        return self:atomic(f, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    end
end

function bind(a,b)
    if not b then
        return Bind(a)
    else
        return Bind(function() return a[b] end)
    end
end

function alias(o, p)
    return Alias(o,  p)
end

function EFrame:enqueue(f)
    EFrame.procced.head.next = f
    EFrame.procced.head = EFrame.procced.head.next
end

local function query(self, f, k)
    if type(f) == "table" then
        return f[k]
    else
        return f(self, k)
    end
end

local function getRecycled(t)
    local ret = tremove(t)
    if ret then
        ret._destroyed = nil
        return ret
    end
    local fresh = {}
    if EFrame.debug then
        EFrame:addObject(fresh)
    end
    return fresh
end

local function recycle(o)
    o._destroyed = true
    local tt = EFrame[o.type]
    tinsert(tt.recycle, o)
end

local function destroy(o)
    o._destroyed = true
end

local binding

function noBind(f, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    local old = binding
    if not old then return f(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) end
    binding = nil
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15 = f(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    binding = old
    return arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15
end

local function callNew(self, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    local obj = getRecycled(self.recycle)
    setmetatable(obj, self._MT)
    self.new(obj, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    return obj
end

local function getpmethodname(self, property, method)
    return self[mnames[property]][method]
end

local function getpmethod(self, property, method)
    return self[getpmethodname(self, property, method)]
end

local function objIndex(self, idx, k)
    if not k then return nil end
    local pn = mnames[k]
    local p = rawget(self, pn)
    if not p then
        p = idx[pn]
        if p and getmetatable(p) == Property._MT then
            rawset(self, pn, p)
        end
    end
    if p then
        if getmetatable(p) == Property._MT then
            return self:_get(k)
        end
        if getmetatable(p) == Alias._MT then
            return p.target[p.property]
        end
    end
--    if getmetatable(r) == Property._MT then
        rawset(self, k, idx[k])
  --  end
    return rawget(self, k)
end

local function objNewIndex(self, k, v)
    local p = self[mnames[k]]
    if getmetatable(p) == Alias._MT then
        p.target[p.property] = v
        return
    end
    if getmetatable(p) ~= Property._MT then
        return rawset(self, k, v)
    end
    local binds = self._binds
    local oldbind = binds[k]
    if oldbind and oldbind == v then
        return
    end
    if getmetatable(v) == Bind._MT then
        v.parent = self
        v._p = k
    --    v.lazy = true
    --    v.dirty = true
        v:update()
        binds[k] = v
    else
        binds[k] = nil
        self:set(k, v)
    end
    if oldbind then
        oldbind:destroy()
    end
end

function newClass(type, super)
    if rawget(getfenv(2),type) then error(format("type \"%s\" already exists.", type)) end
    getfenv(2)[type] = {type = type}
    local tt = getfenv(2)[type]
    if super then
        setmetatable(tt, { __call = callNew, __index = super })
    else
        setmetatable(tt, { __call = callNew })
    end
    if type == "Object" or super and super.isObject then
        tt._MT = {
            __index = function(self, k) return objIndex(self, tt, k) end,
            __newindex = function(self, k, v) objNewIndex(self, k, v) end }
    else
        tt._MT = { __index = tt }
    end
    tt.recycle = weakTable()
end

newClass("Array")

newClass("Object")

newClass("Connection")

newClass("Signal")

newClass("Property")

newClass("Alias")

function Array:new()
    self._lock = false
    self.toInsert = {}
    self.toRemove = {}
    self.commitOrder = {}
    self.data = {}
end

function Array:lock()
    if self._lock then
        return false
    end
    self._lock = true
    return true
end

function Array:commit()
    self._lock = false
    local op = tremove(self.commitOrder, 1)
    while op do
        if op == 1 then
            self.data[tremove(self.toRemove, 1)] = nil
        else
            local v = tremove(self.toInsert, 1)
            self.data[v] = v
        end
        op = tremove(self.commitOrder, 1)
    end
end

function Array:insert(v)
    if self._lock then
        tinsert(self.toInsert, v)
        tinsert(self.commitOrder, 2)
    else
        self.data[v] = v
    end
end

function Array:remove(v)
    if self._lock then
        tinsert(self.toRemove, v)
        tinsert(self.commitOrder, 1)
    else
        self.data[v] = nil
    end
end

function Array:iter()
    return pairs(self.data)
end


function Array:destroy()
    for k in pairs(self.data) do
        self.data[k] = nil
    end
    recycle(self)
end

function Connection._MT.__call(self, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    if not self.blocked then
        if self.lambda then
            self.target(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
        else
            if self.queued or self.nocombat or getmetatable(self.target) == Bind._MT and self.target.lazy then
                local args = {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15}
                EFrame:enqueue({fun=self.slot, obj=self.target ,args=args,nocombat = self.nocombat})
                if getmetatable(self.target) == Bind._MT then
                    self.target.dirty = true
                end
            else
                if EFrame.debug then
                    return xpcall(function() self.target[self.slot](self.target, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) end, geterrorhandler())
                else
                    return pcall(self.target[self.slot], self.target, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
                end
            end
        end
    end
end

function Connection:new(source, signal, target, slot)
    self.source = source
    self.target = target
    self.slot = slot
    self.signal = signal
    self.lambda = type(self.target) == "function"
end

function Connection:disconnect()
    if not self.lambda
    then
        self.target._connections[self] = nil
    end
    self.source:disconnect(self)
    destroy(self)
end

function Signal._MT.__call(self, obj, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    if EFrame.debug and type(obj.type) == "string" then
   --     tinsert(EFrame.stack, format("%s.%s(%s)", obj.type,self.name,tostring(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15 == nil and "" or arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15), ", "))
    end
    local locked
    if not EFrame.lock then
        EFrame.lock = true
        locked = true
    end
    local oldbind = binding
    binding = nil
    local auto = obj and self.autoslot and obj[self.autoslot]
    if auto then
        auto(obj, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
    end
    if obj.connections then
        local conns = obj.connections[self.name]
        if conns then
            local owned = conns:lock()
            for k, c in conns:iter() do
                c(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15)
            end
            if owned then
                conns:commit()
            end
        end
    end
    binding = oldbind
    if locked then
        EFrame:process()
        EFrame.lock = false
    end
    if EFrame.debug and type(obj.type) == "string" then
        tremove(EFrame.stack)
    end
end

function Signal:new(name)
    self.name = name
    self.autoslot = asnames[name]
end

function Signal:destroy()
    self:disconnectAll()
    if self.connections then
        self.connections:destroy()
    end
    destroy(self)
end

function Object:connect(signal, target, slot)
    local t1, t2 = type(target), type(slot)
    if EFrame.debug and (not (t1 == "table" and t2 == "string" or t1 == "function" and not slot)) then error(format("Cannot connect to types (<%s,%s>)",t1,t2)) end
    local c = Connection(self, signal, target, slot)
    local cs = self.connections[signal]
    if not cs then
        cs = Array()
        self.connections[signal] = cs
    end
    cs:insert(c)
    if t1 == "table" then
        target._connections[c] = c
    end
    return c
end

function Object:disconnect(signal, target, slot)
    if type(signal) == "table" and signal.type == "Connection" then
        local cs = self.connections[signal.signal]
        if not cs then return end
        return cs:remove(signal)
    end
    local cs = self.connections[signal]
    if not cs then return end
    for k,c in cs:iter() do
        if type(c) == "table" and c.target == target and c.slot == slot then
            cs:remove(c)
            break
        end
    end
end

function Object:disconnectAll(signal)
    local cs = self.connections[signal]
    if not cs then return end
    for _,c in cs:iter() do
        if type(c) == "table" then
            c:disconnect()
        end
    end
end

function Object:get(property)
    local bind = self._binds[property]
    if bind and bind.dirty then
        bind:update()
    end
    return noBind(getpmethod(self, property, "getter"), self)
end

function Object:_get(property)
    local bind = self._binds[property]
    if bind and bind.dirty then
        bind:update()
    end
    if binding then
        local s = getpmethodname(self, property, "signal")
        if s then
            binding:bind(self, s)
        end
    end
    return noBind(getpmethod(self, property, "getter"), self)
end

function Object:set(property, v)
    noBind(getpmethod(self, property, "setter"), self, v)
end

function Property:new(name, getter, setter, signal)
    self.name = name
    self.getter = getter
    self.setter = setter
    self.signal = signal
end

function Alias:new(target, property)
    self.target = target
    self.property = property
end

Object.isObject = true
    
function Object:new(parent)
    self._connections = {}
    self.connections = {}
    self._binds = {}
    
    self:attachSignal("destroyed")
    self.parent = parent
    self.__children = {}
end

Object.deleteLater = EFrame:makeAtomic( function (self)
    EFrame:enqueue({fun="destroy", obj=self})
end)

function Object:destroy()
    local t = self.type
    assert(not self._destroyed, "Attempt to destroy object twice.")
    self:destroyed(self)
    self:disconnectAll("destroyed")
    EFrame:deleteEventsFor(self)
    destroy(self)
    local c = tremove(self.children)
    while c do
        c:destroy()
        c = tremove(self.children)
    end
    if self.parent and not self.parent._destroyed then
        self.parent:removeChild(self)
    end
    for k in pairs(self.connections) do
        self:disconnectAll(k)
    end
    for k,c in pairs(self._connections) do
        c:disconnect()
    end
    
   -- self.parent = nil
    
    destroy(self)
end

Property.ReadOnly = "READONLY"
Property.Integer = "INTEGER"

function Object:attach(name, getterName, setterName, implicit)
    local sn = snames[name]
    getterName = getterName or gcnames[name]
    setterName = setterName or scnames[name]
    local mmname = mmnames[name]
    if setterName == Property.ReadOnly then
        setterName = scnames[name]
        self[setterName] = function() error(format("cannot make assignment to readonly property %s.",name)) end
    elseif setterName == Property.Integer then
        setterName = scnames[name]
        self[setterName] = function (self, v)
            v = round(v)
            if v == self[getterName](self) then return end
            rawset(self, mmname, v)
            local s = self[sn]
            if s then
                return s(self, v)
            end
        end
    end
    
    if not self[setterName] then
        self[setterName] = function (self, v)
            if v == self[getterName](self) then return end
            rawset(self, mmname, v)
            local s = self[sn]
            if s then
                return s(self, v)
            end
        end
    end
    
    if not self[getterName] then
        self[getterName] = function (self)
            return self[mmname]
        end
    end
    
    rawset(self, mnames[name], Property(name, getterName, setterName, snames[name]))
    self:attachSignal(sn)
end

function Object:attachSignal(n)
    rawset(self, n, Signal(n))
end

function Object:setParent(parent)
    local oldparent = self.__parent
    if parent == oldparent then return end
    if oldparent then
        oldparent:removeChild(self)
    end
    self.__parent = parent
    if parent then
        parent:addChild(self)
    end
    self:parentChanged(parent)
end

function Object:addChild(f)
    tinsert(self.__children, f)
    self:childrenChanged(self.__children)
end

function Object:removeChild(f)
    for k,c in pairs(self.__children) do
        if c == f then
            tremove(self.__children, k)
            self:childrenChanged(self.__children)
            return
        end
    end
end

Object:attach("children",nil, Property.ReadOnly)
Object:attach("parent", nil, "setParent")

newClass("Bind", Object)

function Bind:new(f, p)
    Object.new(self)
    if type(f) == "string" then
        f = loadstring(format("return function(self)return %s end", f))()
    end
    self._f = f
    self._p = p
    self._s = {}
end

function Bind:update()
--     if self.dirty then
--         self.dirty = false
--         EFrame:deleteEventsFor(self)
--     end
    local bindOwn
    if EFrame.debug then
        if not bindLoop then
            bindOwn = true
            bindLoop = {}
        end
        if self._p then
            if not bindLoop[self._p] then
                bindLoop[self._p] = (bindLoop[self._p] or 0) + 1
            else
                -- print("Binding loop detected for "..self._p.parent.type..":"..self._p.signal .. " / " .. bindLoop[self._p])
            end
        end
    end
    local _cs = self._connections
    for k, c in pairs(_cs) do
        c.blocked = true
    end
    local old = binding
    binding = self
    local v = self._f(self.parent)
    binding = old
    for k, c in pairs(_cs) do
        if c.blocked ~= 1 then
            c:disconnect()
            self._s[c.source][c.signal] = nil
            _cs[k] = nil
        else
            c.blocked = nil
        end
    end
    if self._p then
        self.parent:set(self._p, v)
    end
    if bindOwn then
        bindLoop = nil
    end
    return v
end

function Bind:schedule()
    EFrame:atomic(function(self) EFrame:enqueue({fun=self.update, obj=self}) end, self)
end

function Bind:bind(o, s)
    if not self._s[o] then
        self._s[o] = {}
    end
    local oc = self._s[o]
    local c = oc[s]
    if not c then
        oc[s] = o:connect(s, self, "update")
        oc[s].blocked = 1
    elseif c.blocked then
        c.blocked = 1
    end
end

function Bind:drop()
    for k,c in pairs(self._connections) do
        c:disconnect()
    end
end

function Bind:destroy()
    self:drop()
    Object.destroy(self)
end

EFrame.procced = {}
EFrame.procced.head = EFrame.procced
