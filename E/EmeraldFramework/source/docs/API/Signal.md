# Class Signal

`:connect(fun)`
------------------------------------------------

### Arguments
- `fun`: the callback function

### Returns
- a `Connection` between the `Signal` and `fun` which can be stored to disconnect `fun` later.

### Description

Connects the `Signal` to `fun`, causing `fun` to be called whenever the `Signal` is called until its disconnection.


`:connect(target, functionName)`
------------------------------------------------

### Arguments
- `target`: an `Object` or derivate
- `functionName`: a string containing the name of the function to be called

### Returns
- a `Connection` between the `Signal` and `fun` which can be stored to disconnect later.

### Description

Connects the `Signal` to `target`'s `functionName` member function, causing `target[functionName]` to be called whenever the `Signal` is called until its disconnection.


`:disconnect(fun)`
------------------------------------------------

`:disconnect(target, functionName)`
------------------------------------------------

### Description

Disconnect matching connections.

`:disconnectAll()`
------------------------------------------------

### Description

Disconnect all connections.

