
# luapack

Pack a lua file with many `require`d dependencies into a standalone lua!


## Installation

Head to [releases](https://github.com/Le0Developer/luapack/releases) and get the latest `luapack.lua`.

### Installation from source

Install [yuescript](http://yuescript.org): `luarocks install yuescript`

And then run `yue -e luapack.yue luapack.yue`.

You can use `luapack.packed.lua` afterwards.

## Usage

You can use luapack directly in the CLI:

`lua luapack.lua test.lua` generates `test.packed.lua`

Or by using the API:

```lua
local luapack = require("luapack")

local packer = luapack.Packer()
-- or with options:
-- local packer = luapack.Packer({minify = false})

packer:pack("test.lua")
print(packer:export())
```

Make a new packer instance for each file you want to pack!


Output:
```lua
package.preload["__luapack_entry__"] = function()
    print("hello world") -- test.lua
end
package.loaded["__luapack_entry__"] = nil
do
    local _result = package.preload["__luapack_entry__"](...)
    return _result
end
```

## How does it work?

Luapack extracts all `require` calls statically using a lua pattern, so if you require a dependency dynamically it won't be included.

```lua
require("test") -- works
require "test" -- works
require'test' -- works
require("someone's lib") -- works
require ( "test"      )  -- works
require                     "test" -- works

myrequire("test") -- also works!
-- require "test" -- also works!
[[require "test"]] -- also works!

local name = "name"
require(name) -- doesnt work

require(("test")) -- doesnt work
require([[test]]) -- doesnt work

require("te" .. "st") -- includes "te"
```

To add a dynamic require, you can add the name explicitly in comments:

```lua
local name = "test"
require(name) -- require("test")
```

Or use the `packer:include` api.

## Using the API

- Using `packer:include`:

```lua
local packer = luapack.Packer()

packer:include("dependency")

packer:pack("test.lua")
print(packed:export())
```

Output:
```lua
package.preload["__luapack_entry__"] = function(...)
    local name = "dependency" -- dynamic require
    local print_ = require(name)
    print_("hello world") -- test.lua
end
package.loaded["__luapack_entry__"] = nil
package.preload["dependency"] = function(...) -- added by packer:include
    return print
end
package.loaded["dependency"] = nil
do
    local _result = package.preload["__luapack_entry__"](...)
    return _result
end
```

- Using `package_polyfill` option to polyfill the require function and the package table for enviroments that don't support it:

```lua
-- package_polyfill to create package and require
local packer = luapack.Packer({package_polyfill = true})

packer:pack("test.lua")
print(packed:export())
```

Or use the `-yes-package-polyfill` CLI option.

Output:
```lua
if not package then _G.package = { ... } end
if not package.preload then ... end
if not require then
    _G.require = ...
end
...
```

- Using `packer:bootstrap` without entry script:

```lua
local packer = luapack.Packer()

packer:include("dependecy")

local packed = packer:bootstrap()
print(packed) -- only has the package.preload sets
```

Output:
```lua
package.preload["dependency"] = function(...)
    return print
end
package.loaded["dependency"] = nil
```

## Full API

- `luapack.__author__` string
- `luapack.__url__` string
- `luapack.__license__` string
- `luapack.__version__` string
- `luapack.Packer` class
- `luapack.default_plugins` array

### luapack.Packer

All options:

- `minify = true` minifies the output
- `package_polyfill = false` add polyfill for require and package
- `with_header = true` adds the luapack header to the output
- `clear_loaded = true` clears `package.loaded` cache
- `plugins = default_plugins` plugins
- `compat_arg = true` compatibility for arg (cmd line arguments) passing in lua5.1 and 5.2
- `include_entry = true` whether to include `__luapack_entry__` or not (useful for standalone packages)
- `entry_name = "__luapack_entry__"` name of the entry function
- `package_preload_name = "package.preload"` name of the package preload table
- `package_loaded_name = "package.loaded"` name of the package loaded table
- `alias = nil` a function that allows you to rename package names (experimental)

Methods:

- **Packer:searchpath_compat(name)**

Uses `package.searchpath` (Lua 5.2+).
If `package.searchpath` does not exist, a janky search using `io.open` is done as fallback. (for Lua 5.1 support)

- **Packer:extract_packages(source)**

Extracts all `require` calls found in the source.

- **Packer:include(package_name, filename=nil)**

Includes the package and its dependencies.

- **Packer:pack(entry)**

Includes the file as entry.

- **Packer:export()**

Returns the bootstrapped lua code, with header and minification.

- **Packer:bootstrap()**

Generates the script and returns it.
This **does not** minify it or add the luapack header.

## Plugins

luapack supports plugins to allow more formats than just Lua or
discovery of packages in different places.

### default_plugins

- lua

This plugin allows discovery of lua packages that are on `package.path`.

- yue

This plugin allows discovery and usage of `.yue` files. (requires `yue` to be installed)

- moonscript

This plugin allows discovery and usage of `.moon` files. (requires `moonscript` to be installed)


### Plugin API

A plugin is just a table with the following fields:

- `name`: string

Not used but recommended.

- `searchpath`(`packer`: Packer, `name`: string) -> `?string` (optional)

A function that searches for the package and returns its path.

- `loader`(`packer`: Packer, `name`: string, `filename`: string, `content`: string) -> `?string`, `?string` (optional)

A function that returns the modified content of the file and a new filename (both can be falsy).
This is for post-processing or compilation of eg yuescript code.

### Example plugin

```lua
local luapack = require("luapack")

luapack.helpers.fast_push(luapack.default_plugins, {
    name = "Add comment",
    loader = function(packer, name, filename, content)
        if not luapack.helpers.check_file_extension(filename, ".lua") then
            return false -- dont do any changes if its not a lua file
        end
        -- add package name and filename as comment at the start
        return "-- " .. name .. " at " .. filename .. "\n" .. content
    end
})

local packer = luapack.Packer()
packer:pack("test.lua")
print(packed:export())
```

Output:
```lua
package.preload["__luapack_entry__"] = function(...)
	-- __luapack_entry__ at test.lua
	print("hello world")
end
package.loaded["__luapack_entry__"] = nil
do
	local _result = package.preload["__luapack_entry__"](...)
	return _result
end
```


## Acknowledgements

This lua uses modified versions in `lib` directory of
- [SquidDev's lua minifier](https://github.com/SquidDev-CC/Howl/tree/master/howl/lexer)
