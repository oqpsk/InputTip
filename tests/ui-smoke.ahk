#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon

configFile := A_Args[1]
statsFile := configFile ".stats"
stateList := []
OnError((err, *) => (FileAppend(err.Message " at " err.File ":" err.Line "`n", "**"), ExitApp(1)))
#Include ..\src\core\fork-policy.ahk
#Include ..\src\core\gui.ahk
#Include ..\src\core\config.ahk
#Include ..\src\core\ini.ahk
#Include ..\src\core\utils.ahk
#Include ..\src\core\i18n.ahk
#Include ..\src\core\var.ahk
#Include ..\src\core\ui.ahk
#Include ..\src\core\input-method.ahk
#Include ..\src\core\tray-menu.ahk

for lang in ["zh-CN", "en-US"] {
    currentLang := lang
    isChinese := lang == "zh-CN"
    g := createGui(inputModeGui)
    g.Show("Hide AutoSize")
    foundTraditional := false, foundSimplified := false, foundHelp := false
    for hwnd, ctrl in g {
        if ctrl.Type == "Tab3" {
            ctrl.Value := 3
            if ctrl.Text != i18n("inputMethod.tab", 1)[3]
                throw Error("Third tab missing: " lang)
        }
        if ctrl.Type == "DDL" {
            if ctrl.Text == var.chineseScriptTraditionalKey
                foundTraditional := true
            if ctrl.Text == var.chineseScriptSimplifiedKey
                foundSimplified := true
        }
        if ctrl.Type == "Text" && ctrl.Text == i18n("chineseScript.help")
            foundHelp := true
    }
    if !(foundTraditional && foundSimplified && foundHelp)
        throw Error("Script settings controls missing: " lang)
    g.Destroy()
    FileAppend("PASS: hidden native settings dialog " lang "`n", "*")
}
stateList := ["CN", "EN", "Caps", "US", "JP", "KR"]
stateVal := {}
for state in stateList
    stateVal.%state% := {color: "0x123456", colorText: "red"}
writeIni("overlayTextCN", "Existing Chinese label")
writeIni("overlayBgColorCN", "0x800000")
writeIni("overlayTextSizeCN", 22)
loadConfig()
if var.overlayTextCN != "Existing Chinese label" || var.overlayBgColorCN_S != "0x800000" || var.overlayTextSizeCN_T != 22
    throw Error("Overlay migration lost old styling")
#Include ..\src\core\overlay.ahk
for lang in ["zh-CN", "en-US"] {
    currentLang := lang, isChinese := lang == "zh-CN"
    g := createGui(overlayStyleGui)
    g.Show("Hide AutoSize")
    foundS := false, foundT := false
    for hwnd, ctrl in g {
        if ctrl.Type == "Text" && ctrl.Text == i18n("CN_S")
            foundS := true
        if ctrl.Type == "Text" && ctrl.Text == i18n("CN_T")
            foundT := true
    }
    if !(foundS && foundT)
        throw Error("Missing separate script style sections: " lang)
    g.Destroy()
    FileAppend("PASS: hidden script overlay settings " lang "`n", "*")
}
writeIni("overlayTextCN_S", "Custom Simplified")
loadConfig()
if var.overlayTextCN != "Existing Chinese label" || var.overlayTextCN_S != "Custom Simplified"
    throw Error("Independent overlay settings did not survive reload")
FileAppend("PASS: overlay config inheritance and independent reload`n", "*")
ExitApp(0)
