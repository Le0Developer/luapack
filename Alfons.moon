
import to_lua, loadstring from require "moonscript/base"


moonc = (path) ->
    -- moonc is broken for me with lua 5.4, so I had to make my own
    content = readfile path
    lua, error = to_lua content
    unless lua
        printError error
        return
    writefile (basename path) .. ".lua", lua

moonexec = (path, ...) ->
    content = readfile path
    fn, error = loadstring content
    unless fn
        printError error
        return
    fn ...


whitelisted_luas = {k, true for k in *{"lester", "minifier", "re"}}

tasks:
    compile: => 
        for file in wildcard "**.moon"
            moonc file unless (filename file) == "Alfons"
    clean: =>
        for file in wildcard "**.lua"
            fs.remove file unless whitelisted_luas[filename file]

    build: => 
        tasks.clean! 
        tasks.compile!

    test: =>
        tasks.build!
        moonexec "tests.moon"
    "test-exit": =>
        tasks.build!
        moonexec "tests.moon", "--exit"

    "self-pack": =>
        tasks.build!
        moonexec "luapack.moon", "--cli", "luapack.lua"
