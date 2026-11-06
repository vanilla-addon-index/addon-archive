# World of Warcraft 1.12.1 & Turtle WoW / Lua 5.0 Compatibility Rules

These rules apply to all World of Warcraft 1.12.1 (Vanilla), Turtle WoW (1.18.1), and custom core (Capybara Paradise) addon development. The game client embeds **Lua 5.0** with Blizzard's custom API extensions.

---

## 1. Syntax & Operator Constraints (Lua 5.0 vs. Lua 5.1+)

### 1.1. Table Length Operator (`#`) is BANNED
- **Forbidden**: `#my_table`, `#str` (syntax error in Lua 5.0).
- **Required**:
  - Tables: `table.getn(my_table)` or global `getn(my_table)`.
  - Strings: `string.len(my_str)`.

### 1.2. Modulo Operator (`%`) is BANNED
- **Forbidden**: `a % b` (syntax error in Lua 5.0).
- **Required**: `math.mod(a, b)` or global `mod(a, b)`.

### 1.3. Integer Division Operator (`//`) is BANNED
- **Forbidden**: `a // b` (introduced in Lua 5.3).
- **Required**: `math.floor(a / b)`.

### 1.4. `goto` and Label Markers (`::label::`) are BANNED
- **Forbidden**: `goto my_label`, `::my_label::` (introduced in Lua 5.2).
- **Required**: Use standard control flow (`while`, `repeat...until`, boolean flags).

### 1.5. Varargs (`...`) in Expressions is BANNED
- **Forbidden**: `function foo(...) local x = ... end`
- **Required**: In Lua 5.0, varargs are passed in the implicit `arg` table with count `arg.n`:
  ```lua
  function foo()
      for i = 1, arg.n do
          local val = arg[i]
      end
  end
  ```

---

## 2. Standard Library Differences

| Lua 5.1+ Function (BANNED) | Lua 5.0 / WoW 1.12 Equivalent (REQUIRED) |
| :--- | :--- |
| `string.match(s, pattern)` | `string.find(s, pattern)` with captured return indices |
| `string.gmatch(s, pattern)` | `string.gfind(s, pattern)` |
| `table.pack(...)` | `{ n = arg.n, unpack(arg) }` |
| `table.unpack(t)` | `unpack(t)` (global function) |
| `select(index, ...)` | Index into `arg` directly: `arg[index]` |
| `math.huge` | `1/0` or numeric ceiling like `99999999` |

---

## 3. Lua 5.0 Closure Upvalue Limit (Max 32 Upvalues)

- In Lua 5.0, a single function closure has a hard VM limit of **32 upvalues**.
- Exceeding 32 upvalues causes a fatal compilation error: `too many upvalues`.
- In large hot-path functions (e.g. `OnUpdate` loops, evaluation matrices, decision trees), **never** close over dozens of chunk-level local variables.
- Group chunk-local helpers and state into a single module table (e.g., `local D = {}` or `local m = {}`) to consume only 1 upvalue.

---

## 4. WoW 1.12 FrameXML & API Guidelines

### 4.1. Event Handler Calling Convention
- In WoW 1.12, event parameters are passed as global variables rather than function arguments:
  - `event`: Event name string (e.g., `"PLAYER_LOGIN"`, `"CHAT_MSG_SYSTEM"`).
  - `arg1`, `arg2`, `arg3`, ...: Event arguments.
  - `this`: The frame receiving the event.

### 4.2. No Modern WoW Namespaces or Hooks
- **BANNED**: `C_*` namespaces (e.g., `C_Timer`, `C_Map` - added in retail).
- **BANNED**: `hooksecurefunc` and `:HookScript` (added in WoW 2.0 TBC).
- **REQUIRED**: Classic function detouring for hooks:
  ```lua
  local Original_Function = TargetFunction
  TargetFunction = function(a, b)
      -- Pre-hook logic
      local ret = Original_Function(a, b)
      -- Post-hook logic
      return ret
  end
  ```

### 4.3. AddOn Directory Matching Rule
- The directory containing the addon MUST match the `.toc` filename exactly (case-sensitive on Unix/case-insensitive on Windows).
  - Example: `Interface/AddOns/TurtleCalendar/TurtleCalendar.toc`.
  - Folders with mismatched names will be silently ignored by the WoW client.
