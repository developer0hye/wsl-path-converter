# Project: wsl-path-converter

AutoHotkey v2 script that converts clipboard paths between Windows and WSL formats.

## Architecture

- `wsl-path-converter.ahk` -> Main script (tray app, hotkey handler, startup logic)
- `lib/convert.ahk` -> Path conversion logic (`ConvertPath`, `ConvertMultiLine`)
- `test.ahk` -> Test suite for conversion logic

**IMPORTANT:** `lib/convert.ahk` is `#Include`d by both `wsl-path-converter.ahk` and `test.ahk`. When modifying conversion logic, only edit `lib/convert.ahk`. Never duplicate conversion functions; the shared include keeps main and test logic identical.

## CI

- `test.yml` -> Runs `test.ahk` on every push/PR to master
- `release.yml` -> Compiles `.exe` and creates a GitHub Release on `v*` tags

## Release

```
git tag v0.X.0 && git push origin v0.X.0
```
