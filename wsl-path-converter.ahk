#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
;  WSL Path Converter
;  Ctrl+Shift+V : Convert and paste clipboard path (WSL <-> Windows)
; ============================================================

global AppVersion := "0.3.0"

TraySetIcon("shell32.dll", 44)
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
tray.Add("Contact", (*) => Run("mailto:developer.0hye@gmail.com"))
tray.Add()
tray.Add("Exit", (*) => ExitApp())

; --- Startup notification ---
TrayTip("Ctrl+Shift+V to convert paths`nDistro: " DefaultDistro, "WSL Path Converter", 1)
SetTimer(() => TrayTip(), -3000)

; ============================================================
;  Startup registration
; ============================================================
RegisterStartup() {
    shortcut := ComObject("WScript.Shell").CreateShortcut(StartupLink)
    shortcut.TargetPath := A_ScriptFullPath
    shortcut.WorkingDirectory := A_ScriptDir
    shortcut.Description := "WSL Path Converter"
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
^+v:: {
    ; Non-text clipboard (image/file) -> normal paste
    if (A_Clipboard = "" && DllCall("IsClipboardFormatAvailable", "UInt", 1) = 0) {
        Send("^v")
        return
    }

    rawText := A_Clipboard

    ; Multi-line: convert each line individually
    if (InStr(rawText, "`n")) {
        result := ConvertMultiLine(rawText)
        if (result = rawText) {
            Send("^v")
            return
        }
        PasteConverted(result)
        return
    }

    clipText := Trim(rawText, " `t`r`n")

    if (clipText = "") {
        Send("^v")
        return
    }

    ; Strip surrounding quotes (use separate var to preserve original)
    pathCandidate := clipText
    if (StrLen(pathCandidate) >= 2 && SubStr(pathCandidate, 1, 1) = '"' && SubStr(pathCandidate, -1) = '"')
        pathCandidate := SubStr(pathCandidate, 2, -1)
    else if (StrLen(pathCandidate) >= 2 && SubStr(pathCandidate, 1, 1) = "'" && SubStr(pathCandidate, -1) = "'")
        pathCandidate := SubStr(pathCandidate, 2, -1)

    pathCandidate := Trim(pathCandidate, " `t`r`n")
    if (pathCandidate = "") {
        Send("^v")
        return
    }

    converted := ConvertPath(pathCandidate)

    ; Not a path -> normal paste
    if (converted = pathCandidate) {
        Send("^v")
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
        tempFile := A_Temp "\wsl_status_detect.txt"
        RunWait(A_ComSpec ' /c wsl.exe --status > "' tempFile '" 2>nul', , "Hide")
        content := FileRead(tempFile, "UTF-16")
        FileDelete(tempFile)
        if (RegExMatch(content, "im)(?:Default Distribution|기본 배포[^:]*)[:\s]+(.+)", &m)) {
            distro := Trim(m[1], " `r`n`0")
            if (distro != "")
                return distro
        }
    } catch {
    }

    ; Method 2: wsl -l -v (* marks default)
    try {
        tempFile := A_Temp "\wsl_list_detect.txt"
        RunWait(A_ComSpec ' /c wsl.exe -l -v > "' tempFile '" 2>nul', , "Hide")
        content := FileRead(tempFile, "UTF-16")
        FileDelete(tempFile)
        if (RegExMatch(content, "m)^\s*\*\s+(\S+)", &m)) {
            distro := Trim(m[1], " `r`n`0")
            if (distro != "")
                return distro
        }
    } catch {
    }

    ; Method 3: wsl -l -q first line (legacy fallback)
    try {
        tempFile := A_Temp "\wsl_distro_detect.txt"
        RunWait(A_ComSpec ' /c wsl.exe -l -q > "' tempFile '" 2>nul', , "Hide")
        content := FileRead(tempFile, "UTF-16")
        FileDelete(tempFile)
        for line in StrSplit(content, "`n") {
            line := Trim(line, " `r`n`0")
            if (line != "")
                return line
        }
    } catch {
    }

    return "Ubuntu"
}
