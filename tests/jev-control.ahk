#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include ..\src\core\jev-control.ahk
OnError((err, *) => (FileAppend(err.Message " at " err.File ":" err.Line "`n", "**"), ExitApp(1)))
checks := 0
assert(condition, label) {
    global checks
    if !condition
        throw Error(label)
    checks++
}
for bad in ['{"v":1,"v":2}', '{"x":true,}', '[1,]', '{"x":"\q"}', '[] trailing', '{"x":01}'] {
    rejected := false
    try JevJSON.Parse(bad)
    catch
        rejected := true
    assert(rejected, "invalid JSON rejected: " bad)
}
assert(JevJSON.Parse('{"value":"\u7e41\u9ad4","array":[true,false,-1.5]}')["value"] == "繁體", "Unicode JSON")
cache := JevStateCache()
for mode, state in Map("ascii", "EN", "zh_hans", "CN_S", "zh_hant", "CN_T") {
    reply := JevJSON.Parse('{"v":1,"result":"ok","target":{"hwnd":123},"state":{"valid":true,"mode":"' mode '"}}')
    assert(cache.Accept(reply, 123, 1000), "accept " mode)
    assert(cache.State("CN", 123, 1100) == state, "display " mode)
    assert(cache.State("EN", 123, 1100) == state, "Jev overrides unreliable legacy mode " mode)
    assert(cache.State("US", 123, 1100) == "US", "ENG keyboard wins")
    assert(cache.State("Caps", 123, 1100) == "Caps", "CapsLock wins")
    assert(cache.State("CN", 456, 1100) == "CN", "another window is unknown")
    assert(cache.State("CN", 123, 1700) == "CN", "expired cache is unknown")
    reply["state"]["valid"] := false
    assert(!cache.Accept(reply, 123, 1000) && cache.State("CN", 123, 1100) == "CN", "invalid clears old state")
}
assert(jevOverlayStates().Length == 8, "overlay states remain separate")
request := JevPipeRequest("\\.\pipe\InputTip-missing-test-" DllCall("GetCurrentProcessId"), '{}', 50)
assert(request.Poll() && request.reply == "", "missing pipe fails without blocking")
FileAppend("PASS: " checks " Jev parser/cache/client checks`n", "*")
ExitApp(0)
