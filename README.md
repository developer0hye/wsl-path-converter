# wsl-path-converter

`C:\Users\me\project` → `/mnt/c/Users/me/project`

Copy a path. **Ctrl+Shift+V**. Done.

## Install

[Download](https://github.com/developer0hye/wsl-path-converter/releases/latest) → Run → Done.

## Conversions

| You copy | You get |
|---|---|
| `C:\Users\me\project` | `/mnt/c/Users/me/project` |
| `/mnt/c/Users/me/project` | `C:\Users\me\project` |
| `/home/me/.config` | `\\wsl.localhost\Ubuntu\home\me\.config` |
| `\\wsl$\Ubuntu\home\me` | `/home/me` |

## How it works

1. **Ctrl+C** — Copy a path as usual
2. **Ctrl+Shift+V** — Paste the converted path

Not a path? It just pastes normally.

Lives quietly in your system tray. Auto-detects your WSL distro.

Want it on every boot? Right-click the tray icon → **Start with Windows**.
