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
ExitApp(0)
