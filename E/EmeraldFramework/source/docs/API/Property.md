# Class Property


`:get()`
------------------------------------------------

### Arguments

### Returns
- value held by the property

### Description

Returns the value held by the property.

**NOTE**: this bypass bindings


`:set(value)`
------------------------------------------------

### Arguments
- `value`: a value to be stored

### Returns
- `nil`

### Description

Stores `value` in the property.

**NOTE**: properties accessed by this are not captured by binds.


