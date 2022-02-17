# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2022-01-17

### Added

- Added package polyfill

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
