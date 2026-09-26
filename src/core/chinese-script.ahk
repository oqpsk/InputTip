; Only deterministic Rime bindings; never toggle or infer the current script.
chineseScriptKeys() {
    keys := []
    loop 12
        keys.Push("Ctrl+Alt+F" A_Index)
    return keys
}

chineseScriptSequence(key) {
    if RegExMatch(key, "^Ctrl\+Alt\+(F(?:[1-9]|1[0-2]))$", &match)
        return "^!{" match[1] "}"
    return ""
}

chineseScriptBindingsValid(traditional, simplified) =>
    chineseScriptSequence(traditional) != "" && chineseScriptSequence(simplified) != "" && traditional != simplified

; Accept observations and an injected sender for desktop-free regression tests.
class ChineseScriptRequest {
    pending := 0

    Queue(key, hwnd, now) {
        this.Cancel()
        if !hwnd || !chineseScriptSequence(key)
            return false
        this.pending := { key: key, hwnd: hwnd, started: now }
        return true
    }

    Cancel() {
        this.pending := 0
    }

    Poll(hwnd, ready, now, sender) {
        if !this.pending
            return false
        request := this.pending
        elapsed := now - request.started
        if hwnd != request.hwnd || elapsed < 0 || elapsed >= 1000 {
            this.Cancel()
            return false
        }
        ; Allow existing state/keyboard actions to finish and Alt+Tab to release.
        if elapsed < 150 || !ready
            return true
        this.Cancel()
        sender.Call(chineseScriptSequence(request.key))
        return false
    }
}

requestChineseScript(mode) {
    static request := ChineseScriptRequest()
    SetTimer(deliver, 0)
    request.Cancel()
    if !var.chineseScriptEnabled || var._paused
        return
    if !chineseScriptBindingsValid(var.chineseScriptTraditionalKey, var.chineseScriptSimplifiedKey)
        return
    switch mode {
        case "traditional": key := var.chineseScriptTraditionalKey
        case "simplified": key := var.chineseScriptSimplifiedKey
        default: return
    }
    if request.Queue(key, WinExist("A"), A_TickCount)
        SetTimer(deliver, 25)

    deliver() {
        try {
            if !var.chineseScriptEnabled || var._paused {
                request.Cancel()
                SetTimer(deliver, 0)
                return
            }
            ; Preserve the current Chinese IME instead of selecting another one.
            ready := (IME.GetKeyboardLayout(IME.GetFocusedWindow()) & 0xFF) == 0x04
            for modifier in ["LAlt", "RAlt", "LControl", "RControl", "LShift", "RShift", "LWin", "RWin"] {
                if GetKeyState(modifier, "P") || GetKeyState(modifier)
                    ready := false
            }
            if !request.Poll(WinExist("A"), ready, A_TickCount, SendInput)
                SetTimer(deliver, 0)
        } catch {
            request.Cancel()
            SetTimer(deliver, 0)
        }
    }
}
