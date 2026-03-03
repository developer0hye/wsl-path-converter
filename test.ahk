#Requires AutoHotkey v2.0

global DefaultDistro := "Ubuntu-24.04"

#Include lib/convert.ahk

; ============================================================
;  Test runner
; ============================================================
global TotalTests := 0
global PassedTests := 0
global FailedTests := 0

Assert(input, expected, label := "") {
    global TotalTests, PassedTests, FailedTests
    TotalTests++
    actual := ConvertPath(input)
    if (actual = expected) {
        PassedTests++
        FileAppend("  PASS: " label "`n", "*")
    } else {
        FailedTests++
        FileAppend("  FAIL: " label "`n", "*")
        FileAppend("    input:    " input "`n", "*")
        FileAppend("    expected: " expected "`n", "*")
        FileAppend("    actual:   " actual "`n", "*")
    }
}

; ============================================================
;  Windows drive path -> WSL
; ============================================================
FileAppend("[Windows -> WSL]`n", "*")
Assert("C:\Users\foo", "/mnt/c/Users/foo", "basic backslash path")
Assert("D:\projects\app", "/mnt/d/projects/app", "D drive")
Assert("C:/Users/foo", "/mnt/c/Users/foo", "forward slash path")
Assert("C:\", "/mnt/c", "drive root")
Assert("C:\Users\foo\", "/mnt/c/Users/foo", "trailing backslash")
Assert("c:\users\foo", "/mnt/c/users/foo", "lowercase drive")
Assert("Z:\a\b\c", "/mnt/z/a/b/c", "Z drive")
Assert("C:\Program Files\app", "/mnt/c/Program Files/app", "path with spaces")

; ============================================================
;  WSL /mnt/X/... -> Windows drive path
; ============================================================
FileAppend("`n[WSL mount -> Windows]`n", "*")
Assert("/mnt/c/Users/foo", "C:\Users\foo", "basic mnt path")
Assert("/mnt/d/projects/app", "D:\projects\app", "D drive mnt")
Assert("/mnt/c", "C:\", "mnt drive root")
Assert("/mnt/c/", "C:\", "mnt drive root trailing slash")
Assert("/mnt/c/Users/foo/", "C:\Users\foo", "trailing slash")
Assert("/mnt/c/Program Files/app", "C:\Program Files\app", "path with spaces")

; ============================================================
;  WSL native path -> \\wsl.localhost\...
; ============================================================
FileAppend("`n[WSL native -> UNC]`n", "*")
Assert("/home/user", "\\wsl.localhost\Ubuntu-24.04\home\user", "home dir")
Assert("/home/user/.config", "\\wsl.localhost\Ubuntu-24.04\home\user\.config", "dotfile")
Assert("/etc/config", "\\wsl.localhost\Ubuntu-24.04\etc\config", "etc path")
Assert("/usr/local/bin", "\\wsl.localhost\Ubuntu-24.04\usr\local\bin", "usr path")
Assert("/tmp/test", "\\wsl.localhost\Ubuntu-24.04\tmp\test", "tmp path")
Assert("/var/log/syslog", "\\wsl.localhost\Ubuntu-24.04\var\log\syslog", "var path")
Assert("/opt/app", "\\wsl.localhost\Ubuntu-24.04\opt\app", "opt path")

; ============================================================
;  UNC WSL path -> WSL native path
; ============================================================
FileAppend("`n[UNC -> WSL native]`n", "*")
Assert("\\wsl$\Ubuntu-24.04\home\user", "/home/user", "wsl$ path")
Assert("\\wsl.localhost\Ubuntu-24.04\home\user", "/home/user", "wsl.localhost path")
Assert("\\wsl$\Ubuntu-24.04", "/", "wsl$ root")
Assert("\\WSL$\Ubuntu-24.04\etc\config", "/etc/config", "case insensitive wsl$")

; ============================================================
;  Non-path text (should return as-is)
; ============================================================
FileAppend("`n[Non-path passthrough]`n", "*")
Assert("hello world", "hello world", "plain text")
Assert("http://example.com", "http://example.com", "URL")
Assert("/api/v1/users", "/api/v1/users", "API route")
Assert("SELECT * FROM table", "SELECT * FROM table", "SQL")
Assert("foo/bar/baz", "foo/bar/baz", "relative path")
Assert("123", "123", "number")
Assert("", "", "empty string")

; ============================================================
;  Multi-line conversion
; ============================================================
FileAppend("`n[Multi-line]`n", "*")
global TotalTests += 1
multiInput := "C:\Users\foo`n/mnt/d/projects"
multiExpected := "/mnt/c/Users/foo`nD:\projects"
multiActual := ConvertMultiLine(multiInput)
if (multiActual = multiExpected) {
    global PassedTests += 1
    FileAppend("  PASS: multi-line mixed paths`n", "*")
} else {
    global FailedTests += 1
    FileAppend("  FAIL: multi-line mixed paths`n", "*")
    FileAppend("    expected: " multiExpected "`n", "*")
    FileAppend("    actual:   " multiActual "`n", "*")
}

global TotalTests += 1
multiPlain := "hello`nworld"
multiPlainResult := ConvertMultiLine(multiPlain)
if (multiPlainResult = multiPlain) {
    global PassedTests += 1
    FileAppend("  PASS: multi-line non-path unchanged`n", "*")
} else {
    global FailedTests += 1
    FileAppend("  FAIL: multi-line non-path unchanged`n", "*")
}

; ============================================================
;  Results
; ============================================================
FileAppend("`n========================================`n", "*")
FileAppend(TotalTests " tests, " PassedTests " passed, " FailedTests " failed`n", "*")

if (FailedTests > 0)
    ExitApp(1)
ExitApp(0)
