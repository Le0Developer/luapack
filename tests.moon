
args = {...}

lester = require "lester"
import describe, it, expect from lester

fs = require "filekit"

expect.starts_with = (s, t) -> expect.equal s\sub(1, #t), t


describe "luapack", ->
    import extract_modules, resolve, pack from require "luapack"

    it "extract require'd modules", ->
        tbl = extract_modules [[
            require("normal_with_()")
            require "without()"
            require                  "with_spaces"
            require"no_space_infront"
        ]]
        expect.equal tbl, {"normal_with_()", "without()", "with_spaces", "no_space_infront"}
    
    it "module resolver", ->
        expect.equal resolve"luapack", "./luapack.lua"
        expect.equal resolve"lib/re", "./lib/re.lua"
        expect.equal resolve"lib.re", "./lib/re.lua"
        expect.not_exist resolve"something_that_most_definetly_does_not_exist"
        expect.not_exist resolve"luapack.lua"
    
    it "self-pack", ->
        packed = pack "luapack.lua"
        expect.starts_with packed, "--NO REQUIRE--\n"

        original_require = require
        _G.require = error

        loaded = (loadstring or load)(packed)!
        expect.exist loaded.extract_modules
        expect.exist loaded.resolve
        expect.exist loaded.pack

        _G.require = original_require
        

lester.report!

if args[1] == "--exit"
    lester.exit!
