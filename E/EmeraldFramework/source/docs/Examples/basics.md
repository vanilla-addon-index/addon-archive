# Basic Examples

## Using signals

```lua
local alarm = EFrame.Object()
alarm:attachSignal("triggered")

local connection = alarm.triggered:connect(function() print("The alarm is ringing") end)
alarm.triggered() -- prints "The alarm is ringing"
connection:disconnect()
alarm.triggered() -- does nothing
```

## Using properties

```lua
local alarm = EFrame.Object()
alarm:attach("ringing")

alarm.ringingChanged:connect(function(ringing) print(ringing and "The alarm begun ringing" or "The alarm stopped ringing") end)
alarm.ringing = true -- prints "The alarm begun ringing"
alarm.ringing = false -- prints "The alarm stopped ringing"
```

## Using classes

```lua
EFrame.newClass("Alarm", EFrame.Object)
Alarm:attachMeta("ringing")

local alarm = Alarm()

alarm.ringingChanged:connect(function(ringing) print(ringing and "The alarm begun ringing" or "The alarm stopped ringing") end)
alarm.ringing = true -- prints "The alarm begun ringing"
alarm.ringing = false -- prints "The alarm stopped ringing"
```

## Connecting to objects

```lua
local alarm = EFrame.Object()
alarm:attach("ringing")

local testSubject = EFrame.Object()

function testSubject.wakeUp()
    if not testSubject.awake then
        testSubject.awake = true
        print("testSubject woke up")
    end
    if alarm.ringing then
        alarm.ringing = false
    end
end

alarm.ringingChanged:connect(function(ringing) print(ringing and "The alarm begun ringing" or "The alarm stopped ringing") end)
alarm.ringingChanged:connect(testSubject, "wakeUp") -- connections are ordered
alarm.ringing = true -- prints "The alarm begun ringing", "testSubject woke up", "The alarm stopped ringing"
```

## Using bindings

```lua
local alarm = EFrame.Object()
alarm:attach("ringing")

local testSubject = EFrame.Object()
testSubject:attach("awake")

function testSubject.wakeUp()
    if not testSubject.awake then
        testSubject.awake = true
        print("testSubject woke up")
    end
    if alarm.ringing then
        alarm.ringing = false
    end
end

alarm.ringingChanged:connect(function(ringing) print(ringing and "The alarm begun ringing" or "The alarm stopped ringing") end)
testSubject.awakeChanged:connect(function(awake) print(awake and "testSubject woke up" or "testSubject fell asleep") end)
testSubject.awake = EFrame.bind(function() return not alarm.ringing end)
alarm.ringing = true -- prints "The alarm begun ringing", "testSubject woke up", "The alarm stopped ringing", "testSubject fell asleep"
```
