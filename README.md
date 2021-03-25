
# LuaPack

Pack a lua file with many `require`d dependencies into a standalone lua!

## Usage

Firstly, you need to compile luapack `alfons build` and then you're ready to go!

Use `lua luapack.lua --cli <FILE>` for packing or use the API.

> The `--cli` is required for the script to identify that it's being run from the command line

```lua
local lp = require("luapack")
local packed = lp.pack("FILE")  -- file must include .lua
print(packed)
```

If you want a standalone luapack version, you can luapack luapack. `alfons self-pack` or `lua luapack.lua --cli luapack.lua`  
Heck, you can even pack the packed file.

## How it works

Luapack extracts all `require` calls using a regex, that means the following code won't work:

```lua
local name = "luapack"
local luapack = require(name)
```

If you still want to require files like that, you can put the call in comments

```lua
local name = "luapack"
local luapack = require(name)  -- require("luapack")
```

The regex isn't "the best", the following causes will be extracted

```lua
myrequire("name")
-- require("commented out")
"require('a string...')"
```

---

The extracted require modules will be searched for in `package.path` and ignored if not found or not ending in `.lua` (so it doesn't try to embed c modules)


## Tests

You can run the tests with `alfons test`


## Acknowledgements

This lua uses modified versions in `lib` directory of
- [SquidDev's lua minifier](https://github.com/SquidDev-CC/Howl/tree/master/howl/lexer)
- [reLua by oO8Oo](https://github.com/o080o/reLua) (luapacked)

