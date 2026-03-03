#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
;  WSL Path Converter
;  Ctrl+Shift+V : Convert and paste clipboard path (WSL <-> Windows)
; ============================================================

TraySetIcon("shell32.dll", 44)
A_IconTip := "WSL Path Converter (Ctrl+Shift+V)"

; --- Detect default WSL distro on startup ---
global DefaultDistro := DetectDefaultDistro()

; --- Startup shortcut path ---
global StartupLink := A_Startup "\WSL Path Converter.lnk"

; --- Tray menu ---
tray := A_TrayMenu
tray.Delete()
tray.Add("WSL Path Converter", (*) => "")
tray.Disable("WSL Path Converter")
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
;  Multi-line: convert each line individually
; ============================================================
ConvertMultiLine(text) {
    lines := StrSplit(text, "`n")
    result := ""
    anyConverted := false
    for i, line in lines {
        trimmed := Trim(line, " `t`r")
        if (trimmed != "") {
            converted := ConvertPath(trimmed)
            if (converted != trimmed) {
                anyConverted := true
                line := converted
            }
        }
        result .= (i > 1 ? "`n" : "") line
    }
    if (!anyConverted)
        return text
    return result
}

; ============================================================
;  Path conversion logic
; ============================================================
ConvertPath(path) {
    ; 1) Windows drive path -> WSL
    ;    C:\Users\foo  ->  /mnt/c/Users/foo
    ;    D:/projects   ->  /mnt/d/projects
    if (RegExMatch(path, "^([A-Za-z]):[\\\/](.*)", &m)) {
        drive := StrLower(m[1])
        rest := StrReplace(m[2], "\", "/")
        rest := RTrim(rest, "/")
        if (rest = "")
            return "/mnt/" drive
        return "/mnt/" drive "/" rest
    }

    ; 2) \\wsl$\Distro\path  or  \\wsl.localhost\Distro\path -> WSL path
    if (RegExMatch(path, "i)^\\\\(?:wsl\$|wsl\.localhost)\\[^\\]+\\?(.*)", &m)) {
        rest := StrReplace(m[1], "\", "/")
        rest := RTrim(rest, "/")
        if (rest = "")
            return "/"
        return "/" rest
    }

    ; 3) WSL /mnt/X/... -> Windows drive path
    ;    /mnt/c/Users/foo  ->  C:\Users\foo
    if (RegExMatch(path, "^/mnt/([a-zA-Z])(?:/(.*)|$)", &m)) {
        drive := StrUpper(m[1])
        rest := m.Count >= 2 ? m[2] : ""
        rest := StrReplace(rest, "/", "\")
        rest := RTrim(rest, "\")
        if (rest = "")
            return drive ":\"
        return drive ":\" rest
    }

    ; 4) WSL native path -> \\wsl.localhost\Distro\path
    ;    /home/user  ->  \\wsl.localhost\Ubuntu-24.04\home\user
    ;    Only convert paths starting with known top-level directories
    if (RegExMatch(path, "^/([a-zA-Z0-9._-]+(?:/[a-zA-Z0-9._@:~-]*)*)", &m)) {
        matched := m[0]
        ; Only convert if entire input matches (no trailing junk)
        if (matched != path)
            return path
        ; Must start with a known WSL top-level directory
        if (!RegExMatch(path, "^/(home|etc|usr|var|tmp|opt|root|srv|bin|sbin|lib|lib64|dev|proc|sys|run|mnt|media|boot|snap)\b"))
            return path
        rest := StrReplace(SubStr(path, 2), "/", "\")
        rest := RTrim(rest, "\")
        if (rest = "")
            return "\\wsl.localhost\" DefaultDistro
        return "\\wsl.localhost\" DefaultDistro "\" rest
    }

    ; Unrecognized format -> return as-is
    return path
}

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
