#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
;  WSL Path Converter
;  Ctrl+Shift+V : 클립보드의 경로를 WSL <-> Windows 변환 후 붙여넣기
; ============================================================

TraySetIcon("shell32.dll", 44)
A_IconTip := "WSL Path Converter (Ctrl+Shift+V)"

; --- 시작 시 기본 WSL 배포판 자동 감지 ---
global DefaultDistro := DetectDefaultDistro()

; --- Tray 메뉴 ---
tray := A_TrayMenu
tray.Delete()
tray.Add("WSL Path Converter", (*) => "")
tray.Disable("WSL Path Converter")
tray.Add()
tray.Add("배포판: " DefaultDistro, (*) => "")
tray.Disable("배포판: " DefaultDistro)
tray.Add()
tray.Add("종료", (*) => ExitApp())

; ============================================================
;  Ctrl+Shift+V  →  경로 변환 후 붙여넣기
; ============================================================
^+v:: {
    ; 클립보드가 텍스트가 아니면 (이미지/파일 등) 원본 그대로 붙여넣기
    if (A_Clipboard = "" && DllCall("IsClipboardFormatAvailable", "UInt", 1) = 0) {
        Send("^v")
        return
    }

    rawText := A_Clipboard

    ; 멀티라인이면 각 줄을 개별 변환 시도
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

    ; 따옴표 제거는 경로 판정 후에만 (원본 텍스트 보존 위해 별도 변수 사용)
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

    ; 변환되지 않았으면 (경로가 아닌 텍스트) 원본 그대로 붙여넣기
    if (converted = pathCandidate) {
        Send("^v")
        return
    }

    PasteConverted(converted)
}

; ============================================================
;  변환된 텍스트 붙여넣기 (클립보드 보존)
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
;  멀티라인 처리: 각 줄을 개별 변환
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
;  경로 변환 로직
; ============================================================
ConvertPath(path) {
    ; 1) Windows 드라이브 경로 → WSL
    ;    C:\Users\foo  →  /mnt/c/Users/foo
    ;    D:/projects   →  /mnt/d/projects
    if (RegExMatch(path, "^([A-Za-z]):[\\\/](.*)", &m)) {
        drive := StrLower(m[1])
        rest := StrReplace(m[2], "\", "/")
        rest := RTrim(rest, "/")
        if (rest = "")
            return "/mnt/" drive
        return "/mnt/" drive "/" rest
    }

    ; 2) \\wsl$\Distro\path  또는  \\wsl.localhost\Distro\path → WSL 경로
    if (RegExMatch(path, "i)^\\\\(?:wsl\$|wsl\.localhost)\\[^\\]+\\?(.*)", &m)) {
        rest := StrReplace(m[1], "\", "/")
        rest := RTrim(rest, "/")
        if (rest = "")
            return "/"
        return "/" rest
    }

    ; 3) WSL /mnt/X/... → Windows 드라이브 경로
    ;    /mnt/c/Users/foo  →  C:\Users\foo
    if (RegExMatch(path, "^/mnt/([a-zA-Z])(?:/(.*)|$)", &m)) {
        drive := StrUpper(m[1])
        rest := m.Count >= 2 ? m[2] : ""
        rest := StrReplace(rest, "/", "\")
        rest := RTrim(rest, "\")
        if (rest = "")
            return drive ":\"
        return drive ":\" rest
    }

    ; 4) WSL 고유 경로 → \\wsl.localhost\Distro\path
    ;    /home/user  →  \\wsl.localhost\Ubuntu-24.04\home\user
    ;    /etc/config →  \\wsl.localhost\Ubuntu-24.04\etc\config
    ;    경로처럼 보이지 않는 /텍스트는 변환하지 않음
    if (RegExMatch(path, "^/([a-zA-Z0-9._-]+(?:/[a-zA-Z0-9._@:~-]*)*)", &m)) {
        matched := m[0]
        ; 전체 입력이 매치와 같을 때만 변환 (뒤에 공백이나 다른 문자가 있으면 경로 아님)
        if (matched != path)
            return path
        ; 최소한 알려진 WSL 최상위 디렉토리로 시작해야 변환
        if (!RegExMatch(path, "^/(home|etc|usr|var|tmp|opt|root|srv|bin|sbin|lib|lib64|dev|proc|sys|run|mnt|media|boot|snap)\b"))
            return path
        rest := StrReplace(SubStr(path, 2), "/", "\")
        rest := RTrim(rest, "\")
        if (rest = "")
            return "\\wsl.localhost\" DefaultDistro
        return "\\wsl.localhost\" DefaultDistro "\" rest
    }

    ; 인식되지 않는 형식이면 원본 그대로 반환
    return path
}

; ============================================================
;  기본 WSL 배포판 감지 (wsl --status 로 default 확인 → 폴백: -l -v 파싱)
; ============================================================
DetectDefaultDistro() {
    ; 방법 1: wsl --status (Windows 11+) 에서 기본 배포판 직접 읽기
    try {
        tempFile := A_Temp "\wsl_status_detect.txt"
        RunWait(A_ComSpec ' /c wsl.exe --status > "' tempFile '" 2>nul', , "Hide")
        content := FileRead(tempFile, "UTF-16")
        FileDelete(tempFile)
        ; "기본 배포: XXX" 또는 "Default Distribution: XXX" 패턴 매칭
        if (RegExMatch(content, "im)(?:Default Distribution|기본 배포[^:]*)[:\s]+(.+)", &m)) {
            distro := Trim(m[1], " `r`n`0")
            if (distro != "")
                return distro
        }
    } catch {
    }

    ; 방법 2: wsl -l -v 에서 * 표시된 기본 배포판 찾기
    try {
        tempFile := A_Temp "\wsl_list_detect.txt"
        RunWait(A_ComSpec ' /c wsl.exe -l -v > "' tempFile '" 2>nul', , "Hide")
        content := FileRead(tempFile, "UTF-16")
        FileDelete(tempFile)
        ; * 로 표시된 기본 배포판 찾기
        if (RegExMatch(content, "m)^\s*\*\s+(\S+)", &m)) {
            distro := Trim(m[1], " `r`n`0")
            if (distro != "")
                return distro
        }
    } catch {
    }

    ; 방법 3: wsl -l -q 첫 줄 (레거시 폴백)
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
