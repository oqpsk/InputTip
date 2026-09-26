#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include ..\src\core\jev-control.ahk
OnError((err, *) => (FileAppend(err.Message " at " err.File ":" err.Line "`n", "**"), ExitApp(1)))
Call(payload) {
    request := JevPipeRequest(A_Args[1], payload)
    endTick := jevTick() + 2000
    while !request.Poll() {
        if jevTick() > endTick
            throw Error("IPC stuck")
        Sleep(1)
    }
    return JevJSON.Parse(request.reply)
}
reply := Call('{"v":1,"op":"query","request_id":"1","hwnd":65552}')
if reply["state"]["mode"] != "zh_hans"
    throw Error("Initial query")
reply := Call('{"v":1,"op":"set","request_id":"2","hwnd":65552,"mode":"zh_hant"}')
if reply["result"] != "ok" || !reply["changed"]
    throw Error("Set traditional")
reply := Call('{"v":1,"op":"set","request_id":"3","hwnd":65552,"mode":"zh_hant"}')
if reply["result"] != "ok" || reply["changed"]
    throw Error("Repeat set is not idempotent")
cache := JevStateCache()
loop 25 {
    reply := Call('{"v":1,"op":"query","hwnd":65552}')
    if !cache.Accept(reply, 65552, jevTick()) || cache.State("CN", 65552, jevTick()) != "CN_T"
        throw Error("Polling traditional state")
}
request := JevPipeRequest(A_Args[2], '{"v":1,"op":"query"}', 60)
endTick := jevTick() + 1500
while !request.Poll() {
    if jevTick() > endTick
        throw Error("Cancellation stuck")
    Sleep(1)
}
if !request.aborted || request.reply != ""
    throw Error("Silent server did not time out")
class FixtureControl extends JevControl {
    static PipeName() => A_Args[1]
}
var := {jevControlEnabled: 1, _paused: 0}
FixtureControl.hwnd := 65552
FixtureControl.wanted := {hwnd: 65552, mode: "zh_hans", until: jevTick() + 5000, openAt: 0, epoch: FixtureControl.epoch}
endTick := jevTick() + 3000
loop {
    FixtureControl.Pump(65552)
    if !FixtureControl.wanted && FixtureControl.cache.State("EN", 65552, jevTick()) == "CN_S"
        break
    if jevTick() >= endTick
        throw Error("Pump did not finish query/set/confirm")
    Sleep(1)
}
; A rapid away/back must discard a queued target even with the same HWND.
FixtureControl.wanted := {hwnd: 65552, mode: "zh_hant", until: jevTick() + 5000, epoch: FixtureControl.epoch}
FixtureControl.FocusChanged(), FixtureControl.FocusChanged()
FixtureControl.Pump(65552)
if FixtureControl.wanted
    throw Error("Focus epoch resurrected a queued target")
FileAppend("PASS: real AHK/Go pipe query, set, idempotence, 25 polls and asynchronous cancellation`n", "*")
FileAppend("PASS: InputTip pump query/set confirmation and away/back cancellation`n", "*")
ExitApp(0)
