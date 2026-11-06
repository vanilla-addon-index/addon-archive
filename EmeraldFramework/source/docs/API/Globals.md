# Global Functions

`newClass(className[, baseClass])`
------------------------------------------------

### Arguments
- `className`: a string defining the name of the new class
- `baseClass`: the table of the base calss

### Returns
- `nil`

### Description

Creates a new class using `baseClass` as base (if provided). The class table is stored into the field named by `className` in the global scope of the caller.


`bind(fun)`
------------------------------------------------

### Arguments
- `fun`: the function to be bound

### Returns
- a `Bind` wrapping `fun`

### Description

Creates a `Bind` containig the `fun` function.


`noBind(fun, ...)`
------------------------------------------------

### Arguments
- `fun`: a function to be executed
- `...`: function arguments

### Returns
- `fun`'s return

### Description

Execute `fun` inside a bind without binding accessed properties.


`EFrame:atomic(fun[, ...])`
------------------------------------------------

### Arguments
- `fun`: the function to be called
- `...`: arguments forwarded to `fun`

### Returns
- `fun`'s return

### Description

Execute a function blocking all queued connections till its terminations.


`EFrame:makeAtomic(fun)`
------------------------------------------------

### Arguments
- `fun`: the function to be wrapped

### Returns
- an atomic function wrapping `fun`

### Description

Wraps a function so that all queued connections are blocked till its termination, see `EFrame:atomic(fun[, ...])`


`EFrame:invokeNoCombat(fun[, ...])`
------------------------------------------------

### Arguments
- `fun`: the function to be called
- `...`: arguments forwarded to `fun`

### Returns
- `true` followed by `fun`'s return if the function was not deferred, `false` otherwise

### Description

If out of combat restrictions, the function is executed as [atomic](/API/Globals#eframeatomicfun), elsewise is queued until combat restrictions are dropped.
