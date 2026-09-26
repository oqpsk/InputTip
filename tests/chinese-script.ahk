#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon
#Include ..\src\core\chinese-script.ahk
#Include ..\src\core\fork-policy.ahk

checks := 0
OnError((err, *) => (FileAppend(err.Message " at " err.Line "`n", "**"), ExitApp(1)))
assert(condition, label) {
    global checks
    if !condition
        throw Error(label)
    checks++
}

assert(!allowUpstreamUpdates(), "fork updater disabled")
assert(chineseScriptKeys().Length == 12, "all supported function keys offered")
for key in chineseScriptKeys()
    assert(chineseScriptSequence(key) != "", "UI key accepted: " key)
for key in ["", "F13", "Ctrl+Shift+F", "Ctrl+Alt+F0", "Ctrl+Alt+F13", "Ctrl+Alt+F11{Enter}", "^!{F11}"]
    assert(chineseScriptSequence(key) == "", "reject unsupported key: " key)
assert(chineseScriptSequence("Ctrl+Alt+F11") == "^!{F11}", "traditional key")
assert(chineseScriptSequence("Ctrl+Alt+F12") == "^!{F12}", "simplified key")
assert(chineseScriptBindingsValid("Ctrl+Alt+F11", "Ctrl+Alt+F12"), "distinct keys valid")
assert(!chineseScriptBindingsValid("Ctrl+Alt+F11", "Ctrl+Alt+F11"), "identical keys rejected")

sent := []
sender := (key) => sent.Push(key)
request := ChineseScriptRequest()
assert(!request.Queue("F13", 123, 0), "unsupported request rejected")
assert(!request.Queue("Ctrl+Alt+F11", 0, 0), "missing window rejected")
assert(request.Queue("Ctrl+Alt+F11", 123, 0), "request queued")
assert(request.Poll(123, true, 100, sender), "settling delay")
assert(sent.Length == 0, "no early key")
assert(request.Poll(123, false, 200, sender), "wait for modifiers or Chinese layout")
assert(!request.Poll(123, true, 225, sender), "send once ready")
assert(sent.Length == 1 && sent[1] == "^!{F11}", "correct sequence sent")
assert(!request.Poll(123, true, 300, sender) && sent.Length == 1, "no duplicate send")
request.Queue("Ctrl+Alt+F11", 123, 400)
request.Poll(123, true, 600, sender)
assert(sent.Length == 2 && sent[2] == sent[1], "reentry repeats set, never toggle")
request.Queue("Ctrl+Alt+F11", 123, 700)
assert(!request.Poll(456, true, 900, sender), "focus change cancels")
assert(!request.Poll(123, true, 950, sender) && sent.Length == 2, "return cannot revive stale request")
request.Queue("Ctrl+Alt+F11", 123, 1000)
assert(!request.Poll(123, false, 2000, sender) && sent.Length == 2, "bounded timeout")
request.Queue("Ctrl+Alt+F11", 123, 2200)
request.Cancel()
assert(!request.Poll(123, true, 2400, sender) && sent.Length == 2, "pause/disable cancellation")
request.Queue("Ctrl+Alt+F11", 123, 2500)
request.Queue("Ctrl+Alt+F12", 123, 2550)
request.Poll(123, true, 2750, sender)
assert(sent.Length == 3 && sent[3] == "^!{F12}", "latest request supersedes older one")
request.Queue("Ctrl+Alt+F11", 123, 2800)
assert(!request.Poll(123, true, 1, sender), "tick rollover fails closed")
FileAppend("PASS: " checks " dispatch/policy checks`n", "*")
ExitApp(0)
