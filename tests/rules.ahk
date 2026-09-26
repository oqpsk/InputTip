#Requires AutoHotkey v2.0
#Warn All, Off
#NoTrayIcon

; Use an isolated fixture path supplied by the runner, never the user's config.
configFile := A_Args[1]
statsFile := configFile ".stats"
fontOpt := ["s16", "Microsoft YaHei"]
stateList := []
checks := 0
OnError((err, *) => (FileAppend(err.Message " at " err.File ":" err.Line "`n", "**"), ExitApp(1)))

#Include ..\src\core\fork-policy.ahk
#Include ..\src\core\config.ahk
#Include ..\src\core\ini.ahk
#Include ..\src\core\utils.ahk
#Include ..\src\core\i18n.ahk
#Include ..\src\core\var.ahk

assert(condition, label) {
    global checks
    if !condition
        throw Error(label)
    checks++
}

addRule(id, process, trigger) {
    section := "Window.Rule.20260926." id
    IniWrite(process, configFile, section, "process")
    IniWrite(trigger, configFile, section, "trigger")
}

assert(!var.chineseScriptEnabled, "feature defaults off")
assert(!var.checkUpdateOnStartup, "upstream updater defaults off")
assert(var.chineseScriptTraditionalKey == "Ctrl+Shift+F11", "traditional default")
assert(var.chineseScriptSimplifiedKey == "Ctrl+Shift+F12", "simplified default")
assert(getConflictGroup("setChineseScriptTraditional") == getConflictGroup("setChineseScriptSimplified"), "opposite script actions conflict")
assert(getConflictGroup("setChineseScriptTraditional") != getConflictGroup("switchStateCN-IME"), "CN and script coexist")
assert(getConflictGroup("setChineseScriptTraditional") != getConflictGroup("switchKeyboardCN"), "keyboard and script coexist")
for lang in ["zh-CN", "en-US"] {
    for key in ["trigger.setChineseScriptTraditional", "trigger.setChineseScriptSimplified", "chineseScriptEnabled", "chineseScript.help", "chineseScript.caution"]
        assert(langStrings[lang].Has(key), "translated: " lang " " key)
    assert(langStrings[lang]["inputMethod.tab"].Length == 3, "three settings tabs: " lang)
}

addRule(1, ".*", "setChineseScriptSimplified")
addRule(2, "FixtureGame.exe", "setChineseScriptTraditional")
addRule(3, "FixtureGame.exe", "switchStateCN-IME")
IniWrite("setChineseScriptTraditional", configFile, "Hotkey.Rule.20260926.4", "trigger")
IniWrite("^!t", configFile, "Hotkey.Rule.20260926.4", "hotkey")
writeIni("chineseScriptEnabled", 1)
writeIni("chineseScriptTraditionalKey", "Ctrl+Shift+F9")
writeIni("checkUpdateOnStartup", 1)
loadConfig()
parseWindowRule()
assert(var.chineseScriptEnabled == 1 && var.chineseScriptTraditionalKey == "Ctrl+Shift+F9", "config reload")
assert(var.checkUpdateOnStartup == 0, "old updater opt-in ignored")
assert(IniRead(configFile, "Window.Rule.20260926.2", "trigger") == "setChineseScriptTraditional", "rule retained after parse")
assert(var.hotkeyRule[""].Length == 1, "hotkey action registered")

exeProcess := "FixtureGame.exe", exeTitle := "Fixture", exeClass := "FixtureClass", exeControl := ""
hasProcessChange := true
triggers := returnTriggers()
assert(triggers.Length == 2, "game script and CN both selected")
assert(arrJoin(triggers, "|") ~= "setChineseScriptTraditional", "exact game beats fallback")
assert(!(arrJoin(triggers, "|") ~= "setChineseScriptSimplified"), "only one script action")
exeProcess := "FixtureEditor.exe"
triggers := returnTriggers()
assert(triggers.Length == 1 && triggers[1] == "setChineseScriptSimplified", "other process uses simplified fallback")
hasProcessChange := false
assert(returnTriggers().Length == 0, "no unconditional polling spam")
loadConfig()
parseWindowRule()
assert(var.WindowRule["setChineseScriptTraditional"].Has("FixtureGame.exe"), "rules survive second reload")
assert(IniRead(configFile, "Hotkey.Rule.20260926.4", "trigger") == "setChineseScriptTraditional", "hotkey rule retained")
FileAppend("PASS: " checks " rules/config/i18n checks`n", "*")
ExitApp(0)
