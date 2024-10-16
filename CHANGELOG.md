# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `entry_name` config option (default: `__luapack_entry__`)
- Added `package_preload_name` config option (default: `package.preload`)
- Added `package_loaded_name` config option (default: `package.loaded`)
- Added `alias` config option for renaming imported modules
- Added `outfile` config option (only for CLI)
- CLI now supports simple string arguments (`-name=value`)

### Updated

- Updated to work with latest Yuescript

### Fixed

- Fixed `package.searchpath` not being used in Lua 5.2+ (instead falling back to our implementation)
- Fixed some minor LSP warnings

## [v0.4.3] - 2022-10-29

### Fixed

- Fixed lua pattern not working with 1s in the name.

## [v0.4.2] - 2022-10-29

### Added

- Added `include_entry` option
- Added `packer:export()`
- Added standalone option for CLI
    - reads module names line for line and then includes them

### Changed

- Improved CLI option handler
- `packer:pack()` no longer returns the full lua, use `packer:export()` to get it

## [0.4.1] - 2022-04-12

### Fixed

- Fixed require pattern not working at all

## [0.4.0] - 2022-04-09 [YANKED]

### Updated

- Updated lua pattern:
    - Support `require("someone's lib")` (#2)
    - Allow all whitespace between require and parentheses (#3)
    - Allow whitespace within the parentheses too

## [0.3.3] - 2022-02-06

### Added

- Added `compat_arg` option which is enabled by default (compatibility option for `arg` in lua 5.1/5.2)

## [0.3.2] - 2022-02-04

### Fixed

- Fixed polyfill require not resetting recursion detection when an error occurs
- Fixed polyfill require not returning `":preload:"`

## [0.3.1] - 2022-02-04

### Added

- require of package polyfill now calls the preload function with correct arguments

### Fixed

- Fixed CLI (finally)
- Fixed optional dependecies not being optional

## [0.3.0] - 2022-02-04

### Added

- Added `helper`: `searchpath_compat`, `package_path_with_different_extension`, `check_file_extension`, `fast_push`

### Changed

- Moved `packer:searchpath_compat` to `helper.searchpath_compat`
- Changed plugin logic for `loader`

### Removed

- Removed `plugin.check_filename`

## [0.2.0] - 2022-02-03

### Added

- Added package polyfill
- Added plugin system
- Added support for require()'ing yuescript and moonscript builtin

### Changed

- Using `package.preload` and builtin `require` function now
- Using lua patterns instead of regex dependency
- Standalone 39kb -> 29kb (or 5kb without minify)

### Removed

- Removed `--cli` from the CLI


## [0.1.0] - 2021-03-25

Initial release


[Unreleased]: https://github.com/le0developer/luapack/compare/v0.4.3...HEAD
[0.4.3]: https://github.com/le0developer/luapack/releases/tag/v0.4.3
[0.4.2]: https://github.com/le0developer/luapack/releases/tag/v0.4.2
[0.4.1]: https://github.com/le0developer/luapack/releases/tag/v0.4.1
[0.4.0]: https://github.com/le0developer/luapack/releases/tag/v0.4.0
[0.3.3]: https://github.com/le0developer/luapack/releases/tag/v0.3.3
[0.3.2]: https://github.com/le0developer/luapack/releases/tag/v0.3.2
[0.3.1]: https://github.com/le0developer/luapack/releases/tag/v0.3.1
[0.3.0]: https://github.com/le0developer/luapack/releases/tag/v0.3.0
[0.2.0]: https://github.com/le0developer/luapack/releases/tag/v0.2.0
[0.1.0]: https://github.com/le0developer/luapack/releases/tag/v0.1.0
