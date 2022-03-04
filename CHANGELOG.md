# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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


[Unreleased]: https://github.com/le0developer/luapack/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/le0developer/luapack/releases/tag/v0.2.0
[0.1.0]: https://github.com/le0developer/luapack/releases/tag/v0.1.0
