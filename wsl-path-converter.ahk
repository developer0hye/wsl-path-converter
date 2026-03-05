#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;@Ahk2Exe-SetMainIcon app-icon.ico

; ============================================================
;  WSL Path Converter
;  Ctrl+Shift+V : Convert and paste clipboard path (WSL <-> Windows)
; ============================================================

global AppVersion := "0.6.2"
global RepoOwner := "developer0hye"
global RepoName := "wsl-path-converter"

trayIconPath := A_Temp "\wsl-path-converter-tray.ico"
FileInstall("icon.ico", trayIconPath, 1)
TraySetIcon(trayIconPath)
A_IconTip := "WSL Path Converter v" AppVersion

; --- Detect default WSL distro on startup ---
global DefaultDistro := DetectDefaultDistro()

; --- Startup shortcut path ---
global StartupLink := A_Startup "\WSL Path Converter.lnk"

; --- User settings ---
global ConfigDir := A_AppData "\WSL Path Converter"
global ConfigPath := ConfigDir "\settings.ini"
global DefaultConvertHotkey := "^+v"
global ConvertHotkey := LoadConvertHotkey()
global RegisteredConvertHotkey := ""
global HotkeyInfoLabel := "Hotkey: " FormatHotkeyForDisplay(ConvertHotkey)
global LastHotkeyError := ""
global HotkeyDialogHwnd := 0

; --- Tray menu ---
tray := A_TrayMenu
tray.Delete()
tray.Add("WSL Path Converter v" AppVersion, (*) => "")
tray.Disable("WSL Path Converter v" AppVersion)
tray.Add()
tray.Add("Distro: " DefaultDistro, (*) => "")
tray.Disable("Distro: " DefaultDistro)
tray.Add(HotkeyInfoLabel, (*) => "")
tray.Disable(HotkeyInfoLabel)
tray.Add()
hotkeyMenu := Menu()
hotkeyMenu.Add("Set conversion hotkey...", SetConvertHotkeyPrompt)
hotkeyMenu.Add("Reset to Ctrl+Shift+V", ResetConvertHotkey)
tray.Add("Conversion hotkey", hotkeyMenu)
tray.Add()
tray.Add("Check for updates", CheckForUpdates)
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

; --- Register conversion hotkey ---
ApplyConvertHotkey(ConvertHotkey, false)

; --- Startup notification ---
TrayTip("Copy path as usual`n" FormatHotkeyForDisplay(ConvertHotkey) " convert/paste`nDistro: " DefaultDistro, "WSL Path Converter", 1)
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
;  Hotkey callback -> Convert and paste path
; ============================================================
$^+v:: {
    HandleConvertHotkey()
}

HandleConvertHotkey(*) {
    triggerHotkey := A_ThisHotkey

    ; Non-text clipboard (image/file):
    ; keep native Ctrl+Shift+V behavior only when using the default hotkey.
    if (A_Clipboard = "" && DllCall("IsClipboardFormatAvailable", "UInt", 1) = 0) {
        SendOriginalShortcutIfNeeded(triggerHotkey)
        return
    }

    rawText := A_Clipboard
    converted := ConvertClipboardText(rawText)
    if (converted = rawText) {
        SendOriginalShortcutIfNeeded(triggerHotkey)
        return
    }
    PasteConverted(converted)
}

SendOriginalShortcutIfNeeded(triggerHotkey := "") {
    global DefaultConvertHotkey
    effective := NormalizeHotkey(triggerHotkey)
    if (StrLower(effective) = StrLower(NormalizeHotkey(DefaultConvertHotkey)))
        Send("^+v")
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
;  User settings: conversion hotkey
; ============================================================
LoadConvertHotkey() {
    global ConfigPath, DefaultConvertHotkey
    try {
        value := IniRead(ConfigPath, "Hotkey", "Convert", DefaultConvertHotkey)
    } catch {
        value := DefaultConvertHotkey
    }

    value := NormalizeHotkey(value)
    if (value = "")
        return DefaultConvertHotkey
    return value
}

SaveConvertHotkey(hotkey) {
    global ConfigDir, ConfigPath
    try {
        if (!DirExist(ConfigDir))
            DirCreate(ConfigDir)
        IniWrite(hotkey, ConfigPath, "Hotkey", "Convert")
        return true
    } catch {
        return false
    }
}

ApplyConvertHotkey(hotkey, persist := true, notify := false) {
    global ConvertHotkey, RegisteredConvertHotkey, LastHotkeyError, DefaultConvertHotkey

    candidate := NormalizeHotkey(hotkey)
    if (candidate = "") {
        LastHotkeyError := "Hotkey is empty."
        return false
    }

    defaultKey := NormalizeHotkey(DefaultConvertHotkey)
    isDefaultCandidate := (StrLower(candidate) = StrLower(defaultKey))

    prevRegistered := RegisteredConvertHotkey
    prevHotkey := ConvertHotkey

    ; Default hotkey path: keep static/hook-style registration like v0.6.0.
    if (isDefaultCandidate) {
        if (prevRegistered != "")
            try Hotkey(prevRegistered, "Off")

        if (!SetDefaultHotkeyEnabled(true, &errMsg)) {
            LastHotkeyError := errMsg
            if (prevRegistered != "")
                try Hotkey(prevRegistered, HandleConvertHotkey, "On")
            ConvertHotkey := prevHotkey
            RegisteredConvertHotkey := prevRegistered
            return false
        }

        ConvertHotkey := defaultKey
        RegisteredConvertHotkey := ""
        LastHotkeyError := ""
        UpdateHotkeyTrayLabel()
        if (persist)
            SaveConvertHotkey(defaultKey)
        if (notify) {
            ToolTip("Conversion hotkey: " FormatHotkeyForDisplay(defaultKey))
            SetTimer(() => ToolTip(), -1500)
        }
        return true
    }

    ; Custom hotkey path: disable default static hook and register dynamic one.
    if (prevRegistered != "") {
        try Hotkey(prevRegistered, "Off")
    } else {
        SetDefaultHotkeyEnabled(false, &dummyErr)
    }

    registeredSpec := RegisterDynamicHotkey(candidate, &errMsg)
    if (registeredSpec = "") {
        LastHotkeyError := errMsg
        if (prevRegistered != "") {
            try Hotkey(prevRegistered, HandleConvertHotkey, "On")
        } else {
            SetDefaultHotkeyEnabled(true, &dummyErr2)
        }
        ConvertHotkey := prevHotkey
        RegisteredConvertHotkey := prevRegistered
        return false
    }

    ConvertHotkey := candidate
    RegisteredConvertHotkey := registeredSpec
    LastHotkeyError := ""
    UpdateHotkeyTrayLabel()

    if (persist)
        SaveConvertHotkey(candidate)

    if (notify) {
        ToolTip("Conversion hotkey: " FormatHotkeyForDisplay(candidate))
        SetTimer(() => ToolTip(), -1500)
    }
    return true
}

RegisterDynamicHotkey(candidate, &errorMessage := "") {
    specs := ["$" candidate, candidate]
    for _, spec in specs {
        try {
            Hotkey(spec, HandleConvertHotkey, "On")
            errorMessage := ""
            return spec
        } catch as err {
            errorMessage := err.Message
        }
    }
    return ""
}

SetDefaultHotkeyEnabled(enabled, &errorMessage := "") {
    global DefaultConvertHotkey
    key := NormalizeHotkey(DefaultConvertHotkey)
    action := enabled ? "On" : "Off"

    for _, spec in ["$" key, key] {
        try {
            Hotkey(spec, action)
            errorMessage := ""
            return true
        } catch as err {
            errorMessage := err.Message
        }
    }
    return false
}

SetConvertHotkeyPrompt(*) {
    global ConvertHotkey, HotkeyDialogHwnd

    if (HotkeyDialogHwnd && WinExist("ahk_id " HotkeyDialogHwnd)) {
        WinActivate("ahk_id " HotkeyDialogHwnd)
        return
    }

    state := {accepted: false, value: ""}
    dlg := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "WSL Path Converter")
    dlg.AddText("xm w320", "Press the key combination, then click Save.")
    hotkeyInput := dlg.AddHotkey("xm w320", ConvertHotkey)
    btnSave := dlg.AddButton("xm w100 Default", "Save")
    btnCancel := dlg.AddButton("x+8 w100", "Cancel")
    btnSave.OnEvent("Click", (*) => (state.accepted := true, state.value := hotkeyInput.Value, dlg.Destroy()))
    btnCancel.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.OnEvent("Close", HotkeyDialogClosed)

    dlg.Show("AutoSize Center")
    HotkeyDialogHwnd := dlg.Hwnd
    WinWaitClose("ahk_id " dlg.Hwnd)
    HotkeyDialogHwnd := 0

    if (!state.accepted)
        return

    candidate := NormalizeHotkey(state.value)
    if (candidate = "")
        return

    if (!ApplyConvertHotkey(candidate, true, true)) {
        ; Keep the user's selected key as preference even if registration fails right now.
        ConvertHotkey := candidate
        SaveConvertHotkey(candidate)
        UpdateHotkeyTrayLabel()
    }
}

HotkeyDialogClosed(*) {
    global HotkeyDialogHwnd
    HotkeyDialogHwnd := 0
}

ResetConvertHotkey(*) {
    global DefaultConvertHotkey, ConvertHotkey
    if (!ApplyConvertHotkey(DefaultConvertHotkey, true, true)) {
        ConvertHotkey := DefaultConvertHotkey
        SaveConvertHotkey(DefaultConvertHotkey)
        UpdateHotkeyTrayLabel()
    }
}

UpdateHotkeyTrayLabel() {
    global HotkeyInfoLabel, ConvertHotkey

    tray := A_TrayMenu
    newLabel := "Hotkey: " FormatHotkeyForDisplay(ConvertHotkey)

    if (HotkeyInfoLabel = "") {
        tray.Add(newLabel, (*) => "")
        tray.Disable(newLabel)
        HotkeyInfoLabel := newLabel
        return
    }

    if (HotkeyInfoLabel = newLabel)
        return

    try {
        tray.Rename(HotkeyInfoLabel, newLabel)
    } catch {
        try tray.Delete(HotkeyInfoLabel)
        tray.Add(newLabel, (*) => "")
    }
    tray.Disable(newLabel)
    HotkeyInfoLabel := newLabel
}

NormalizeHotkey(hotkey) {
    value := Trim(hotkey, " `t`r`n")
    while (value != "" && (SubStr(value, 1, 1) = "$" || SubStr(value, 1, 1) = "~" || SubStr(value, 1, 1) = "*"))
        value := SubStr(value, 2)
    return value
}

FormatHotkeyForDisplay(hotkey) {
    value := StrReplace(NormalizeHotkey(hotkey), "<")
    value := StrReplace(value, ">")

    mods := ""
    while (value != "") {
        prefix := SubStr(value, 1, 1)
        if (prefix = "^") {
            mods .= "Ctrl+"
            value := SubStr(value, 2)
            continue
        }
        if (prefix = "!") {
            mods .= "Alt+"
            value := SubStr(value, 2)
            continue
        }
        if (prefix = "+") {
            mods .= "Shift+"
            value := SubStr(value, 2)
            continue
        }
        if (prefix = "#") {
            mods .= "Win+"
            value := SubStr(value, 2)
            continue
        }
        break
    }

    if (value = "")
        return mods != "" ? RTrim(mods, "+") : NormalizeHotkey(hotkey)
    if (StrLen(value) = 1)
        value := StrUpper(value)
    return mods value
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

CheckForUpdates(*) {
    global AppVersion, RepoOwner, RepoName

    info := GetLatestReleaseInfo(RepoOwner, RepoName)
    if (!info.success) {
        MsgBox("Could not check updates.`n`n" info.error, "WSL Path Converter", "Iconx")
        return
    }

    cmp := CompareSemVer(info.version, AppVersion)
    if (cmp > 0) {
        result := MsgBox(
            "New version available: v" info.version "`nCurrent version: v" AppVersion
            "`n`nOpen download page?",
            "WSL Path Converter",
            "YN Iconi"
        )
        if (result = "Yes")
            Run(info.downloadUrl)
        return
    }

    if (cmp = 0) {
        MsgBox("You're up to date.`nVersion: v" AppVersion, "WSL Path Converter", "Iconi")
        return
    }

    MsgBox(
        "You are running a newer build.`nCurrent version: v" AppVersion
        "`nLatest release: v" info.version,
        "WSL Path Converter",
        "Iconi"
    )
}

GetLatestReleaseInfo(owner, repo) {
    apiUrl := "https://api.github.com/repos/" owner "/" repo "/releases/latest"

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(3000, 3000, 5000, 5000)
        req.Open("GET", apiUrl, false)
        req.SetRequestHeader("User-Agent", "wsl-path-converter")
        req.Send()
    } catch as err {
        return { success: false, error: "Network error: " err.Message }
    }

    if (req.Status != 200)
        return { success: false, error: "GitHub API returned HTTP " req.Status "." }

    body := req.ResponseText
    if (!RegExMatch(body, '"tag_name"\s*:\s*"v?([^"]+)"', &tagMatch))
        return { success: false, error: "Could not read latest version from GitHub." }

    version := Trim(tagMatch[1], " `t`r`n")
    pageUrl := "https://github.com/" owner "/" repo "/releases/latest"
    if (RegExMatch(body, '"html_url"\s*:\s*"([^"]+)"', &pageMatch))
        pageUrl := StrReplace(pageMatch[1], "\/", "/")

    setupUrl := "https://github.com/" owner "/" repo "/releases/latest/download/wsl-path-converter-setup.exe"
    if (RegExMatch(body, 'i)"browser_download_url"\s*:\s*"([^"]*wsl-path-converter-setup\.exe)"', &setupMatch))
        setupUrl := StrReplace(setupMatch[1], "\/", "/")

    return {
        success: true,
        version: version,
        pageUrl: pageUrl,
        downloadUrl: setupUrl
    }
}

CompareSemVer(a, b) {
    ParseSemVer(a, &aNums, &aPre)
    ParseSemVer(b, &bNums, &bPre)

    maxLen := aNums.Length >= bNums.Length ? aNums.Length : bNums.Length
    Loop maxLen {
        i := A_Index
        av := i <= aNums.Length ? aNums[i] : 0
        bv := i <= bNums.Length ? bNums[i] : 0
        if (av > bv)
            return 1
        if (av < bv)
            return -1
    }

    ; Stable release is considered newer than prerelease for same numeric core.
    if (aPre = "" && bPre != "")
        return 1
    if (aPre != "" && bPre = "")
        return -1

    if (aPre > bPre)
        return 1
    if (aPre < bPre)
        return -1
    return 0
}

ParseSemVer(version, &numbers, &prerelease) {
    text := Trim(version, " `t`r`n")
    if (SubStr(text, 1, 1) = "v" || SubStr(text, 1, 1) = "V")
        text := SubStr(text, 2)

    if (RegExMatch(text, "^([0-9]+(?:\.[0-9]+)*)(?:-([0-9A-Za-z\.-]+))?$", &m)) {
        core := m[1]
        prerelease := m.Count >= 2 ? m[2] : ""
    } else {
        core := "0"
        prerelease := ""
    }

    numbers := []
    for _, part in StrSplit(core, ".") {
        value := (part = "") ? 0 : (part + 0)
        numbers.Push(value)
    }
}

