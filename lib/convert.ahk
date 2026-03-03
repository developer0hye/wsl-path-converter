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
    ;    Convert only known top-level directories to avoid API-like strings (/api/...)
    if (RegExMatch(path, "^/([^/\r\n]+)(?:/(.*)|$)", &m)) {
        topLevel := StrLower(m[1])
        if (!IsKnownWslTopLevel(topLevel))
            return path
        ; Mixed slash styles are treated as non-path text.
        if (InStr(path, "\"))
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

ConvertPathPreservingQuotes(text) {
    candidate := text
    quote := ""

    if (StrLen(candidate) >= 2) {
        first := SubStr(candidate, 1, 1)
        last := SubStr(candidate, -1)
        if ((first = '"' && last = '"') || (first = "'" && last = "'")) {
            quote := first
            candidate := SubStr(candidate, 2, -1)
        }
    }

    converted := ConvertPath(candidate)
    if (converted = candidate)
        return text
    if (quote != "")
        return quote converted quote
    return converted
}

ConvertClipboardText(text) {
    if (InStr(text, "`n"))
        return ConvertMultiLine(text)

    leadingTrimmed := LTrim(text, " `t`r`n")
    leadingLen := StrLen(text) - StrLen(leadingTrimmed)
    core := RTrim(leadingTrimmed, " `t`r`n")
    trailingLen := StrLen(leadingTrimmed) - StrLen(core)

    if (core = "")
        return text

    leading := leadingLen > 0 ? SubStr(text, 1, leadingLen) : ""
    trailing := trailingLen > 0 ? SubStr(leadingTrimmed, StrLen(core) + 1) : ""
    converted := ConvertPathPreservingQuotes(core)

    if (converted = core)
        return text
    return leading converted trailing
}

ConvertMultiLine(text) {
    lines := StrSplit(text, "`n")
    result := ""
    anyConverted := false
    for i, line in lines {
        lineOut := line

        ; Keep CRLF when splitting by LF.
        trailingCR := ""
        if (RegExMatch(lineOut, "`r$")) {
            trailingCR := "`r"
            lineOut := SubStr(lineOut, 1, -1)
        }

        ; Preserve indentation and trailing spaces/tabs around the path.
        leadingTrimmed := LTrim(lineOut, " `t")
        leadingLen := StrLen(lineOut) - StrLen(leadingTrimmed)
        core := RTrim(leadingTrimmed, " `t")
        trailingLen := StrLen(leadingTrimmed) - StrLen(core)

        if (core != "") {
            leading := leadingLen > 0 ? SubStr(lineOut, 1, leadingLen) : ""
            trailing := trailingLen > 0 ? SubStr(leadingTrimmed, StrLen(core) + 1) : ""
            converted := ConvertPathPreservingQuotes(core)
            if (converted != core) {
                anyConverted := true
                lineOut := leading converted trailing
            }
        }

        lineOut .= trailingCR
        result .= (i > 1 ? "`n" : "") lineOut
    }
    if (!anyConverted)
        return text
    return result
}

IsKnownWslTopLevel(name) {
    static roots := Map(
        "home", true,
        "etc", true,
        "usr", true,
        "var", true,
        "tmp", true,
        "opt", true,
        "root", true,
        "srv", true,
        "bin", true,
        "sbin", true,
        "lib", true,
        "lib64", true,
        "dev", true,
        "proc", true,
        "sys", true,
        "run", true,
        "mnt", true,
        "media", true,
        "boot", true,
        "snap", true
    )
    return roots.Has(name)
}
