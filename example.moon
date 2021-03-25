
-- Hello, I am an example lua script

-- After packing me, you can move the packed lua to a different directory
-- or even different system

-- I will be using `lester` as an example dependency here
--   (because it's only available in this directory)
lester = require "lester"

-- Modules that it can't find or aren't "pure" lua, will simply be ignored
-- and require'd using the normal require at runtime
notexisting = require "does_not_exist"
lester.expect.not_exist notexisting

-- Let's use filekit aswell, because it requires "lfs", which isn't pure lua
--   (alfons comes with filekit, so you should have it)
filekit = require "filekit"
-- When filekit requires "lfs", it'll fallback to the default require and find
-- require the installed one  (won't work if "lfs" is not installed)
lester.expect.exist filekit
