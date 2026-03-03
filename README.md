# wsl-path-converter

<img src="logo.png" alt="WSL Path Converter Logo" width="480" />

`C:\Users\me\project` -> `/mnt/c/Users/me/project`

Copy with `Ctrl+C`, then paste with `Ctrl+Shift+V`.

## Install

[Download](https://github.com/developer0hye/wsl-path-converter/releases/latest/download/wsl-path-converter.exe) -> Run -> Done.

## Conversions

| You copy | You get |
|---|---|
| `C:\Users\me\project` | `/mnt/c/Users/me/project` |
| `/mnt/c/Users/me/project` | `C:\Users\me\project` |
| `/home/me/.config` | `\\wsl.localhost\Ubuntu\home\me\.config` |
| `\\wsl$\Ubuntu\home\me` | `/home/me` |

## How it works

1. Press `Ctrl+C` to copy a path as usual.
2. Press `Ctrl+Shift+V` to paste the converted path.

If the clipboard text is not a supported path, it pastes normally.

The app runs in the system tray and auto-detects your WSL distro.

It starts with Windows automatically. To disable, right-click the tray icon and uncheck **Start with Windows**.
