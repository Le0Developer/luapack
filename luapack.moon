
arguments = {...}
arguments.n = #arguments

re = require "lib/re"
minifier = require "lib/minifier"

require_re = re.compile([[.*require */(?["']([^"']+)["']/)?.*]])

loaded = {}

fast_push = (tbl, value) ->
    tbl.n += 1
    tbl[tbl.n] = value


local api

include = (name, filename) ->
    return if loaded[name] or not filename
    return unless filename\match"^.+(%..+)$" == ".lua"
    with io.open filename, "r"
        loaded[name] = \read "*a"
        \close!
    return if loaded[name]\sub(1, 14) == "--NO REQUIRE--"
    include requires, api.resolve requires for requires in *api.extract_modules loaded[name]


api = {
    extract_modules: =>
        -- not the nicest, but hey, it works!
        max = #@
        matches = {n: 0}
        while max > 0
            break unless require_re\execute @sub 1, max
            match = require_re\match!
            fast_push matches, @sub match[11] + 1, match[12]
            max = match[3]
        [matches[matches.n - i] for i=0, matches.n - 1]
    
    resolve: =>
        -- is there a built in way?
        -- maybe by hijacking package.loaders?
        @ = @gsub "%.", "/"  -- replace "." with "/" in paths
        for path in package.path\gmatch "[^;]+"
            continue if #path == 0
            path = path\gsub "?", @
            fh = io.open path, "r"  -- this will break with directories
            continue unless fh
            fh\close!
            return path

    pack: (filename) ->
        loaded = {}
        include "__luapack_entry__", filename

        formatted = {n: 0}
        for name, content in pairs loaded
            fast_push formatted, ("[%q] = %q")\format name, minifier.Rebuild.MinifyString content

        "--NO REQUIRE--\n" .. minifier.Rebuild.MinifyString [[
            local _package, _require, _load = {
                loaded = {},
                packages = {%s}
            }, require, loadstring or load

            _G.require = function(name, ...)
                if _package.loaded[name] then return _package.loaded[name]
                elseif _package.packages[name] then
                    _package.loaded[name] = _load(_package.packages[name])(...)
                    return _package.loaded[name]
                else return _require(name) end
            end

            return require("__luapack_entry__", ...)
        ]]\format table.concat(formatted, ","), entry
}

if arguments.n > 1 and arguments[1] == "--cli"
    for filename in *arguments[2,]
        packed = api.pack filename
        with io.open filename\gsub("%.lua$", ".packed.lua"), "w"
            \write packed
            \close!

return api
