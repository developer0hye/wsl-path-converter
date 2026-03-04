#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;@Ahk2Exe-SetMainIcon app-icon.ico

; ============================================================
;  WSL Path Converter
;  Ctrl+Shift+V : Convert and paste clipboard path (WSL <-> Windows)
; ============================================================

global AppVersion := "0.5.3"

trayIconPath := A_Temp "\wsl-path-converter-tray.ico"
FileInstall("icon.ico", trayIconPath, 1)
TraySetIcon(trayIconPath)
A_IconTip := "WSL Path Converter v" AppVersion

; --- Detect default WSL distro on startup ---
global DefaultDistro := DetectDefaultDistro()

; --- Startup shortcut path ---
global StartupLink := A_Startup "\WSL Path Converter.lnk"

; --- Tray menu ---
tray := A_TrayMenu
tray.Delete()
tray.Add("WSL Path Converter v" AppVersion, (*) => "")
tray.Disable("WSL Path Converter v" AppVersion)
tray.Add()
tray.Add("Distro: " DefaultDistro, (*) => "")
tray.Disable("Distro: " DefaultDistro)
tray.Add()
tray.Add("Start with Windows", ToggleStartup)
; Auto-register on first run
if (!FileExist(StartupLink))
    RegisterStartup()
tray.Check("Start with Windows")
tray.Add()
tray.Add("Contact: developer.0hye@gmail.com", (*) => "")
tray.Disable("Contact: developer.0hye@gmail.com")
tray.Add()
tray.Add("Exit", (*) => ExitApp())

; --- Startup notification ---
TrayTip("Copy path as usual`nCtrl+Shift+V convert/paste`nDistro: " DefaultDistro, "WSL Path Converter", 1)
SetTimer(() => TrayTip(), -3000)

; ============================================================
;  Startup registration
; ============================================================
RegisterStartup() {
    shortcut := ComObject("WScript.Shell").CreateShortcut(StartupLink)
    shortcut.TargetPath := A_ScriptFullPath
    shortcut.WorkingDirectory := A_ScriptDir
    shortcut.Description := "WSL Path Converter"
    shortcut.IconLocation := A_ScriptFullPath ",0"
    shortcut.Save()
}

ToggleStartup(*) {
    if (FileExist(StartupLink)) {
        FileDelete(StartupLink)
        A_TrayMenu.Uncheck("Start with Windows")
        ToolTip("Removed from startup")
    } else {
        RegisterStartup()
        A_TrayMenu.Check("Start with Windows")
        ToolTip("Added to startup")
    }
    SetTimer(() => ToolTip(), -1500)
}

; ============================================================
;  Ctrl+Shift+V  ->  Convert and paste path
; ============================================================
$^+v:: {
    ; Non-text clipboard (image/file) -> passthrough original Ctrl+Shift+V
    if (A_Clipboard = "" && DllCall("IsClipboardFormatAvailable", "UInt", 1) = 0) {
        Send("^+v")
        return
    }

    rawText := A_Clipboard
    converted := ConvertClipboardText(rawText)
    if (converted = rawText) {
        Send("^+v")
        return
    }
    PasteConverted(converted)
}

; ============================================================
;  Paste converted text (preserves original clipboard)
; ============================================================
PasteConverted(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -2000)

    prevClip := ClipboardAll()
    A_Clipboard := text
    if (!ClipWait(2)) {
        A_Clipboard := prevClip
        return
    }
    Send("^v")
    Sleep(300)
    A_Clipboard := prevClip
}

; ============================================================
;  Path conversion logic (shared with test.ahk)
; ============================================================
#Include lib/convert.ahk

; ============================================================
;  Detect default WSL distro
; ============================================================
DetectDefaultDistro() {
    ; Method 1: wsl --status (Windows 11+)
    try {
        content := RunWslCapture("--status", "wsl_status_detect.txt")
        if (RegExMatch(content, "im)^\s*Default Distribution\s*:\s*(.+)$", &m)) {
            distro := Trim(m[1], " `r`n`0")
            if (distro != "")
                return distro
        }
    } catch {
    }

    ; Method 2: wsl -l -v (* marks default)
    try {
        content := RunWslCapture("-l -v", "wsl_list_detect.txt")
        distro := ParseDefaultDistroFromList(content)
        if (distro != "")
            return distro
    } catch {
    }

    ; Method 3: wsl -l (* marks default on older output format)
    try {
        content := RunWslCapture("-l", "wsl_plain_list_detect.txt")
        distro := ParseDefaultDistroFromList(content)
        if (distro != "")
            return distro
    } catch {
    }

    ; Method 4: wsl -l -q first non-empty line (legacy fallback)
    try {
        content := RunWslCapture("-l -q", "wsl_distro_detect.txt")
        for line in StrSplit(content, "`n") {
            line := Trim(line, " `r`n`0")
            if (line != "")
                return line
        }
    } catch {
    }

    return "Ubuntu"
}

RunWslCapture(args, tempName) {
    tempFile := A_Temp "\" tempName
    try FileDelete(tempFile)
    RunWait(A_ComSpec ' /c wsl.exe ' args ' > "' tempFile '" 2>nul', , "Hide")
    if (!FileExist(tempFile))
        return ""
    content := FileRead(tempFile, "UTF-16")
    try FileDelete(tempFile)
    return content
}

ParseDefaultDistroFromList(content) {
    for rawLine in StrSplit(content, "`n") {
        line := Trim(rawLine, " `t`r`n`0")
        if (line = "")
            continue
        if (SubStr(line, 1, 1) != "*")
            continue

        candidateLine := Trim(SubStr(line, 2), " `t")
        if (candidateLine = "")
            continue

        ; Common format: "<name>  <state>  <version>"
        if (RegExMatch(candidateLine, "^(.+?)\s{2,}.*$", &m))
            candidate := Trim(m[1], " `t")
        ; Alternate format: "<name> (Default)" (localized text inside parentheses)
        else if (RegExMatch(candidateLine, "^(.+?)\s+\([^)]*\)$", &m))
            candidate := Trim(m[1], " `t")
        else
            candidate := candidateLine

        if (candidate != "")
            return candidate
    }
    return ""
}

