; ============================================================
;  Path conversion logic (shared by main script and tests)
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
