; Jev Control.v1: asynchronous local IPC. No polling process or synthetic keys.
class JevJSON {
    static Parse(text) {
        if StrLen(text) > 65536
            throw Error("JSON too large")
        p := 1
        value := this.Value(text, &p, 0)
        this.Space(text, &p)
        if p <= StrLen(text)
            throw Error("Trailing JSON")
        return value
    }
    static Space(text, &p) {
        while p <= StrLen(text) && InStr(" `t`r`n", SubStr(text, p, 1))
            p++
    }
    static Value(text, &p, depth) {
        if depth > 16
            throw Error("JSON nesting")
        this.Space(text, &p)
        ch := SubStr(text, p, 1)
        if ch == '"'
            return this.String(text, &p)
        if ch == "{" || ch == "[" {
            object := ch == "{", result := object ? Map() : [], closing := object ? "}" : "]"
            p++
            this.Space(text, &p)
            if SubStr(text, p, 1) == closing {
                p++
                return result
            }
            loop {
                if object {
                    this.Space(text, &p)
                    key := this.String(text, &p)
                    if result.Has(key)
                        throw Error("Duplicate JSON key")
                    this.Space(text, &p)
                    if SubStr(text, p++, 1) != ":"
                        throw Error("JSON colon")
                }
                value := this.Value(text, &p, depth + 1)
                object ? result.Set(key, value) : result.Push(value)
                this.Space(text, &p)
                ch := SubStr(text, p++, 1)
                if ch == closing
                    return result
                if ch != ","
                    throw Error("JSON comma")
            }
        }
        for word, value in Map("true", 1, "false", 0, "null", "") {
            if SubStr(text, p, StrLen(word)) == word {
                p += StrLen(word)
                return value
            }
        }
        if RegExMatch(SubStr(text, p), "^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?", &m) {
            p += StrLen(m[0])
            return Number(m[0])
        }
        throw Error("Invalid JSON value")
    }
    static String(text, &p) {
        if SubStr(text, p++, 1) != '"'
            throw Error("JSON string")
        out := ""
        while p <= StrLen(text) {
            ch := SubStr(text, p++, 1)
            if ch == '"'
                return out
            if ch == "\" {
                ch := SubStr(text, p++, 1)
                switch ch {
                    case '"', "\", "/": out .= ch
                    case "n": out .= "`n"
                    case "r": out .= "`r"
                    case "t": out .= "`t"
                    case "b": out .= Chr(8)
                    case "f": out .= Chr(12)
                    case "u":
                        hex := SubStr(text, p, 4)
                        if !RegExMatch(hex, "^[0-9a-fA-F]{4}$")
                            throw Error("JSON Unicode")
                        out .= Chr(Integer("0x" hex)), p += 4
                    default: throw Error("JSON escape")
                }
            } else {
                if Ord(ch) < 32
                    throw Error("JSON control character")
                out .= ch
            }
        }
        throw Error("Unterminated JSON")
    }
}

class JevPipeRequest {
    done := false, aborted := false, reply := "", h := -1, event := 0, serverPID := 0
    __New(name, payload, timeout := 900, expectedPID := 0) {
        this.deadline := A_TickCount + timeout
        this.h := DllCall("CreateFileW", "str", name, "uint", 0xC0000000, "uint", 0, "ptr", 0,
            "uint", 3, "uint", 0x40000000, "ptr", 0, "ptr")
        if this.h == -1 {
            this.Finish()
            return
        }
        pid := 0
        if !DllCall("GetNamedPipeServerProcessId", "ptr", this.h, "uint*", &pid) || (expectedPID && expectedPID != pid) {
            this.Finish()
            return
        }
        this.serverPID := pid
        mode := 2
        if !DllCall("SetNamedPipeHandleState", "ptr", this.h, "uint*", &mode, "ptr", 0, "ptr", 0) {
            this.Finish()
            return
        }
        this.event := DllCall("CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")
        if !this.event {
            this.Finish()
            return
        }
        this.buffer := Buffer(StrPut(payload, "UTF-8"))
        StrPut(payload, this.buffer, "UTF-8")
        this.StartIO(true, this.buffer.Size - 1)
    }
    StartIO(write, length) {
        this.writing := write, this.length := length
        this.ov := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("ptr", this.event, this.ov, A_PtrSize == 8 ? 24 : 16)
        DllCall("ResetEvent", "ptr", this.event)
        ok := DllCall(write ? "WriteFile" : "ReadFile", "ptr", this.h, "ptr", this.buffer,
            "uint", length, "ptr", 0, "ptr", this.ov)
        if !ok && A_LastError != 997
            this.Finish()
    }
    Cancel() {
        if this.done || this.aborted
            return
        this.aborted := true
        DllCall("CancelIoEx", "ptr", this.h, "ptr", this.ov)
        ; Keep OVERLAPPED and its buffer alive until Poll observes completion.
    }
    Poll() {
        if this.done
            return true
        if A_TickCount >= this.deadline
            this.Cancel()
        n := 0
        ok := DllCall("GetOverlappedResult", "ptr", this.h, "ptr", this.ov, "uint*", &n, "int", 0)
        err := A_LastError
        if !ok && err == 996
            return false
        if this.aborted || !ok {
            this.Finish()
        } else if this.writing {
            if n != this.length {
                this.Finish()
            } else {
                this.buffer := Buffer(65536)
                this.StartIO(false, this.buffer.Size)
            }
        } else {
            if n
                this.reply := StrGet(this.buffer, n, "UTF-8")
            this.Finish()
        }
        return this.done
    }
    Finish() {
        this.done := true
        if this.event
            DllCall("CloseHandle", "ptr", this.event), this.event := 0
        if this.h != -1
            DllCall("CloseHandle", "ptr", this.h), this.h := -1
    }
}

class JevStateCache {
    hwnd := 0, at := 0, mode := ""
    Clear() => this.mode := ""
    Accept(reply, hwnd, now) {
        this.Clear()
        try {
            if Type(reply["v"]) != "Integer" || reply["v"] != 1 || reply["result"] != "ok" || Type(reply["state"]["valid"]) != "Integer" || reply["state"]["valid"] != 1 || reply["target"]["hwnd"] != hwnd
                return false
            mode := reply["state"]["mode"]
            if mode != "ascii" && mode != "zh_hans" && mode != "zh_hant"
                return false
            this.mode := mode, this.hwnd := hwnd, this.at := now
            return true
        }
        return false
    }
    State(base, hwnd, now) {
        if (base != "CN" && base != "EN") || this.hwnd != hwnd || now - this.at > 600 || now < this.at
            return base
        switch this.mode {
            case "ascii": return "EN"
            case "zh_hans": return "CN_S"
            case "zh_hant": return "CN_T"
        }
        return base
    }
}

class JevControl {
    static cache := JevStateCache(), inflight := 0, nextPoll := 0, seq := 0, hwnd := 0
    static serverPID := 0, hook := 0, hookCallback := 0, epoch := 0, seenEpoch := 0
    static wanted := 0, pendingID := 0, cancelID := 0, cancelHwnd := 0, lastResult := ""
    static PipeName() {
        session := 0
        if !DllCall("ProcessIdToSessionId", "uint", DllCall("GetCurrentProcessId", "uint"), "uint*", &session)
            return ""
        return "\\.\pipe\" A_UserName "\MoqiJev\Control.v1.s" session
    }
    static Request(op, hwnd, extra := "") {
        id := ++this.seq
        payload := '{"v":1,"op":"' op '","request_id":"' id '","hwnd":' hwnd extra '}'
        this.inflight := JevPipeRequest(this.PipeName(), payload, 900, op == "cancel" ? this.serverPID : 0)
        this.inflight.id := String(id), this.inflight.op := op, this.inflight.hwnd := hwnd
        this.inflight.epoch := this.epoch
    }
    static Queue(mode) {
        if !var.jevControlEnabled || var._paused
            return
        if !this.EnsureHook() {
            this.lastResult := "focus_events_unavailable"
            return
        }
        if matchWindowRules(var.WindowRule["ignoreKeyboardSwitch"]).Length || matchWindowRules(var.WindowRule["ignoreStateSwitch"]).Length
            return
        hwnd := WinExist("A") & 0xFFFFFFFF
        if !hwnd
            return
        this.CancelTarget()
        if this.inflight
            this.inflight.Cancel()
        this.hwnd := hwnd, this.cache.Clear()
        this.wanted := {hwnd: hwnd, mode: mode, until: A_TickCount + 10000, openAt: 0, epoch: this.epoch}
        ; Uses InputTip's existing per-window language switch. It cannot select
        ; a particular Chinese TSF profile; the pipe must confirm Jev afterward.
        if (IME.GetKeyboardLayout(IME.GetFocusedWindow()) & 0xFF) != 0x04
            IME.SwitchKeyboard("CN")
        this.nextPoll := 0
    }
    static CancelTarget() {
        this.wanted := 0
        if this.pendingID
            this.cancelID := this.pendingID, this.pendingID := 0
        if this.inflight && this.inflight.op == "set"
            this.cancelHwnd := this.inflight.hwnd
    }
    static EnsureHook() {
        if !this.hook {
            this.hookCallback := CallbackCreate(ObjBindMethod(this, "FocusChanged"), , 7)
            this.hook := DllCall("SetWinEventHook", "uint", 3, "uint", 3, "ptr", 0,
                "ptr", this.hookCallback, "uint", 0, "uint", 0, "uint", 0, "ptr")
            if !this.hook
                CallbackFree(this.hookCallback), this.hookCallback := 0
        }
        return this.hook
    }
    static FocusChanged(*) {
        this.epoch++
    }
    static Pump(hwnd) {
        enabled := var.jevControlEnabled && !var._paused
        hwnd &= 0xFFFFFFFF
        if this.epoch != this.seenEpoch {
            this.seenEpoch := this.epoch, this.cache.Clear(), this.nextPoll := 0
            if this.inflight && this.inflight.epoch != this.epoch {
                if this.inflight.op == "set"
                    this.cancelHwnd := this.inflight.hwnd
                this.inflight.Cancel()
            }
        }
        if hwnd != this.hwnd {
            this.hwnd := hwnd, this.cache.Clear(), this.CancelTarget(), this.nextPoll := 0
            if this.inflight
                this.inflight.Cancel()
        }
        if !enabled {
            this.cache.Clear(), this.CancelTarget()
            if this.inflight && this.inflight.op != "cancel"
                this.inflight.Cancel()
        }
        if this.wanted && (this.wanted.hwnd != hwnd || this.wanted.epoch != this.epoch || A_TickCount >= this.wanted.until)
            this.CancelTarget()
        if this.inflight {
            if !this.inflight.Poll()
                return
            request := this.inflight
            this.inflight := 0
            if request.serverPID && request.serverPID != this.serverPID {
                this.serverPID := request.serverPID, this.pendingID := 0, this.cancelID := 0
            }
            if !request.aborted && request.hwnd == hwnd && request.epoch == this.epoch && enabled {
                this.cache.Clear()
                try {
                    reply := JevJSON.Parse(request.reply)
                    if reply["v"] == 1 && reply["request_id"] == request.id && reply["op"] == request.op {
                        this.lastResult := reply["result"]
                        this.cache.Accept(reply, hwnd, A_TickCount)
                        if request.op == "set" {
                            this.wanted := 0
                            if reply["result"] == "pending"
                                this.pendingID := reply["pending"]["id"]
                        } else if request.op == "query" && this.wanted {
                            this.TrySet(reply, hwnd)
                        }
                    }
                }
            }
            this.nextPoll := A_TickCount + 200
        }
        if this.inflight
            return
        if this.cancelID || this.cancelHwnd {
            id := this.cancelID, root := this.cancelHwnd ? this.cancelHwnd : hwnd
            this.cancelID := 0, this.cancelHwnd := 0
            this.Request("cancel", root, ',"pending_id":' id)
        } else if enabled && hwnd && A_TickCount >= this.nextPoll {
            this.Request("query", hwnd)
        }
    }
    static TrySet(reply, hwnd) {
        if !this.wanted || this.wanted.hwnd != hwnd || reply["target"]["hwnd"] != hwnd || !reply["jev"]["active"]
            return
        if !reply["jev"]["keyboard_open"] {
            if reply["jev"]["thread_focus"] && reply["jev"]["document_focus"] && !reply["jev"]["input_disabled"] && A_TickCount - this.wanted.openAt >= 500 {
                if (WinExist("A") & 0xFFFFFFFF) == hwnd {
                    IME.SetOpenStatus(true, IME.GetFocusedWindow())
                    this.wanted.openAt := A_TickCount
                }
            }
            return
        }
        this.Request("set", hwnd, ',"mode":"' this.wanted.mode '","defer_ms":10000')
    }
    static DisplayState(base) {
        if !var.jevControlEnabled || var._paused
            return base
        return this.cache.State(base, WinExist("A") & 0xFFFFFFFF, A_TickCount)
    }
}

jevOverlayStates() => ["EN", "CN", "CN_S", "CN_T", "Caps", "US", "JP", "KR"]
